extends TestCase
# Indústria (civil x militar), pesquisa e linhas de produção.
# Mundo de teste: AAA 2 fábricas, BBB 1 fábrica, todas civis no começo. Conversão: 25% por dia.


func _days(sim: Simulation, n: int) -> void:
	sim.advance_hours(24 * n)


func test_factories_split_by_share() -> void:
	var sim := make_world()
	var gs := sim.state
	assert_eq(gs.civil_factories("AAA"), 2, "tudo civil")
	assert_eq(gs.military_factories("AAA"), 0)
	gs.country("AAA").civil_share = 0.5
	assert_eq(gs.civil_factories("AAA"), 1, "metade")
	assert_eq(gs.military_factories("AAA"), 1)
	assert_eq(gs.civil_factories("AAA") + gs.military_factories("AAA"), gs.factories("AAA"), "soma fecha")


func test_conversion_takes_days() -> void:
	var sim := make_world()
	sim.submit(SetCivilShareCommand.create("AAA", 0.0))
	sim.apply_pending()
	assert_eq(sim.state.country("AAA").civil_share, 1.0, "não muda na hora")
	_days(sim, 2)
	assert_eq(sim.state.country("AAA").civil_share, 0.5, "dois dias")
	_days(sim, 2)
	assert_eq(sim.state.country("AAA").civil_share, 0.0, "chegou ao alvo")
	assert_eq(sim.state.military_factories("AAA"), 2)


func test_more_military_means_less_money() -> void:
	# BBB: 1 fábrica. Civil: transforma até 10 de petróleo em bens. Militar: zero bens.
	var civil := make_world()
	var military := make_world()
	military.state.country("BBB").civil_share = 0.0
	military.state.country("BBB").civil_share_target = 0.0
	_days(civil, 1)
	_days(military, 1)
	assert_true(civil.state.country("BBB").last_income > 0.0, "civil rende")
	assert_eq(military.state.country("BBB").last_income, 0.0, "militar não rende")
	assert_true(military.state.country("BBB").stock("oil") > civil.state.country("BBB").stock("oil"), "vai tudo para o estoque")


func test_research_takes_days_and_costs_money() -> void:
	var sim := make_world()
	sim.submit(StartResearchCommand.create("AAA", "tech_rifle"))
	sim.apply_pending()
	var c := sim.state.country("AAA")
	assert_eq(c.money, 950.0, "custo pago")
	assert_eq(c.research.size(), 1)
	_days(sim, 19)
	assert_true(not c.has_tech("tech_rifle"), "dia 19")
	_days(sim, 1)
	assert_true(c.has_tech("tech_rifle"), "dia 20")
	assert_eq(c.research.size(), 0, "vaga liberada")


func test_research_requires_prerequisite() -> void:
	var sim := make_world()
	assert_true(ResearchSystem.can_start(sim.state, sim.defs, "AAA", "tech_tank").begins_with("falta pesquisar"), "sem o fuzil")
	sim.state.country("AAA").researched.append("tech_rifle")
	assert_eq(ResearchSystem.can_start(sim.state, sim.defs, "AAA", "tech_tank"), "")


func test_ahead_of_time_and_foreign_penalties() -> void:
	var sim := make_world()
	sim.state.country("AAA").researched.append("tech_rifle")
	sim.state.country("BBB").researched.append("tech_rifle")
	# Tanque: 40 dias, ano 1937 (1 ano adiantado em 1936: +50%), projeto de AAA.
	assert_eq(ResearchSystem.days_needed(sim.state, sim.defs, "AAA", "tech_tank"), 60, "dono, adiantado")
	assert_eq(ResearchSystem.days_needed(sim.state, sim.defs, "BBB", "tech_tank"), 105, "estrangeiro, adiantado")
	# 1940 está 4 anos à frente: além do limite de 2 anos.
	assert_true(ResearchSystem.can_start(sim.state, sim.defs, "AAA", "tech_future").begins_with("ainda não"), "cedo demais")


func test_research_slots_limit() -> void:
	var sim := make_world()
	sim.state.country("AAA").research_slots = 1
	sim.submit(StartResearchCommand.create("AAA", "t_base"))
	sim.apply_pending()
	assert_eq(ResearchSystem.can_start(sim.state, sim.defs, "AAA", "tech_rifle"), "todas as vagas de pesquisa estão ocupadas")
	sim.submit(CancelResearchCommand.create("AAA", "t_base"))
	sim.apply_pending()
	assert_eq(sim.state.country("AAA").research.size(), 0, "cancelada")
	assert_eq(ResearchSystem.can_start(sim.state, sim.defs, "AAA", "tech_rifle"), "", "vaga livre de novo")


func test_cannot_produce_without_research() -> void:
	var sim := make_world()
	var reasons: Array = []
	sim.command_rejected.connect(func(_c, r): reasons.append(r))
	sim.submit(AddProductionLineCommand.create("AAA", "rifle", 1))
	sim.apply_pending()
	assert_eq(reasons, ["o equipamento ainda não foi pesquisado"])


func _military_world() -> Simulation:
	# AAA: 2 fábricas militares, fuzil pesquisado, 100 de ferro no estoque.
	var sim := make_world()
	var c := sim.state.country("AAA")
	c.civil_share = 0.0
	c.civil_share_target = 0.0
	c.researched.append("tech_rifle")
	c.stockpile["iron"] = 100.0
	return sim


func test_production_line_builds_and_consumes() -> void:
	var sim := _military_world()
	sim.submit(AddProductionLineCommand.create("AAA", "rifle", 2))
	_days(sim, 1)
	var c := sim.state.country("AAA")
	# Dia 1: 2 fábricas x eficiência 0,5 = 1 dia-fábrica = 1 fuzil (custo 1), 1 de ferro.
	assert_eq(c.equipment_count("rifle"), 1.0, "dia 1")
	assert_eq(c.stock("iron"), 99.0, "ferro gasto")
	_days(sim, 1)
	# Dia 2: eficiência 0,6 -> 1,2 fuzil; total 2,2 (2 prontos).
	assert_eq(c.equipment_count("rifle"), 2.0, "dia 2")
	assert_true(absf(c.stock("iron") - 97.8) < 0.001, "ferro proporcional")


func test_efficiency_grows_to_cap() -> void:
	var sim := _military_world()
	sim.submit(AddProductionLineCommand.create("AAA", "rifle", 1))
	_days(sim, 10)
	assert_eq(sim.state.country("AAA").production_lines[0].efficiency, 1.0)


func test_shortage_slows_but_never_stops() -> void:
	var sim := _military_world()
	var c := sim.state.country("AAA")
	c.stockpile["iron"] = 0.0
	c.production_lines.clear()
	ProductionSystem.new_line(c, sim.defs, "rifle", 2)
	c.production_lines[0].efficiency = 1.0
	_days(sim, 1)
	# Sem ferro: anda a 25% (2 x 1,0 x 0,25 = 0,5 fuzil) e o estoque não fica negativo.
	assert_true(absf(c.production_lines[0].progress - 0.5) < 0.001, "piso de 25%")
	assert_eq(c.stock("iron"), 0.0, "estoque não negativo")
	assert_true(c.last_shortage.get("iron", 0.0) > 0.0, "falta registrada")


func test_lines_share_military_factories_in_order() -> void:
	var sim := _military_world()
	var c := sim.state.country("AAA")
	ProductionSystem.new_line(c, sim.defs, "rifle", 2)
	ProductionSystem.new_line(c, sim.defs, "rifle", 2)
	_days(sim, 1)
	assert_eq(c.production_lines[0].assigned, 2, "primeira linha leva tudo")
	assert_eq(c.production_lines[1].assigned, 0, "segunda fica sem")
	sim.submit(SetLineFactoriesCommand.create("AAA", c.production_lines[0].id, 1))
	_days(sim, 1)
	assert_eq(c.production_lines[1].assigned, 1, "dividiu")
	sim.submit(RemoveProductionLineCommand.create("AAA", c.production_lines[0].id))
	sim.apply_pending()
	assert_eq(c.production_lines.size(), 1, "linha fechada")


func test_military_commands_serialize() -> void:
	for cmd in [SetCivilShareCommand.create("AAA", 0.4), StartResearchCommand.create("AAA", "tech_rifle"),
			CancelResearchCommand.create("AAA", "tech_rifle"), AddProductionLineCommand.create("AAA", "rifle", 3),
			SetLineFactoriesCommand.create("AAA", 1, 5), RemoveProductionLineCommand.create("AAA", 1)]:
		var copy := CommandRegistry.from_dict(cmd.to_dict())
		assert_eq(copy.to_dict(), cmd.to_dict(), cmd.type_name())


func test_real_data_loads() -> void:
	# Os JSON reais: todo equipamento tem fonte, toda tecnologia aponta para coisas que existem.
	var defs := ScenarioLoader.load_defs()
	assert_true(defs.equipment.size() >= 40, "equipamentos")
	for id in defs.equipment:
		assert_true(not defs.equipment[id].sources.is_empty(), "fonte de " + id)
	var techs: Dictionary = defs.research.techs
	for id in techs:
		for req in techs[id].get("requires", []):
			assert_true(techs.has(req), "%s requer %s" % [id, req])
		for eq in techs[id].get("unlocks_equipment", []):
			assert_true(defs.equipment.has(eq), "%s libera %s" % [id, eq])
	var gs := ScenarioLoader.load_scenario("1936", defs)
	assert_true(gs.country("ALE").has_tech("tech_kar98k"), "Alemanha começa com o Kar98k")
	assert_true(gs.military_factories("ALE") > 0, "Alemanha tem fábricas militares")
