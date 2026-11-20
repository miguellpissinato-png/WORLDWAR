class_name StartScreen
extends Control
## Escolha do país: lista com bandeiras de 1936 (grandes potências primeiro), ficha do país e
## "Ver no mapa", que esconde a tela, destaca o país no mapa e voa a câmera até ele.
## É o único momento em que a produção de todos os países fica à vista; depois de começar,
## os dados dos outros só chegam por relatórios de inteligência.

signal country_chosen(tag: String)
signal back_requested

const MAJORS := ["ALE", "URS", "EUA", "RUN", "FRA", "ITA", "JAP"]
const CREAM := Color("#e8d9b5")
const RED := Color("#a8201a")

var _main
var _tags: Array = []
var _selected := ""
var _rows := {}               # tag -> Button da lista
var _scrim: ColorRect
var _layout: Control          # cabeçalho + lista + ficha (some no modo mapa)
var _filter: LineEdit
var _list: VBoxContainer
var _scroll: ScrollContainer
# ficha
var _flag_box: PanelContainer
var _name: Label
var _badge: PanelContainer
var _facts: RichTextLabel
var _tiles := {}
var _res_rows := {}
var _play: Button
# modo mapa
var _map_card: PanelContainer
var _map_flag: PanelContainer
var _map_name: Label
var _map_play: Button
var _map_mode := false


func setup(main) -> void:
	_main = main
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_scrim = ColorRect.new()
	_scrim.color = Color(0.05, 0.055, 0.065, 0.78)
	_scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(_scrim)

	_layout = VBoxContainer.new()
	_layout.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_layout.add_theme_constant_override("separation", 0)
	_layout.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_layout)
	_build_header()

	var body := MarginContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for side in ["left", "right", "top", "bottom"]:
		body.add_theme_constant_override("margin_" + side, 24 if side != "top" else 20)
	body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_layout.add_child(body)
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 20)
	body.add_child(cols)
	_build_list(cols)
	_build_sheet(cols)
	_build_map_card()

	_tags = main.sim.state.countries.keys()
	_tags.sort_custom(func(a, b): return _plain(main.sim.state.country(a).name) < _plain(main.sim.state.country(b).name))
	_fill_list()


# ---------------------------------------------------------------- cabeçalho

func _build_header() -> void:
	var top := PanelContainer.new()
	var sb := UiStyle.box(UiStyle.BG, Color(0, 0, 0, 0), 0, 0)
	sb.border_color = UiStyle.PANEL_BORDER
	sb.border_width_bottom = 1
	sb.content_margin_left = 24
	sb.content_margin_right = 24
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	top.add_theme_stylebox_override("panel", sb)
	_layout.add_child(top)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 18)
	top.add_child(h)
	var logo := Label.new()
	logo.text = "WORLDWAR"
	var lf := FontVariation.new()
	lf.base_font = load("res://ui/fonts/BigShouldersStencil-Black.ttf")
	lf.spacing_glyph = 2
	logo.add_theme_font_override("font", lf)
	logo.add_theme_font_size_override("font_size", 38)
	logo.add_theme_color_override("font_color", CREAM)
	logo.add_theme_color_override("font_shadow_color", RED)
	logo.add_theme_constant_override("shadow_offset_x", 3)
	logo.add_theme_constant_override("shadow_offset_y", 3)
	h.add_child(logo)
	h.add_child(UiStyle.vsep(40))
	var tv := VBoxContainer.new()
	tv.alignment = BoxContainer.ALIGNMENT_CENTER
	tv.add_theme_constant_override("separation", 2)
	tv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(tv)
	tv.add_child(UiStyle.title_label("Escolha seu país", 20))
	tv.add_child(UiStyle.small_label("%s · 1º de janeiro de 1936" % _main.sim.state.scenario_name, 12))
	var back := Button.new()
	back.text = "Voltar ao menu"
	back.icon = UiStyle.icon_texture("back")
	back.expand_icon = true
	back.add_theme_constant_override("icon_max_width", 14)
	back.custom_minimum_size = Vector2(0, 40)
	back.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	back.pressed.connect(func(): back_requested.emit())
	h.add_child(back)


# ---------------------------------------------------------------- lista

func _build_list(cols: HBoxContainer) -> void:
	var panel := UiStyle.panel(14)
	panel.custom_minimum_size = Vector2(360, 0)
	cols.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	panel.add_child(v)
	_filter = LineEdit.new()
	_filter.placeholder_text = "Buscar país..."
	_filter.right_icon = UiStyle.icon_texture("search_small")
	_filter.custom_minimum_size = Vector2(0, 40)
	_filter.text_changed.connect(func(_t): _fill_list())
	v.add_child(_filter)
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(_scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 3)
	_scroll.add_child(_list)


func _fill_list() -> void:
	UiStyle.clear(_list)
	_rows.clear()
	var q := _filter.text.strip_edges().to_lower()
	var majors := []
	var others := []
	for tag in _tags:
		var c: Country = _main.sim.state.country(tag)
		if q != "" and not _plain(q) in _plain(c.name):
			continue
		(majors if tag in MAJORS else others).append(tag)
	if not majors.is_empty():
		_list.add_child(_list_title("Grandes potências"))
		for tag in majors:
			_list.add_child(_row(tag))
	if not others.is_empty():
		if not majors.is_empty():
			var gap := Control.new()
			gap.custom_minimum_size = Vector2(0, 8)
			_list.add_child(gap)
		_list.add_child(_list_title("Demais países"))
		for tag in others:
			_list.add_child(_row(tag))
	if majors.is_empty() and others.is_empty():
		_list.add_child(UiStyle.dim_label("Nenhum país com esse nome."))
	_highlight_rows()


## Nome sem acentos e em minúsculas, para ordenar (Áustria junto do A) e buscar.
static func _plain(t: String) -> String:
	var out := t.to_lower()
	for pair in [["áàâãä", "a"], ["éèêë", "e"], ["íìîï", "i"], ["óòôõö", "o"], ["úùûü", "u"], ["ç", "c"]]:
		for ch in pair[0]:
			out = out.replace(ch, pair[1])
	return out


func _list_title(t: String) -> Control:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", 4)
	m.add_theme_constant_override("margin_bottom", 4)
	m.add_child(UiStyle.section(t))
	return m


func _row(tag: String) -> Button:
	var c: Country = _main.sim.state.country(tag)
	var b := UiStyle.plain_button(Vector2(0, 46))
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 8
	h.add_theme_constant_override("separation", 12)
	b.add_child(h)
	var fb := UiStyle.flag_box(Vector2(42, 28), false)
	UiStyle.set_flag(fb, tag, c.color)
	h.add_child(fb)
	var l := Label.new()
	l.text = c.name
	l.add_theme_font_size_override("font_size", 15)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	h.add_child(l)
	UiStyle.passthrough(h)
	b.pressed.connect(func(): select(tag))
	_rows[tag] = b
	return b


func _highlight_rows() -> void:
	for tag in _rows:
		var b: Button = _rows[tag]
		var on: bool = tag == _selected
		var sb := UiStyle.box(UiStyle.BG_HOVER if on else Color(0, 0, 0, 0), UiStyle.ACCENT if on else Color(0, 0, 0, 0), 1, 4)
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb if on else UiStyle.box(Color("#1d2024"), Color(0, 0, 0, 0), 0, 4))
		var l: Label = b.get_child(0).get_child(1)
		l.add_theme_color_override("font_color", UiStyle.ACCENT_LIGHT if on else UiStyle.TEXT)


# ---------------------------------------------------------------- ficha do país

func _build_sheet(cols: HBoxContainer) -> void:
	var panel := UiStyle.panel(24)
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(panel)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 18)
	panel.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 22)
	v.add_child(head)
	_flag_box = UiStyle.flag_box(Vector2(150, 100), true)
	head.add_child(_flag_box)
	var hv := VBoxContainer.new()
	hv.alignment = BoxContainer.ALIGNMENT_CENTER
	hv.add_theme_constant_override("separation", 6)
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 12)
	hv.add_child(name_row)
	_name = UiStyle.title_label("", 34)
	name_row.add_child(_name)
	_badge = PanelContainer.new()
	var bsb := UiStyle.box(Color(UiStyle.ACCENT, 0.16), UiStyle.PANEL_BORDER, 1, 3)
	bsb.content_margin_left = 8
	bsb.content_margin_right = 8
	bsb.content_margin_top = 2
	bsb.content_margin_bottom = 2
	_badge.add_theme_stylebox_override("panel", bsb)
	_badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_badge.add_child(UiStyle.title_label("Grande potência", 11))
	name_row.add_child(_badge)
	_facts = UiStyle.rich(400)
	hv.add_child(_facts)

	# números principais em placas
	var tiles := HBoxContainer.new()
	tiles.add_theme_constant_override("separation", 12)
	v.add_child(tiles)
	for spec in [["civ", "factory", "Fábricas civis"], ["mil", "factory", "Fábricas militares"],
			["money", "treasury", "Tesouro"], ["states", "map_political", "Estados"]]:
		tiles.add_child(_tile(spec[0], spec[1], spec[2]))

	# recursos
	var rhead := HBoxContainer.new()
	v.add_child(rhead)
	var rt := UiStyle.section("Produção de recursos por dia")
	rt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rhead.add_child(rt)
	rhead.add_child(UiStyle.small_label("parte da produção mundial", 11))
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 9)
	v.add_child(grid)
	for r in _main.sim.defs.resources:
		var nh := HBoxContainer.new()
		nh.add_theme_constant_override("separation", 10)
		nh.custom_minimum_size = Vector2(150, 0)
		nh.add_child(UiStyle.icon(r.id, Color(r.color), 18))
		var nl := Label.new()
		nl.text = r.name
		nh.add_child(nl)
		grid.add_child(nh)
		var val := UiStyle.number_label("", 16)
		val.custom_minimum_size = Vector2(56, 0)
		val.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(val)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 8)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		bar.add_theme_stylebox_override("fill", UiStyle.box(Color(r.color), Color(0, 0, 0, 0), 0, 2))
		grid.add_child(bar)
		var pct := UiStyle.small_label("", 12)
		pct.custom_minimum_size = Vector2(56, 0)
		pct.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		grid.add_child(pct)
		_res_rows[r.id] = {"value": val, "bar": bar, "pct": pct}
	v.add_child(UiStyle.small_label("Produção baseada em estatísticas reais de 1936 (docs/fontes-recursos.md).", 11))

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(spacer)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 12)
	v.add_child(actions)
	var see := Button.new()
	see.text = "VER NO MAPA"
	see.icon = UiStyle.icon_texture("map_political")
	see.expand_icon = true
	see.add_theme_constant_override("icon_max_width", 18)
	see.add_theme_font_override("font", UiStyle.font("title"))
	see.add_theme_font_size_override("font_size", 16)
	see.custom_minimum_size = Vector2(220, 50)
	see.pressed.connect(show_on_map)
	actions.add_child(see)
	_play = UiStyle.primary_button("Jogar", 50)
	_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_play.pressed.connect(_choose)
	actions.add_child(_play)


func _tile(id: String, icon_name: String, caption: String) -> PanelContainer:
	var p := PanelContainer.new()
	var sb := UiStyle.box(UiStyle.BG_DARK, UiStyle.LINE_WARM, 1, 4)
	sb.content_margin_left = 14
	sb.content_margin_right = 14
	sb.content_margin_top = 10
	sb.content_margin_bottom = 10
	p.add_theme_stylebox_override("panel", sb)
	p.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	p.add_child(h)
	h.add_child(UiStyle.icon(icon_name, UiStyle.MILITARY if id == "mil" else UiStyle.ACCENT, 22))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var val := UiStyle.number_label("", 22)
	v.add_child(val)
	v.add_child(UiStyle.title_label(caption, 10, UiStyle.MUTED))
	_tiles[id] = val
	return p


func select(tag: String) -> void:
	if tag == "" or _main.sim.state.country(tag) == null:
		return
	_selected = tag
	var sim: Simulation = _main.sim
	var st := sim.state
	var c := st.country(tag)
	_highlight_rows()
	_scroll_to(tag)
	UiStyle.set_flag(_flag_box, tag, c.color)
	_name.text = c.name.to_upper()
	_badge.visible = tag in MAJORS
	_facts.text = "%s\n%s     %s" % [
		UiStyle.kv("Líder", c.leader if c.leader != "" else "a definir"),
		UiStyle.kv("Ideologia", c.ideology if c.ideology != "" else "a definir"),
		UiStyle.kv("Capital", c.capital_city)]
	_tiles.civ.text = str(st.civil_factories(tag))
	_tiles.mil.text = str(st.military_factories(tag))
	_tiles.money.text = UiStyle.money(c.money, sim.defs.currency)
	_tiles.states.text = str(st.states_of(tag).size())
	for r in sim.defs.resources:
		var p := st.resource_production(tag, r.id)
		var w := st.world_production(r.id)
		var share := 0.0 if w == 0 else 100.0 * p / w
		var row: Dictionary = _res_rows[r.id]
		row.value.text = UiStyle.num(p)
		row.bar.value = share
		row.pct.text = ("%.1f%%" % share).replace(".", ",")
	_play.text = ("Jogar com %s" % c.name).to_upper()
	if _map_mode:
		_update_map_card()
		_highlight_on_map()


## Rola a lista até o país (espera a lista se arrumar antes).
func _scroll_to(tag: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	if _rows.has(tag) and is_instance_valid(_rows[tag]):
		_scroll.ensure_control_visible(_rows[tag])


func _choose() -> void:
	if _map_mode:
		_leave_map(false)
	country_chosen.emit(_selected)


# ---------------------------------------------------------------- ver no mapa

func _build_map_card() -> void:
	_map_card = UiStyle.panel(16)
	_map_card.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_map_card.custom_minimum_size = Vector2(640, 0)
	_map_card.offset_left = -320
	_map_card.offset_right = 320
	_map_card.offset_bottom = -24
	_map_card.grow_vertical = Control.GROW_DIRECTION_BEGIN
	_map_card.visible = false
	add_child(_map_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	_map_card.add_child(v)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	v.add_child(h)
	_map_flag = UiStyle.flag_box(Vector2(60, 40), true)
	h.add_child(_map_flag)
	var nv := VBoxContainer.new()
	nv.alignment = BoxContainer.ALIGNMENT_CENTER
	nv.add_theme_constant_override("separation", 2)
	nv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(nv)
	_map_name = UiStyle.title_label("", 24)
	nv.add_child(_map_name)
	nv.add_child(UiStyle.small_label("Clique em outro país no mapa para trocar. Roda do mouse: zoom.", 12))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	var back := Button.new()
	back.text = "Voltar à lista"
	back.icon = UiStyle.icon_texture("back")
	back.expand_icon = true
	back.add_theme_constant_override("icon_max_width", 14)
	back.custom_minimum_size = Vector2(180, 46)
	back.pressed.connect(func(): _leave_map(true))
	row.add_child(back)
	_map_play = UiStyle.primary_button("Jogar", 46)
	_map_play.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_map_play.pressed.connect(_choose)
	row.add_child(_map_play)


func show_on_map() -> void:
	_map_mode = true
	_scrim.visible = false
	_layout.visible = false
	_map_card.visible = true
	_update_map_card()
	_highlight_on_map()


func _update_map_card() -> void:
	var c: Country = _main.sim.state.country(_selected)
	UiStyle.set_flag(_map_flag, _selected, c.color)
	_map_name.text = c.name.to_upper()
	_map_play.text = ("Jogar com %s" % c.name).to_upper()


## Destaca o país escolhido (os outros ficam apagados) e leva a câmera até ele.
func _highlight_on_map() -> void:
	var st: GameState = _main.sim.state
	var tag := _selected
	var mine: Color = st.country(tag).color
	if mine.s < 0.25:   # cores acinzentadas (ex.: Alemanha) não se destacariam: usa o dourado
		mine = UiStyle.ACCENT
	mine = mine.lightened(0.1)
	_main.map.color_states(st, func(s: MapState):
		return mine if s.owner == tag else Color(0.12, 0.13, 0.14))
	var states: Array = st.states_of(tag)
	if states.is_empty():
		return
	var cam: MapCamera = _main.camera
	var capital: Vector2 = st.state(st.country(tag).capital_state).center
	var box := Rect2(capital, Vector2.ZERO)
	for s in states:
		# só junta o que está do mesmo lado do mundo que a capital (países que cruzam a borda)
		if absf(s.center.x - capital.x) < cam.map_size.x * 0.3:
			box = box.expand(s.center)
	var vp := get_viewport_rect().size
	var avail := Vector2(vp.x * 0.8, (vp.y - 230) * 0.8)
	var z := minf(avail.x / maxf(box.size.x, 40.0), avail.y / maxf(box.size.y, 30.0))
	z = clampf(z, cam.min_zoom(), 6.0)
	# o cartão de baixo cobre ~170 px: sobe o país para o meio do espaço livre
	var target := box.get_center() + Vector2(0, 105.0 / z)
	var tw := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tw.tween_method(func(t: float):
		cam.set_zoom_level(lerpf(_tw_from_zoom, z, t))
		cam.position = _tw_from_pos.lerp(target, t)
		cam._clamp(), 0.0, 1.0, 0.7)
	_tw_from_zoom = cam.zoom.x
	_tw_from_pos = _near(cam.position, target, cam.map_size.x)


var _tw_from_zoom := 1.0
var _tw_from_pos := Vector2.ZERO


## Posição de partida do voo do lado do mundo mais perto do destino (o mapa dá a volta).
func _near(from: Vector2, to: Vector2, width: float) -> Vector2:
	var dx := fposmod(from.x - to.x + width * 0.5, width) - width * 0.5
	return Vector2(to.x + dx, from.y)


func _leave_map(back_to_list: bool) -> void:
	_map_mode = false
	_main.map.color_by_owner(_main.sim.state)
	_map_card.visible = false
	if back_to_list:
		_scrim.visible = true
		_layout.visible = true
