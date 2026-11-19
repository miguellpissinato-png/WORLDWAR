extends TestCase


func test_investigation_takes_days_and_produces_frozen_report() -> void:
	var sim := make_world()
	var a := sim.state.country("AAA")
	sim.state.country("BBB").intel_defense = 1
	a.intel_offense = 5   # bloqueio 0%; detecção mínima (0,2%/dia)
	sim.state.rng.seed = 7
	var cmd := StartInvestigationCommand.create("AAA", "BBB")
	sim.submit(cmd)
	sim.apply_pending()
	assert_eq(cmd.result, "iniciada")
	assert_eq(a.money, 950.0, "custo da investigação")
	var days := IntelligenceSystem.investigation_days(sim.defs, 5)
	assert_eq(days, 4)
	sim.advance_hours(24 * (days - 1))
	assert_true(not a.intel_reports.has("BBB"), "ainda não terminou")
	sim.advance_hours(24)
	assert_true(a.intel_reports.has("BBB"), "relatório pronto")
	var rep: Dictionary = a.intel_reports["BBB"]
	var oil: int = rep.production["oil"]
	assert_true(oil >= 18 and oil <= 22, "petróleo ~20 com erro de até 6%%: %d" % oil)
	# O relatório não muda sozinho, mesmo que o país mude.
	sim.state.state(2).buildings["extraction_oil"] = 5
	sim.advance_hours(24 * 5)
	assert_eq(a.intel_reports["BBB"].production["oil"], oil, "congelado")


func test_strong_counterintelligence_catches_spies() -> void:
	# Defesa 5 contra ataque 1: bloqueio 54% e detecção 5,4%/dia. Em 40 tentativas, quase todas falham.
	var failures := 0
	for seed in 40:
		var sim := make_world()
		sim.state.rng.seed = seed
		sim.state.country("AAA").money = 100000.0
		sim.state.country("BBB").intel_defense = 5
		sim.submit(StartInvestigationCommand.create("AAA", "BBB"))
		sim.advance_hours(24 * 12)
		if not sim.state.country("AAA").intel_reports.has("BBB"):
			failures += 1
	assert_true(failures >= 25, "contraespionagem forte barra a maioria: %d/40" % failures)


func test_both_sides_are_told_when_spies_are_caught() -> void:
	for seed in 200:
		var sim := make_world()
		sim.state.rng.seed = seed
		sim.state.country("BBB").intel_defense = 5
		sim.submit(StartInvestigationCommand.create("AAA", "BBB"))
		sim.advance_hours(24 * 12)
		var texts: Array = sim.state.events.map(func(e): return e.text)
		if texts.any(func(t): return "presos" in t):
			assert_true(sim.state.events.any(func(e): return "AAA" in e.tags), "atacante avisado")
			assert_true(sim.state.events.any(func(e): return "BBB" in e.tags), "alvo avisado")
			return
	assert_true(false, "nenhuma prisão em 200 tentativas")


func test_no_duplicate_investigation_and_cost() -> void:
	var sim := make_world()
	var reasons: Array = []
	sim.command_rejected.connect(func(_c, r): reasons.append(r))
	sim.state.country("AAA").intel_offense = 5
	sim.submit(StartInvestigationCommand.create("AAA", "BBB"))
	sim.submit(StartInvestigationCommand.create("AAA", "BBB"))
	sim.submit(StartInvestigationCommand.create("AAA", "AAA"))
	sim.apply_pending()
	assert_eq(reasons, ["já existe uma investigação em andamento nesse país", "não dá para investigar o próprio país"])


func test_upgrade_intelligence() -> void:
	var sim := make_world()
	sim.submit(UpgradeIntelligenceCommand.create("AAA", "defense"))
	sim.submit(UpgradeIntelligenceCommand.create("AAA", "offense"))
	sim.apply_pending()
	var a := sim.state.country("AAA")
	assert_eq(a.intel_defense, 2)
	assert_eq(a.intel_offense, 2)
	assert_eq(a.money, 800.0, "2 x $100")


func test_same_seed_same_outcome() -> void:
	var results: Array = []
	for i in 2:
		var sim := make_world()
		sim.state.rng.seed = 99
		sim.state.country("BBB").intel_defense = 3
		sim.submit(StartInvestigationCommand.create("AAA", "BBB"))
		sim.advance_hours(24 * 12)
		results.append([sim.state.country("AAA").intel_reports.duplicate(true), sim.state.events.size()])
	assert_eq(results[0], results[1])


func test_intel_commands_serialize() -> void:
	for original in [StartInvestigationCommand.create("AAA", "BBB"), UpgradeIntelligenceCommand.create("AAA", "defense")]:
		assert_eq(CommandRegistry.from_dict(original.to_dict()).to_dict(), original.to_dict())
