class_name UiStyle
extends RefCounted
## Estilo visual comum dos painéis (escuro com detalhes dourados) e formatação de números.

const PANEL_BG := Color(0.09, 0.10, 0.11, 0.97)
const PANEL_BORDER := Color(0.30, 0.31, 0.33)
const ACCENT := Color(0.80, 0.70, 0.45)
const ACCENT_HEX := "#c9b37a"
const GOOD := Color(0.55, 0.80, 0.50)
const BAD := Color(0.90, 0.45, 0.40)


static func panel() -> PanelContainer:
	var p := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PANEL_BG
	sb.border_color = PANEL_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	sb.set_content_margin_all(10)
	p.add_theme_stylebox_override("panel", sb)
	return p


static func theme() -> Theme:
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
	var bar_bg := StyleBoxFlat.new()
	bar_bg.bg_color = Color(0.16, 0.17, 0.18)
	bar_bg.border_color = Color(0.36, 0.34, 0.28)
	bar_bg.set_border_width_all(1)
	bar_bg.set_corner_radius_all(2)
	var bar_fill := StyleBoxFlat.new()
	bar_fill.bg_color = ACCENT
	bar_fill.set_corner_radius_all(2)
	th.set_stylebox("background", "ProgressBar", bar_bg)
	th.set_stylebox("fill", "ProgressBar", bar_fill)
	th.set_color("default_color", "RichTextLabel", Color(0.86, 0.86, 0.84))
	return th


## Título de painel com botão Fechar opcional.
static func header(text: String, on_close: Callable = Callable()) -> HBoxContainer:
	var h := HBoxContainer.new()
	var t := Label.new()
	t.text = text
	t.add_theme_font_size_override("font_size", 18)
	t.add_theme_color_override("font_color", ACCENT)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	if on_close.is_valid():
		var b := Button.new()
		b.text = "Fechar"
		b.pressed.connect(on_close)
		h.add_child(b)
	return h


## Posição padrão das janelas: logo à direita do menu lateral, abaixo da barra de cima.
const PANEL_X := 160
const PANEL_Y := 58


static func place(p: Control, width: float) -> void:
	p.add_theme_stylebox_override("panel", panel().get_theme_stylebox("panel"))
	p.set_anchors_preset(Control.PRESET_TOP_LEFT)
	p.offset_left = PANEL_X
	p.offset_top = PANEL_Y
	p.offset_right = PANEL_X + width
	p.visible = false


## Cabeçalho de janela: título, uma linha curta de ajuda (opcional) e Fechar.
## A explicação longa vai no tooltip do título, para não poluir a tela.
static func window_header(parent: Control, title: String, subtitle: String, on_close: Callable, help: String = "") -> void:
	var h := header(title, on_close)
	if help != "":
		h.get_child(0).mouse_filter = Control.MOUSE_FILTER_STOP
		h.get_child(0).tooltip_text = help
	parent.add_child(h)
	if subtitle != "":
		parent.add_child(dim_label(subtitle))


## Bloco recolhível: um botão "Mais detalhes" que mostra/esconde o conteúdo.
static func details(parent: Control, closed_text: String = "Mais detalhes", open_text: String = "Menos detalhes") -> VBoxContainer:
	var b := Button.new()
	b.text = closed_text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.add_theme_color_override("font_color", ACCENT)
	parent.add_child(b)
	var box := VBoxContainer.new()
	box.visible = false
	parent.add_child(box)
	b.pressed.connect(func():
		box.visible = not box.visible
		b.text = open_text if box.visible else closed_text)
	return box


## Texto "rótulo valor" com o rótulo em dourado (para RichTextLabel).
static func kv(label: String, value: String) -> String:
	return "[color=%s]%s[/color] %s" % [ACCENT_HEX, label, value]


static func rich(min_width: float = 0.0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.custom_minimum_size = Vector2(min_width, 0)
	return r


static func clear(box: Node) -> void:
	for c in box.get_children():
		c.queue_free()


static func section(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", ACCENT)
	return l


static func dim_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.modulate = Color(1, 1, 1, 0.6)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


static func flag(color: Color) -> ColorRect:
	var f := ColorRect.new()
	f.color = color
	f.custom_minimum_size = Vector2(18, 12)
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return f


## 12345.6 -> "12.346"
static func num(v: float) -> String:
	var s := str(int(round(v)))
	var neg := s.begins_with("-")
	if neg:
		s = s.substr(1)
	var out := ""
	while s.length() > 3:
		out = "." + s.right(3) + out
		s = s.left(s.length() - 3)
	return ("-" if neg else "") + s + out


static func money(v: float, currency: String = "$") -> String:
	return "%s %s" % [currency, num(v)]


static func price(v: float) -> String:
	return ("%.2f" % v).replace(".", ",")
