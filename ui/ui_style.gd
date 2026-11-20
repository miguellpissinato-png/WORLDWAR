class_name UiStyle
extends RefCounted
## Visual comum da interface ("quartel-general"): painéis escuros com fio dourado, títulos em
## Oswald maiúsculo e espaçado, texto em Inter, ícones de traço (ui/icons) e números formatados.
## Todas as telas usam estas funções, para o jogo inteiro ter a mesma cara.

# Cores
const PANEL_BG := Color(0.0902, 0.098, 0.1098, 0.97)
const BG := Color("#17191c")
const BG_DARK := Color("#121416")
const BG_HOVER := Color("#22252a")
const BG_BUTTON := Color("#1d2024")
const LINE := Color("#2c2f33")
const LINE_SOFT := Color("#26292d")
const LINE_WARM := Color("#3a3a35")
const PANEL_BORDER := Color(0.79, 0.70, 0.48, 0.45)
const ACCENT := Color("#c9b37a")
const ACCENT_LIGHT := Color("#e2cf98")
const ACCENT_HEX := "#c9b37a"
const TEXT := Color("#e2e0d8")
const MUTED := Color("#9a988f")
const MUTED_HEX := "#9a988f"
const GOOD := Color("#8ccc80")
const GOOD_HEX := "#8ccc80"
const BAD := Color("#e6735f")
const BAD_HEX := "#e6735f"
const WARN := Color("#e0b050")
const WARN_HEX := "#e0b050"
const MILITARY := Color("#e6a07a")
const INFO := Color("#9fb7d8")

const FONT_SIZE := 14

static var _fonts := {}
static var _icons := {}


# ---------------------------------------------------------------- fontes e ícones

static func font(kind: String = "body") -> Font:
	if _fonts.has(kind):
		return _fonts[kind]
	var f: Font
	match kind:
		"bold":
			f = load("res://ui/fonts/Inter-SemiBold.ttf")
		"title":     # Oswald espaçado, para títulos e rótulos em maiúsculas
			var v := FontVariation.new()
			v.base_font = load("res://ui/fonts/Oswald-Medium.ttf")
			v.spacing_glyph = 2
			f = v
		"number":    # Oswald normal, para números grandes
			f = load("res://ui/fonts/Oswald-Medium.ttf")
		_:
			f = load("res://ui/fonts/Inter-Regular.ttf")
	_fonts[kind] = f
	return f


static func icon_texture(name: String) -> Texture2D:
	if not _icons.has(name):
		var path := "res://ui/icons/%s.svg" % name
		_icons[name] = load(path) if ResourceLoader.exists(path) else null
	return _icons[name]


## Ícone de traço colorido (os SVG são brancos; a cor vem do modulate).
static func icon(name: String, color: Color = ACCENT, size: float = 20.0) -> TextureRect:
	var t := TextureRect.new()
	t.texture = icon_texture(name)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	t.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	t.modulate = color
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return t


# ---------------------------------------------------------------- caixas

static func box(bg: Color, border: Color = Color(0, 0, 0, 0), width: int = 0, radius: int = 4, margin: float = 0.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(width)
	sb.set_corner_radius_all(radius)
	sb.set_content_margin_all(margin)
	sb.anti_aliasing = true
	return sb


## Estilo das janelas: fundo escuro quase opaco, fio dourado e sombra.
static func panel_style(margin: float = 14.0) -> StyleBoxFlat:
	var sb := box(PANEL_BG, PANEL_BORDER, 1, 4, margin)
	sb.shadow_color = Color(0, 0, 0, 0.45)
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 4)
	return sb


static func panel(margin: float = 14.0) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", panel_style(margin))
	return p


static func theme() -> Theme:
	var th := Theme.new()
	th.default_font = font("body")
	th.default_font_size = FONT_SIZE

	var normal := box(BG_BUTTON, LINE_WARM, 1, 3)
	normal.content_margin_left = 12
	normal.content_margin_right = 12
	normal.content_margin_top = 6
	normal.content_margin_bottom = 6
	var hover := normal.duplicate()
	hover.bg_color = BG_HOVER
	hover.border_color = ACCENT
	var pressed := normal.duplicate()
	pressed.bg_color = Color("#2a2922")
	pressed.border_color = ACCENT
	var disabled := normal.duplicate()
	disabled.bg_color = Color("#15171a")
	disabled.border_color = LINE
	var focus := box(Color(0, 0, 0, 0), Color(ACCENT, 0.6), 1, 3)
	for type in ["Button", "OptionButton", "MenuButton"]:
		th.set_stylebox("normal", type, normal)
		th.set_stylebox("hover", type, hover)
		th.set_stylebox("pressed", type, pressed)
		th.set_stylebox("hover_pressed", type, pressed)
		th.set_stylebox("disabled", type, disabled)
		th.set_stylebox("focus", type, focus)
		th.set_color("font_color", type, TEXT)
		th.set_color("font_hover_color", type, ACCENT_LIGHT)
		th.set_color("font_pressed_color", type, ACCENT_LIGHT)
		th.set_color("font_hover_pressed_color", type, ACCENT_LIGHT)
		th.set_color("font_focus_color", type, TEXT)
		th.set_color("font_disabled_color", type, Color(MUTED, 0.7))
		th.set_color("icon_normal_color", type, ACCENT)
		th.set_color("icon_hover_color", type, ACCENT_LIGHT)
		th.set_color("icon_pressed_color", type, ACCENT_LIGHT)
		th.set_constant("h_separation", type, 8)
	th.set_color("font_color", "Label", TEXT)

	# Caixas de marcar
	for type in ["CheckBox", "CheckButton"]:
		var empty := StyleBoxEmpty.new()
		empty.set_content_margin_all(4)
		for st in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
			th.set_stylebox(st, type, empty)
		th.set_color("font_color", type, TEXT)
		th.set_color("font_hover_color", type, ACCENT_LIGHT)
		th.set_color("font_pressed_color", type, TEXT)
		th.set_color("font_hover_pressed_color", type, ACCENT_LIGHT)
	th.set_icon("checked", "CheckBox", icon_texture("check_on"))
	th.set_icon("unchecked", "CheckBox", icon_texture("check_off"))

	# Barras de progresso
	th.set_stylebox("background", "ProgressBar", box(BG_DARK, LINE, 1, 2))
	th.set_stylebox("fill", "ProgressBar", box(ACCENT, Color(0, 0, 0, 0), 0, 2))
	th.set_color("font_color", "ProgressBar", TEXT)
	th.set_font("font", "ProgressBar", font("number"))
	th.set_font_size("font_size", "ProgressBar", 12)

	# Controles deslizantes
	var track := box(BG_DARK, LINE_WARM, 1, 3)
	track.content_margin_top = 3
	track.content_margin_bottom = 3
	th.set_stylebox("slider", "HSlider", track)
	th.set_stylebox("grabber_area", "HSlider", box(Color(ACCENT, 0.75), Color(0, 0, 0, 0), 0, 3))
	th.set_stylebox("grabber_area_highlight", "HSlider", box(ACCENT, Color(0, 0, 0, 0), 0, 3))
	th.set_icon("grabber", "HSlider", icon_texture("grabber"))
	th.set_icon("grabber_highlight", "HSlider", icon_texture("grabber_hl"))

	# Campos de texto e números
	var field := box(BG_DARK, LINE_WARM, 1, 3)
	field.content_margin_left = 8
	field.content_margin_right = 8
	field.content_margin_top = 4
	field.content_margin_bottom = 4
	var field_focus := field.duplicate()
	field_focus.border_color = ACCENT
	th.set_stylebox("normal", "LineEdit", field)
	th.set_stylebox("focus", "LineEdit", field_focus)
	th.set_stylebox("read_only", "LineEdit", field)
	th.set_color("font_color", "LineEdit", TEXT)
	th.set_color("caret_color", "LineEdit", ACCENT)
	th.set_color("selection_color", "LineEdit", Color(ACCENT, 0.35))

	# Menus suspensos e dicas
	var popup := box(BG, PANEL_BORDER, 1, 4, 6)
	th.set_stylebox("panel", "PopupMenu", popup)
	th.set_stylebox("hover", "PopupMenu", box(BG_HOVER, Color(0, 0, 0, 0), 0, 3))
	th.set_color("font_color", "PopupMenu", TEXT)
	th.set_color("font_hover_color", "PopupMenu", ACCENT_LIGHT)
	th.set_stylebox("panel", "TooltipPanel", box(BG, PANEL_BORDER, 1, 4, 9))
	th.set_color("font_color", "TooltipLabel", TEXT)
	th.set_font_size("font_size", "TooltipLabel", 13)

	# Rolagem
	var grab := box(LINE_WARM, Color(0, 0, 0, 0), 0, 4)
	var grab_hl := box(Color(ACCENT, 0.7), Color(0, 0, 0, 0), 0, 4)
	var scroll := box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4)
	scroll.content_margin_left = 3
	scroll.content_margin_right = 3
	for type in ["VScrollBar", "HScrollBar"]:
		th.set_stylebox("scroll", type, scroll)
		th.set_stylebox("grabber", type, grab)
		th.set_stylebox("grabber_highlight", type, grab_hl)
		th.set_stylebox("grabber_pressed", type, grab_hl)

	# Listas
	th.set_stylebox("panel", "ItemList", box(BG_DARK, LINE_WARM, 1, 4, 4))
	th.set_stylebox("focus", "ItemList", StyleBoxEmpty.new())
	th.set_stylebox("selected", "ItemList", box(BG_HOVER, PANEL_BORDER, 1, 3))
	th.set_stylebox("selected_focus", "ItemList", box(BG_HOVER, ACCENT, 1, 3))
	th.set_stylebox("hovered", "ItemList", box(Color("#1b1e22"), Color(0, 0, 0, 0), 0, 3))
	th.set_stylebox("cursor", "ItemList", StyleBoxEmpty.new())
	th.set_stylebox("cursor_unfocused", "ItemList", StyleBoxEmpty.new())
	th.set_color("font_color", "ItemList", TEXT)
	th.set_color("font_selected_color", "ItemList", ACCENT_LIGHT)
	th.set_color("font_hovered_color", "ItemList", ACCENT_LIGHT)
	th.set_constant("v_separation", "ItemList", 6)
	th.set_constant("h_separation", "ItemList", 10)

	# Separadores
	var sep := StyleBoxLine.new()
	sep.color = LINE
	sep.thickness = 1
	th.set_stylebox("separator", "HSeparator", sep)
	th.set_constant("separation", "HSeparator", 9)

	# Texto rico
	th.set_color("default_color", "RichTextLabel", TEXT)
	th.set_font("normal_font", "RichTextLabel", font("body"))
	th.set_font("bold_font", "RichTextLabel", font("bold"))
	th.set_font_size("normal_font_size", "RichTextLabel", FONT_SIZE)
	th.set_font_size("bold_font_size", "RichTextLabel", FONT_SIZE)
	th.set_constant("line_separation", "RichTextLabel", 3)
	return th


# ---------------------------------------------------------------- textos

## Rótulo em Oswald maiúsculo e espaçado (títulos, cabeçalhos de seção).
static func title_label(text: String, size: int = 18, color: Color = ACCENT) -> Label:
	var l := Label.new()
	l.text = text.to_upper()
	l.add_theme_font_override("font", font("title"))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Número grande em Oswald.
static func number_label(text: String = "", size: int = 18, color: Color = TEXT) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font("number"))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


static func small_label(text: String = "", size: int = 11, color: Color = MUTED) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


## Botão só com ícone (fechar, pausar...).
static func icon_button(name: String, tip: String, size: float = 30.0, icon_size: int = 16) -> Button:
	var b := Button.new()
	b.icon = icon_texture(name)
	b.tooltip_text = tip
	b.flat = true
	b.custom_minimum_size = Vector2(size, size)
	b.icon_alignment = HORIZONTAL_ALIGNMENT_CENTER
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", icon_size)
	b.add_theme_stylebox_override("normal", box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover_pressed", box(BG_HOVER, Color(0, 0, 0, 0), 0, 4))
	b.add_theme_stylebox_override("hover", box(BG_HOVER, Color(0, 0, 0, 0), 0, 4))
	b.add_theme_stylebox_override("pressed", box(BG_HOVER, Color(0, 0, 0, 0), 0, 4))
	b.add_theme_color_override("icon_normal_color", ACCENT)
	b.add_theme_color_override("icon_hover_color", ACCENT_LIGHT)
	return b


## Botão principal (ação mais importante da tela): dourado com texto escuro.
static func primary_button(text: String, height: float = 44.0) -> Button:
	var b := Button.new()
	b.text = text.to_upper()
	b.custom_minimum_size = Vector2(0, height)
	b.add_theme_font_override("font", font("title"))
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_stylebox_override("normal", box(ACCENT, Color(0, 0, 0, 0), 0, 4))
	b.add_theme_stylebox_override("hover", box(ACCENT_LIGHT, Color(0, 0, 0, 0), 0, 4))
	b.add_theme_stylebox_override("pressed", box(Color("#b39d66"), Color(0, 0, 0, 0), 0, 4))
	b.add_theme_stylebox_override("focus", box(Color(0, 0, 0, 0), ACCENT_LIGHT, 1, 4))
	for k in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_hover_pressed_color"]:
		b.add_theme_color_override(k, BG)
	return b


## Botão "invisível" que serve de área clicável para um conteúdo montado (chips da barra).
static func plain_button(min_size: Vector2 = Vector2.ZERO) -> Button:
	var b := Button.new()
	b.flat = true
	b.custom_minimum_size = min_size
	var empty := box(Color(0, 0, 0, 0), Color(0, 0, 0, 0), 0, 4)
	b.add_theme_stylebox_override("normal", empty)
	b.add_theme_stylebox_override("hover", box(BG_HOVER, Color(0, 0, 0, 0), 0, 4))
	b.add_theme_stylebox_override("pressed", box(BG_HOVER, Color(0, 0, 0, 0), 0, 4))
	b.add_theme_stylebox_override("hover_pressed", box(BG_HOVER, Color(0, 0, 0, 0), 0, 4))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	return b


## Filhos que não roubam o clique do botão onde estão montados.
static func passthrough(node: Node) -> void:
	if node is Control:
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for c in node.get_children():
		passthrough(c)


static func vsep(height: float = 36.0) -> ColorRect:
	var r := ColorRect.new()
	r.color = Color("#34373c")
	r.custom_minimum_size = Vector2(1, height)
	r.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Bolinha de cor (status, legenda). A fonte não tem "●", então é um painel redondo.
static func dot(color: Color, size: float = 8.0) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(size, size)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", box(color, Color(0, 0, 0, 0), 0, int(size)))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Título de painel com ícone e botão de fechar.
static func header(text: String, on_close: Callable = Callable(), icon_name: String = "") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	if icon_name != "":
		h.add_child(icon(icon_name, ACCENT, 20))
	var t := title_label(text, 19)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.mouse_filter = Control.MOUSE_FILTER_PASS
	h.add_child(t)
	if on_close.is_valid():
		var b := icon_button("close", "Fechar", 28, 14)
		b.pressed.connect(on_close)
		h.add_child(b)
	return h


## Posição padrão das janelas: logo à direita do menu lateral, abaixo da barra de cima.
const PANEL_X := 176
const PANEL_Y := 76

## Ícone de cada janela (pelo título).
const WINDOW_ICONS := {"Economia": "economy", "Mercado": "market", "Produção": "production",
	"Pesquisa": "research", "Exército": "army", "Inteligência": "intel"}


static func place(p: Control, width: float) -> void:
	p.add_theme_stylebox_override("panel", panel_style())
	p.set_anchors_preset(Control.PRESET_TOP_LEFT)
	p.offset_left = PANEL_X
	p.offset_top = PANEL_Y
	p.offset_right = PANEL_X + width
	p.visible = false


## Cabeçalho de janela: título, uma linha curta de ajuda (opcional) e Fechar.
## A explicação longa vai no tooltip do título, para não poluir a tela.
static func window_header(parent: Control, title: String, subtitle: String, on_close: Callable, help: String = "") -> void:
	var h := header(title, on_close, WINDOW_ICONS.get(title, ""))
	if help != "":
		var t: Label = h.get_child(1 if WINDOW_ICONS.has(title) else 0)
		t.mouse_filter = Control.MOUSE_FILTER_STOP
		t.tooltip_text = help
	parent.add_child(h)
	parent.add_child(rule())
	if subtitle != "":
		parent.add_child(dim_label(subtitle))


## Fio dourado fino sob os títulos.
static func rule(color: Color = Color(ACCENT, 0.35)) -> ColorRect:
	var r := ColorRect.new()
	r.color = color
	r.custom_minimum_size = Vector2(0, 1)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return r


## Bloco recolhível: um botão "Mais detalhes" que mostra/esconde o conteúdo.
static func details(parent: Control, closed_text: String = "Mais detalhes", open_text: String = "Menos detalhes") -> VBoxContainer:
	var b := Button.new()
	b.text = closed_text
	b.flat = true
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.icon = icon_texture("chevron_down")
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 12)
	b.add_theme_color_override("font_color", ACCENT)
	b.add_theme_color_override("icon_normal_color", ACCENT)
	b.add_theme_stylebox_override("normal", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("hover", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("pressed", StyleBoxEmpty.new())
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	parent.add_child(b)
	var box_ := VBoxContainer.new()
	box_.visible = false
	parent.add_child(box_)
	b.pressed.connect(func():
		box_.visible = not box_.visible
		b.text = open_text if box_.visible else closed_text)
	return box_


## Texto "rótulo valor" (para RichTextLabel): rótulo apagado, valor em destaque.
static func kv(label: String, value: String) -> String:
	return "[color=%s]%s[/color] %s" % [MUTED_HEX, label, value]


static func rich(min_width: float = 0.0) -> RichTextLabel:
	var r := RichTextLabel.new()
	r.bbcode_enabled = true
	r.fit_content = true
	r.custom_minimum_size = Vector2(min_width, 0)
	return r


static func clear(box_: Node) -> void:
	for c in box_.get_children():
		c.queue_free()


## Cabeçalho de seção / coluna: Oswald maiúsculo dourado.
static func section(text: String) -> Label:
	return title_label(text, 13)


static func dim_label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", MUTED)
	l.add_theme_font_size_override("font_size", 13)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return l


## Bandeira (cor do país) com moldura dourada.
static func flag(color: Color, size: Vector2 = Vector2(18, 12), frame: bool = false) -> Control:
	var f := ColorRect.new()
	f.color = color
	f.custom_minimum_size = size
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if not frame:
		return f
	var p := PanelContainer.new()
	var sb := box(Color(0, 0, 0, 0), ACCENT, 2, 1, 4)
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_child(f)
	return p


# ---------------------------------------------------------------- números

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


## Número com sinal: +12, −3, +0,5 (uma casa decimal quando é pequeno).
static func signed(v: float) -> String:
	var a := absf(v)
	var body := ("%.1f" % a).replace(".", ",") if a < 10.0 and absf(a - roundf(a)) > 0.05 else num(a)
	if a < 0.05:
		return "0"
	return ("+" if v > 0 else "−") + body


static func money(v: float, currency: String = "$") -> String:
	return "%s %s" % [currency, num(v)]


static func price(v: float) -> String:
	return ("%.2f" % v).replace(".", ",")
