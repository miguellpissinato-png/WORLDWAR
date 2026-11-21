class_name SettingsPanel
extends Control
## Janela de configurações, usada no menu inicial e no menu de pausa. Abas no topo
## (por enquanto só Áudio); os valores ficam no autoload Audio e são guardados no computador.

signal closed

var _tabs: HBoxContainer
var _pages: Dictionary = {}
var _tab_buttons: Dictionary = {}
var _value_labels: Dictionary = {}
var _sliders: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiStyle.scrim())
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var p := UiStyle.panel(22)
	p.custom_minimum_size = Vector2(560, 0)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	head.add_child(UiStyle.icon("settings", UiStyle.ACCENT, 20))
	var t := UiStyle.title_label("Configurações", 20)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(t)
	var close := UiStyle.icon_button("close", "Fechar (Esc)", 28, 14)
	close.pressed.connect(close_panel)
	head.add_child(close)
	v.add_child(UiStyle.rule())

	_tabs = HBoxContainer.new()
	_tabs.add_theme_constant_override("separation", 6)
	v.add_child(_tabs)
	_add_page("audio", "Áudio", _build_audio())
	_select("audio")


func _add_page(id: String, title: String, page: Control) -> void:
	var b := Button.new()
	b.text = title
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(110, 34)
	b.pressed.connect(func(): _select(id))
	_tabs.add_child(b)
	_tab_buttons[id] = b
	_pages[id] = page
	_tabs.get_parent().add_child(page)


func _select(id: String) -> void:
	for k in _pages:
		_pages[k].visible = k == id
		_tab_buttons[k].button_pressed = k == id


func _build_audio() -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	var pad := Control.new()
	pad.custom_minimum_size = Vector2(0, 4)
	v.add_child(pad)
	v.add_child(_slider_row("master", "volume", "Volume geral", Audio.master_volume, Audio.set_master))
	v.add_child(_slider_row("music", "music", "Música", Audio.music_volume, Audio.set_music))
	var hint := UiStyle.small_label("Para desligar a música, deixe o volume dela em 0.", 12)
	v.add_child(hint)
	return v


func _slider_row(id: String, icon_name: String, title: String, value: float, setter: Callable) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(UiStyle.icon(icon_name, UiStyle.ACCENT, 20))
	var l := Label.new()
	l.text = title
	l.custom_minimum_size = Vector2(130, 0)
	row.add_child(l)
	var s := HSlider.new()
	s.min_value = 0
	s.max_value = 100
	s.step = 1
	s.value = value
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(s)
	var n := UiStyle.number_label("%d%%" % int(value), 17)
	n.custom_minimum_size = Vector2(54, 0)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(n)
	s.value_changed.connect(func(x):
		setter.call(x)
		n.text = "%d%%" % int(x))
	_sliders[id] = s
	_value_labels[id] = n
	return row


func open() -> void:
	_sliders.master.set_value_no_signal(Audio.master_volume)
	_sliders.music.set_value_no_signal(Audio.music_volume)
	_value_labels.master.text = "%d%%" % int(Audio.master_volume)
	_value_labels.music.text = "%d%%" % int(Audio.music_volume)
	visible = true


func close_panel() -> void:
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		close_panel()
		get_viewport().set_input_as_handled()
