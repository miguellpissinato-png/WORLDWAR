class_name MainMenu
extends Control
## Menu inicial (modelo "cartaz central", escolhido pelo Miguel): imagem de cartazes ao fundo,
## título em estêncil, Single player, Multiplayer, Configurações e Sair.

signal single_player_chosen
signal multiplayer_chosen

const CREAM := Color("#e8d9b5")
const CREAM_LIGHT := Color("#f3e7c8")
const RED := Color("#a8201a")
const RED_LIGHT := Color("#c22b22")
const INK := Color("#1c1a17")

var _dialog: PanelContainer
var _dialog_title: Label
var _dialog_text: Label


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var bg := TextureRect.new()
	bg.texture = load("res://ui/menu/menu_bg.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	add_child(_scrim())

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 0)
	center.add_child(v)

	var title := Label.new()
	title.text = "WORLDWAR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var tf := FontVariation.new()
	tf.base_font = load("res://ui/fonts/BigShouldersStencil-Black.ttf")
	tf.spacing_glyph = 5
	title.add_theme_font_override("font", tf)
	title.add_theme_font_size_override("font_size", 148)
	title.add_theme_color_override("font_color", CREAM)
	title.add_theme_color_override("font_shadow_color", RED)
	title.add_theme_constant_override("shadow_offset_x", 6)
	title.add_theme_constant_override("shadow_offset_y", 6)
	title.add_theme_constant_override("line_spacing", -20)
	v.add_child(title)

	# Faixa vermelha: 1936 ◆ 1945 ◆ GRANDE ESTRATÉGIA
	var ribbon_row := CenterContainer.new()
	v.add_child(ribbon_row)
	var ribbon := PanelContainer.new()
	var rsb := UiStyle.box(RED, Color(0, 0, 0, 0), 0, 0)
	rsb.content_margin_left = 22
	rsb.content_margin_right = 22
	rsb.content_margin_top = 5
	rsb.content_margin_bottom = 5
	ribbon.add_theme_stylebox_override("panel", rsb)
	ribbon_row.add_child(ribbon)
	var rh := HBoxContainer.new()
	rh.add_theme_constant_override("separation", 14)
	ribbon.add_child(rh)
	for i in 3:
		if i > 0:
			rh.add_child(_diamond())
		rh.add_child(_ribbon_text(["1936", "1945", "GRANDE ESTRATÉGIA"][i]))

	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 52)
	v.add_child(gap)

	# Botões principais
	var big := HBoxContainer.new()
	big.alignment = BoxContainer.ALIGNMENT_CENTER
	big.add_theme_constant_override("separation", 16)
	v.add_child(big)
	var sp := _big_button("person", "SINGLE PLAYER", "Você contra a IA", RED, RED_LIGHT, Color("#5e120e"), CREAM_LIGHT, Color("#f0dcc0"))
	sp.pressed.connect(func(): single_player_chosen.emit())
	big.add_child(sp)
	var mp := _big_button("people", "MULTIPLAYER", "Com amigos; os outros países ficam com a IA", CREAM, CREAM_LIGHT, Color("#8f8162"), INK, Color("#4a4338"))
	mp.pressed.connect(func(): multiplayer_chosen.emit())
	big.add_child(mp)

	var gap2 := Control.new()
	gap2.custom_minimum_size = Vector2(0, 22)
	v.add_child(gap2)
	var small := HBoxContainer.new()
	small.alignment = BoxContainer.ALIGNMENT_CENTER
	small.add_theme_constant_override("separation", 12)
	v.add_child(small)
	var cfg := _small_button("settings", "CONFIGURAÇÕES", 196)
	cfg.pressed.connect(func(): show_dialog("Configurações", "As opções do jogo serão definidas em breve."))
	small.add_child(cfg)
	if not OS.has_feature("web"):   # no navegador não dá para fechar a página pelo jogo
		var quit := _small_button("exit", "SAIR", 124)
		quit.pressed.connect(func(): get_tree().quit())
		small.add_child(quit)

	# Rodapé
	var foot_l := _foot("Protótipo em desenvolvimento")
	foot_l.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	foot_l.offset_left = 24
	foot_l.offset_top = -32
	add_child(foot_l)
	var foot_r := _foot("Mapa: Natural Earth · dados históricos com fontes")
	foot_r.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	foot_r.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	foot_r.offset_right = -24
	foot_r.offset_left = -400
	foot_r.offset_top = -32
	foot_r.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(foot_r)

	_build_dialog()


## Escurece as bordas para o título e os botões aparecerem sobre os cartazes.
func _scrim() -> TextureRect:
	var g := Gradient.new()
	g.set_color(0, Color(0.078, 0.07, 0.059, 0.55))
	g.set_color(1, Color(0.055, 0.047, 0.04, 0.94))
	g.add_point(0.7, Color(0.078, 0.07, 0.059, 0.82))
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.48)
	t.fill_to = Vector2(1.08, 1.02)
	t.width = 256
	t.height = 256
	var r := TextureRect.new()
	r.texture = t
	r.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	r.stretch_mode = TextureRect.STRETCH_SCALE
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


func _ribbon_text(t: String) -> Label:
	var l := Label.new()
	l.text = t
	var f := FontVariation.new()
	f.base_font = UiStyle.font("number")
	f.spacing_glyph = 5
	l.add_theme_font_override("font", f)
	l.add_theme_font_size_override("font_size", 17)
	l.add_theme_color_override("font_color", CREAM_LIGHT)
	return l


func _diamond() -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = Vector2(8, 8)
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var d := ColorRect.new()
	d.color = CREAM_LIGHT
	d.size = Vector2(6, 6)
	d.position = Vector2(1, 1)
	d.pivot_offset = Vector2(3, 3)
	d.rotation_degrees = 45
	holder.add_child(d)
	return holder


func _big_button(icon_name: String, title: String, desc: String, bg: Color, bg_hover: Color, shadow: Color, fg: Color, fg_desc: Color) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(300, 96)
	for st in ["normal", "hover", "pressed", "hover_pressed"]:
		var sb := UiStyle.box(bg if st == "normal" else bg_hover, Color(0, 0, 0, 0), 0, 2)
		sb.shadow_color = shadow
		sb.shadow_size = 1
		sb.shadow_offset = Vector2(0, 6 if st != "pressed" else 2)
		b.add_theme_stylebox_override(st, sb)
	b.add_theme_stylebox_override("focus", UiStyle.box(Color(0, 0, 0, 0), fg, 1, 2))
	var h := HBoxContainer.new()
	h.set_anchors_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 22
	h.offset_right = -16
	h.add_theme_constant_override("separation", 16)
	b.add_child(h)
	h.add_child(UiStyle.icon(icon_name, fg, 34))
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	var t := Label.new()
	t.text = title
	var f := FontVariation.new()
	f.base_font = UiStyle.font("number")
	f.spacing_glyph = 1
	t.add_theme_font_override("font", f)
	t.add_theme_font_size_override("font_size", 26)
	t.add_theme_color_override("font_color", fg)
	tv.add_child(t)
	var d := Label.new()
	d.text = desc
	d.add_theme_font_size_override("font_size", 12)
	d.add_theme_color_override("font_color", fg_desc)
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(210, 0)
	tv.add_child(d)
	UiStyle.passthrough(h)
	return b


func _small_button(icon_name: String, text: String, width: float) -> Button:
	var b := Button.new()
	b.text = text
	b.icon = UiStyle.icon_texture(icon_name)
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 18)
	b.add_theme_constant_override("h_separation", 10)
	b.custom_minimum_size = Vector2(width, 46)
	var f := FontVariation.new()
	f.base_font = UiStyle.font("number")
	f.spacing_glyph = 2
	b.add_theme_font_override("font", f)
	b.add_theme_font_size_override("font_size", 16)
	b.add_theme_stylebox_override("normal", UiStyle.box(Color(0.078, 0.07, 0.059, 0.5), Color(CREAM, 0.55), 1, 2))
	b.add_theme_stylebox_override("hover", UiStyle.box(Color(CREAM, 0.14), CREAM, 1, 2))
	b.add_theme_stylebox_override("pressed", UiStyle.box(Color(CREAM, 0.22), CREAM, 1, 2))
	b.add_theme_stylebox_override("hover_pressed", UiStyle.box(Color(CREAM, 0.22), CREAM, 1, 2))
	b.add_theme_stylebox_override("focus", UiStyle.box(Color(0, 0, 0, 0), Color(CREAM, 0.8), 1, 2))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color"]:
		b.add_theme_color_override(k, CREAM)
	for k in ["icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_focus_color"]:
		b.add_theme_color_override(k, CREAM)
	return b


func _foot(t: String) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Color("#b9ab8a"))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l


# ---------------------------------------------------------------- aviso (configurações, multiplayer)

func _build_dialog() -> void:
	_dialog = UiStyle.panel(20)
	_dialog.set_anchors_preset(Control.PRESET_CENTER)
	_dialog.custom_minimum_size = Vector2(440, 0)
	_dialog.offset_left = -220
	_dialog.offset_right = 220
	_dialog.offset_top = -90
	_dialog.grow_vertical = Control.GROW_DIRECTION_BOTH
	_dialog.visible = false
	add_child(_dialog)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	_dialog.add_child(v)
	var h := HBoxContainer.new()
	v.add_child(h)
	_dialog_title = UiStyle.title_label("", 19)
	_dialog_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(_dialog_title)
	var close := UiStyle.icon_button("close", "Fechar", 28, 14)
	close.pressed.connect(func(): _dialog.visible = false)
	h.add_child(close)
	v.add_child(UiStyle.rule())
	_dialog_text = Label.new()
	_dialog_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_dialog_text.custom_minimum_size = Vector2(400, 0)
	v.add_child(_dialog_text)
	var ok := Button.new()
	ok.text = "Entendi"
	ok.size_flags_horizontal = Control.SIZE_SHRINK_END
	ok.pressed.connect(func(): _dialog.visible = false)
	v.add_child(ok)


func show_dialog(title: String, text: String) -> void:
	_dialog_title.text = title.to_upper()
	_dialog_text.text = text
	_dialog.visible = true
	_dialog.reset_size()
