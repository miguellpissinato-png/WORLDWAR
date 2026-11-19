extends Control
## Tela provisória da Fase 1: escolher país, controlar o tempo e construir na capital.
## Ainda sem mapa. Toda ação vira um comando enviado à simulação.

## Horas de jogo por segundo real em cada velocidade (1 a 5).
const HOURS_PER_SECOND := [2.0, 6.0, 12.0, 24.0, 72.0]

var sim: Simulation
var player_tag := ""
var paused := true
var speed := 1
var _accum := 0.0

var _date_label: Label
var _pause_button: Button
var _country_picker: OptionButton
var _info: RichTextLabel
var _log: RichTextLabel


func _ready() -> void:
	sim = Simulation.new(ScenarioLoader.load_scenario("1936"), ScenarioLoader.load_defs())
	sim.command_rejected.connect(func(_c, reason): _write_log("Ordem recusada: " + reason))
	_build_ui()
	_country_picker.select(0)
	_on_country_selected(0)


func _process(delta: float) -> void:
	if not paused:
		_accum += delta * HOURS_PER_SECOND[speed - 1]
		var whole := int(_accum)
		if whole > 0:
			_accum -= whole
			sim.advance_hours(whole)
	_refresh()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_SPACE:
			_toggle_pause()
		elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
			speed = event.keycode - KEY_0


func _toggle_pause() -> void:
	paused = not paused


func _on_country_selected(index: int) -> void:
	player_tag = _country_picker.get_item_metadata(index)
	_write_log("Você agora joga como %s." % sim.state.country(player_tag).name)


func _build_on_capital(building: String) -> void:
	var cap := sim.state.country(player_tag).capital_state
	sim.submit(QueueConstructionCommand.create(player_tag, cap, building))


func _refresh() -> void:
	_date_label.text = sim.state.date_text()
	_pause_button.text = "Continuar" if paused else "Pausar"
	var c := sim.state.country(player_tag)
	var cap := sim.state.state(c.capital_state)
	var t := "[b]%s[/b]\nLíder: %s\nIdeologia: %s\n" % [c.name, c.leader, c.ideology]
	t += "Capital: %s\n\n" % cap.name
	t += "Fábricas civis: %d\n" % sim.state.total_building(player_tag, "civilian_factory")
	t += "Fábricas militares: %d\n" % sim.state.total_building(player_tag, "military_factory")
	t += "Infraestrutura da capital: %d\n\n[b]Fila de construção[/b]\n" % cap.level("infrastructure")
	if c.construction_queue.is_empty():
		t += "(vazia)\n"
	for item in c.construction_queue:
		var def: Dictionary = sim.defs.buildings[item.building]
		t += "%s em %s — %d%%\n" % [def.name, sim.state.state(item.state_id).name,
			int(100.0 * item.progress / float(def.cost))]
	_info.text = t


func _write_log(line: String) -> void:
	_log.append_text("[%s] %s\n" % [sim.state.date_text(), line])


func _build_ui() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 20
	root.offset_top = 16
	root.offset_right = -20
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	var top := HBoxContainer.new()
	root.add_child(top)
	var title := Label.new()
	title.text = "WorldWar — %s" % sim.state.scenario_name
	title.add_theme_font_size_override("font_size", 22)
	top.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	_date_label = Label.new()
	_date_label.add_theme_font_size_override("font_size", 20)
	top.add_child(_date_label)
	_pause_button = Button.new()
	_pause_button.pressed.connect(_toggle_pause)
	top.add_child(_pause_button)
	for s in range(1, 6):
		var b := Button.new()
		b.text = ">".repeat(s)
		b.tooltip_text = "Velocidade %d (tecla %d)" % [s, s]
		b.pressed.connect(func(): speed = s)
		top.add_child(b)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(320, 0)
	body.add_child(left)
	var pick_label := Label.new()
	pick_label.text = "Jogar como:"
	left.add_child(pick_label)
	_country_picker = OptionButton.new()
	var i := 0
	for tag in sim.state.countries:
		_country_picker.add_item(sim.state.country(tag).name)
		_country_picker.set_item_metadata(i, tag)
		i += 1
	_country_picker.item_selected.connect(_on_country_selected)
	left.add_child(_country_picker)
	for pair in [["Construir fábrica civil na capital", "civilian_factory"],
			["Construir fábrica militar na capital", "military_factory"],
			["Melhorar infraestrutura da capital", "infrastructure"]]:
		var b := Button.new()
		b.text = pair[0]
		var building: String = pair[1]
		b.pressed.connect(func(): _build_on_capital(building))
		left.add_child(b)
	var help := Label.new()
	help.text = "Espaço: pausar   1–5: velocidade"
	help.modulate = Color(1, 1, 1, 0.6)
	left.add_child(help)

	_info = RichTextLabel.new()
	_info.bbcode_enabled = true
	_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_info)

	_log = RichTextLabel.new()
	_log.bbcode_enabled = true
	_log.custom_minimum_size = Vector2(0, 140)
	_log.scroll_following = true
	root.add_child(_log)
