extends TestCase
# Paz: propostas com dinheiro, território e recursos; a IA decide pelo andamento da guerra.
# Mundo: AAA (1, 3) e BBB (2, 5), em guerra.


func _world() -> Simulation:
	var sim := make_world()
	var gs := sim.state
	gs.states[3] = MapState.from_dict({"id": 3, "name": "Estado 3", "owner": "AAA"})
	gs.states[5] = MapState.from_dict({"id": 5, "name": "Estado 5", "owner": "BBB"})
	gs.adjacency = {1: [3], 3: [1, 2], 2: [3, 5], 5: [2]}
	DiplomacySystem.start_war(gs, "AAA", "BBB")
	return sim


func test_white_peace_when_even() -> void:
	var sim := _world()
	sim.submit(ProposePeaceCommand.create("AAA", "BBB"))
	sim.apply_pending()
	assert_true(not sim.state.at_war("AAA", "BBB"), "guerra parelha: aceita paz branca")
	assert_true(sim.state.news.back().headline.contains("assinam a paz"), "notícia")


func test_greedy_terms_refused_then_accepted_when_winning() -> void:
	var sim := _world()
	var gs := sim.state
	sim.submit(ProposePeaceCommand.create("AAA", "BBB", 0.0, [5]))
	sim.apply_pending()
	assert_true(gs.at_war("AAA", "BBB"), "pedir metade do país sem vencer: recusa")
	# AAA ocupa os dois estados de BBB (capital inclusive)
	gs.set_control(gs.state(2), "AAA")
	gs.set_control(gs.state(5), "AAA")
	var g := ArmySystem.new_group(gs, "AAA", 2)
	ArmySystem.add_troops(sim.defs, g, "infantaria", "rifle", 10.0, 100.0)
	sim.submit(ProposePeaceCommand.create("AAA", "BBB", 300.0, [5], {"oil": 5.0}))
	sim.apply_pending()
	assert_true(not gs.at_war("AAA", "BBB"), "vencendo: aceita")
	assert_eq(gs.state(5).owner, "AAA", "território entregue")
	assert_eq(gs.state(2).control(), "BBB", "o resto ocupado volta ao dono")
	assert_eq(gs.country("AAA").money, 1300.0, "dinheiro pago")
	assert_eq(gs.country("BBB").stock("oil"), 0.0, "recurso pago até o que havia")
	assert_true(g.state_id != 2, "as tropas saíram do território de BBB")


func test_human_must_answer() -> void:
	var sim := _world()
	var gs := sim.state
	gs.human_tags = ["BBB"]
	sim.submit(ProposePeaceCommand.create("AAA", "BBB", 100.0))
	sim.apply_pending()
	assert_eq(gs.peace_offers.size(), 1, "espera a resposta do jogador")
	assert_true(ProposePeaceCommand.create("AAA", "BBB").validate(gs, sim.defs) != "", "uma proposta por vez")
	var id: int = gs.peace_offers.keys()[0]
	assert_true(RespondPeaceCommand.create("AAA", id, true).validate(gs, sim.defs) != "", "só o destinatário responde")
	sim.submit(RespondPeaceCommand.create("BBB", id, true))
	sim.apply_pending()
	assert_true(not gs.at_war("AAA", "BBB"))
	assert_eq(gs.country("BBB").money, 900.0)


func test_offer_expires_and_validation() -> void:
	var sim := _world()
	var gs := sim.state
	gs.human_tags = ["BBB"]
	assert_true(ProposePeaceCommand.create("AAA", "BBB", 0.0, [1]).validate(gs, sim.defs) != "", "só estados do inimigo")
	sim.submit(ProposePeaceCommand.create("AAA", "BBB"))
	sim.advance_hours(24 * 31)
	assert_true(gs.peace_offers.is_empty(), "expirou")
	DiplomacySystem.start_war(gs, "AAA", "BBB")
	var gs2 := _world().state
	gs2.wars.clear()
	assert_true(ProposePeaceCommand.create("AAA", "BBB").validate(gs2, sim.defs).begins_with("não estamos em guerra"))


func test_peace_commands_serialize() -> void:
	for cmd in [ProposePeaceCommand.create("AAA", "BBB", 50.0, [2, 5], {"oil": 3.0}), RespondPeaceCommand.create("BBB", 4, false)]:
		var copy := CommandRegistry.from_dict(cmd.to_dict())
		assert_eq(copy.to_dict(), cmd.to_dict(), cmd.type_name())
