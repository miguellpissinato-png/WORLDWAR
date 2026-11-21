extends Node
## Tela principal: mapa mundial + tela de escolha de país + barra superior + painéis.
## Toda ação do jogador vira um comando enviado à simulação.

## Horas de jogo por segundo real em cada velocidade (1 a 5).
const HOURS_PER_SECOND := [2.0, 6.0, 12.0, 24.0, 72.0]

var sim: Simulation
var player_tag := ""
var paused := true
var speed := 1
var selected_state := -1
var started := false
var _accum := 0.0
var _events_seen := 0
var _map_mode := "political"

var map: MapView
var labels: MapLabels
var camera: MapCamera
var units: UnitLayer

var _root: Control
var _game_ui: Control
var _start: StartScreen
var _menu: MainMenu
var _economy: EconomyPanel
var _market: MarketPanel
var _intel: IntelPanel
var _research: ResearchPanel
var _production: ProductionPanel
var _army: ArmyPanel
var _date_label: Label
var _date_sub: Label
var _date_box: PanelContainer
var _pause_button: Button
var _speed_bars: Array = []   # ColorRect de cada barrinha de velocidade
var _flag: PanelContainer
var _country_label: Label
var _peace_label: Label
var _peace_dot: Panel
var _war_dialog: PanelContainer
var _nation_button: Button
var _chips := {}              # id -> {button, value, extra...}
var _res_button: Button
var _res_cells := {}          # recurso -> {box, value}
var _alert_button: Button
var _alert_badge: PanelContainer
var _alert_count: Label
var _newspaper: Newspaper
var _news_read := 0          # notícias já vistas no jornal (contador de GameState.news_count)
var _news_toasted := 0
var _extra: PanelContainer   # aviso "EXTRA!" de notícia grande
var _extra_timer := 0.0
var _events_read := 0         # avisos do jogador já vistos no sino
var _drop: PanelContainer     # caixa que abre embaixo da barra (recursos, tesouro, avisos...)
var _drop_kind := ""
var _drop_anchor: Control
var _prev_stock := {}
var _stock_delta := {}        # recurso -> variação do estoque no último dia
var _map_mode_buttons := {}
var _state_title: Label
var _state_sub: Label
var _state_flag: PanelContainer
var _nav_buttons := {}     # id -> Button do menu lateral
var _panels := {}          # id -> janela
var _queue_box: VBoxContainer
var _state_panel: PanelContainer
var _state_info: RichTextLabel
var _build_box: VBoxContainer
var _spy_button: Button
var _hover_label: Label
var _log: RichTextLabel


func _ready() -> void:
	var defs := ScenarioLoader.load_defs()
	var loading := SaveGame.pending
	SaveGame.pending = {}
	if loading.is_empty():
		sim = Simulation.new(ScenarioLoader.load_scenario(SCENARIO, defs), defs)
	else:
		sim = SaveGame.replay(loading, ScenarioLoader.load_scenario(String(loading.get("scenario", SCENARIO)), defs), defs)
	sim.command_rejected.connect(func(_c, reason): write_log("[color=#e08070]Ordem recusada:[/color] " + reason))
	sim.day_passed.connect(func(_h): _on_day())
	sim.command_applied.connect(func(_c): _refresh_all.call_deferred())

	map = MapView.new()
	add_child(map)
	map.load_shapes()
	map.color_by_owner(sim.state)
	map.state_clicked.connect(_on_state_clicked)
	map.state_hovered.connect(_on_state_hovered)
	map.sea_hovered.connect(_on_sea_hovered)

	labels = MapLabels.new()
	add_child(labels)
	labels.build(sim.state, map)

	units = UnitLayer.new()
	add_child(units)
	units.setup(self)
	units.group_selected.connect(func(_id):
		_army.refresh()
		_refresh_group_card())

	camera = MapCamera.new()
	camera.map_size = map.map_size
	add_child(camera)
	camera.zoom_changed.connect(func(z):
		map.set_zoom(z)
		labels.set_zoom(z))
	camera.position = sim.state.state(sim.state.country("ALE").capital_state).center
	camera.set_zoom_level(0.9)

	_build_ui()
	_start.select("BRA")
	if not loading.is_empty():
		_enter_game(String(loading.player))
		write_log("Jogo carregado: %s." % GameDate.format(sim.state.hours))


func _process(delta: float) -> void:
	if _extra != null:
		_extra_timer -= delta
		if _extra_timer <= 0.0:
			_hide_extra()
	if started and _briefing_pending and sim.state.objectives.has(player_tag):
		_briefing_pending = false
		_briefing.open_briefing(player_tag, not mp, mp)
		_refresh_top_bar()
	if started and sim.state.winner != "" and not _result_shown:
		_result_shown = true
		if not mp:
			paused = true
			_update_time_controls()
		_briefing.open_result(player_tag)
	if started and sim.state.control_version != _control_seen:
		_control_seen = sim.state.control_version
		_apply_map_mode()
		_refresh_state_panel()
	if started and not paused:
		_accum += delta * HOURS_PER_SECOND[speed - 1]
		var whole := int(_accum)
		if whole > 0:
			_accum -= whole
			if not mp or Net.is_host:
				sim.advance_hours(whole)
				if mp:
					Net.broadcast_advance(whole)
	if _date_label != null:
		_update_date()
	if _drop_kind != "":
		_place_drop()


## Clique fora da caixa aberta da barra superior fecha a caixa (sem consumir o clique).
func _input(event: InputEvent) -> void:
	if _drop_kind == "" or not (event is InputEventMouseButton) or not event.pressed:
		return
	var p: Vector2 = event.position
	if _drop.get_global_rect().has_point(p) or _top_bar_rect().has_point(p):
		return
	_close_drop()


func _unhandled_input(event: InputEvent) -> void:
	if not started:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_toggle_pause()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
			_set_speed(event.keycode - KEY_0)
		elif event.keycode == KEY_ESCAPE:
			_on_escape()
			get_viewport().set_input_as_handled()


## Ordem de marcha vinda do mapa. Se o caminho passa por um país com quem não estamos em guerra,
## abre o aviso de fronteira (cancelar, justificar ou declarar guerra) em vez de mandar a ordem.
func order_move(group_id: int, sid: int) -> void:
	var g := sim.state.group(group_id)
	if g == null:
		return
	var cmd := MoveGroupCommand.create(player_tag, group_id, sid)
	var reason := cmd.validate(sim.state, sim.defs)
	if reason == "":
		submit(cmd)
		units.preview(-1)
		return
	var dest_owner: String = sim.state.state(sid).owner
	var blocker := ""
	if not sim.state.can_enter(player_tag, dest_owner):
		blocker = dest_owner
	else:
		var from: int = g.path[0] if g.moving() else g.state_id
		blocker = ArmySystem.route_blocker(sim.state, from, sid, player_tag)
	if blocker != "":
		_show_war_dialog(blocker, group_id, sid)
	elif reason != "o grupo já está lá" and reason != "o grupo já vai para lá":
		write_log("[color=#e08070]Ordem recusada:[/color] " + reason)


## Envia uma ordem e aplica na hora (jogo solo: este computador é o "host").
func submit(cmd: Command) -> void:
	if mp and not Net.is_host:
		Net.send_command(cmd.to_dict())   # o host aplica e devolve para todos
		return
	sim.submit(cmd)
	sim.apply_pending()
	if mp:
		Net.broadcast_command(cmd.to_dict())


func write_log(line: String) -> void:
	_log.append_text("[color=%s][%s][/color] %s\n" % [UiStyle.ACCENT_HEX, sim.state.date_text().split(",")[0], line])


# ---------------------------------------------------------------- início do jogo

func _start_game(tag: String) -> void:
	submit(ClaimCountryCommand.create(tag))
	_enter_game(tag)
	_ui_rng.randomize()
	var c := ObjectiveSystem.candidates(sim.state, sim.defs, tag)
	if not c.is_empty():
		submit(SetObjectivesCommand.create({tag: c[_ui_rng.randi() % c.size()]}))
	_briefing_pending = true


func _reroll_objective() -> void:
	var cur: String = sim.state.objectives.get(player_tag, "")
	var c := ObjectiveSystem.candidates(sim.state, sim.defs, player_tag).filter(func(o): return o != cur)
	if not c.is_empty():
		submit(SetObjectivesCommand.create({player_tag: c[_ui_rng.randi() % c.size()]}))
	_briefing.open_briefing(player_tag, true, false)


## Partida em rede: todos entram juntos; o host registra cada jogador no seu país.
func _start_mp(my_tag: String) -> void:
	mp = true
	_mp_screen.visible = false
	_enter_game(my_tag)
	paused = true
	_update_time_controls()
	_briefing_pending = true
	if Net.is_host:
		var ids: Array = Net.players.keys()
		ids.sort()
		for id in ids:
			submit(ClaimCountryCommand.create(String(Net.players[id].tag)))
		submit(SetObjectivesCommand.create(_mp_objectives(ids)))
	write_log("Partida em rede: %s." % ", ".join(Net.players.values().map(func(p): return "%s (%s)" % [p.nick, sim.state.country(p.tag).name])))


## Host: objetivos da partida em rede. Individual = um sorteado para cada jogador (secreto);
## comum = o mais votado na sala (empate: sorteio entre os mais votados), igual para todos.
func _mp_objectives(ids: Array) -> Dictionary:
	_ui_rng.randomize()
	var out := {}
	if Net.objective_mode == "comum":
		var votes := {}
		for id in ids:
			var vt := String(Net.players[id].get("vote", ""))
			if vt != "":
				votes[vt] = int(votes.get(vt, 0)) + 1
		var best := []
		var top := 0
		for k in votes:
			if votes[k] > top:
				top = votes[k]
				best = [k]
			elif votes[k] == top:
				best.append(k)
		if best.is_empty():
			best = ObjectiveSystem.list(sim.defs).map(func(o): return o.id)
		best.sort()
		var chosen: String = best[_ui_rng.randi() % best.size()]
		for id in ids:
			out[String(Net.players[id].tag)] = chosen
	else:
		for id in ids:
			var tag := String(Net.players[id].tag)
			var c := ObjectiveSystem.candidates(sim.state, sim.defs, tag)
			if c.is_empty():
				c = ObjectiveSystem.list(sim.defs).map(func(o): return o.id)
			out[tag] = c[_ui_rng.randi() % c.size()]
	return out


## Entra na partida já com o país escolhido (jogo novo ou carregado).
func _enter_game(tag: String) -> void:
	player_tag = tag
	started = true
	_start.visible = false
	_menu.visible = false
	_game_ui.visible = true
	var c := sim.state.country(tag)
	UiStyle.set_flag(_flag, tag, c.color)
	_country_label.text = c.name.to_upper()
	_country_label.add_theme_font_size_override("font_size", 19 if c.name.length() <= 9 else (16 if c.name.length() <= 13 else 13))
	for r in sim.defs.resources:
		_prev_stock[r.id] = c.stock(r.id)
		_stock_delta[r.id] = 0.0
	camera.position = sim.state.state(c.capital_state).center
	camera.set_zoom_level(1.6)
	_events_seen = sim.state.events.size()
	_events_read = _events_seen
	_news_read = sim.state.news_count
	_news_toasted = _news_read
	write_log("Você governa %s. Boa sorte." % c.name)
	_refresh_all()


# ---------------------------------------------------------------- tempo e atualização

func _toggle_pause() -> void:
	if not _time_allowed():
		return
	paused = not paused
	_update_time_controls()
	Net.broadcast_time(paused, speed)


func _set_speed(s: int) -> void:
	if not _time_allowed():
		return
	speed = s
	_update_time_controls()
	Net.broadcast_time(paused, speed)


## No multiplayer só o host mexe no tempo.
func _time_allowed() -> bool:
	if mp and not Net.is_host:
		write_log("[color=#999]O tempo da partida é controlado pelo host.[/color]")
		return false
	return true


func _update_time_controls() -> void:
	if _pause_button == null:
		return
	_pause_button.icon = UiStyle.icon_texture("play" if paused else "pause")
	_pause_button.tooltip_text = ("Continuar" if paused else "Pausar") + " (espaço)"
	var round_box := UiStyle.box(UiStyle.WARN if paused else Color(0, 0, 0, 0),
		UiStyle.WARN if paused else Color("#4a463a"), 1, 17)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		_pause_button.add_theme_stylebox_override(st, round_box)
	var ic: Color = UiStyle.BG if paused else UiStyle.ACCENT
	_pause_button.add_theme_color_override("icon_normal_color", ic)
	_pause_button.add_theme_color_override("icon_hover_color", ic)
	_pause_button.add_theme_color_override("icon_pressed_color", ic)
	for i in _speed_bars.size():
		var on := i < speed
		_speed_bars[i].color = (Color("#6c6a64") if paused else UiStyle.ACCENT) if on else Color("#34373c")
	_update_date()


const WEEKDAYS := ["domingo", "segunda-feira", "terça-feira", "quarta-feira", "quinta-feira", "sexta-feira", "sábado"]


func _update_date() -> void:
	var h: int = sim.state.hours
	var d := GameDate.from_hours(h)
	_date_label.text = "%d %s %d" % [d.day, GameDate.MONTH_NAMES[d.month - 1].to_upper(), d.year]
	if paused:
		_date_sub.text = "PAUSADO · %02d:00" % d.hour
	else:
		_date_sub.text = "%02d:00 · %s" % [d.hour, WEEKDAYS[(3 + h / 24) % 7]]   # 1º/01/1936 foi quarta
	var c: Color = UiStyle.WARN if paused else UiStyle.TEXT
	_date_label.add_theme_color_override("font_color", c)
	_date_sub.add_theme_color_override("font_color", UiStyle.WARN if paused else UiStyle.MUTED)


func _on_day() -> void:
	if started:
		var c := sim.state.country(player_tag)
		for r in sim.defs.resources:
			_stock_delta[r.id] = c.stock(r.id) - float(_prev_stock.get(r.id, c.stock(r.id)))
			_prev_stock[r.id] = c.stock(r.id)
	# Avisos novos que envolvem o jogador (ex.: espiões presos, relatório pronto).
	while _events_seen < sim.state.events.size():
		var e: Dictionary = sim.state.events[_events_seen]
		_events_seen += 1
		if player_tag in e.tags:
			write_log("[color=#e0c070]%s:[/color] %s" % [e.get("kind", "Inteligência"), e.text])
	_check_extra()
	_refresh_all()


func _refresh_all() -> void:
	if not started:
		return
	_refresh_top_bar()
	_refresh_country_panel()
	_refresh_state_panel()
	_economy.refresh()
	_market.refresh()
	_intel.refresh()
	_research.refresh()
	_production.refresh()
	_army.refresh()
	_refresh_group_card()
	if _map_mode == "resources":
		_apply_map_mode()


func _refresh_top_bar() -> void:
	var c := sim.state.country(player_tag)
	var cur: String = sim.defs.currency
	var gold: Dictionary = _chips.treasury
	gold.value.text = UiStyle.money(c.money, cur)
	gold.extra.text = UiStyle.signed(c.last_income)
	gold.extra.add_theme_color_override("font_color", UiStyle.GOOD if c.last_income >= 0 else UiStyle.BAD)
	gold.extra.visible = absf(c.last_income) >= 0.5
	gold.button.tooltip_text = "Tesouro: %s\nRenda de ontem: %s" % [UiStyle.money(c.money, cur), UiStyle.money(c.last_income, cur)]
	var civ := sim.state.civil_factories(player_tag)
	var mil := sim.state.military_factories(player_tag)
	_chips.factories.civ.text = str(civ)
	_chips.factories.mil.text = str(mil)
	_chips.factories.button.tooltip_text = "Fábricas: %d civis, %d militares\nClique para abrir a Produção." % [civ, mil]
	_chips.research.value.text = str(c.research.size())
	_chips.research.extra.text = "/%d" % c.research_slots
	_chips.research.button.tooltip_text = "Pesquisa: %d de %d vagas ocupadas\nClique para abrir a Pesquisa." % [c.research.size(), c.research_slots]
	var obj_id: String = sim.state.objectives.get(player_tag, "")
	var op := ObjectiveSystem.progress(sim.state, sim.defs, player_tag, obj_id)
	_chips.objective.value.text = "%d%%" % roundi(op.value * 100) if obj_id != "" else "—"
	_chips.objective.button.tooltip_text = "Objetivo: %s\nClique para ver o andamento." % ObjectiveSystem.find(sim.defs, obj_id).get("name", "nenhum")
	var groups := sim.state.groups_of(player_tag)
	_chips.army.value.text = str(groups.size())
	_chips.army.button.tooltip_text = "Exército: %d grupos\nClique para abrir o Exército." % groups.size()
	for r in sim.defs.resources:
		var cell: Dictionary = _res_cells[r.id]
		var stock := c.stock(r.id)
		var prod := sim.state.resource_production(player_tag, r.id)
		cell.value.text = UiStyle.num(stock)
		var short := float(c.last_shortage.get(r.id, 0.0)) > 0.0
		cell.value.add_theme_color_override("font_color", UiStyle.WARN if short else UiStyle.TEXT)
		cell.box.modulate = Color(1, 1, 1, 0.5) if stock < 0.5 and prod == 0 and not short else Color(1, 1, 1)
	var enemies := sim.state.enemies_of(player_tag)
	_peace_label.text = "Em paz" if enemies.is_empty() else ("Em guerra" if enemies.size() == 1 else "Em %d guerras" % enemies.size())
	_peace_label.add_theme_color_override("font_color", UiStyle.MUTED if enemies.is_empty() else UiStyle.BAD)
	_peace_dot.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.GOOD if enemies.is_empty() else UiStyle.BAD, Color(0, 0, 0, 0), 0, 7))
	var unread := _unread_events().size() + _shortages().size() + (sim.state.news_count - _news_read)
	_alert_badge.visible = unread > 0
	_alert_count.text = str(unread) if unread < 100 else "99+"
	_alert_button.tooltip_text = "Jornal e despachos" if unread == 0 else "Jornal: %d novidades" % unread
	if _drop_kind != "":
		_fill_drop()


func _war_summary() -> String:
	var parts := []
	for e in sim.state.enemies_of(player_tag):
		parts.append("[color=%s]em guerra com %s[/color]" % [UiStyle.BAD_HEX, sim.state.country(e).name])
	for j in sim.state.justifications:
		if j.owner == player_tag:
			var n: String = sim.state.country(j.target).name
			parts.append(("pronto para declarar guerra a %s" % n) if j.done else
				("justificando guerra contra %s (%d dias)" % [n, DiplomacySystem.days_left(j)]))
	return "em paz com todos" if parts.is_empty() else ", ".join(parts)


func _player_events() -> Array:
	var out := []
	for e in sim.state.events:
		if player_tag in e.tags:
			out.append(e)
	return out


func _unread_events() -> Array:
	var out := []
	for i in range(_events_read, sim.state.events.size()):
		if player_tag in sim.state.events[i].tags:
			out.append(sim.state.events[i])
	return out


func _shortages() -> Array:
	var out := []
	var c := sim.state.country(player_tag)
	for r in sim.defs.resources:
		if float(c.last_shortage.get(r.id, 0.0)) > 0.0:
			out.append(r)
	return out


func _refresh_country_panel() -> void:
	var c := sim.state.country(player_tag)
	var tip := "%s\nLíder: %s" % [c.name, c.leader if c.leader != "" else "a definir"]
	if c.ideology != "":
		tip += "\nIdeologia: %s" % c.ideology
	tip += "\nCapital: %s\nEstados: %d" % [c.capital_city, sim.state.states_of(player_tag).size()]
	_nation_button.tooltip_text = tip
	for b in _nav_buttons:
		var p: Control = _panels[b]
		_style_nav(_nav_buttons[b], p.visible)
	# Obras: só aparece quando há algo na fila.
	UiStyle.clear(_queue_box)
	_queue_box.visible = not c.construction_queue.is_empty()
	if _queue_box.visible:
		_queue_box.add_child(UiStyle.rule(UiStyle.LINE))
		_queue_box.add_child(UiStyle.section("Obras"))
	for item in c.construction_queue:
		var def := ConstructionSystem.definition(sim.defs, item.building)
		var pct: float = 100.0 * item.progress / float(def.cost)
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = def.name
		l.clip_text = true
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.add_theme_font_size_override("font_size", 12)
		row.add_child(l)
		row.add_child(UiStyle.small_label("%d%%" % int(pct), 11))
		row.tooltip_text = "%s em %s" % [def.name, sim.state.state(item.state_id).name]
		row.mouse_filter = Control.MOUSE_FILTER_STOP
		_queue_box.add_child(row)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 4)
		bar.value = pct
		_queue_box.add_child(bar)


## Botão do menu lateral: aceso (dourado) quando a janela dele está aberta.
func _style_nav(b: Button, active: bool) -> void:
	var on := UiStyle.box(UiStyle.BG_HOVER, UiStyle.PANEL_BORDER, 1, 4)
	on.content_margin_left = 10
	on.content_margin_right = 8
	var off := UiStyle.box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 1, 4)
	off.content_margin_left = 10
	off.content_margin_right = 8
	var hover := off.duplicate()
	hover.bg_color = UiStyle.BG_HOVER
	b.add_theme_stylebox_override("normal", on if active else off)
	b.add_theme_stylebox_override("hover", on if active else hover)
	b.add_theme_stylebox_override("pressed", on)
	b.add_theme_stylebox_override("hover_pressed", on)
	b.add_theme_color_override("font_color", UiStyle.ACCENT if active else UiStyle.TEXT)
	b.add_theme_color_override("icon_normal_color", UiStyle.ACCENT if active else UiStyle.MUTED)


# ---------------------------------------------------------------- mapa

func _on_state_clicked(sid: int) -> void:
	if not started:
		if sid != -1:
			_start.select(sim.state.state(sid).owner)
		return
	selected_state = sid
	map.select(sid)
	if sid != -1 and units.selected != -1:
		units.select(-1)
	_state_panel.visible = sid != -1
	_refresh_state_panel()


## Cartão do grupo selecionado no mapa (usa o mesmo painel da direita que os estados).
func _refresh_group_card() -> void:
	if units == null or _state_panel == null:
		return
	var g := sim.state.group(units.selected)
	if g == null:
		if selected_state == -1:
			_state_panel.visible = false
		return
	selected_state = -1
	map.select(-1)
	_state_panel.visible = true
	var owner := sim.state.country(g.owner)
	_set_card_title(g.name, owner.name, g.owner)
	var t := ""
	var gen := sim.state.general(g.general_id)
	if gen != null:
		t += UiStyle.kv("General", "%s  [color=#999](ataque %d, defesa %d, velocidade %d)[/color]" % [gen.name, gen.attack, gen.defense, gen.speed]) + "\n"
	var org := CombatSystem.group_org(sim.defs, g)
	t += UiStyle.kv("Organização", "[color=%s]%d%%[/color]" % ["#d9503c" if org < 40 else ("#e0b050" if org < 75 else "#8fc46a"), roundi(org)]) + "\n"
	var fight := CombatSystem.attack_target(sim.state, g)
	if fight != -1:
		t += "[color=#d9503c]Atacando %s[/color]\n" % sim.state.state(fight).name
	elif sim.state.battles.has(g.state_id):
		t += "[color=#d9503c]Defendendo %s[/color]\n" % sim.state.state(g.state_id).name
	if g.moving() and fight == -1:
		t += UiStyle.kv("Marchando para", "%s, chega em ~%d dias" % [sim.state.state(g.destination()).name,
			ceili(ArmySystem.eta_days(sim.state, sim.defs, g))]) + "\n"
	elif fight == -1:
		t += UiStyle.kv("Em", sim.state.state(g.state_id).name) + "\n"
	t += ArmyPanel.summary(sim, g)
	if g.owner == player_tag:
		t += "\n\n[color=%s]Clique num estado para mandar marchar. Esc tira a seleção.[/color]" % UiStyle.MUTED_HEX
	_state_info.text = t
	UiStyle.clear(_build_box)
	_spy_button.visible = false


func _set_card_title(title: String, sub: String, tag: String) -> void:
	_state_title.text = title.to_upper()
	_state_sub.text = sub
	UiStyle.set_flag(_state_flag, tag, sim.state.country(tag).color)


func _on_state_hovered(sid: int) -> void:
	if started:
		units.preview(sid)
	if sid == -1:
		_hover_label.text = ""
		return
	var s := sim.state.state(sid)
	var t := "%s — %s" % [s.name, sim.state.country(s.owner).name]
	var g := sim.state.group(units.selected) if started else null
	if g != null and g.owner == player_tag:
		if not sim.state.can_enter(player_tag, s.owner):
			t += "  ·  fronteira fechada: sem guerra com %s" % sim.state.country(s.owner).name
		elif sim.state.at_war(player_tag, s.owner):
			t += "  ·  clique para atacar"
		else:
			t += "  ·  clique para marchar"
	_hover_label.text = t


func _on_sea_hovered(zid: int) -> void:
	if zid != -1:
		_hover_label.text = sim.state.sea_zones[zid].name
	elif map.state_at(map.get_local_mouse_position()) == -1:
		_hover_label.text = ""


func _refresh_state_panel() -> void:
	if selected_state == -1 or _state_panel == null:
		return
	var s := sim.state.state(selected_state)
	var owner := sim.state.country(s.owner)
	var mine := s.owner == player_tag and s.control() == player_tag
	_set_card_title(s.name, "%s · %s km²" % [owner.name, UiStyle.num(s.area_km2)], s.owner)
	var st := ""
	if s.occupied():
		st += "[color=#d9503c]Ocupado por %s[/color]\n" % sim.state.country(s.controller).name
	if sim.state.battles.has(s.id):
		st += "[color=#d9503c]Batalha em andamento[/color]\n"
	if mine:
		st += UiStyle.kv("Fábricas", "%d de %d vagas" % [s.level("factory"), s.building_slots])
		st += "   " + UiStyle.kv("Infraestrutura", "%d" % s.level("infrastructure")) + "\n"
		for r in sim.defs.resources:
			if int(s.resources.get(r.id, 0)) > 0:
				st += "[color=%s]%s[/color] %d/dia\n" % [r.color, r.name, s.extraction(r.id)]
	else:
		var rep: Dictionary = sim.state.country(player_tag).intel_reports.get(s.owner, {})
		if rep.is_empty():
			st += "[color=#888]Dados de outro país. Investigue para ver produção e estoques.[/color]\n"
		else:
			st += "[color=#888]Relatório de inteligência de %s:[/color]\n" % GameDate.format(rep.hours).split(",")[0]
			st += UiStyle.kv("Tesouro", "~" + UiStyle.money(rep.money, sim.defs.currency)) + "   "
			st += UiStyle.kv("Fábricas", "~%d civis, ~%d militares" % [rep.civilian_factories, rep.military_factories]) + "\n"
	_state_info.text = st

	UiStyle.clear(_build_box)
	_spy_button.visible = not mine
	_spy_button.text = "Investigar %s" % owner.name
	if not mine:
		_diplomacy_box(_build_box, s.owner)
		return
	var cur: String = sim.defs.currency
	var options: Array = sim.defs.buildings.keys()
	for r in sim.defs.resources:
		if int(s.resources.get(r.id, 0)) > 0:
			options.append("extraction_" + r.id)
	for b in options:
		var def := ConstructionSystem.definition(sim.defs, b)
		var btn := Button.new()
		btn.text = "Construir %s  ·  %s" % [str(def.name).to_lower(), UiStyle.money(float(def.get("money_cost", 0)), cur)]
		btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
		btn.icon = UiStyle.icon_texture("build")
		btn.expand_icon = true
		btn.add_theme_constant_override("icon_max_width", 16)
		var reason: String = QueueConstructionCommand.create(player_tag, selected_state, b).validate(sim.state, sim.defs)
		btn.disabled = reason != ""
		btn.tooltip_text = reason if reason != "" else "Leva o trabalho das fábricas civis; custa %s na hora." % UiStyle.money(float(def.get("money_cost", 0)), cur)
		var building: String = b
		btn.pressed.connect(func():
			submit(QueueConstructionCommand.create(player_tag, selected_state, building))
			_refresh_all())
		_build_box.add_child(btn)


## Situação com outro país e o botão do próximo passo (justificar, declarar).
func _diplomacy_box(parent: Control, tag: String) -> void:
	var them := sim.state.country(tag)
	parent.add_child(UiStyle.section("Diplomacia"))
	var j := sim.state.justification(player_tag, tag)
	var cur: String = sim.defs.currency
	if sim.state.at_war(player_tag, tag):
		parent.add_child(UiStyle.small_label("Em guerra com %s. Suas tropas podem entrar." % them.name, 13, UiStyle.BAD))
	elif sim.state.allied(player_tag, tag):
		parent.add_child(UiStyle.small_label("Aliado.", 13, UiStyle.GOOD))
	elif j.is_empty():
		parent.add_child(UiStyle.dim_label("Em paz. Para suas tropas entrarem, é preciso justificar e depois declarar guerra."))
		var b := Button.new()
		b.text = "Justificar guerra  ·  %d dias, %s" % [DiplomacySystem.justify_days(sim.defs), UiStyle.money(DiplomacySystem.justify_cost(sim.defs), cur)]
		var why := DiplomacySystem.can_justify(sim.state, sim.defs, player_tag, tag)
		b.disabled = why != ""
		b.tooltip_text = why
		b.pressed.connect(func(): submit(JustifyWarCommand.create(player_tag, tag)))
		parent.add_child(b)
	elif not j.done:
		parent.add_child(UiStyle.small_label("Justificando guerra: faltam %d dias." % DiplomacySystem.days_left(j), 13, UiStyle.WARN))
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		bar.max_value = float(j.days_needed)
		bar.value = float(j.days_done)
		parent.add_child(bar)
	else:
		parent.add_child(UiStyle.small_label("Justificativa pronta.", 13, UiStyle.WARN))
		parent.add_child(_declare_button(tag))


func _declare_button(tag: String) -> Button:
	var b := Button.new()
	b.text = "Declarar guerra a %s" % sim.state.country(tag).name
	b.icon = UiStyle.icon_texture("warning")
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 16)
	b.add_theme_stylebox_override("normal", UiStyle.box(Color("#5a1d17"), UiStyle.BAD, 1, 3))
	b.add_theme_stylebox_override("hover", UiStyle.box(Color("#7a271f"), UiStyle.BAD, 1, 3))
	b.add_theme_color_override("icon_normal_color", Color.WHITE)
	b.pressed.connect(func(): submit(DeclareWarCommand.create(player_tag, tag)))
	return b


# ---------------------------------------------------------------- aviso de fronteira

func _build_war_dialog() -> void:
	_war_dialog = UiStyle.panel(20)
	_war_dialog.custom_minimum_size = Vector2(480, 0)
	_war_dialog.visible = false
	_game_ui.add_child(_war_dialog)


func _show_war_dialog(tag: String, group_id: int, target_state: int) -> void:
	UiStyle.clear(_war_dialog)
	var them := sim.state.country(tag)
	var cur: String = sim.defs.currency
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_war_dialog.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	v.add_child(h)
	h.add_child(UiStyle.icon("warning", UiStyle.WARN, 22))
	var title := UiStyle.title_label("Fronteira fechada", 19)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(title)
	var close := UiStyle.icon_button("close", "Cancelar", 28, 14)
	close.pressed.connect(func(): _war_dialog.visible = false)
	h.add_child(close)
	v.add_child(UiStyle.rule())
	var who := HBoxContainer.new()
	who.add_theme_constant_override("separation", 12)
	v.add_child(who)
	var fb := UiStyle.flag_box(Vector2(48, 32), true)
	UiStyle.set_flag(fb, tag, them.color)
	who.add_child(fb)
	var msg := Label.new()
	msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	msg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	msg.custom_minimum_size = Vector2(360, 0)
	msg.text = "Suas tropas não podem entrar em %s: vocês não estão em guerra." % them.name
	who.add_child(msg)
	var j := sim.state.justification(player_tag, tag)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	var cancel := Button.new()
	cancel.text = "Cancelar"
	cancel.custom_minimum_size = Vector2(120, 40)
	cancel.pressed.connect(func(): _war_dialog.visible = false)
	if j.is_empty():
		v.add_child(UiStyle.dim_label("Justificar a guerra leva %d dias e custa %s. Quando terminar, a guerra só começa se você a declarar." % [
			DiplomacySystem.justify_days(sim.defs), UiStyle.money(DiplomacySystem.justify_cost(sim.defs), cur)]))
		v.add_child(row)
		row.add_child(cancel)
		var just := UiStyle.primary_button("Justificar guerra", 40)
		just.custom_minimum_size.x = 220
		var why := DiplomacySystem.can_justify(sim.state, sim.defs, player_tag, tag)
		just.disabled = why != ""
		just.tooltip_text = why
		just.pressed.connect(func():
			submit(JustifyWarCommand.create(player_tag, tag))
			_war_dialog.visible = false)
		row.add_child(just)
	elif not j.done:
		v.add_child(UiStyle.small_label("A justificativa contra %s termina em %d dias. Depois disso, declare a guerra para entrar." % [
			them.name, DiplomacySystem.days_left(j)], 13, UiStyle.WARN))
		v.add_child(row)
		cancel.text = "Entendi"
		row.add_child(cancel)
	else:
		v.add_child(UiStyle.small_label("A justificativa está pronta. Declarar a guerra abre a fronteira e a marcha começa.", 13, UiStyle.WARN))
		v.add_child(row)
		row.add_child(cancel)
		var dec := _declare_button(tag)
		dec.custom_minimum_size = Vector2(0, 40)
		dec.pressed.connect(func():
			_war_dialog.visible = false
			order_move.call_deferred(group_id, target_state))
		row.add_child(dec)
	_war_dialog.visible = true
	_center_war_dialog.call_deferred()


func _center_war_dialog() -> void:
	_war_dialog.size = _war_dialog.get_combined_minimum_size()
	_war_dialog.position = ((get_viewport().get_visible_rect().size - _war_dialog.size) * 0.5).floor()


func _set_map_mode(mode: String) -> void:
	_map_mode = mode
	for m in _map_mode_buttons:
		_style_nav(_map_mode_buttons[m], m == mode)
	_apply_map_mode()


## Modo "Recursos": jazidas do seu país e dos países com relatório de inteligência.
func _apply_map_mode() -> void:
	if _map_mode == "resources":
		var colors := {}
		for r in sim.defs.resources:
			colors[r.id] = Color(r.color)
		var known: Dictionary = sim.state.country(player_tag).intel_reports
		map.color_states(sim.state, func(s: MapState):
			if s.owner != player_tag and not known.has(s.owner):
				return Color(0.26, 0.27, 0.28)
			var best := ""
			for r in s.resources:
				if best == "" or s.resources[r] > s.resources[best]:
					best = r
			return colors[best] if best != "" else Color(0.36, 0.37, 0.38))
	else:
		map.color_by_owner(sim.state)


# ---------------------------------------------------------------- interface

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 10   # acima da camada 3D das tropas
	add_child(layer)
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.theme = UiStyle.theme()
	layer.add_child(_root)

	_game_ui = Control.new()
	_game_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	_game_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_ui.visible = false
	_root.add_child(_game_ui)

	_build_top_bar()

	_economy = EconomyPanel.new()
	_economy.setup(self)
	_game_ui.add_child(_economy)
	_market = MarketPanel.new()
	_market.setup(self)
	_game_ui.add_child(_market)
	_intel = IntelPanel.new()
	_intel.setup(self)
	_game_ui.add_child(_intel)
	_research = ResearchPanel.new()
	_research.setup(self)
	_game_ui.add_child(_research)
	_production = ProductionPanel.new()
	_production.setup(self)
	_game_ui.add_child(_production)
	_army = ArmyPanel.new()
	_army.setup(self)
	_game_ui.add_child(_army)
	_build_side_panels()
	for p in [_economy, _market, _intel, _research, _production, _army]:
		_game_ui.move_child(p, -1)   # janelas por cima do registro e dos modos de mapa
	_build_war_dialog()
	_game_ui.move_child(_drop, -1)   # a caixa da barra fica por cima de tudo

	_hover_label = Label.new()
	_hover_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hover_label.offset_left = -420
	_hover_label.offset_right = -12
	_hover_label.offset_top = -120
	_hover_label.offset_bottom = -96
	_hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hover_label.add_theme_font_override("font", UiStyle.font("bold"))
	_hover_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hover_label.add_theme_constant_override("outline_size", 4)
	_root.add_child(_hover_label)

	_start = StartScreen.new()
	_start.setup(self)
	_start.country_chosen.connect(_start_game)
	_start.back_requested.connect(func():
		_start.visible = false
		_menu.visible = true)
	_start.visible = false
	_root.add_child(_start)

	# Menu inicial: a primeira tela do jogo
	_menu = MainMenu.new()
	_menu.single_player_chosen.connect(func():
		_menu.visible = false
		_start.visible = true
		_start.select(_start._selected if _start._selected != "" else "BRA"))
	_root.add_child(_menu)
	_mp_screen = MultiplayerScreen.new()
	_mp_screen.visible = false
	_root.add_child(_mp_screen)
	_menu.multiplayer_chosen.connect(func(): _mp_screen.open())


	_settings = SettingsPanel.new()
	_settings.visible = false
	_root.add_child(_settings)
	_menu.settings_chosen.connect(func(): _settings.open())
	_menu.load_chosen.connect(_load_game)
	_menu.set_has_save(FileAccess.file_exists(SAVE_PATH))

	_pause_menu = PauseMenu.new()
	_pause_menu.visible = false
	_root.add_child(_pause_menu)
	_root.move_child(_settings, -1)   # configurações por cima do menu de pausa
	_pause_menu.continue_chosen.connect(_close_pause_menu)
	_pause_menu.save_chosen.connect(_save_game)
	_pause_menu.settings_chosen.connect(func(): _settings.open())
	_pause_menu.quit_chosen.connect(func():
		Net.leave()
		get_tree().reload_current_scene())
	_mp_screen.setup(self)
	_newspaper = Newspaper.new()
	_root.add_child(_newspaper)
	_newspaper.setup(self)
	_newspaper.closed.connect(_refresh_top_bar)
	_briefing = BriefingScreen.new()
	_root.add_child(_briefing)
	_briefing.setup(self)
	_root.move_child(_settings, -1)
	_briefing.reroll_requested.connect(_reroll_objective)
	_briefing.quit_requested.connect(func():
		Net.leave()
		get_tree().reload_current_scene())
	if Net.last_message != "":
		_menu.show_dialog("Multiplayer", Net.last_message)
		Net.last_message = ""
	Net.game_started.connect(_start_mp)
	Net.host_command.connect(func(d):
		var c := CommandRegistry.from_dict(d)
		if c != null:
			submit(c))
	Net.net_command.connect(func(d):
		var c := CommandRegistry.from_dict(d)
		if c != null:
			sim.submit(c)
			sim.apply_pending())
	Net.net_advance.connect(func(h): sim.advance_hours(h))
	Net.time_changed.connect(func(p, s):
		paused = p
		speed = s
		_update_time_controls())
	Net.player_left.connect(func(tag):
		write_log("%s saiu; a IA assume %s." % [tag, sim.state.country(tag).name])
		submit(ClaimCountryCommand.create(tag, tag)))
	Net.session_ended.connect(func(_r):
		if mp:
			get_tree().reload_current_scene())


# ---------------------------------------------------------------- menu do Esc, salvar e carregar

const SCENARIO := "1936"
var _briefing: BriefingScreen
var _briefing_pending := false   # abre o briefing quando o objetivo do jogador chegar
var _result_shown := false
var _ui_rng := RandomNumberGenerator.new()
var mp := false   # partida em rede
var _mp_screen: MultiplayerScreen
var _control_seen := 0
const SAVE_PATH := "user://save.json"
var _settings: SettingsPanel
var _pause_menu: PauseMenu
var _paused_before_menu := true


## Esc fecha primeiro o que estiver aberto (aviso, caixa, janela, seleção); sem nada aberto,
## abre o menu do jogo. Com o menu aberto, Esc volta ao jogo.
func _on_escape() -> void:
	if _pause_menu.visible:
		_close_pause_menu()
	elif _newspaper.visible:
		_newspaper.close()
	elif _war_dialog.visible:
		_war_dialog.visible = false
	elif _drop_kind != "":
		_close_drop()
	elif [_economy, _market, _intel, _research, _production, _army].any(func(p): return p.visible):
		_only_one_panel(null)
	elif units.selected != -1 or _state_panel.visible:
		units.select(-1)
		_on_state_clicked(-1)
	else:
		_open_pause_menu()


func _open_pause_menu() -> void:
	if not mp:
		_paused_before_menu = paused
		paused = true   # single player: o jogo para enquanto o menu está aberto
		_update_time_controls()
	_pause_menu.open(mp)


func _close_pause_menu() -> void:
	_pause_menu.visible = false
	if not mp:
		paused = _paused_before_menu
		_update_time_controls()


func _save_game() -> void:
	var data := SaveGame.to_dict(sim, SCENARIO, player_tag)
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		_pause_menu.set_status("Não foi possível salvar o jogo.")
		return
	f.store_string(JSON.stringify(data))
	f.close()
	_pause_menu.set_status("Jogo salvo em %s." % GameDate.format(sim.state.hours))
	write_log("Jogo salvo.")


func _load_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if not (data is Dictionary) or not data.has("journal"):
		_menu.show_dialog("Carregar jogo", "O jogo salvo não pôde ser lido.")
		return
	SaveGame.pending = data
	_menu.show_dialog("Carregando", "Refazendo a partida até %s..." % GameDate.format(int(data.get("hours", 0))))
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().reload_current_scene()


func _only_one_panel(p: Control) -> void:
	for other in [_economy, _market, _intel, _research, _production, _army]:
		if other != p:
			other.visible = false


const TOP_H := 64


func _top_bar_rect() -> Rect2:
	return Rect2(0, 0, _root.size.x, TOP_H)


func _build_top_bar() -> void:
	var top := PanelContainer.new()
	var sb := UiStyle.box(UiStyle.BG, Color(0, 0, 0, 0), 0, 0)
	sb.border_color = UiStyle.PANEL_BORDER
	sb.border_width_bottom = 1
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 3
	sb.shadow_offset = Vector2(0, 3)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	top.add_theme_stylebox_override("panel", sb)
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(0, TOP_H)
	_game_ui.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 6)
	top.add_child(bar)

	# País: bandeira com moldura, nome e situação (em paz / em guerra)
	_nation_button = UiStyle.plain_button(Vector2(178, 52))
	_nation_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var nh := HBoxContainer.new()
	nh.add_theme_constant_override("separation", 12)
	nh.set_anchors_preset(Control.PRESET_FULL_RECT)
	nh.offset_left = 6
	_nation_button.add_child(nh)
	_flag = UiStyle.flag_box(Vector2(42, 28), true)
	nh.add_child(_flag)
	var nv := VBoxContainer.new()
	nv.alignment = BoxContainer.ALIGNMENT_CENTER
	nv.add_theme_constant_override("separation", 2)
	nh.add_child(nv)
	_country_label = UiStyle.title_label("", 19)
	_country_label.clip_text = true
	_country_label.custom_minimum_size = Vector2(110, 0)
	nv.add_child(_country_label)
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 6)
	_peace_dot = UiStyle.dot(UiStyle.GOOD, 7)
	ph.add_child(_peace_dot)
	_peace_label = UiStyle.small_label("Em paz", 11)
	ph.add_child(_peace_label)
	nv.add_child(ph)
	UiStyle.passthrough(nh)
	_nation_button.pressed.connect(func(): _toggle_drop("nation", _nation_button))
	bar.add_child(_nation_button)
	bar.add_child(UiStyle.vsep())

	# Números principais
	_chips.treasury = _chip(bar, "treasury", "Tesouro", 126)
	_chips.treasury.button.pressed.connect(func(): _toggle_drop("treasury", _chips.treasury.button))
	_chips.factories = _chip(bar, "factory", "Fábricas", 96, true)
	_chips.factories.button.pressed.connect(func(): _open_panel("production"))
	_chips.research = _chip(bar, "research", "Pesquisa", 94)
	_chips.research.extra.add_theme_color_override("font_color", UiStyle.MUTED)
	_chips.research.extra.add_theme_font_override("font", UiStyle.font("number"))
	_chips.research.extra.add_theme_font_size_override("font_size", 14)
	_chips.research.button.pressed.connect(func(): _open_panel("research"))
	_chips.army = _chip(bar, "army", "Grupos", 88)
	_chips.army.button.pressed.connect(func(): _open_panel("army"))
	_chips.objective = _chip(bar, "target", "Objetivo", 92)
	_chips.objective.button.pressed.connect(func(): _toggle_drop("objective", _chips.objective.button))
	bar.add_child(UiStyle.vsep())

	# Recursos: ícone + estoque; o clique abre a tabela completa
	_res_button = UiStyle.plain_button(Vector2(0, 52))
	_res_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_res_button.tooltip_text = "Recursos: estoque, variação e preço"
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 0)
	rh.set_anchors_preset(Control.PRESET_FULL_RECT)
	_res_button.add_child(rh)
	for r in sim.defs.resources:
		var cell := VBoxContainer.new()
		cell.custom_minimum_size = Vector2(46, 0)
		cell.alignment = BoxContainer.ALIGNMENT_CENTER
		cell.add_theme_constant_override("separation", 3)
		var ic := UiStyle.icon(r.id, Color(r.color), 18)
		ic.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		cell.add_child(ic)
		var v := UiStyle.number_label("0", 14)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		cell.add_child(v)
		rh.add_child(cell)
		_res_cells[r.id] = {"box": cell, "value": v}
	var chev := UiStyle.icon("chevron_down", UiStyle.MUTED, 12)
	chev.custom_minimum_size = Vector2(18, 12)
	rh.add_child(chev)
	_res_button.custom_minimum_size.x = 46 * sim.defs.resources.size() + 22
	UiStyle.passthrough(rh)
	_res_button.pressed.connect(func(): _toggle_drop("resources", _res_button))
	bar.add_child(_res_button)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(spacer)

	# Avisos
	_alert_button = UiStyle.icon_button("newspaper", "Jornal", 44, 22)
	_alert_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_alert_badge = PanelContainer.new()
	var bsb := UiStyle.box(Color("#d2563f"), Color(0, 0, 0, 0), 0, 8)
	bsb.content_margin_left = 4
	bsb.content_margin_right = 4
	_alert_badge.add_theme_stylebox_override("panel", bsb)
	_alert_badge.position = Vector2(24, 5)
	_alert_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert_count = Label.new()
	_alert_count.add_theme_font_override("font", UiStyle.font("bold"))
	_alert_count.add_theme_font_size_override("font_size", 10)
	_alert_count.add_theme_color_override("font_color", Color.WHITE)
	_alert_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_alert_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_alert_badge.add_child(_alert_count)
	_alert_badge.visible = false
	_alert_button.add_child(_alert_badge)
	_alert_button.pressed.connect(func(): _open_newspaper(-1))
	bar.add_child(_alert_button)

	# Data, pausa e velocidade numa placa só
	_date_box = PanelContainer.new()
	var dsb := UiStyle.box(UiStyle.BG_DARK, UiStyle.LINE_WARM, 1, 4)
	dsb.content_margin_left = 12
	dsb.content_margin_right = 8
	dsb.content_margin_top = 5
	dsb.content_margin_bottom = 5
	_date_box.add_theme_stylebox_override("panel", dsb)
	_date_box.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	bar.add_child(_date_box)
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 8)
	_date_box.add_child(dh)
	var dv := VBoxContainer.new()
	dv.custom_minimum_size = Vector2(104, 0)
	dv.alignment = BoxContainer.ALIGNMENT_CENTER
	dv.add_theme_constant_override("separation", 1)
	dh.add_child(dv)
	_date_label = UiStyle.number_label("", 19)
	dv.add_child(_date_label)
	_date_sub = UiStyle.small_label("", 10)
	dv.add_child(_date_sub)
	_pause_button = Button.new()
	_pause_button.custom_minimum_size = Vector2(34, 34)
	_pause_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_pause_button.expand_icon = true
	_pause_button.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_pause_button.add_theme_constant_override("icon_max_width", 14)
	_pause_button.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	_pause_button.pressed.connect(_toggle_pause)
	dh.add_child(_pause_button)
	var sp := HBoxContainer.new()
	sp.add_theme_constant_override("separation", 3)
	dh.add_child(sp)
	for i in 5:
		var b := UiStyle.plain_button(Vector2(11, 34))
		b.tooltip_text = "Velocidade %d (tecla %d)" % [i + 1, i + 1]
		b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
		var level := i + 1
		b.pressed.connect(func(): _set_speed(level))
		var bar_rect := ColorRect.new()
		bar_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		bar_rect.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
		bar_rect.offset_top = -(10 + i * 6)
		bar_rect.offset_bottom = -2
		b.add_child(bar_rect)
		sp.add_child(b)
		_speed_bars.append(bar_rect)

	# Caixa que abre embaixo da barra
	_drop = PanelContainer.new()
	_drop.add_theme_stylebox_override("panel", UiStyle.panel_style(12))
	_drop.visible = false
	_game_ui.add_child(_drop)
	_update_time_controls()


## Bloco da barra: ícone dourado, número grande e legenda pequena embaixo.
func _chip(bar: HBoxContainer, icon_name: String, caption: String, width: float, split: bool = false) -> Dictionary:
	var b := UiStyle.plain_button(Vector2(width, 52))
	b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 9)
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 10
	b.add_child(h)
	h.add_child(UiStyle.icon(icon_name, UiStyle.ACCENT, 20))
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 1)
	h.add_child(v)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 4)
	v.add_child(line)
	var out := {"button": b}
	if split:   # fábricas: civis | militares
		out.civ = UiStyle.number_label("0", 18)
		line.add_child(out.civ)
		line.add_child(UiStyle.number_label("|", 18, Color("#6c6a64")))
		out.mil = UiStyle.number_label("0", 18, UiStyle.MILITARY)
		line.add_child(out.mil)
	else:
		out.value = UiStyle.number_label("", 18)
		line.add_child(out.value)
		out.extra = UiStyle.small_label("", 11, UiStyle.GOOD)
		out.extra.add_theme_font_override("font", UiStyle.font("bold"))
		out.extra.size_flags_vertical = Control.SIZE_SHRINK_END
		line.add_child(out.extra)
	var cap := UiStyle.title_label(caption, 10, UiStyle.MUTED)
	v.add_child(cap)
	UiStyle.passthrough(h)
	bar.add_child(b)
	return out


func _open_panel(which: String) -> void:
	_close_drop()
	var p: Control = _panels[which]
	_only_one_panel(p)
	if not p.visible:
		p.toggle()
	_refresh_country_panel()


# ---------------------------------------------------------------- caixas da barra superior

func _toggle_drop(kind: String, anchor: Control) -> void:
	if _drop_kind == kind:
		_close_drop()
		return
	_drop_kind = kind
	_drop_anchor = anchor
	if kind == "alerts":
		_events_read = sim.state.events.size()
	_fill_drop()
	_drop.visible = true
	_refresh_top_bar()


func _close_drop() -> void:
	_drop_kind = ""
	_drop.visible = false
	for b in [_nation_button, _chips.treasury.button, _res_button, _alert_button]:
		b.button_pressed = false
	_refresh_top_bar()


func _fill_drop() -> void:
	UiStyle.clear(_drop)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_drop.add_child(v)
	var c := sim.state.country(player_tag)
	var cur: String = sim.defs.currency
	var width := 300.0
	match _drop_kind:
		"objective":
			v.add_child(UiStyle.section("Objetivo de vitória"))
			v.add_child(UiStyle.rule())
			v.add_child(ObjectiveView.build(sim.state, sim.defs, player_tag, sim.state.objectives.get(player_tag, ""), 300))
			var how := UiStyle.small_label("Conta o território que você controla (o seu e o ocupado). Vence quem cumprir o próprio objetivo primeiro.", 11)
			how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			how.custom_minimum_size = Vector2(300, 0)
			v.add_child(how)
		"nation":
			v.add_child(UiStyle.section(c.name))
			v.add_child(UiStyle.rule())
			var t := UiStyle.rich(280)
			t.text = "%s\n%s\n%s\n%s\n%s" % [
				UiStyle.kv("Líder", c.leader if c.leader != "" else "a definir"),
				UiStyle.kv("Ideologia", c.ideology if c.ideology != "" else "a definir"),
				UiStyle.kv("Capital", c.capital_city),
				UiStyle.kv("Estados", str(sim.state.states_of(player_tag).size())),
				UiStyle.kv("Situação", _war_summary())]
			v.add_child(t)
		"treasury":
			v.add_child(UiStyle.section("Tesouro"))
			v.add_child(UiStyle.rule())
			v.add_child(_drop_row("Em caixa", UiStyle.money(c.money, cur), UiStyle.TEXT))
			v.add_child(_drop_row("Bens de consumo (ontem)", ("+" if c.last_income >= 0 else "") + UiStyle.money(c.last_income, cur),
				UiStyle.GOOD if c.last_income >= 0 else UiStyle.BAD))
			v.add_child(_drop_row("Em 30 dias, no ritmo atual", UiStyle.money(c.money + c.last_income * 30.0, cur), UiStyle.ACCENT))
			v.add_child(UiStyle.dim_label("Obras, pesquisas, investigações e generais são pagos na hora, ao dar a ordem."))
			v.add_child(_drop_link("Abrir Economia", "economy"))
		"resources":
			width = 420.0
			var head := HBoxContainer.new()
			var ht := UiStyle.section("Recursos")
			ht.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			head.add_child(ht)
			head.add_child(UiStyle.small_label("estoque · ontem · preço", 11))
			v.add_child(head)
			var grid := GridContainer.new()
			grid.columns = 5
			grid.add_theme_constant_override("h_separation", 10)
			grid.add_theme_constant_override("v_separation", 7)
			v.add_child(grid)
			for r in sim.defs.resources:
				grid.add_child(UiStyle.icon(r.id, Color(r.color), 16))
				var name_box := HBoxContainer.new()
				name_box.custom_minimum_size = Vector2(170, 0)
				name_box.add_theme_constant_override("separation", 6)
				var nl := Label.new()
				nl.text = r.name
				name_box.add_child(nl)
				var prod := sim.state.resource_production(player_tag, r.id)
				var warn := ""
				if float(c.last_shortage.get(r.id, 0.0)) > 0.0:
					warn = "falta na produção"
				elif prod == 0:
					warn = "sem extração"
				if warn != "":
					name_box.add_child(UiStyle.small_label(warn, 11, UiStyle.WARN))
				grid.add_child(name_box)
				var sl := UiStyle.number_label(UiStyle.num(c.stock(r.id)), 15)
				sl.custom_minimum_size = Vector2(54, 0)
				sl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				grid.add_child(sl)
				var dv: float = _stock_delta.get(r.id, 0.0)
				var dl := UiStyle.small_label(UiStyle.signed(dv), 12,
					UiStyle.GOOD if dv > 0.05 else (UiStyle.BAD if dv < -0.05 else UiStyle.MUTED))
				dl.add_theme_font_override("font", UiStyle.font("bold"))
				dl.custom_minimum_size = Vector2(52, 0)
				dl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				grid.add_child(dl)
				var pl := UiStyle.small_label("%s %s" % [cur, UiStyle.price(sim.state.price(r.id))], 12)
				pl.custom_minimum_size = Vector2(60, 0)
				pl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
				grid.add_child(pl)
			var links := HBoxContainer.new()
			links.add_theme_constant_override("separation", 8)
			var l1 := _drop_link("Abrir Economia", "economy")
			var l2 := _drop_link("Abrir Mercado", "market")
			l1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			l2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			links.add_child(l1)
			links.add_child(l2)
			v.add_child(links)
		"alerts":
			width = 380.0
			v.add_child(UiStyle.section("Avisos"))
			v.add_child(UiStyle.rule())
			var any := false
			for r in _shortages():
				v.add_child(_alert_row("warning", UiStyle.WARN, "Produção",
					"falta %s: as linhas que usam esse recurso andam mais devagar." % str(r.name).to_lower()))
				any = true
			var evs := _player_events()
			for i in range(evs.size() - 1, maxi(-1, evs.size() - 9), -1):
				var e: Dictionary = evs[i]
				var kind: String = e.get("kind", "Inteligência")
				var look: Array = {"Inteligência": ["intel", UiStyle.INFO], "Pesquisa": ["research", UiStyle.GOOD],
					"Exército": ["army", UiStyle.ACCENT], "Produção": ["warning", UiStyle.WARN],
					"Diplomacia": ["map_political", UiStyle.WARN], "Guerra": ["warning", UiStyle.BAD]}.get(kind, ["bell", UiStyle.ACCENT])
				v.add_child(_alert_row(look[0], look[1], kind, e.text))
				any = true
			if not any:
				v.add_child(UiStyle.dim_label("Nenhum aviso por enquanto."))
	_drop.custom_minimum_size = Vector2(width, 0)
	_drop.size = Vector2(width, 0)
	_place_drop()


## A caixa fica logo abaixo do botão que a abriu, sem sair da tela.
func _place_drop() -> void:
	_drop.size = _drop.get_combined_minimum_size()
	var x := _drop_anchor.global_position.x if _drop_anchor != null else 0.0
	var vw := get_viewport().get_visible_rect().size.x
	x = clampf(x, 8.0, maxf(8.0, vw - _drop.size.x - 8.0))
	_drop.position = Vector2(x, TOP_H + 6)


func _drop_row(label: String, value: String, color: Color) -> HBoxContainer:
	var h := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var val := UiStyle.number_label(value, 15, color)
	h.add_child(val)
	return h


func _drop_link(text: String, panel_id: String) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(func(): _open_panel(panel_id))
	return b


func _alert_row(icon_name: String, color: Color, kind: String, text: String) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var ic := UiStyle.icon(icon_name, color, 16)
	ic.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	h.add_child(ic)
	var t := UiStyle.rich(330)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.text = "[b][color=#%s]%s[/color][/b] · %s" % [color.to_html(false), kind, text]
	h.add_child(t)
	return h


# ---------------------------------------------------------------- menu lateral, ficha e rodapé

func _build_side_panels() -> void:
	# Menu lateral: um botão por janela; o botão da janela aberta fica aceso.
	_panels = {"economy": _economy, "market": _market, "production": _production,
		"research": _research, "army": _army, "intel": _intel}
	var left := UiStyle.panel(8)
	left.position = Vector2(10, UiStyle.PANEL_Y)
	left.custom_minimum_size = Vector2(156, 0)
	_game_ui.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 2)
	left.add_child(lv)
	for pair in [["Economia", "economy"], ["Mercado", "market"], ["Produção", "production"],
			["Pesquisa", "research"], ["Exército", "army"], ["Inteligência", "intel"]]:
		var b := Button.new()
		b.text = pair[0]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.custom_minimum_size = Vector2(0, 38)
		b.icon = UiStyle.icon_texture(UiStyle.WINDOW_ICONS[pair[0]])
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 18)
		b.add_theme_constant_override("h_separation", 10)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		_style_nav(b, false)
		var which: String = pair[1]
		b.pressed.connect(func():
			_close_drop()
			var p: Control = _panels[which]
			_only_one_panel(p)
			p.toggle()
			_refresh_country_panel())
		lv.add_child(b)
		_nav_buttons[which] = b
		_panels[which].visibility_changed.connect(func():
			if started:
				_refresh_country_panel.call_deferred())
	_queue_box = VBoxContainer.new()
	_queue_box.custom_minimum_size = Vector2(130, 0)
	_queue_box.add_theme_constant_override("separation", 3)
	lv.add_child(_queue_box)

	# Estado ou grupo selecionado (direita)
	_state_panel = UiStyle.panel()
	_state_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_state_panel.offset_left = -344
	_state_panel.offset_right = -10
	_state_panel.offset_top = UiStyle.PANEL_Y
	_state_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_state_panel.visible = false
	_game_ui.add_child(_state_panel)
	var rv := VBoxContainer.new()
	rv.add_theme_constant_override("separation", 8)
	_state_panel.add_child(rv)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	rv.add_child(head)
	_state_flag = UiStyle.flag_box(Vector2(30, 20), true)
	head.add_child(_state_flag)
	var hv := VBoxContainer.new()
	hv.add_theme_constant_override("separation", 0)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	_state_title = UiStyle.title_label("", 18)
	_state_title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hv.add_child(_state_title)
	_state_sub = UiStyle.small_label("", 12)
	hv.add_child(_state_sub)
	var close := UiStyle.icon_button("close", "Fechar (Esc)", 28, 14)
	close.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	close.pressed.connect(func():
		units.select(-1)
		_on_state_clicked(-1))
	head.add_child(close)
	rv.add_child(UiStyle.rule())
	_state_info = UiStyle.rich(310)
	rv.add_child(_state_info)
	_build_box = VBoxContainer.new()
	_build_box.add_theme_constant_override("separation", 4)
	rv.add_child(_build_box)
	_spy_button = Button.new()
	_spy_button.icon = UiStyle.icon_texture("spy")
	_spy_button.expand_icon = true
	_spy_button.add_theme_constant_override("icon_max_width", 16)
	_spy_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_spy_button.pressed.connect(func():
		_only_one_panel(_intel)
		_intel.visible = true
		var owner_tag: String = sim.state.state(selected_state).owner
		_intel.select_target(owner_tag)
		_intel.refresh())
	rv.add_child(_spy_button)

	# Modos de mapa (embaixo, à direita)
	var modes := UiStyle.panel(6)
	modes.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	modes.offset_left = -250
	modes.offset_right = -10
	modes.offset_top = -86
	modes.offset_bottom = -34
	modes.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	modes.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_game_ui.add_child(modes)
	var mh := HBoxContainer.new()
	mh.add_theme_constant_override("separation", 4)
	modes.add_child(mh)
	for pair in [["Político", "political", "map_political"], ["Recursos", "resources", "map_resources"]]:
		var b := Button.new()
		b.text = pair[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.custom_minimum_size = Vector2(0, 36)
		b.icon = UiStyle.icon_texture(pair[2])
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 16)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var mode: String = pair[1]
		b.pressed.connect(func(): _set_map_mode(mode))
		mh.add_child(b)
		_map_mode_buttons[mode] = b
		_style_nav(b, mode == _map_mode)

	# Registro (embaixo, à esquerda)
	var bottom := UiStyle.panel(10)
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.offset_left = 10
	bottom.offset_right = 480
	bottom.offset_top = -124
	bottom.offset_bottom = -10
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_game_ui.add_child(bottom)
	var bv := VBoxContainer.new()
	bv.add_theme_constant_override("separation", 4)
	bottom.add_child(bv)
	bv.add_child(UiStyle.title_label("Registro", 11, UiStyle.MUTED))
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	_log.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_log.add_theme_font_size_override("normal_font_size", 13)
	_log.add_theme_font_size_override("bold_font_size", 13)
	bv.add_child(_log)

	var help := Label.new()
	help.text = "Roda: zoom · Botão direito: arrastar · WASD: mover · Espaço: pausar · 1–5: velocidade"
	help.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	help.offset_left = -640
	help.offset_right = -12
	help.offset_top = -26
	help.offset_bottom = -6
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.add_theme_font_size_override("font_size", 12)
	help.add_theme_color_override("font_color", UiStyle.MUTED)
	help.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	help.add_theme_constant_override("outline_size", 3)
	help.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_game_ui.add_child(help)


# ---------------------------------------------------------------- jornal

func _open_newspaper(index: int) -> void:
	_close_drop()
	_hide_extra()
	_news_read = sim.state.news_count
	_events_read = sim.state.events.size()
	_newspaper.open(index)
	_refresh_top_bar()


## Notícia de guerra ou de aliança que saiu hoje: mostra o "EXTRA!" com "Ler a notícia".
func _check_extra() -> void:
	var st := sim.state
	var fresh := st.news_count - _news_toasted
	_news_toasted = st.news_count
	if fresh <= 0 or st.news.is_empty():
		return
	var pick := -1
	for i in range(st.news.size() - 1, maxi(-1, st.news.size() - 1 - fresh), -1):
		var n: Dictionary = st.news[i]
		if n.kind == "Guerra" or n.kind == "Diplomacia" or player_tag in n.tags:
			pick = i
			if player_tag in n.tags:
				break
	if pick == -1:
		return
	_show_extra(pick)


func _show_extra(index: int) -> void:
	_hide_extra()
	var n: Dictionary = sim.state.news[index]
	_extra = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Newspaper.PAPER
	sb.set_border_width_all(2)
	sb.border_color = Newspaper.INK
	sb.shadow_color = Color(0, 0, 0, 0.5)
	sb.shadow_size = 10
	sb.content_margin_left = 14
	sb.content_margin_right = 10
	sb.content_margin_top = 8
	sb.content_margin_bottom = 8
	_extra.add_theme_stylebox_override("panel", sb)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	_extra.add_child(row)
	var tag := Label.new()
	tag.text = "EXTRA!"
	tag.add_theme_font_override("font", load("res://ui/fonts/OldStandard-Bold.ttf"))
	tag.add_theme_font_size_override("font_size", 22)
	tag.add_theme_color_override("font_color", Newspaper.RED)
	row.add_child(tag)
	var h := Label.new()
	h.text = n.headline
	h.add_theme_font_override("font", load("res://ui/fonts/OldStandard-Bold.ttf"))
	h.add_theme_font_size_override("font_size", 16)
	h.add_theme_color_override("font_color", Newspaper.INK)
	h.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	h.custom_minimum_size = Vector2(380, 0)
	h.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(h)
	var read := Button.new()
	read.text = "Ler a notícia"
	read.add_theme_font_override("font", load("res://ui/fonts/OldStandard-Bold.ttf"))
	read.add_theme_font_size_override("font_size", 14)
	read.add_theme_color_override("font_color", Newspaper.PAPER)
	read.add_theme_color_override("font_hover_color", Color.WHITE)
	for k in ["normal", "hover", "pressed", "focus"]:
		var bs := StyleBoxFlat.new()
		bs.bg_color = Newspaper.RED if k == "hover" else Newspaper.INK
		bs.content_margin_left = 12
		bs.content_margin_right = 12
		bs.content_margin_top = 4
		bs.content_margin_bottom = 4
		read.add_theme_stylebox_override(k, bs)
	read.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	read.pressed.connect(func(): _open_newspaper(index))
	row.add_child(read)
	var x := UiStyle.icon_button("close", "Dispensar", 26, 12)
	x.modulate = Newspaper.INK
	x.pressed.connect(_hide_extra)
	row.add_child(x)
	_game_ui.add_child(_extra)
	_extra.reset_size()
	var vw := get_viewport().get_visible_rect().size.x
	_extra.position = Vector2((vw - _extra.size.x) * 0.5, 70)
	_extra_timer = 14.0


func _hide_extra() -> void:
	if _extra != null:
		_extra.queue_free()
		_extra = null
