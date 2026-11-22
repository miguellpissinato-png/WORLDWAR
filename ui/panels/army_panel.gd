class_name ArmyPanel
extends PanelContainer
## Exército: encomendar tropas às fábricas militares (botão +), acompanhar o preparo, ver as pilhas
## de tropas espalhadas pelo país e os generais. As tropas nascem no estado favorito (estrela na
## ficha do estado). Ordens de marcha são dadas no mapa (clique no boneco e depois no destino).

const TYPE_ICONS := {"infantaria": "army", "artilharia": "target", "tanques": "factory", "avioes": "map_political"}

var _main
var _info: RichTextLabel
var _recruit_rows: VBoxContainer
var _queue: VBoxContainer
var _groups: VBoxContainer
var _generals: VBoxContainer
var _recruit_general: Button


func setup(main) -> void:
	_main = main
	UiStyle.place(self, 720)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 7)
	add_child(v)
	UiStyle.window_header(v, "Exército", "Encomende tropas: as fábricas militares preparam e elas nascem no estado favorito.",
		func(): visible = false,
		"Cada + encomenda um lote. O lote usa as fábricas militares e recursos do estoque e fica pronto depois de alguns dias.\n"
		+ "Marque o estado favorito com a estrela na ficha de um estado seu. Se ele estiver cheio, as tropas nascem nos vizinhos.\n"
		+ "No mapa: clique numa pilha de tropas e depois no destino. Na ficha da pilha dá para enviar só uma parte.")
	_info = UiStyle.rich(680)
	v.add_child(_info)
	# o resto rola, para caber em telas baixas
	var outer := ScrollContainer.new()
	outer.custom_minimum_size = Vector2(0, 520)
	outer.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(outer)
	v = VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 7)
	outer.add_child(v)

	v.add_child(UiStyle.section("Encomendar tropas"))
	_recruit_rows = VBoxContainer.new()
	_recruit_rows.add_theme_constant_override("separation", 4)
	v.add_child(_recruit_rows)

	v.add_child(UiStyle.section("Em preparo"))
	_queue = VBoxContainer.new()
	_queue.add_theme_constant_override("separation", 3)
	v.add_child(_queue)

	v.add_child(UiStyle.section("Tropas no mapa"))
	_groups = VBoxContainer.new()
	_groups.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_groups.add_theme_constant_override("separation", 3)
	v.add_child(_groups)

	v.add_child(UiStyle.section("Generais"))
	_generals = VBoxContainer.new()
	v.add_child(_generals)
	_recruit_general = Button.new()
	_recruit_general.pressed.connect(func(): _main.submit(RecruitGeneralCommand.create(_main.player_tag)))
	v.add_child(_recruit_general)


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
	var c := st.country(tag)
	var rally := ArmySystem.rally_state(st, tag)
	var mil := st.military_factories(tag)
	_info.text = "%s   %s   [color=#999](mude com a estrela na ficha de um estado seu)[/color]" % [
		UiStyle.kv("Fábricas militares", str(mil) if mil > 0 else "[color=#d9503c]nenhuma[/color]"),
		UiStyle.kv("Estado favorito", st.state(rally).name if rally != -1 else "—")]

	# Encomendar
	UiStyle.clear(_recruit_rows)
	var queued := {}
	for item in c.recruit_queue:
		queued[item.type] = int(queued.get(item.type, 0)) + int(item.count)
	for type in ArmySystem.troop_types(defs):
		_recruit_rows.add_child(_recruit_row(type, int(queued.get(type, 0))))

	# Fila
	UiStyle.clear(_queue)
	if c.recruit_queue.is_empty():
		_queue.add_child(UiStyle.dim_label("Nada em preparo. Use os botões + acima."))
	for item in c.recruit_queue:
		_queue.add_child(_queue_row(item))

	# Pilhas
	UiStyle.clear(_groups)
	var groups := st.groups_of(tag)
	if groups.is_empty():
		_groups.add_child(UiStyle.dim_label("Nenhuma tropa no mapa."))
	for g: ArmyGroup in groups:
		_groups.add_child(_group_row(g))

	# Generais
	UiStyle.clear(_generals)
	for gen: General in st.generals_of(tag):
		var n := ArmySystem.groups_of_general(st, gen.id).size()
		var r := UiStyle.rich()
		r.text = "[b]%s[/b]   [color=#999]Ataque[/color] %d  [color=#999]Defesa[/color] %d  [color=#999]Velocidade[/color] %d   [color=#999]· %s[/color]" % [
			gen.name, gen.attack, gen.defense, gen.speed, "sem tropas" if n == 0 else "comanda %d de %d pilhas" % [n, int(defs.army.max_groups_per_general)]]
		_generals.add_child(r)
	var cost := float(defs.army.generals.recruit_cost)
	_recruit_general.text = "Promover um novo general  ·  %s" % UiStyle.money(cost, defs.currency)
	_recruit_general.disabled = c.money < cost


func _recruit_row(type: String, in_queue: int) -> Control:
	var sim: Simulation = _main.sim
	var defs := sim.defs
	var td := ArmySystem.troop_def(defs, type)
	var c := sim.state.country(_main.player_tag)
	var model := ArmySystem.best_model(defs, c, type)
	var box := PanelContainer.new()
	box.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.BG_DARK, Color(UiStyle.ACCENT, 0.18), 1, 4, 6))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	box.add_child(h)
	h.add_child(UiStyle.icon(TYPE_ICONS.get(type, "army"), UiStyle.ACCENT, 22))
	var v := VBoxContainer.new()
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_constant_override("separation", 0)
	h.add_child(v)
	var title := Label.new()
	title.add_theme_font_override("font", UiStyle.font("bold"))
	title.text = str(td.get("name", type))
	v.add_child(title)
	var plus := Button.new()
	plus.text = "+%d" % int(td.get("batch", 10))
	plus.custom_minimum_size = Vector2(64, 34)
	var plus5 := Button.new()
	plus5.text = "+%d" % (int(td.get("batch", 10)) * 5)
	plus5.custom_minimum_size = Vector2(64, 34)
	plus5.flat = true
	if model == "":
		v.add_child(UiStyle.small_label("Sem modelo: pesquise em Pesquisa.", 11, UiStyle.WARN))
		plus.disabled = true
		plus5.disabled = true
	else:
		var cost := ArmySystem.batch_cost(defs, type, model, 1)
		var res := []
		for r in cost.resources:
			if float(cost.resources[r]) >= 0.005:
				res.append("%s %s" % [_res_name(r), _short(cost.resources[r])])
		v.add_child(UiStyle.small_label("%s  ·  lote de %d %s: %d dias, %s dias-fábrica%s" % [defs.equipment[model].name,
			int(cost.count), td.get("short", ""), int(cost.days), _short(cost.work), ("  ·  " + ", ".join(res)) if not res.is_empty() else ""], 11))
	var q := UiStyle.number_label(("%d na fila" % in_queue) if in_queue > 0 else "", 13, UiStyle.ACCENT)
	q.custom_minimum_size = Vector2(90, 0)
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	h.add_child(q)
	plus.tooltip_text = "Encomendar um lote"
	plus5.tooltip_text = "Encomendar 5 lotes"
	plus.pressed.connect(func(): _main.submit(RecruitTroopsCommand.create(_main.player_tag, type, 1)))
	plus5.pressed.connect(func(): _main.submit(RecruitTroopsCommand.create(_main.player_tag, type, 5)))
	h.add_child(plus5)
	h.add_child(plus)
	return box


func _queue_row(item: Dictionary) -> Control:
	var sim: Simulation = _main.sim
	var defs := sim.defs
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var name_l := Label.new()
	name_l.text = "%d %s" % [int(item.count), ArmySystem.troop_def(defs, item.type).get("short", item.type)]
	name_l.custom_minimum_size = Vector2(120, 0)
	h.add_child(name_l)
	var bar := ProgressBar.new()
	bar.max_value = 1.0
	bar.value = clampf(float(item.work_done) / maxf(float(item.work), 0.001), 0.0, 1.0)
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 10)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	h.add_child(bar)
	var eta := RecruitSystem.eta_days(sim.state, defs, _main.player_tag, int(item.id))
	var when := UiStyle.small_label("parado: sem fábricas livres" if eta < 0 else ("pronto amanhã" if eta <= 1 else "faltam %d dias" % eta), 12,
		UiStyle.BAD if eta < 0 else UiStyle.MUTED)
	when.custom_minimum_size = Vector2(170, 0)
	h.add_child(when)
	var x := UiStyle.icon_button("close", "Cancelar (o que já foi gasto se perde)", 26, 12)
	var id := int(item.id)
	x.pressed.connect(func(): _main.submit(CancelRecruitCommand.create(_main.player_tag, id)))
	h.add_child(x)
	return h


func _group_row(g: ArmyGroup) -> HBoxContainer:
	var sim: Simulation = _main.sim
	var st := sim.state
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var name_b := Button.new()
	name_b.text = g.name
	name_b.custom_minimum_size = Vector2(100, 0)
	if g.id == _main.units.selected:
		name_b.add_theme_color_override("font_color", UiStyle.ACCENT)
	var gid := g.id
	name_b.pressed.connect(func():
		_main.units.select(gid)
		_main.camera.position = MovementSystem.map_position(st, st.group(gid)))
	h.add_child(name_b)
	var where := Label.new()
	where.custom_minimum_size = Vector2(170, 0)
	where.clip_text = true
	if g.moving():
		where.text = "indo para %s · %d dias" % [st.state(g.destination()).name, ceili(ArmySystem.eta_days(st, sim.defs, g))]
	else:
		where.text = "em %s" % st.state(g.state_id).name
	h.add_child(where)
	var what := UiStyle.small_label(counts_text(sim, g), 12, UiStyle.TEXT)
	what.custom_minimum_size = Vector2(230, 0)
	what.clip_text = true
	what.tooltip_text = summary(sim, g)
	what.mouse_filter = Control.MOUSE_FILTER_STOP
	h.add_child(what)
	var gen := OptionButton.new()
	gen.custom_minimum_size = Vector2(150, 0)
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
	return h


## "320 soldados, 10 peças, 5 tanques".
static func counts_text(sim: Simulation, g: ArmyGroup) -> String:
	var parts := []
	for type in g.types():
		parts.append("%d %s" % [roundi(g.count_of(type)), ArmySystem.troop_def(sim.defs, type).get("short", type)])
	return ", ".join(parts)


## Resumo da pilha em texto simples (tooltip e cartão da pilha).
static func summary(sim: Simulation, g: ArmyGroup) -> String:
	var models := []
	for t in g.troops:
		models.append("%s ×%d" % [sim.defs.equipment.get(t.model, {}).get("name", t.model), roundi(t.count)])
	return "Tropas: %s\nModelos: %s\nMarcha: %d km por dia" % [counts_text(sim, g), ", ".join(models),
		int(ArmySystem.march_km_day(sim.state, sim.defs, g))]


func _res_name(id: String) -> String:
	for r in _main.sim.defs.resources:
		if r.id == id:
			return str(r.name).to_lower()
	return id


static func _short(v: float) -> String:
	return ("%.1f" % v).replace(".", ",") if v < 10.0 else str(roundi(v))
