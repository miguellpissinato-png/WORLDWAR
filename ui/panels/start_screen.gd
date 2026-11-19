class_name StartScreen
extends PanelContainer
## Tela de escolha do país. É o único momento em que a produção de todos os países fica à vista;
## depois de começar, os dados dos outros só chegam por relatórios de inteligência.

signal country_chosen(tag: String)

var _main
var _list: ItemList
var _filter: LineEdit
var _details: RichTextLabel
var _play: Button
var _tags: Array = []
var _selected := ""


func setup(main) -> void:
	_main = main
	var sb := StyleBoxFlat.new()
	sb.bg_color = UiStyle.PANEL_BG
	sb.border_color = UiStyle.ACCENT
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(4)
	sb.set_content_margin_all(16)
	add_theme_stylebox_override("panel", sb)
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(900, 560)
	offset_left = -450
	offset_right = 450
	offset_top = -280
	offset_bottom = 280

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var title := Label.new()
	title.text = "WorldWar — %s" % main.sim.state.scenario_name
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", UiStyle.ACCENT)
	v.add_child(title)
	v.add_child(UiStyle.dim_label("1º de janeiro de 1936. Escolha o país que você vai governar. "
		+ "Esta é a única vez em que você vê a produção de todos os países: no jogo, só a inteligência revela os dados dos outros."))

	var h := HBoxContainer.new()
	h.size_flags_vertical = Control.SIZE_EXPAND_FILL
	h.add_theme_constant_override("separation", 16)
	v.add_child(h)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(300, 0)
	h.add_child(left)
	_filter = LineEdit.new()
	_filter.placeholder_text = "Buscar país..."
	_filter.text_changed.connect(func(_t): _fill_list())
	left.add_child(_filter)
	_list = ItemList.new()
	_list.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_list.item_selected.connect(func(i): select(_list.get_item_metadata(i)))
	left.add_child(_list)

	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(right)
	_details = RichTextLabel.new()
	_details.bbcode_enabled = true
	_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_details)
	_play = Button.new()
	_play.custom_minimum_size = Vector2(0, 44)
	_play.add_theme_font_size_override("font_size", 18)
	_play.pressed.connect(func(): country_chosen.emit(_selected))
	right.add_child(_play)

	_tags = main.sim.state.countries.keys()
	_tags.sort_custom(func(a, b): return main.sim.state.country(a).name < main.sim.state.country(b).name)
	_fill_list()


func _fill_list() -> void:
	_list.clear()
	var q := _filter.text.strip_edges().to_lower()
	for tag in _tags:
		var c: Country = _main.sim.state.country(tag)
		if q != "" and not q in c.name.to_lower():
			continue
		var i := _list.add_item(c.name)
		_list.set_item_metadata(i, tag)
		_list.set_item_icon_modulate(i, c.color)
		if tag == _selected:
			_list.select(i)


func select(tag: String) -> void:
	_selected = tag
	var sim: Simulation = _main.sim
	var st := sim.state
	var c := st.country(tag)
	for i in _list.item_count:
		if _list.get_item_metadata(i) == tag:
			_list.select(i)
			_list.ensure_current_is_visible()
	var a := UiStyle.ACCENT_HEX
	var t := "[font_size=22][b]%s[/b][/font_size]\n" % c.name
	t += "[color=%s]Líder:[/color] %s     [color=%s]Ideologia:[/color] %s\n" % [a, c.leader if c.leader != "" else "a definir", a, c.ideology if c.ideology != "" else "a definir"]
	t += "[color=%s]Capital:[/color] %s     [color=%s]Estados:[/color] %d\n" % [a, c.capital_city, a, st.states_of(tag).size()]
	t += "[color=%s]Fábricas civis:[/color] %d     [color=%s]Fábricas militares:[/color] %d     [color=%s]Tesouro:[/color] %s\n\n" % [
		a, st.total_building(tag, "civilian_factory"), a, st.total_building(tag, "military_factory"), a, UiStyle.money(c.money, sim.defs.currency)]
	t += "[b]Produção de recursos (por dia)[/b]\n[table=4]"
	t += "[cell][color=%s]Recurso[/color]   [/cell][cell][color=%s]Produção[/color]   [/cell][cell][color=%s]Mundo[/color]   [/cell][cell][color=%s]Participação[/color][/cell]" % [a, a, a, a]
	for r in sim.defs.resources:
		var p := st.resource_production(tag, r.id)
		var w := st.world_production(r.id)
		var share := 0.0 if w == 0 else 100.0 * p / w
		t += "[cell][color=%s]%s[/color]   [/cell][cell]%d   [/cell][cell]%d   [/cell][cell]%.1f%%[/cell]" % [r.color, r.name, p, w, share]
	t += "[/table]\n\n[color=#888]Dados de produção baseados em estatísticas reais de 1936 (ver docs/fontes-recursos.md).[/color]"
	_details.text = t
	_play.text = "Jogar com %s" % c.name
