extends Node
## Tela principal da Fase 1: mapa mundial + barra superior + painéis.
## Toda ação do jogador vira um comando enviado à simulação.

## Horas de jogo por segundo real em cada velocidade (1 a 5).
const HOURS_PER_SECOND := [2.0, 6.0, 12.0, 24.0, 72.0]
const PANEL_BG := Color(0.09, 0.10, 0.11, 0.97)
const PANEL_BORDER := Color(0.30, 0.31, 0.33)
const ACCENT := Color(0.80, 0.70, 0.45)

var sim: Simulation
var player_tag := "BRA"
var paused := true
var speed := 1
var selected_state := -1
var _accum := 0.0
var _last_day := -1

var map: MapView
var labels: MapLabels
var camera: MapCamera

var _date_label: Label
var _pause_button: Button
var _speed_buttons: Array = []
var _flag: ColorRect
var _country_label: Label
var _country_picker: OptionButton
var _country_info: RichTextLabel
var _state_panel: PanelContainer
var _state_info: RichTextLabel
var _build_buttons := {}
var _hover_label: Label
var _log: RichTextLabel


func _ready() -> void:
	sim = Simulation.new(ScenarioLoader.load_scenario("1936"), ScenarioLoader.load_defs())
	sim.command_rejected.connect(func(_c, reason): _write_log("Ordem recusada: " + reason))
	sim.day_passed.connect(func(_h): _refresh_panels())

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
	camera.set_zoom_level(1.6)

	_build_ui()
	_select_country(player_tag)


func _process(delta: float) -> void:
	if not paused:
		_accum += delta * HOURS_PER_SECOND[speed - 1]
		var whole := int(_accum)
		if whole > 0:
			_accum -= whole
			sim.advance_hours(whole)
	_date_label.text = sim.state.date_text()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_toggle_pause()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
			_set_speed(event.keycode - KEY_0)
		elif event.keycode == KEY_ESCAPE:
			_on_state_clicked(-1)


func _toggle_pause() -> void:
	paused = not paused
	_pause_button.text = "▶" if paused else "❚❚"


func _set_speed(s: int) -> void:
	speed = s
	for i in _speed_buttons.size():
		_speed_buttons[i].modulate = ACCENT if i < speed else Color(1, 1, 1, 0.45)


func _select_country(tag: String) -> void:
	player_tag = tag
	var c := sim.state.country(tag)
	_flag.color = c.color
	_country_label.text = c.name
	_write_log("Você agora joga como %s." % c.name)
	_refresh_panels()


func _on_state_clicked(sid: int) -> void:
	selected_state = sid
	map.select(sid)
	_state_panel.visible = sid != -1
	_refresh_panels()


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


func _build_here(building: String) -> void:
	sim.submit(QueueConstructionCommand.create(player_tag, selected_state, building))
	_write_log("Ordem: %s em %s." % [sim.defs.buildings[building].name, sim.state.state(selected_state).name])
	_refresh_panels.call_deferred()


func _refresh_panels() -> void:
	var c := sim.state.country(player_tag)
	var t := "[color=#c9b37a]Líder:[/color] %s\n" % (c.leader if c.leader != "" else "a definir")
	if c.ideology != "":
		t += "[color=#c9b37a]Ideologia:[/color] %s\n" % c.ideology
	t += "[color=#c9b37a]Capital:[/color] %s\n" % c.capital_city
	t += "[color=#c9b37a]Estados:[/color] %d\n" % sim.state.states_of(player_tag).size()
	t += "[color=#c9b37a]Fábricas civis:[/color] %d\n" % sim.state.total_building(player_tag, "civilian_factory")
	t += "[color=#c9b37a]Fábricas militares:[/color] %d\n" % sim.state.total_building(player_tag, "military_factory")
	t += "\n[b]Fila de construção[/b]\n"
	if c.construction_queue.is_empty():
		t += "[color=#888](vazia — clique num estado seu no mapa)[/color]\n"
	for item in c.construction_queue:
		var def: Dictionary = sim.defs.buildings[item.building]
		t += "%s — %s  [color=#c9b37a]%d%%[/color]\n" % [def.name, sim.state.state(item.state_id).name,
			int(100.0 * item.progress / float(def.cost))]
	_country_info.text = t

	if selected_state == -1:
		return
	var s := sim.state.state(selected_state)
	var owner := sim.state.country(s.owner)
	var st := "[b][font_size=18]%s[/font_size][/b]\n" % s.name
	st += "[color=#c9b37a]Dono:[/color] %s\n" % owner.name
	st += "[color=#c9b37a]Área:[/color] %s km²\n" % _thousands(s.area_km2)
	st += "[color=#c9b37a]Vagas de fábrica:[/color] %d\n" % s.building_slots
	for b in sim.defs.buildings:
		st += "[color=#c9b37a]%s:[/color] %d\n" % [sim.defs.buildings[b].name, s.level(b)]
	_state_info.text = st
	var mine := s.owner == player_tag
	for b in _build_buttons:
		_build_buttons[b].disabled = not mine
		_build_buttons[b].tooltip_text = "" if mine else "Só dá para construir nos seus estados"


func _write_log(line: String) -> void:
	_log.append_text("[color=#c9b37a][%s][/color] %s\n" % [sim.state.date_text(), line])


static func _thousands(n: int) -> String:
	var s := str(n)
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return s + out


# ---------------------------------------------------------------- interface

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.theme = _make_theme()
	layer.add_child(root)

	# Barra superior
	var top := _panel()
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.custom_minimum_size = Vector2(0, 46)
	root.add_child(top)
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 10)
	top.add_child(bar)
	_flag = ColorRect.new()
	_flag.custom_minimum_size = Vector2(46, 28)
	bar.add_child(_flag)
	_country_label = Label.new()
	_country_label.add_theme_font_size_override("font_size", 20)
	_country_label.add_theme_color_override("font_color", ACCENT)
	bar.add_child(_country_label)
	var title := Label.new()
	title.text = "   WorldWar · %s" % sim.state.scenario_name
	title.modulate = Color(1, 1, 1, 0.5)
	bar.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(spacer)
	_date_label = Label.new()
	_date_label.add_theme_font_size_override("font_size", 18)
	bar.add_child(_date_label)
	_pause_button = Button.new()
	_pause_button.text = "▶"
	_pause_button.custom_minimum_size = Vector2(40, 0)
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

	# Painel do país (esquerda)
	var left := _panel()
	left.position = Vector2(10, 58)
	left.custom_minimum_size = Vector2(300, 0)
	root.add_child(left)
	var lv := VBoxContainer.new()
	left.add_child(lv)
	var pick := Label.new()
	pick.text = "Jogar como"
	pick.modulate = Color(1, 1, 1, 0.6)
	lv.add_child(pick)
	_country_picker = OptionButton.new()
	var tags: Array = sim.state.countries.keys()
	tags.sort_custom(func(a, b): return sim.state.country(a).name < sim.state.country(b).name)
	for i in tags.size():
		_country_picker.add_item(sim.state.country(tags[i]).name)
		_country_picker.set_item_metadata(i, tags[i])
		if tags[i] == player_tag:
			_country_picker.select(i)
	_country_picker.item_selected.connect(func(i): _select_country(_country_picker.get_item_metadata(i)))
	lv.add_child(_country_picker)
	_country_info = RichTextLabel.new()
	_country_info.bbcode_enabled = true
	_country_info.fit_content = true
	_country_info.custom_minimum_size = Vector2(280, 0)
	lv.add_child(_country_info)

	# Painel do estado selecionado (direita)
	_state_panel = _panel()
	_state_panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_state_panel.offset_left = -340
	_state_panel.offset_right = -10
	_state_panel.offset_top = 58
	_state_panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_state_panel.visible = false
	root.add_child(_state_panel)
	var rv := VBoxContainer.new()
	_state_panel.add_child(rv)
	_state_info = RichTextLabel.new()
	_state_info.bbcode_enabled = true
	_state_info.fit_content = true
	_state_info.custom_minimum_size = Vector2(300, 0)
	rv.add_child(_state_info)
	for b in sim.defs.buildings:
		var btn := Button.new()
		btn.text = "Construir: " + sim.defs.buildings[b].name
		var building: String = b
		btn.pressed.connect(func(): _build_here(building))
		rv.add_child(btn)
		_build_buttons[b] = btn

	# Registro (embaixo, à esquerda) e nome sob o mouse
	var bottom := _panel()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.offset_left = 10
	bottom.offset_right = 470
	bottom.offset_top = -130
	bottom.offset_bottom = -10
	bottom.grow_vertical = Control.GROW_DIRECTION_BEGIN
	root.add_child(bottom)
	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.scroll_following = true
	bottom.add_child(_log)

	_hover_label = Label.new()
	_hover_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_hover_label.offset_left = -420
	_hover_label.offset_right = -12
	_hover_label.offset_top = -52
	_hover_label.offset_bottom = -30
	_hover_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_hover_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_hover_label.add_theme_constant_override("outline_size", 4)
	root.add_child(_hover_label)

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
	root.add_child(help)


func _panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	return p


func _make_theme() -> Theme:
	var th := Theme.new()
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.16, 0.17, 0.18)
	normal.border_color = Color(0.36, 0.34, 0.28)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(2)
	normal.set_content_margin_all(6)
	var hover := normal.duplicate()
	hover.bg_color = Color(0.22, 0.22, 0.20)
	hover.border_color = ACCENT
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.12, 0.12, 0.13)
	for type in ["Button", "OptionButton"]:
		th.set_stylebox("normal", type, normal)
		th.set_stylebox("hover", type, hover)
		th.set_stylebox("pressed", type, hover)
		th.set_stylebox("disabled", type, disabled)
		th.set_color("font_color", type, Color(0.88, 0.86, 0.80))
	th.set_color("font_color", "Label", Color(0.88, 0.88, 0.86))
	th.set_color("default_color", "RichTextLabel", Color(0.86, 0.86, 0.84))
	return th
