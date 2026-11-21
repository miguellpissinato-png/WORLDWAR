class_name Newspaper
extends Control
## O jornal do mundo: abre no lugar do antigo sino de avisos. Página de papel com o nome do jornal,
## a manchete escolhida, uma "foto" em retícula (recorte do relevo do mapa no lugar do fato, ou
## ui/news/<TAG>.jpg se existir), as outras notícias e os despachos ao governo (avisos do jogador).

signal closed

const PAPER := Color("#ece3cf")
const PAPER_DARK := Color("#d9ccb0")
const INK := Color("#231c15")
const INK_SOFT := Color("#5b4d3c")
const RED := Color("#8e2a1c")
const NAME := "O Correio do Mundo"
const PHOTO_SIZE := Vector2(560, 210)
const TERRAIN_PATH := "res://data/map/terrain.webp"
const MAP_WIDTH := 3600.0
const MONTHS := ["janeiro", "fevereiro", "março", "abril", "maio", "junho", "julho", "agosto", "setembro",
	"outubro", "novembro", "dezembro"]          # largura do mapa em unidades (data/map/shapes.json)

var _main
var _index := -1                   # notícia aberta (posição em state.news)
var _sheet: PanelContainer
var _body: VBoxContainer
var _halftone: ShaderMaterial
var _terrain: Texture2D
var _fonts := {}


func setup(main) -> void:
	_main = main
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiStyle.scrim(0.6))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	_sheet = PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_border_width_all(1)
	sb.border_color = PAPER_DARK
	sb.shadow_color = Color(0, 0, 0, 0.55)
	sb.shadow_size = 18
	sb.set_content_margin_all(26)
	sb.content_margin_top = 16
	sb.content_margin_bottom = 14
	_sheet.add_theme_stylebox_override("panel", sb)
	_sheet.custom_minimum_size = Vector2(980, 0)
	center.add_child(_sheet)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 6)
	_sheet.add_child(_body)
	var sh := Shader.new()
	sh.code = HALFTONE
	_halftone = ShaderMaterial.new()
	_halftone.shader = sh
	visible = false


## Abre na notícia `index` (-1 = a mais recente).
func open(index: int = -1) -> void:
	var news: Array = _main.sim.state.news
	_index = news.size() - 1 if index < 0 else clampi(index, 0, news.size() - 1)
	_build()
	visible = true


func close() -> void:
	visible = false
	closed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and not _sheet.get_global_rect().has_point(event.position):
		close()


# ---------------------------------------------------------------- página

func _build() -> void:
	UiStyle.clear(_body)
	var st: GameState = _main.sim.state
	var d := GameDate.from_hours(st.hours)
	# linha do alto: ano e número, data da edição
	var top := HBoxContainer.new()
	_body.add_child(top)
	var yr := _label("ANO %s  ·  Nº %d" % [_roman(d.year - 1935), maxi(1, st.hours / 24 + 1)], "regular", 11, INK_SOFT)
	yr.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(yr)
	top.add_child(_label("Edição de %d de %s de %d" % [d.day, MONTHS[d.month - 1], d.year], "italic", 12, INK_SOFT))
	var mast := _label(NAME, "fraktur", 52, INK)
	mast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(mast)
	_body.add_child(_rule(3))
	var motto := _label("NOTÍCIAS DO MUNDO EM GUERRA  ·  TELEGRAMAS DE TODAS AS CAPITAIS", "regular", 10, INK_SOFT)
	motto.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_body.add_child(motto)
	_body.add_child(_rule(1))

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	_body.add_child(cols)
	var main_col := VBoxContainer.new()
	main_col.custom_minimum_size = Vector2(PHOTO_SIZE.x, 0)
	main_col.add_theme_constant_override("separation", 6)
	cols.add_child(main_col)
	var vr := ColorRect.new()
	vr.color = INK
	vr.custom_minimum_size = Vector2(1, 0)
	cols.add_child(vr)
	var side := VBoxContainer.new()
	side.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	side.add_theme_constant_override("separation", 5)
	cols.add_child(side)

	if st.news.is_empty():
		var h := _label("Mundo em compasso de espera", "bold", 32, INK)
		h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		main_col.add_child(h)
		main_col.add_child(_para("As chancelarias trabalham em silêncio. Nenhum telegrama importante chegou à redação até o fechamento desta edição.", 14))
	else:
		_main_story(main_col, st.news[_index])
	_side_column(side)

	# rodapé
	_body.add_child(_rule(1))
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	_body.add_child(foot)
	var prev := _paper_button("< Notícia anterior")
	prev.disabled = _index <= 0
	prev.pressed.connect(func(): open(_index - 1))
	foot.add_child(prev)
	var next := _paper_button("Próxima notícia >")
	next.disabled = _index >= st.news.size() - 1
	next.pressed.connect(func(): open(_index + 1))
	foot.add_child(next)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	var close_b := _paper_button("Fechar o jornal")
	close_b.pressed.connect(close)
	foot.add_child(close_b)


func _main_story(col: VBoxContainer, n: Dictionary) -> void:
	var kick := _label(String(n.get("kind", "")).to_upper() + "  ·  " + GameDate.format(n.hours).split(",")[0], "bold", 11, RED)
	col.add_child(kick)
	var h := _label(n.headline, "bold", 34 if n.headline.length() < 44 else 28, INK)
	h.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.custom_minimum_size = Vector2(PHOTO_SIZE.x, 0)
	col.add_child(h)
	if String(n.get("sub", "")) != "":
		col.add_child(_para(n.sub, 16, "italic", INK_SOFT))
	col.add_child(_photo(n))
	var st: GameState = _main.sim.state
	var s := st.state(int(n.get("state", -1)))
	if s != null:
		var cap := _label("Vista aérea da região de %s. Foto: arquivo da redação." % s.name, "italic", 11, INK_SOFT)
		col.add_child(cap)
	col.add_child(_para(String(n.get("body", "")), 14))


func _side_column(side: VBoxContainer) -> void:
	var st: GameState = _main.sim.state
	side.add_child(_label("OUTRAS NOTÍCIAS", "bold", 13, INK))
	side.add_child(_rule(1))
	var shown := 0
	for i in range(st.news.size() - 1, -1, -1):
		if i == _index:
			continue
		if shown >= 6:
			break
		shown += 1
		var n: Dictionary = st.news[i]
		var b := Button.new()
		b.flat = true
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		b.text = n.headline
		b.add_theme_font_override("font", _font("bold"))
		b.add_theme_font_size_override("font_size", 14)
		for k in ["font_color", "font_pressed_color", "font_focus_color"]:
			b.add_theme_color_override(k, INK)
		b.add_theme_color_override("font_hover_color", RED)
		for k in ["normal", "hover", "pressed", "focus"]:
			b.add_theme_stylebox_override(k, StyleBoxEmpty.new())
		b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		var idx := i
		b.pressed.connect(func(): open(idx))
		side.add_child(b)
		side.add_child(_label(GameDate.format(n.hours).split(",")[0], "italic", 10, INK_SOFT))
	if shown == 0:
		side.add_child(_para("Sem outros telegramas.", 12, "italic", INK_SOFT))

	side.add_child(Control.new())
	side.add_child(_label("DESPACHOS AO GOVERNO", "bold", 13, INK))
	side.add_child(_rule(1))
	var lines := []
	for r in _main._shortages():
		lines.append("Falta %s: a produção que usa esse recurso anda mais devagar." % str(r.name).to_lower())
	var evs: Array = _main._player_events()
	for i in range(evs.size() - 1, maxi(-1, evs.size() - 6), -1):
		lines.append("%s: %s" % [evs[i].get("kind", "Aviso"), evs[i].text])
	if lines.is_empty():
		lines.append("Nenhum despacho novo para o gabinete.")
	for t in lines.slice(0, 6):
		side.add_child(_para("— " + t, 12))


# ---------------------------------------------------------------- foto

func _photo(n: Dictionary) -> Control:
	var frame := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = PAPER
	sb.set_border_width_all(1)
	sb.border_color = INK
	sb.set_content_margin_all(3)
	frame.add_theme_stylebox_override("panel", sb)
	var tr := TextureRect.new()
	tr.custom_minimum_size = PHOTO_SIZE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	tr.material = _halftone
	tr.texture = _photo_texture(n)
	var reg := Vector4(0, 0, 1, 1)
	if tr.texture is AtlasTexture:
		var at: AtlasTexture = tr.texture
		var full := Vector2(at.atlas.get_width(), at.atlas.get_height())
		reg = Vector4(at.region.position.x / full.x, at.region.position.y / full.y, at.region.size.x / full.x, at.region.size.y / full.y)
	_halftone.set_shader_parameter("region", reg)
	frame.add_child(tr)
	return frame


## Foto do país (ui/news/<TAG>.jpg ou .png, se o Miguel colocar uma) ou recorte do relevo do mapa.
func _photo_texture(n: Dictionary) -> Texture2D:
	for tag in n.get("tags", []):
		for ext in ["jpg", "png", "webp"]:
			var p := "res://ui/news/%s.%s" % [tag, ext]
			if ResourceLoader.exists(p):
				return load(p)
	if _terrain == null:
		_terrain = load(TERRAIN_PATH)
	var st: GameState = _main.sim.state
	var s := st.state(int(n.get("state", -1)))
	var k := _terrain.get_width() / MAP_WIDTH
	var c := Vector2(_terrain.get_width() * 0.5, _terrain.get_height() * 0.4)
	if s != null:
		c = s.center * k
	var size := Vector2(400, 150)
	var at := AtlasTexture.new()
	at.atlas = _terrain
	var r := Rect2(c - size * 0.5, size)
	r.position.x = clampf(r.position.x, 0, _terrain.get_width() - size.x)
	r.position.y = clampf(r.position.y, 0, _terrain.get_height() - size.y)
	at.region = r
	return at


# ---------------------------------------------------------------- peças

func _font(kind: String) -> Font:
	if not _fonts.has(kind):
		var path: String = {"bold": "res://ui/fonts/OldStandard-Bold.ttf", "italic": "res://ui/fonts/OldStandard-Italic.ttf",
			"fraktur": "res://ui/fonts/UnifrakturMaguntia.ttf"}.get(kind, "res://ui/fonts/OldStandard-Regular.ttf")
		_fonts[kind] = load(path)
	return _fonts[kind]


func _label(text: String, kind: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", _font(kind))
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _para(text: String, size: int, kind: String = "regular", color: Color = INK) -> Label:
	var l := _label(text, kind, size, color)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(120, 0)
	return l


func _rule(px: int) -> Control:
	var r := ColorRect.new()
	r.color = INK
	r.custom_minimum_size = Vector2(0, px)
	return r


func _paper_button(text: String) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", _font("bold"))
	b.add_theme_font_size_override("font_size", 13)
	b.add_theme_color_override("font_color", INK)
	b.add_theme_color_override("font_hover_color", RED)
	b.add_theme_color_override("font_disabled_color", Color(INK, 0.3))
	for k in ["normal", "hover", "pressed", "disabled", "focus"]:
		var sb := StyleBoxFlat.new()
		sb.bg_color = PAPER_DARK if k == "hover" else Color(0, 0, 0, 0)
		sb.set_border_width_all(1)
		sb.border_color = Color(INK, 0.3 if k == "disabled" else 1.0)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 5
		sb.content_margin_bottom = 5
		b.add_theme_stylebox_override(k, sb)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


static func _roman(n: int) -> String:
	var vals := [[10, "X"], [9, "IX"], [5, "V"], [4, "IV"], [1, "I"]]
	var out := ""
	for v in vals:
		while n >= v[0]:
			out += v[1]
			n -= v[0]
	return out if out != "" else "I"


## Retícula de jornal: cinza em pontos de tinta sobre o papel.
const HALFTONE := """
shader_type canvas_item;
uniform float cell = 4.0;
uniform vec4 region = vec4(0.0, 0.0, 1.0, 1.0);   // parte da textura usada (x, y, largura, altura em UV)
float lum(vec3 c) { return dot(c, vec3(0.3, 0.59, 0.11)); }
void fragment() {
	// níveis automáticos: claro e escuro da própria foto (amostras numa grade 6x6)
	float lo = 1.0;
	float hi = 0.0;
	for (int i = 0; i < 6; i++) {
		for (int j = 0; j < 6; j++) {
			vec2 uv = vec2((float(i) + 0.5) / 6.0, (float(j) + 0.5) / 6.0);
			float v = lum(textureLod(TEXTURE, region.xy + uv * region.zw, 0.0).rgb);
			lo = min(lo, v);
			hi = max(hi, v);
		}
	}
	float l = (lum(texture(TEXTURE, UV).rgb) - lo) / max(hi - lo, 0.05);
	l = clamp(pow(clamp(l, 0.0, 1.0), 0.8) * 1.1 - 0.05, 0.0, 1.0);
	float a = 0.785;
	vec2 p = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a))) * (FRAGCOORD.xy / cell);
	float d = length(fract(p) - 0.5);
	float r = sqrt(1.0 - l) * 0.66;
	float ink = 1.0 - smoothstep(r - 0.1, r + 0.1, d);
	vec3 paper = vec3(0.925, 0.89, 0.81);
	vec3 tint = vec3(0.17, 0.13, 0.10);
	COLOR = vec4(mix(paper, tint, ink * 0.92), 1.0);
}
"""
