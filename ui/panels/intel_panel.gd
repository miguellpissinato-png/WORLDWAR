class_name IntelPanel
extends PanelContainer
## Agência de inteligência: nível de espionagem e contraespionagem, investigar um país e ler os
## relatórios (congelados na data em que foram feitos). Detalhes de cada relatório ficam recolhidos.

var _main
var _off_info: RichTextLabel
var _def_info: RichTextLabel
var _up_off: Button
var _up_def: Button
var _target: OptionButton
var _go: Button
var _ops: VBoxContainer
var _reports: VBoxContainer
var _open_report := ""


func setup(main) -> void:
	_main = main
	UiStyle.place(self, 620)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	UiStyle.window_header(v, "Inteligência", "Só espiões revelam produção, estoques e tesouro de outros países.",
		func(): visible = false,
		"Investigações levam dias e geram um relatório com a data em que foi feito: os números mudam depois.\n"
		+ "A contraespionagem do alvo pode barrar seus agentes na entrada ou prendê-los durante a missão.")
	for which in ["offense", "defense"]:
		var h := HBoxContainer.new()
		v.add_child(h)
		var info := UiStyle.rich()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(info)
		var b := Button.new()
		b.custom_minimum_size = Vector2(170, 0)
		var w: String = which
		b.pressed.connect(func(): _main.submit(UpgradeIntelligenceCommand.create(_main.player_tag, w)))
		h.add_child(b)
		if which == "offense":
			_off_info = info
			_up_off = b
		else:
			_def_info = info
			_up_def = b

	v.add_child(UiStyle.section("Investigar"))
	var th := HBoxContainer.new()
	v.add_child(th)
	_target = OptionButton.new()
	_target.custom_minimum_size = Vector2(250, 0)
	th.add_child(_target)
	_go = Button.new()
	_go.pressed.connect(func(): investigate(_target.get_item_metadata(_target.selected)))
	th.add_child(_go)
	_ops = VBoxContainer.new()
	v.add_child(_ops)

	v.add_child(UiStyle.section("Relatórios"))
	_reports = VBoxContainer.new()
	_reports.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_reports)

	var tags: Array = main.sim.state.countries.keys()
	tags.sort_custom(func(a, b): return main.sim.state.country(a).name < main.sim.state.country(b).name)
	for i in tags.size():
		_target.add_item(main.sim.state.country(tags[i]).name)
		_target.set_item_metadata(i, tags[i])


func investigate(tag: String) -> void:
	var cmd := StartInvestigationCommand.create(_main.player_tag, tag)
	_main.submit(cmd)
	if cmd.result == "iniciada":
		_main.write_log("Agentes enviados para investigar %s." % _main.sim.state.country(tag).name)
	refresh()


func select_target(tag: String) -> void:
	for i in _target.item_count:
		if _target.get_item_metadata(i) == tag:
			_target.select(i)


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	if not visible:
		return
	var sim: Simulation = _main.sim
	var st := sim.state
	var me: Country = st.country(_main.player_tag)
	var cur: String = sim.defs.currency
	var max_level := int(sim.defs.intelligence.get("max_level", 5))
	var days := IntelligenceSystem.investigation_days(sim.defs, me.intel_offense)
	var err := float(sim.defs.intelligence.investigation.noise_base) / me.intel_offense * 100.0
	_off_info.text = UiStyle.kv("Espionagem", "nível %d de %d" % [me.intel_offense, max_level])
	_off_info.tooltip_text = "Investigações levam %d dias; os números têm erro de até ±%d%%." % [days, int(err)]
	_def_info.text = UiStyle.kv("Contraespionagem", "nível %d de %d" % [me.intel_defense, max_level])
	_def_info.tooltip_text = "Barra infiltrações e prende agentes inimigos."
	for pair in [[_up_off, me.intel_offense], [_up_def, me.intel_defense]]:
		var b: Button = pair[0]
		if pair[1] >= max_level:
			b.text = "No máximo"
			b.disabled = true
		else:
			var cost := IntelligenceSystem.upgrade_cost(sim.defs, pair[1])
			b.text = "Melhorar  ·  %s" % UiStyle.money(cost, cur)
			b.disabled = me.money < cost
	_go.text = "Investigar  ·  %s, %d dias" % [UiStyle.money(float(sim.defs.intelligence.investigation.cost), cur), days]

	UiStyle.clear(_ops)
	for op in st.operations.values():
		if op.owner != _main.player_tag:
			continue
		var h := HBoxContainer.new()
		var l := Label.new()
		l.text = "Investigando %s" % st.country(op.target).name
		l.custom_minimum_size = Vector2(250, 0)
		h.add_child(l)
		var bar := ProgressBar.new()
		bar.max_value = float(op.days_total)
		bar.value = float(op.days_done)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(200, 12)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bar)
		var left := Label.new()
		left.text = "  faltam %d dias" % (op.days_total - op.days_done)
		h.add_child(left)
		_ops.add_child(h)

	# Relatórios: uma linha por país; clicar abre os números.
	UiStyle.clear(_reports)
	var tags: Array = me.intel_reports.keys()
	tags.sort_custom(func(x, y): return me.intel_reports[x].hours > me.intel_reports[y].hours)
	if tags.is_empty():
		_reports.add_child(UiStyle.dim_label("Nenhum relatório ainda."))
	for tag in tags:
		var r: Dictionary = me.intel_reports[tag]
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.text = "%s  ·  relatório de %s" % [st.country(tag).name, GameDate.format(r.hours).split(",")[0]]
		var t: String = tag
		b.pressed.connect(func():
			_open_report = "" if _open_report == t else t
			refresh())
		_reports.add_child(b)
		if _open_report == tag:
			var body := UiStyle.rich()
			body.text = report_text(tag, r)
			_reports.add_child(body)


func report_text(tag: String, r: Dictionary) -> String:
	var sim: Simulation = _main.sim
	var t := UiStyle.kv("Tesouro:", "~" + UiStyle.money(r.money, sim.defs.currency)) + "     "
	t += UiStyle.kv("Fábricas:", "~%d civis, ~%d militares" % [r.civilian_factories, r.military_factories])
	t += "   [color=#888](erro de até ±%d%%)[/color]\n" % int(r.error * 100)
	var parts: Array = []
	for res in sim.defs.resources:
		var p: int = r.production.get(res.id, 0)
		var s: int = r.stock.get(res.id, 0)
		if p > 0 or s > 0:
			parts.append("[color=%s]%s[/color] %d/dia, estoque %s" % [res.color, res.name, p, UiStyle.num(s)])
	t += "\n".join(parts) if not parts.is_empty() else "[color=#888]Sem produção nem estoque de recursos.[/color]"
	return t
