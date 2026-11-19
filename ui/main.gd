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

var _root: Control
var _game_ui: Control
var _start: StartScreen
var _economy: EconomyPanel
var _market: MarketPanel
var _intel: IntelPanel
var _date_label: Label
var _pause_button: Button
var _speed_buttons: Array = []
var _flag: ColorRect
var _country_label: Label
var _money_label: Label
var _resource_labels := {}
var _country_info: RichTextLabel
var _state_panel: PanelContainer
var _state_info: RichTextLabel
var _build_box: VBoxContainer
var _spy_button: Button
var _hover_label: Label
var _log: RichTextLabel


func _ready() -> void:
	var defs := ScenarioLoader.load_defs()
	sim = Simulation.new(ScenarioLoader.load_scenario("1936", defs), defs)
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


func _process(delta: float) -> void:
	if started and not paused:
		_accum += delta * HOURS_PER_SECOND[speed - 1]
		var whole := int(_accum)
		if whole > 0:
			_accum -= whole
			sim.advance_hours(whole)
	if _date_label != null:
		_date_label.text = sim.state.date_text()


func _unhandled_input(event: InputEvent) -> void:
	if not started:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_toggle_pause()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
			_set_speed(event.keycode - KEY_0)
		elif event.keycode == KEY_ESCAPE:
			_on_state_clicked(-1)


## Envia uma ordem e aplica na hora (jogo solo: este computador é o "host").
func submit(cmd: Command) -> void:
	sim.submit(cmd)
	sim.apply_pending()


func write_log(line: String) -> void:
	_log.append_text("[color=%s][%s][/color] %s\n" % [UiStyle.ACCENT_HEX, sim.state.date_text().split(",")[0], line])


# ---------------------------------------------------------------- início do jogo

func _start_game(tag: String) -> void:
	player_tag = tag
	submit(ClaimCountryCommand.create(tag))
	started = true
	_start.visible = false
	_game_ui.visible = true
	var c := sim.state.country(tag)
	_flag.color = c.color
	_country_label.text = c.name
	camera.position = sim.state.state(c.capital_state).center
	camera.set_zoom_level(1.6)
	_events_seen = sim.state.events.size()
	write_log("Você governa %s. Boa sorte." % c.name)
	_refresh_all()


# ---------------------------------------------------------------- tempo e atualização

func _toggle_pause() -> void:
	paused = not paused
	_pause_button.text = "Continuar" if paused else "Pausar"


func _set_speed(s: int) -> void:
	speed = s
	for i in _speed_buttons.size():
		_speed_buttons[i].modulate = UiStyle.ACCENT if i < speed else Color(1, 1, 1, 0.45)


func _on_day() -> void:
	# Avisos novos que envolvem o jogador (ex.: espiões presos, relatório pronto).
	while _events_seen < sim.state.events.size():
		var e: Dictionary = sim.state.events[_events_seen]
		_events_seen += 1
		if player_tag in e.tags:
			write_log("[color=#e0c070]Inteligência:[/color] " + e.text)
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
	if _map_mode == "resources":
		_apply_map_mode()


func _refresh_top_bar() -> void:
	var c := sim.state.country(player_tag)
	var cur: String = sim.defs.currency
	_money_label.text = UiStyle.money(c.money, cur)
	_money_label.tooltip_text = "Tesouro\nRenda de ontem: %s" % UiStyle.money(c.last_income, cur)
	for r in sim.defs.resources:
		var l: Label = _resource_labels[r.id]
		var prod := sim.state.resource_production(player_tag, r.id)
		l.text = "%s %s" % [r.short, UiStyle.num(c.stock(r.id))]
		l.modulate = Color(1, 1, 1) if c.stock(r.id) > 0 or prod > 0 else Color(1, 1, 1, 0.4)
		l.tooltip_text = "%s\nEstoque: %s\nExtração: %d/dia\nPreço mundial: %s %s" % [
			r.name, UiStyle.num(c.stock(r.id)), prod, cur, UiStyle.price(sim.state.price(r.id))]


func _refresh_country_panel() -> void:
	var c := sim.state.country(player_tag)
	var a := UiStyle.ACCENT_HEX
	var t := "[color=%s]Líder:[/color] %s\n" % [a, c.leader if c.leader != "" else "a definir"]
	if c.ideology != "":
		t += "[color=%s]Ideologia:[/color] %s\n" % [a, c.ideology]
	t += "[color=%s]Capital:[/color] %s\n" % [a, c.capital_city]
	t += "[color=%s]Estados:[/color] %d\n" % [a, sim.state.states_of(player_tag).size()]
	t += "[color=%s]Fábricas civis:[/color] %d\n" % [a, sim.state.total_building(player_tag, "civilian_factory")]
	t += "[color=%s]Fábricas militares:[/color] %d\n" % [a, sim.state.total_building(player_tag, "military_factory")]
	t += "[color=%s]Renda de ontem:[/color] %s\n" % [a, UiStyle.money(c.last_income, sim.defs.currency)]
	t += "\n[b]Fila de construção[/b]\n"
	if c.construction_queue.is_empty():
		t += "[color=#888](vazia — clique num estado seu no mapa)[/color]\n"
	for item in c.construction_queue:
		var def := ConstructionSystem.definition(sim.defs, item.building)
		t += "%s — %s  [color=%s]%d%%[/color]\n" % [def.name, sim.state.state(item.state_id).name, a,
			int(100.0 * item.progress / float(def.cost))]
	_country_info.text = t


# ---------------------------------------------------------------- mapa

func _on_state_clicked(sid: int) -> void:
	if not started:
		if sid != -1:
			_start.select(sim.state.state(sid).owner)
		return
	selected_state = sid
	map.select(sid)
	_state_panel.visible = sid != -1
	_refresh_state_panel()


func _on_state_hovered(sid: int) -> void:
	if sid == -1:
		_hover_label.text = ""
		return
	var s := sim.state.state(sid)
	_hover_label.text = "%s — %s" % [s.name, sim.state.country(s.owner).name]


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
	var mine := s.owner == player_tag
	var a := UiStyle.ACCENT_HEX
	var st := "[b][font_size=18]%s[/font_size][/b]\n" % s.name
	st += "[color=%s]Dono:[/color] %s\n" % [a, owner.name]
	st += "[color=%s]Área:[/color] %s km²\n" % [a, UiStyle.num(s.area_km2)]
	if mine:
		st += "[color=%s]Vagas de fábrica:[/color] %d\n" % [a, s.building_slots]
		for b in sim.defs.buildings:
			st += "[color=%s]%s:[/color] %d\n" % [a, sim.defs.buildings[b].name, s.level(b)]
		var res_lines := ""
		for r in sim.defs.resources:
			if int(s.resources.get(r.id, 0)) > 0:
				var lvl := s.level("extraction_" + r.id)
				var max_lvl := s.max_extraction_levels(r.id, float(sim.defs.extraction.deposit_factor))
				res_lines += "[color=%s]%s:[/color] %d/dia (extração nível %d de %d)\n" % [r.color, r.name, s.extraction(r.id), lvl, max_lvl]
		if res_lines != "":
			st += "\n[b]Jazidas[/b]\n" + res_lines
	else:
		st += "\n[color=#888]Construções, jazidas e produção deste estado são informação de outro país.[/color]\n"
		var rep: Dictionary = sim.state.country(player_tag).intel_reports.get(s.owner, {})
		if not rep.is_empty():
			st += "\n" + _intel.report_text(s.owner, rep)
		else:
			st += "[color=#888]Sem relatório de inteligência sobre %s.[/color]\n" % owner.name
	_state_info.text = st

	for c in _build_box.get_children():
		c.queue_free()
	_spy_button.visible = not mine
	_spy_button.text = "Investigar %s" % owner.name
	if not mine:
		return
	var cur: String = sim.defs.currency
	var options: Array = sim.defs.buildings.keys()
	for r in sim.defs.resources:
		if int(s.resources.get(r.id, 0)) > 0:
			options.append("extraction_" + r.id)
	for b in options:
		var def := ConstructionSystem.definition(sim.defs, b)
		var btn := Button.new()
		btn.text = "Construir: %s (%s)" % [def.name, UiStyle.money(float(def.get("money_cost", 0)), cur)]
		var building: String = b
		btn.pressed.connect(func():
			submit(QueueConstructionCommand.create(player_tag, selected_state, building))
			_refresh_all())
		_build_box.add_child(btn)


func _set_map_mode(mode: String) -> void:
	_map_mode = mode
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
	_build_side_panels()

	_economy = EconomyPanel.new()
	_economy.setup(self)
	_game_ui.add_child(_economy)
	_market = MarketPanel.new()
	_market.setup(self)
	_game_ui.add_child(_market)
	_intel = IntelPanel.new()
	_intel.setup(self)
	_game_ui.add_child(_intel)

	_hover_label = Label.new()
	_hover_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hover_label.offset_left = -420
	_hover_label.offset_right = -12
	_hover_label.offset_top = -140
	_hover_label.offset_bottom = -118
	_hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hover_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hover_label.add_theme_constant_override("outline_size", 4)
	_root.add_child(_hover_label)

	_start = StartScreen.new()
	_start.setup(self)
	_start.country_chosen.connect(_start_game)
	_root.add_child(_start)


func _only_one_panel(p: Control) -> void:
	for other in [_economy, _market, _intel]:
		if other != p:
			other.visible = false


func _build_top_bar() -> void:
	var top := UiStyle.panel()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(0, 46)
	_game_ui.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	_flag = ColorRect.new()
	_flag.custom_minimum_size = Vector2(46, 28)
	bar.add_child(_flag)
	_country_label = Label.new()
	_country_label.add_theme_font_size_override("font_size", 20)
	_country_label.add_theme_color_override("font_color", UiStyle.ACCENT)
	bar.add_child(_country_label)
	_money_label = Label.new()
	_money_label.mouse_filter = Control.MOUSE_FILTER_STOP
	_money_label.add_theme_color_override("font_color", UiStyle.GOOD)
	bar.add_child(_money_label)
	var res_box := HBoxContainer.new()
	res_box.add_theme_constant_override("separation", 10)
	bar.add_child(res_box)
	for r in sim.defs.resources:
		var dot := ColorRect.new()   # quadrado de cor (a fonte da versão web não tem "●")
		dot.color = Color(r.color)
		dot.custom_minimum_size = Vector2(9, 9)
		dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		res_box.add_child(dot)
		var l := Label.new()
		l.mouse_filter = Control.MOUSE_FILTER_STOP
		res_box.add_child(l)
		_resource_labels[r.id] = l
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_date_label = Label.new()
	_date_label.add_theme_font_size_override("font_size", 18)
	bar.add_child(_date_label)
	_pause_button = Button.new()
	_pause_button.text = "Continuar"
	_pause_button.custom_minimum_size = Vector2(96, 0)
	_pause_button.tooltip_text = "Pausar / continuar (espaço)"
	_pause_button.pressed.connect(_toggle_pause)
	bar.add_child(_pause_button)
	for s in range(1, 6):
		var b := Button.new()
		b.text = "›"
		b.custom_minimum_size = Vector2(22, 0)
		b.tooltip_text = "Velocidade %d (tecla %d)" % [s, s]
		b.pressed.connect(func(): _set_speed(s))
		bar.add_child(b)
		_speed_buttons.append(b)
	_set_speed(1)


func _build_side_panels() -> void:
	# País (esquerda)
	var left := UiStyle.panel()
	left.position = Vector2(10, 58)
	left.custom_minimum_size = Vector2(300, 0)
	_game_ui.add_child(left)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	left.add_child(lv)
	var buttons := HBoxContainer.new()
	lv.add_child(buttons)
	for pair in [["Economia", "economy"], ["Mercado", "market"], ["Inteligência", "intel"]]:
		var b := Button.new()
		b.text = pair[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var which: String = pair[1]
		b.pressed.connect(func():
			var p: Control = {"economy": _economy, "market": _market, "intel": _intel}[which]
			_only_one_panel(p)
			p.toggle())
		buttons.add_child(b)
	_country_info = RichTextLabel.new()
	_country_info.bbcode_enabled = true
	_country_info.fit_content = true
	_country_info.custom_minimum_size = Vector2(270, 0)
	lv.add_child(_country_info)

	# Estado selecionado (direita)
	_state_panel = UiStyle.panel()
	_state_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_state_panel.offset_left = -350
	_state_panel.offset_right = -10
	_state_panel.offset_top = 58
	_state_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_state_panel.visible = false
	_game_ui.add_child(_state_panel)
	var rv := VBoxContainer.new()
	_state_panel.add_child(rv)
	_state_info = RichTextLabel.new()
	_state_info.bbcode_enabled = true
	_state_info.fit_content = true
	_state_info.custom_minimum_size = Vector2(320, 0)
	rv.add_child(_state_info)
	_build_box = VBoxContainer.new()
	rv.add_child(_build_box)
	_spy_button = Button.new()
	_spy_button.pressed.connect(func():
		_only_one_panel(_intel)
		_intel.visible = true
		var owner_tag: String = sim.state.state(selected_state).owner
		_intel.select_target(owner_tag)
		_intel.refresh())
	rv.add_child(_spy_button)

	# Modos de mapa (embaixo, à direita)
	var modes := UiStyle.panel()
	modes.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	modes.offset_left = -230
	modes.offset_right = -10
	modes.offset_top = -110
	modes.offset_bottom = -60
	modes.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	modes.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_game_ui.add_child(modes)
	var mh := HBoxContainer.new()
	modes.add_child(mh)
	for pair in [["Político", "political"], ["Recursos", "resources"]]:
		var b := Button.new()
		b.text = pair[0]
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var mode: String = pair[1]
		b.pressed.connect(func(): _set_map_mode(mode))
		mh.add_child(b)

	# Registro (embaixo, à esquerda)
	var bottom := UiStyle.panel()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.offset_left = 10
	bottom.offset_right = 520
	bottom.offset_top = -130
	bottom.offset_bottom = -10
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_game_ui.add_child(bottom)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	bottom.add_child(_log)

	var help := Label.new()
	help.text = "Roda: zoom · Botão direito: arrastar · WASD: mover · Espaço: pausar · 1–5: velocidade"
	help.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	help.offset_left = -640
	help.offset_right = -12
	help.offset_top = -26
	help.offset_bottom = -6
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	help.add_theme_font_size_override("font_size", 12)
	help.modulate = Color(1, 1, 1, 0.55)
	_game_ui.add_child(help)
