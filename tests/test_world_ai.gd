extends TestCase
# Mundo vivo: alianças (facções), IA dos países, passagem militar, travessias e textos das notícias.


func _world3() -> Simulation:
	var sim := make_world()
	var gs := sim.state
	gs.countries["CCC"] = Country.from_dict({"tag": "CCC", "name": "País C", "capital_state": 3})
	gs.states[3] = MapState.from_dict({"id": 3, "name": "Estado 3", "owner": "CCC"})
	gs.countries["CCC"].money = 1000.0
	gs.adjacency = {1: [2], 2: [1, 3], 3: [2]}
	return sim


func test_news_articles() -> void:
	assert_eq(NewsText.to("França"), "à França", "feminino")
	assert_eq(NewsText.to("Brasil"), "ao Brasil", "masculino")
	assert_eq(NewsText.to("Estados Unidos"), "aos Estados Unidos", "plural")
	assert_eq(NewsText.to("Portugal"), "a Portugal", "sem artigo")
	assert_eq(NewsText.the("África do Sul"), "a África do Sul", "gênero da primeira palavra")
	assert_eq(NewsText.of("Nova Zelândia"), "da Nova Zelândia", "gênero da primeira palavra")
	assert_eq(NewsText.to("Aliados"), "aos Aliados", "aliança no plural")
	assert_eq(NewsText.the("Eixo", true), "O Eixo", "maiúscula")


func test_faction_join_makes_allies_and_news() -> void:
	var sim := _world3()
	var gs := sim.state
	gs.factions["f"] = {"name": "Eixo", "leader": "AAA", "members": ["AAA"]}
	assert_true(not gs.allied("AAA", "CCC"), "antes não são aliados")
	var cmd := JoinFactionCommand.create("CCC", "f")
	assert_eq(cmd.validate(gs, sim.defs), "", "pode entrar")
	sim.submit(cmd)
	sim.apply_pending()
	assert_true(gs.allied("AAA", "CCC"), "mesma aliança = aliados")
	assert_true(gs.can_enter("CCC", "AAA"), "aliado pode entrar")
	assert_eq(gs.news.back().headline, "O País C adere ao Eixo", "manchete com artigo")
	var back := CommandRegistry.from_dict(cmd.to_dict())
	assert_eq(back.type_name(), cmd.type_name(), "comando serializável")


func test_join_faction_enters_its_wars() -> void:
	var sim := _world3()
	var gs := sim.state
	gs.factions["f"] = {"name": "Eixo", "leader": "AAA", "members": ["AAA"]}
	DiplomacySystem.start_war(gs, "AAA", "BBB")
	assert_true(gs.at_war("AAA", "BBB"), "guerra começou")
	FactionSystem.join(gs, "CCC", "f")
	assert_true(gs.at_war("CCC", "BBB"), "quem entra na aliança entra nas guerras dela")


func test_cannot_join_faction_at_war_with_member() -> void:
	var sim := _world3()
	var gs := sim.state
	gs.factions["f"] = {"name": "Eixo", "leader": "AAA", "members": ["AAA"]}
	DiplomacySystem.start_war(gs, "AAA", "CCC")
	assert_true(FactionSystem.can_join(gs, "CCC", "f") != "", "inimigo não entra")


func test_military_access() -> void:
	var sim := _world3()
	var gs := sim.state
	assert_true(not gs.can_enter("AAA", "BBB"), "sem passagem")
	gs.access.append(["AAA", "BBB"])
	assert_true(gs.can_enter("AAA", "BBB"), "com passagem militar")
	assert_true(not gs.can_enter("BBB", "AAA"), "a passagem tem sentido")


func test_ai_follows_war_plan() -> void:
	var sim := _world3()
	var gs := sim.state
	sim.defs["ai"] = {"think_every_days": 1, "war_plans": [{"tag": "AAA", "target": "BBB", "from": "1936-01"}]}
	gs.human_tags = ["CCC"]
	var cmds := AiSystem.think(gs, sim.defs, "AAA", 0)
	assert_true(cmds.any(func(c): return c is JustifyWarCommand), "primeiro justifica")
	for c in cmds:
		if c is JustifyWarCommand:
			c.apply(gs, sim.defs)
	gs.justification("AAA", "BBB").done = true
	cmds = AiSystem.think(gs, sim.defs, "AAA", 1)
	assert_true(cmds.any(func(c): return c is DeclareWarCommand), "com a justificativa pronta, declara")


func test_ai_runs_in_simulation_without_breaking() -> void:
	var sim := _world3()
	sim.defs["ai"] = {"think_every_days": 1}
	sim.state.human_tags = ["AAA"]
	sim.advance_hours(24 * 10)
	assert_true(sim.state.country("BBB").money >= 0.0, "a IA joga dez dias sem erro e sem dívida")


func test_ai_disabled_without_rules() -> void:
	var sim := _world3()
	assert_eq(AiSystem.decide(sim.state, sim.defs).size(), 0, "sem regras, a IA não joga")


func test_liberating_ally_returns_state_to_owner() -> void:
	var sim := _world3()
	var gs := sim.state
	gs.factions["f"] = {"name": "Aliados", "leader": "AAA", "members": ["AAA", "CCC"]}
	DiplomacySystem.start_war(gs, "BBB", "CCC")
	DiplomacySystem.start_war(gs, "AAA", "BBB")
	gs.set_control(gs.state(3), "BBB")
	var g := ArmyGroup.new()
	g.id = 99
	g.owner = "AAA"
	g.state_id = 3
	gs.groups[99] = g
	CombatSystem.on_enter(gs, g)
	assert_eq(gs.state(3).control(), "CCC", "volta para o dono aliado, não para quem libertou")
