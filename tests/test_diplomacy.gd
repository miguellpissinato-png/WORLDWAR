extends TestCase
# Guerra: justificar (leva dias e custa dinheiro), declarar, e as tropas só entram em país inimigo em guerra.
# Mundo: AAA tem 1, 3 e 4 em linha; 4 faz fronteira com 2 (BBB); 5 é de BBB depois de 2.


func _world() -> Simulation:
	var sim := make_world()
	var gs := sim.state
	var y: float = MapGeo._miller_deg(83.0) * 10.0
	gs.states[1].center = Vector2(1800, y)
	gs.states[3] = MapState.from_dict({"id": 3, "name": "Estado 3", "owner": "AAA"})
	gs.states[4] = MapState.from_dict({"id": 4, "name": "Estado 4", "owner": "AAA"})
	gs.states[5] = MapState.from_dict({"id": 5, "name": "Estado 5", "owner": "BBB"})
	gs.states[3].center = Vector2(1810, y)
	gs.states[4].center = Vector2(1820, y)
	gs.states[2].center = Vector2(1830, y)
	gs.states[5].center = Vector2(1840, y)
	gs.adjacency = {1: [3], 3: [1, 4], 4: [3, 2], 2: [4, 5], 5: [2]}
	var c := gs.country("AAA")
	c.researched.append("tech_rifle")
	return sim


func _group(sim: Simulation) -> ArmyGroup:
	return ArmySystem.spawn(sim.state, sim.defs, "AAA", "infantaria", "rifle", 10.0)


func test_cannot_enter_country_without_war() -> void:
	var sim := _world()
	var g := _group(sim)
	var cmd := MoveGroupCommand.create("AAA", g.id, 5)
	assert_true(cmd.validate(sim.state, sim.defs).begins_with("não estamos em guerra"), "sem guerra, não entra")
	assert_eq(ArmySystem.route_blocker(sim.state, g.state_id, 5, "AAA"), "BBB", "quem bloqueia o caminho")
	assert_eq(MoveGroupCommand.create("AAA", g.id, 4).validate(sim.state, sim.defs), "", "dentro do país pode")


func test_justify_takes_days_and_money() -> void:
	var sim := _world()
	var money := sim.state.country("AAA").money
	sim.submit(JustifyWarCommand.create("AAA", "BBB"))
	sim.apply_pending()
	assert_eq(sim.state.country("AAA").money, money - 10.0, "custa dinheiro")
	var j := sim.state.justification("AAA", "BBB")
	assert_true(not (j.done), "ainda não terminou")
	assert_true(DiplomacySystem.can_declare(sim.state, "AAA", "BBB") != "", "não dá para declarar antes")
	assert_true(DiplomacySystem.can_justify(sim.state, sim.defs, "AAA", "BBB") != "", "não justifica duas vezes")
	sim.advance_hours(24 * 3)
	assert_true(sim.state.justification("AAA", "BBB").done, "terminou depois de 3 dias")
	assert_true(not (sim.state.at_war("AAA", "BBB")), "justificar não começa a guerra")
	var told := sim.state.events.filter(func(e): return "BBB" in e.tags and "justificar" in e.text)
	assert_eq(told.size(), 1, "o alvo é avisado")


func test_declare_war_opens_border() -> void:
	var sim := _world()
	var g := _group(sim)
	sim.submit(DeclareWarCommand.create("AAA", "BBB"))
	sim.apply_pending()
	assert_true(not (sim.state.at_war("AAA", "BBB")), "sem justificativa, a declaração é recusada")
	sim.submit(JustifyWarCommand.create("AAA", "BBB"))
	sim.advance_hours(24 * 4)
	sim.submit(DeclareWarCommand.create("AAA", "BBB"))
	sim.apply_pending()
	assert_true(sim.state.at_war("AAA", "BBB"), "em guerra")
	assert_true(sim.state.at_war("BBB", "AAA"), "vale para os dois lados")
	assert_true(sim.state.justification("AAA", "BBB").is_empty(), "a justificativa foi usada")
	assert_eq(sim.state.enemies_of("BBB"), ["AAA"])
	sim.submit(MoveGroupCommand.create("AAA", g.id, 5))
	sim.apply_pending()
	assert_eq(g.path, [3, 4, 2, 5], "em guerra, o caminho entra no território inimigo")


func test_commands_round_trip() -> void:
	for cmd in [JustifyWarCommand.create("AAA", "BBB"), DeclareWarCommand.create("AAA", "BBB")]:
		var back: Command = CommandRegistry.from_dict(cmd.to_dict())
		assert_eq(back.to_dict(), cmd.to_dict(), "serializa %s" % cmd.type_name())
