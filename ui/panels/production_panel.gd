class_name ProductionPanel
extends PanelContainer
## Indústria e produção militar: divisão civil x militar das fábricas, linhas de produção e depósito.
## Na tela: o essencial (quantas fábricas, o que está sendo feito e quanto por dia).
## Eficiência, custo e recursos aparecem ao passar o mouse.

var _main
var _split_info: RichTextLabel
var _split: HSlider
var _lines: VBoxContainer
var _new_eq: OptionButton
var _new_fac: SpinBox
var _add: Button
var _depot: RichTextLabel
var _eq_ids: Array = []


func setup(main) -> void:
	_main = main
	UiStyle.place(self, 680)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	UiStyle.window_header(v, "Produção", "", func(): visible = false,
		"Fábricas civis fazem dinheiro (bens de consumo) e construções.\nFábricas militares fazem equipamento.\n"
		+ "Trocar o uso das fábricas leva alguns dias.")

	var sh := HBoxContainer.new()
	sh.add_theme_constant_override("separation", 10)
	v.add_child(sh)
	var l1 := Label.new()
	l1.text = "Civil"
	sh.add_child(l1)
	_split = HSlider.new()
	_split.min_value = 0
	_split.max_value = 100
	_split.step = 5
	_split.custom_minimum_size = Vector2(300, 0)
	_split.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	# O controle vai de "tudo civil" (esquerda) a "tudo militar" (direita).
	_split.drag_ended.connect(func(_c):
		_main.submit(SetCivilShareCommand.create(_main.player_tag, 1.0 - _split.value / 100.0)))
	sh.add_child(_split)
	var l2 := Label.new()
	l2.text = "Militar"
	sh.add_child(l2)
	_split_info = UiStyle.rich()
	_split_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_split_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	sh.add_child(_split_info)

	v.add_child(UiStyle.section("Linhas de produção"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 160)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_lines = VBoxContainer.new()
	_lines.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lines.add_theme_constant_override("separation", 4)
	scroll.add_child(_lines)

	var nh := HBoxContainer.new()
	v.add_child(nh)
	_new_eq = OptionButton.new()
	_new_eq.custom_minimum_size = Vector2(330, 0)
	_new_eq.clip_text = true
	nh.add_child(_new_eq)
	_new_fac = SpinBox.new()
	_new_fac.min_value = 1
	_new_fac.max_value = int(ProductionSystem.rules(main.sim.defs).get("max_factories_per_line", 15))
	_new_fac.value = 1
	_new_fac.suffix = "fáb."
	nh.add_child(_new_fac)
	_add = Button.new()
	_add.text = "Nova linha"
	_add.pressed.connect(func():
		if _new_eq.selected >= 0 and _new_eq.selected < _eq_ids.size():
			_main.submit(AddProductionLineCommand.create(_main.player_tag, _eq_ids[_new_eq.selected], int(_new_fac.value))))
	nh.add_child(_add)

	v.add_child(UiStyle.section("Depósito"))
	_depot = UiStyle.rich()
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

	if not _split.has_focus():
		_split.set_value_no_signal((1.0 - c.civil_share_target) * 100.0)
	var t := "[b]%d[/b] civis  ·  [b]%d[/b] militares" % [gs.civil_factories(tag), gs.military_factories(tag)]
	var days := IndustrySystem.days_to_target(c, sim.defs)
	if days > 0:
		t += "\n[color=#e0a060]convertendo, %d dias[/color]" % days
	_split_info.text = t

	# Linhas
	UiStyle.clear(_lines)
	var requested := 0
	var free := gs.military_factories(tag)
	for l in c.production_lines:
		requested += int(l.factories)
		var gets := mini(int(l.factories), free)   # mesma ordem que o ProductionSystem usa
		free -= gets
		_lines.add_child(_line_row(l, gets))
	if c.production_lines.is_empty():
		_lines.add_child(UiStyle.dim_label("Nenhuma linha. Escolha um equipamento abaixo."))
	var notes: Array = []
	if requested > gs.military_factories(tag):
		notes.append("Faltam fábricas militares: as últimas linhas ficam paradas.")
	if not c.last_shortage.is_empty():
		var parts: Array = []
		for r in c.last_shortage:
			parts.append(ResearchPanel._res_name(sim.defs, r))
		notes.append("Falta %s no estoque: produção mais lenta." % ", ".join(parts))
	for n in notes:
		var warn := UiStyle.dim_label(n)
		warn.modulate = Color(1.0, 0.75, 0.45)
		_lines.add_child(warn)

	# Equipamentos que dá para produzir
	var unlocked := ResearchSystem.unlocked_equipment(sim.defs, c)
	if unlocked != _eq_ids or _new_eq.item_count == 0:
		_eq_ids = unlocked
		_new_eq.clear()
		for eq in _eq_ids:
			_new_eq.add_item(sim.defs.equipment[eq].name)
		if _eq_ids.is_empty():
			_new_eq.add_item("Pesquise um equipamento primeiro")
	_add.disabled = _eq_ids.is_empty()

	# Depósito
	var items: Array = []
	for eq in c.equipment:
		var e: Dictionary = sim.defs.equipment.get(eq, {})
		items.append("%s [b]%s[/b]" % [e.get("name", eq), UiStyle.num(c.equipment[eq])])
	_depot.text = "     ".join(items) if not items.is_empty() else "[color=#888]Vazio.[/color]"


func _line_row(l: Dictionary, gets: int) -> HBoxContainer:
	var sim: Simulation = _main.sim
	var e: Dictionary = sim.defs.equipment.get(l.equipment, {})
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var name_l := Label.new()
	name_l.text = e.get("name", l.equipment)
	name_l.custom_minimum_size = Vector2(250, 0)
	name_l.clip_text = true
	name_l.mouse_filter = Control.MOUSE_FILTER_STOP
	var res: Array = []
	for r in e.get("resources", {}):
		res.append("%s %s" % [ResearchPanel._fmt(e.resources[r]), ResearchPanel._res_name(sim.defs, r)])
	name_l.tooltip_text = "%s (%s)\nCusto: %s dias-fábrica\nGasta por unidade: %s" % [
		e.get("name", ""), e.get("unit", ""), ResearchPanel._fmt(e.get("cost", 0)), ", ".join(res)]
	h.add_child(name_l)
	var lid := int(l.id)
	var minus := Button.new()
	minus.text = "-"
	minus.custom_minimum_size = Vector2(28, 0)
	minus.pressed.connect(func(): _main.submit(SetLineFactoriesCommand.create(_main.player_tag, lid, maxi(0, int(l.factories) - 1))))
	h.add_child(minus)
	var fac := Label.new()
	fac.text = "%d fáb." % int(l.factories)
	fac.custom_minimum_size = Vector2(60, 0)
	fac.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	h.add_child(fac)
	var plus := Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(28, 0)
	plus.pressed.connect(func(): _main.submit(SetLineFactoriesCommand.create(_main.player_tag, lid, mini(15, int(l.factories) + 1))))
	h.add_child(plus)
	var out := Label.new()
	var per_day := gets * float(l.efficiency) / maxf(float(e.get("cost", 1.0)), 0.01)
	out.text = "%s/dia" % UiStyle.price(per_day) if per_day > 0 else "parada"
	out.custom_minimum_size = Vector2(90, 0)
	out.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	out.mouse_filter = Control.MOUSE_FILTER_STOP
	out.tooltip_text = "Eficiência %d%% (sobe com o tempo)\n%d de %d fábricas trabalhando" % [
		int(round(float(l.efficiency) * 100.0)), gets, int(l.factories)]
	h.add_child(out)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(sp)
	var rm := Button.new()
	rm.text = "Fechar linha"
	rm.flat = true
	rm.modulate = Color(1, 1, 1, 0.6)
	rm.pressed.connect(func(): _main.submit(RemoveProductionLineCommand.create(_main.player_tag, lid)))
	h.add_child(rm)
	return h
