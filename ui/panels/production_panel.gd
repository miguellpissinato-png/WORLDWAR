class_name ProductionPanel
extends PanelContainer
## Indústria e produção militar: divisão das fábricas entre uso civil e militar,
## linhas de produção (fábricas, eficiência, unidades por dia) e o depósito de equipamento.

var _main
var _split_info: RichTextLabel
var _split: HSlider
var _split_pct: Label
var _lines: VBoxContainer
var _new_eq: OptionButton
var _new_fac: SpinBox
var _add: Button
var _depot: RichTextLabel
var _eq_ids: Array = []


func setup(main) -> void:
	_main = main
	add_theme_stylebox_override("panel", UiStyle.panel().get_theme_stylebox("panel"))
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -330
	offset_right = 470
	offset_top = 64
	visible = false

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	v.add_child(UiStyle.header("Indústria e produção militar", func(): visible = false))

	v.add_child(UiStyle.section("Divisão das fábricas"))
	v.add_child(UiStyle.dim_label("Fábricas civis fazem bens de consumo (dinheiro) e construções. Fábricas militares "
		+ "fazem equipamento. Mais militar = menos dinheiro. A conversão leva alguns dias."))
	var sh := HBoxContainer.new()
	v.add_child(sh)
	var l1 := Label.new()
	l1.text = "Mais militar"
	sh.add_child(l1)
	_split = HSlider.new()
	_split.min_value = 0
	_split.max_value = 100
	_split.step = 5
	_split.custom_minimum_size = Vector2(360, 0)
	_split.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_split.value_changed.connect(func(val): _split_pct.text = "%d%% civil · %d%% militar" % [int(val), 100 - int(val)])
	_split.drag_ended.connect(func(_c): _main.submit(SetCivilShareCommand.create(_main.player_tag, _split.value / 100.0)))
	sh.add_child(_split)
	var l2 := Label.new()
	l2.text = "Mais civil   "
	sh.add_child(l2)
	_split_pct = Label.new()
	_split_pct.custom_minimum_size = Vector2(190, 0)
	_split_pct.add_theme_color_override("font_color", UiStyle.ACCENT)
	sh.add_child(_split_pct)
	_split_info = RichTextLabel.new()
	_split_info.bbcode_enabled = true
	_split_info.fit_content = true
	v.add_child(_split_info)

	v.add_child(UiStyle.section("Linhas de produção"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 190)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_lines = VBoxContainer.new()
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_lines)

	var nh := HBoxContainer.new()
	v.add_child(nh)
	_new_eq = OptionButton.new()
	_new_eq.custom_minimum_size = Vector2(360, 0)
	nh.add_child(_new_eq)
	var fl := Label.new()
	fl.text = " Fábricas:"
	nh.add_child(fl)
	_new_fac = SpinBox.new()
	_new_fac.min_value = 1
	_new_fac.max_value = int(ProductionSystem.rules(main.sim.defs).get("max_factories_per_line", 15))
	_new_fac.value = 1
	nh.add_child(_new_fac)
	_add = Button.new()
	_add.text = "Abrir linha"
	_add.pressed.connect(func():
		if _new_eq.selected >= 0 and _new_eq.selected < _eq_ids.size():
			_main.submit(AddProductionLineCommand.create(_main.player_tag, _eq_ids[_new_eq.selected], int(_new_fac.value))))
	nh.add_child(_add)

	v.add_child(UiStyle.section("Depósito de equipamento"))
	_depot = RichTextLabel.new()
	_depot.bbcode_enabled = true
	_depot.fit_content = true
	v.add_child(_depot)


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	if not visible:
		return
	var sim: Simulation = _main.sim
	var gs := sim.state
	var tag: String = _main.player_tag
	var c: Country = gs.country(tag)
	var a := UiStyle.ACCENT_HEX

	if not _split.has_focus():
		_split.set_value_no_signal(c.civil_share_target * 100.0)
		var pct := int(round(c.civil_share_target * 100.0))
		_split_pct.text = "%d%% civil · %d%% militar" % [pct, 100 - pct]
	var t := "[color=%s]Fábricas:[/color] %d     [color=%s]Civis:[/color] %d     [color=%s]Militares:[/color] %d" % [
		a, gs.factories(tag), a, gs.civil_factories(tag), a, gs.military_factories(tag)]
	var days := IndustrySystem.days_to_target(c, sim.defs)
	if days > 0:
		t += "\n[color=#e0a060]Convertendo: %d%% civil agora, alvo %d%% (faltam %d dias)[/color]" % [
			int(round(c.civil_share * 100.0)), int(round(c.civil_share_target * 100.0)), days]
	_split_info.text = t

	# Linhas
	for ch in _lines.get_children():
		ch.queue_free()
	var requested := 0
	for l in c.production_lines:
		requested += int(l.factories)
		_lines.add_child(_line_row(l))
	if c.production_lines.is_empty():
		_lines.add_child(UiStyle.dim_label("Nenhuma linha aberta. Escolha um equipamento pesquisado abaixo."))
	elif requested > gs.military_factories(tag):
		_lines.add_child(UiStyle.dim_label("As linhas pedem %d fábricas, mas só há %d militares: as últimas linhas ficam paradas." % [
			requested, gs.military_factories(tag)]))
	if not c.last_shortage.is_empty():
		var parts: Array = []
		for r in c.last_shortage:
			parts.append(ResearchPanel._res_name(sim.defs, r))
		var warn := UiStyle.dim_label("Faltou %s no estoque ontem: a produção andou mais devagar (no mínimo %d%% da velocidade). Compre no mercado ou aumente a extração." % [
			", ".join(parts), int(100 * float(ProductionSystem.rules(sim.defs).get("shortage_floor", 0.25)))])
		warn.modulate = Color(1.0, 0.75, 0.45)
		_lines.add_child(warn)

	# Equipamentos que dá para produzir
	var unlocked := ResearchSystem.unlocked_equipment(sim.defs, c)
	if unlocked != _eq_ids:
		_eq_ids = unlocked
		_new_eq.clear()
		for eq in _eq_ids:
			var e: Dictionary = sim.defs.equipment[eq]
			_new_eq.add_item("%s (%s)" % [e.name, e.category_name])
	_add.disabled = _eq_ids.is_empty()
	if _eq_ids.is_empty():
		_new_eq.clear()
		_new_eq.add_item("Nenhum equipamento pesquisado")

	# Depósito
	var lines: Array = []
	for eq in c.equipment:
		var e: Dictionary = sim.defs.equipment.get(eq, {})
		var made := int(c.last_production.get(eq, 0))
		lines.append("%s: [color=%s]%s[/color] %s%s" % [e.get("name", eq), a, UiStyle.num(c.equipment[eq]),
			e.get("unit", ""), ("  (+%d ontem)" % made) if made > 0 else ""])
	_depot.text = "\n".join(lines) if not lines.is_empty() else "[color=#888](vazio)[/color]"


func _line_row(l: Dictionary) -> HBoxContainer:
	var sim: Simulation = _main.sim
	var e: Dictionary = sim.defs.equipment.get(l.equipment, {})
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var name_l := Label.new()
	name_l.text = e.get("name", l.equipment)
	name_l.custom_minimum_size = Vector2(250, 0)
	name_l.mouse_filter = Control.MOUSE_FILTER_STOP
	name_l.tooltip_text = "%s\nCusto: %s dias-fábrica por %s" % [e.get("category_name", ""), str(e.get("cost", "")), e.get("unit", "")]
	h.add_child(name_l)
	var lid := int(l.id)
	var minus := Button.new()
	minus.text = "-"
	minus.pressed.connect(func(): _main.submit(SetLineFactoriesCommand.create(_main.player_tag, lid, maxi(0, int(l.factories) - 1))))
	h.add_child(minus)
	var fac := Label.new()
	fac.text = "%d fáb." % int(l.factories)
	if int(l.get("assigned", l.factories)) < int(l.factories):
		fac.text += " (%d em uso)" % int(l.get("assigned", 0))
	fac.custom_minimum_size = Vector2(120, 0)
	fac.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(fac)
	var plus := Button.new()
	plus.text = "+"
	plus.pressed.connect(func(): _main.submit(SetLineFactoriesCommand.create(_main.player_tag, lid, mini(15, int(l.factories) + 1))))
	h.add_child(plus)
	var eff := Label.new()
	eff.text = "eficiência %d%%" % int(round(float(l.efficiency) * 100.0))
	eff.custom_minimum_size = Vector2(130, 0)
	h.add_child(eff)
	var out := Label.new()
	out.text = "%s/dia" % UiStyle.price(ProductionSystem.daily_output(sim.defs, l))
	out.custom_minimum_size = Vector2(80, 0)
	h.add_child(out)
	var rm := Button.new()
	rm.text = "Fechar"
	rm.pressed.connect(func(): _main.submit(RemoveProductionLineCommand.create(_main.player_tag, lid)))
	h.add_child(rm)
	return h
