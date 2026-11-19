class_name IntelPanel
extends PanelContainer
## Agência de inteligência: investir em espionagem e contraespionagem, mandar investigar
## países e ler os relatórios (congelados na data em que foram feitos).

var _main
var _agency: RichTextLabel
var _up_off: Button
var _up_def: Button
var _target: OptionButton
var _go: Button
var _ops: RichTextLabel
var _reports: RichTextLabel


func setup(main) -> void:
	_main = main
	add_theme_stylebox_override("panel", UiStyle.panel().get_theme_stylebox("panel"))
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -330
	offset_right = 430
	offset_top = 70
	visible = false

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	v.add_child(UiStyle.header("Agência de inteligência", func(): visible = false))
	_agency = RichTextLabel.new()
	_agency.bbcode_enabled = true
	_agency.fit_content = true
	v.add_child(_agency)
	var ah := HBoxContainer.new()
	v.add_child(ah)
	_up_off = Button.new()
	_up_off.pressed.connect(func(): _main.submit(UpgradeIntelligenceCommand.create(_main.player_tag, "offense")))
	ah.add_child(_up_off)
	_up_def = Button.new()
	_up_def.pressed.connect(func(): _main.submit(UpgradeIntelligenceCommand.create(_main.player_tag, "defense")))
	ah.add_child(_up_def)

	v.add_child(UiStyle.section("Nova investigação"))
	var th := HBoxContainer.new()
	v.add_child(th)
	_target = OptionButton.new()
	_target.custom_minimum_size = Vector2(260, 0)
	th.add_child(_target)
	_go = Button.new()
	_go.pressed.connect(func(): investigate(_target.get_item_metadata(_target.selected)))
	th.add_child(_go)

	v.add_child(UiStyle.section("Operações em andamento"))
	_ops = RichTextLabel.new()
	_ops.bbcode_enabled = true
	_ops.fit_content = true
	v.add_child(_ops)
	v.add_child(UiStyle.section("Relatórios"))
	_reports = RichTextLabel.new()
	_reports.bbcode_enabled = true
	_reports.custom_minimum_size = Vector2(0, 220)
	v.add_child(_reports)

	var tags: Array = main.sim.state.countries.keys()
	tags.sort_custom(func(a, b): return main.sim.state.country(a).name < main.sim.state.country(b).name)
	for i in tags.size():
		_target.add_item(main.sim.state.country(tags[i]).name)
		_target.set_item_metadata(i, tags[i])


func investigate(tag: String) -> void:
	var cmd := StartInvestigationCommand.create(_main.player_tag, tag)
	_main.submit(cmd)
	var name_of: String = _main.sim.state.country(tag).name
	if cmd.result == "iniciada":
		_main.write_log("Agentes enviados para investigar %s." % name_of)
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
	var a := UiStyle.ACCENT_HEX
	var max_level := int(sim.defs.intelligence.get("max_level", 5))
	var days := IntelligenceSystem.investigation_days(sim.defs, me.intel_offense)
	var err := float(sim.defs.intelligence.investigation.noise_base) / me.intel_offense * 100.0
	_agency.text = "[color=%s]Espionagem:[/color] nível %d de %d — investigações levam %d dias, erro de até ±%d%%\n" % [a, me.intel_offense, max_level, days, int(err)]
	_agency.text += "[color=%s]Contraespionagem:[/color] nível %d de %d — barra infiltrações e prende agentes inimigos" % [a, me.intel_defense, max_level]
	for pair in [[_up_off, me.intel_offense, "espionagem"], [_up_def, me.intel_defense, "contraespionagem"]]:
		var b: Button = pair[0]
		if pair[1] >= max_level:
			b.text = "%s no máximo" % pair[2].capitalize()
			b.disabled = true
		else:
			var cost := IntelligenceSystem.upgrade_cost(sim.defs, pair[1])
			b.text = "Investir em %s (%s)" % [pair[2], UiStyle.money(cost, cur)]
			b.disabled = me.money < cost
	_go.text = "Investigar (%s, %d dias)" % [UiStyle.money(float(sim.defs.intelligence.investigation.cost), cur), days]

	var ops := ""
	for op in st.operations.values():
		if op.owner == _main.player_tag:
			ops += "Investigando [b]%s[/b] — dia %d de %d\n" % [st.country(op.target).name, op.days_done, op.days_total]
	_ops.text = ops if ops != "" else "[color=#888]Nenhuma.[/color]"

	var rep := ""
	var tags: Array = me.intel_reports.keys()
	tags.sort_custom(func(x, y): return me.intel_reports[x].hours > me.intel_reports[y].hours)
	for tag in tags:
		rep += report_text(tag, me.intel_reports[tag]) + "\n"
	_reports.text = rep if rep != "" else "[color=#888]Nenhum relatório ainda. Investigue um país para conhecer a produção, os estoques e o tesouro dele.[/color]"


func report_text(tag: String, r: Dictionary) -> String:
	var sim: Simulation = _main.sim
	var a := UiStyle.ACCENT_HEX
	var t := "[b]%s[/b] — relatório de %s [color=#888](erro de até ±%d%%)[/color]\n" % [
		sim.state.country(tag).name, GameDate.format(r.hours).split(",")[0], int(r.error * 100)]
	t += "[color=%s]Tesouro:[/color] ~%s   [color=%s]Fábricas:[/color] ~%d civis, ~%d militares\n" % [
		a, UiStyle.money(r.money, sim.defs.currency), a, r.civilian_factories, r.military_factories]
	var parts: Array = []
	for res in sim.defs.resources:
		var p: int = r.production.get(res.id, 0)
		var s: int = r.stock.get(res.id, 0)
		if p > 0 or s > 0:
			parts.append("[color=%s]%s[/color] %d/dia (estoque %s)" % [res.color, res.name, p, UiStyle.num(s)])
	t += ("   ".join(parts) if not parts.is_empty() else "[color=#888]Sem produção nem estoque de recursos.[/color]") + "\n"
	return t
