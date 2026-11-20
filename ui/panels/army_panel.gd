class_name ArmyPanel
extends PanelContainer
## Exército: grupos (onde estão, para onde vão, general), formar regimentos com o equipamento do
## depósito e os generais. Ordens de marcha são dadas no mapa (clique no boneco, botão direito no destino).

var _main
var _groups: VBoxContainer
var _type: OptionButton
var _target: OptionButton
var _need: Label
var _form: Button
var _generals: VBoxContainer
var _recruit: Button
var _type_ids: Array = []
var _target_ids: Array = []


func setup(main) -> void:
	_main = main
	UiStyle.place(self, 700)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	UiStyle.window_header(v, "Exército", "Clique num soldado no mapa e depois, com o botão direito, no destino.",
		func(): visible = false,
		"Regimentos ficam prontos na hora e usam o equipamento do depósito.\nCada grupo tem até %d regimentos; cada general comanda até %d grupos.\nAs tropas só marcham dentro do próprio país por enquanto." % [
			int(main.sim.defs.army.max_regiments_per_group), int(main.sim.defs.army.max_groups_per_general)])

	v.add_child(UiStyle.section("Grupos"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 110)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	_groups = VBoxContainer.new()
	_groups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_groups.add_theme_constant_override("separation", 3)
	scroll.add_child(_groups)

	v.add_child(UiStyle.section("Formar regimento"))
	var fh := HBoxContainer.new()
	fh.add_theme_constant_override("separation", 8)
	v.add_child(fh)
	_type = OptionButton.new()
	_type.custom_minimum_size = Vector2(210, 0)
	_type.item_selected.connect(func(_i): _update_form())
	fh.add_child(_type)
	var em := Label.new()
	em.text = "em"
	fh.add_child(em)
	_target = OptionButton.new()
	_target.custom_minimum_size = Vector2(230, 0)
	_target.clip_text = true
	_target.item_selected.connect(func(_i): _update_form())
	fh.add_child(_target)
	_form = Button.new()
	_form.text = "Formar"
	_form.pressed.connect(func():
		if _type.selected < 0 or _type.selected >= _type_ids.size():
			return
		var cmd := FormRegimentCommand.create(_main.player_tag, _type_ids[_type.selected], _target_ids[_target.selected])
		_main.submit(cmd)
		if cmd.created_group != -1:
			_main.units.select(cmd.created_group))
	fh.add_child(_form)
	_need = UiStyle.dim_label("")
	v.add_child(_need)

	v.add_child(UiStyle.section("Generais"))
	_generals = VBoxContainer.new()
	v.add_child(_generals)
	_recruit = Button.new()
	_recruit.pressed.connect(func(): _main.submit(RecruitGeneralCommand.create(_main.player_tag)))
	v.add_child(_recruit)


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	if not visible:
		return
	var sim: Simulation = _main.sim
	var st := sim.state
	var tag: String = _main.player_tag
	var defs := sim.defs

	# Grupos
	UiStyle.clear(_groups)
	var groups := st.groups_of(tag)
	if groups.is_empty():
		_groups.add_child(UiStyle.dim_label("Nenhum grupo. Forme um regimento abaixo."))
	for g: ArmyGroup in groups:
		_groups.add_child(_group_row(g))

	# Tipos de regimento disponíveis (pesquisados)
	var types: Array = []
	for t in defs.army.regiments:
		if st.country(tag).has_tech("t_" + t):
			types.append(t)
	if types != _type_ids:
		_type_ids = types
		_type.clear()
		for t in types:
			_type.add_item(defs.army.regiments[t].name)
	var targets: Array = [-1]
	for g: ArmyGroup in groups:
		if g.regiments.size() < int(defs.army.max_regiments_per_group):
			targets.append(g.id)
	if targets != _target_ids:
		var keep: int = _target_ids[_target.selected] if _target.selected >= 0 and _target.selected < _target_ids.size() else -1
		_target_ids = targets
		_target.clear()
		for id in targets:
			_target.add_item("um grupo novo na capital" if id == -1 else st.group(id).name)
		_target.select(maxi(0, targets.find(keep)))
	_update_form()

	# Generais
	UiStyle.clear(_generals)
	for gen: General in st.generals_of(tag):
		var n := ArmySystem.groups_of_general(st, gen.id).size()
		var r := UiStyle.rich()
		r.text = "[b]%s[/b]   [color=#999]Ataque[/color] %d  [color=#999]Defesa[/color] %d  [color=#999]Velocidade[/color] %d   [color=#999]· %s[/color]" % [
			gen.name, gen.attack, gen.defense, gen.speed, "sem grupos" if n == 0 else "%d de %d grupos" % [n, int(defs.army.max_groups_per_general)]]
		_generals.add_child(r)
	var cost := float(defs.army.generals.recruit_cost)
	_recruit.text = "Promover um novo general  ·  %s" % UiStyle.money(cost, defs.currency)
	_recruit.disabled = st.country(tag).money < cost


func _update_form() -> void:
	if _type.selected < 0 or _type.selected >= _type_ids.size():
		_form.disabled = true
		_need.text = "Pesquise uma tropa em Pesquisa > Tropas e especializações."
		return
	var sim: Simulation = _main.sim
	var type: String = _type_ids[_type.selected]
	var c: Country = sim.state.country(_main.player_tag)
	var parts: Array = []
	for need in ArmySystem.regiment_def(sim.defs, type).needs:
		var have := 0
		for eq in ArmySystem.ranked_equipment(sim.defs, c, need.categories):
			have += int(c.equipment_count(eq))
		parts.append("%d %s (tem %d)" % [int(need.qty), "/".join(need.categories.map(func(x): return ArmySystem.category_plural(x))), have])
	_need.text = "Precisa de " + ", ".join(parts) + "."
	var why := ArmySystem.can_form(sim.state, sim.defs, _main.player_tag, type, _target_ids[_target.selected] if _target.selected >= 0 else -1)
	_form.disabled = why != ""
	_form.tooltip_text = why


func _group_row(g: ArmyGroup) -> HBoxContainer:
	var sim: Simulation = _main.sim
	var st := sim.state
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var name_b := Button.new()
	name_b.text = g.name
	name_b.custom_minimum_size = Vector2(110, 0)
	if g.id == _main.units.selected:
		name_b.add_theme_color_override("font_color", UiStyle.ACCENT)
	var gid := g.id
	name_b.pressed.connect(func():
		_main.units.select(gid)
		_main.camera.position = MovementSystem.map_position(st, st.group(gid)))
	h.add_child(name_b)
	var where := Label.new()
	where.custom_minimum_size = Vector2(250, 0)
	where.clip_text = true
	if g.moving():
		where.text = "indo para %s · %d dias" % [st.state(g.destination()).name, ceili(ArmySystem.eta_days(st, sim.defs, g))]
	else:
		where.text = "em %s" % st.state(g.state_id).name
	where.tooltip_text = summary(sim, g)
	where.mouse_filter = Control.MOUSE_FILTER_STOP
	h.add_child(where)
	var gen := OptionButton.new()
	gen.custom_minimum_size = Vector2(190, 0)
	gen.clip_text = true
	gen.add_item("sem general")
	gen.set_item_metadata(0, -1)
	var i := 1
	for x: General in st.generals_of(g.owner):
		gen.add_item(x.name)
		gen.set_item_metadata(i, x.id)
		if x.id == g.general_id:
			gen.select(i)
		i += 1
	gen.item_selected.connect(func(idx): _main.submit(AssignGeneralCommand.create(_main.player_tag, gid, gen.get_item_metadata(idx))))
	h.add_child(gen)
	var rm := Button.new()
	rm.text = "Dissolver"
	rm.flat = true
	rm.modulate = Color(1, 1, 1, 0.6)
	rm.tooltip_text = "Desfaz o grupo; o equipamento volta ao depósito."
	rm.pressed.connect(func(): _main.submit(DisbandGroupCommand.create(_main.player_tag, gid)))
	h.add_child(rm)
	return h


## Resumo do grupo em texto simples (tooltip e cartão do grupo).
static func summary(sim: Simulation, g: ArmyGroup) -> String:
	var counts := {}
	for r in g.regiments:
		var n: String = ArmySystem.regiment_def(sim.defs, r.type).get("name", r.type)
		counts[n] = int(counts.get(n, 0)) + 1
	var parts: Array = []
	for n in counts:
		parts.append("%d× %s" % [counts[n], n])
	var eq := {}
	for r in g.regiments:
		for k in r.equipment:
			eq[k] = int(eq.get(k, 0)) + int(r.equipment[k])
	var eparts: Array = []
	for k in eq:
		eparts.append("%s ×%d" % [sim.defs.equipment[k].name, eq[k]])
	return "%s\nEquipamento: %s\nMarcha: %d km por dia" % [", ".join(parts), ", ".join(eparts),
		int(ArmySystem.march_km_day(sim.state, sim.defs, g))]
