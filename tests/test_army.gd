extends TestCase
# Exército: encomenda de tropas, estado favorito, pilhas, generais e marcha.
# Mundo: AAA tem os estados 1, 3 e 4 em linha no equador (cerca de 111 km entre vizinhos); 2 é de BBB.


func _world() -> Simulation:
	var sim := make_world()
	var gs := sim.state
	gs.states[1].center = Vector2(1800, MapGeo._miller_deg(83.0) * 10.0)
	var y: float = gs.states[1].center.y
	gs.states[3] = MapState.from_dict({"id": 3, "name": "Estado 3", "owner": "AAA"})
	gs.states[4] = MapState.from_dict({"id": 4, "name": "Estado 4", "owner": "AAA"})
	gs.states[3].center = Vector2(1810, y)
	gs.states[4].center = Vector2(1820, y)
	gs.states[2].center = Vector2(1830, y)
	gs.adjacency = {1: [3], 3: [1, 4], 4: [3, 2], 2: [4]}
	var c := gs.country("AAA")
	c.researched.append_array(["tech_rifle", "tech_tank"])
	c.civil_share = 0.0
	c.civil_share_target = 0.0   # 2 fábricas militares
	c.stockpile["iron"] = 100.0
	c.stockpile["oil"] = 100.0
	return sim


func test_distance_on_equator() -> void:
	var sim := _world()
	var km := MapGeo.km(sim.state.states[1].center, sim.state.states[3].center)
	assert_true(absf(km - 111.2) < 1.0, "0,1 grau no equador = 111 km (deu %.1f)" % km)


func _spawn(sim: Simulation, n: float = 10.0, type: String = "infantaria", model: String = "rifle") -> ArmyGroup:
	return ArmySystem.spawn(sim.state, sim.defs, "AAA", type, model, n)


func test_best_model_and_cost() -> void:
	var sim := _world()
	var c := sim.state.country("AAA")
	assert_eq(ArmySystem.best_model(sim.defs, c, "infantaria"), "rifle", "fuzil melhor que o velho")
	var cost := ArmySystem.batch_cost(sim.defs, "infantaria", "rifle", 3)
	assert_eq(cost.count, 30, "3 lotes de 10")
	assert_true(absf(cost.work - 3.0) < 0.001, "0,1 dia-fábrica por soldado")
	assert_true(absf(cost.resources.iron - 3.0) < 0.001, "ferro do modelo x 0,1")
	assert_true(ArmySystem.can_recruit(sim.state, sim.defs, "BBB", "infantaria", 1).begins_with("pesquise"), "sem modelo")


func test_recruit_takes_days_and_spawns_at_rally() -> void:
	var sim := _world()
	sim.submit(SetRallyStateCommand.create("AAA", 3))
	sim.submit(RecruitTroopsCommand.create("AAA", "infantaria", 2))
	sim.advance_hours(24 * 2)
	var c := sim.state.country("AAA")
	assert_eq(c.recruit_queue.size(), 1, "ainda em preparo (prazo de 3 dias)")
	assert_true(sim.state.groups_of("AAA").is_empty(), "nada pronto")
	sim.advance_hours(24)
	assert_eq(c.recruit_queue.size(), 0, "pronto no 3º dia")
	var g: ArmyGroup = sim.state.groups_of("AAA")[0]
	assert_eq(g.state_id, 3, "nasceu no estado favorito")
	assert_eq(g.count_of("infantaria"), 20.0, "20 soldados")
	assert_true(c.stock("iron") < 100.0, "gastou ferro")


func test_slow_without_factories() -> void:
	var sim := _world()
	var c := sim.state.country("AAA")
	c.civil_share = 1.0
	c.civil_share_target = 1.0
	sim.submit(RecruitTroopsCommand.create("AAA", "infantaria", 1))
	sim.advance_hours(24 * 5)
	assert_eq(c.recruit_queue.size(), 1, "sem fábrica militar não anda")
	assert_eq(RecruitSystem.eta_days(sim.state, sim.defs, "AAA", c.recruit_queue[0].id), -1, "parado")


func test_full_rally_spills_to_neighbor() -> void:
	var sim := _world()
	_spawn(sim, 45.0)
	var g := _spawn(sim, 10.0)
	assert_eq(sim.state.groups_of("AAA").size(), 2, "capital cheia (50): outra pilha")
	assert_eq(g.state_id, 3, "nasceu no vizinho")
	var g2 := _spawn(sim, 5.0)
	assert_eq(g2.state_id, 1, "cabe na capital: junta na mesma pilha")
	assert_eq(g2.count_of("infantaria"), 50.0)


func test_split_and_merge() -> void:
	var sim := _world()
	var g := _spawn(sim, 30.0)
	ArmySystem.add_troops(sim.defs, g, "tanques", "tank", 4.0, 100.0)
	sim.submit(MoveGroupCommand.create("AAA", g.id, 3, {"infantaria": 10, "tanques": 4}))
	sim.apply_pending()
	assert_eq(sim.state.groups_of("AAA").size(), 2, "separou")
	assert_eq(g.count_of("infantaria"), 20.0, "ficou a guarnição")
	assert_eq(g.count_of("tanques"), 0.0)
	var moved: ArmyGroup = sim.state.groups_of("AAA")[1]
	assert_true(moved.moving(), "a parte enviada marcha")
	assert_eq(ArmySystem.march_km_day(sim.state, sim.defs, moved), 24.0, "anda no passo dos soldados")
	sim.submit(MoveGroupCommand.create("AAA", moved.id, 1))
	sim.advance_hours(24 * 12)
	assert_eq(sim.state.groups_of("AAA").size(), 1, "voltou e juntou na mesma pilha")
	assert_eq(sim.state.groups_of("AAA")[0].count_of("infantaria"), 30.0)


func test_cancel_recruit() -> void:
	var sim := _world()
	sim.submit(RecruitTroopsCommand.create("AAA", "tanques", 1))
	sim.apply_pending()
	var c := sim.state.country("AAA")
	sim.submit(CancelRecruitCommand.create("AAA", c.recruit_queue[0].id))
	sim.apply_pending()
	assert_true(c.recruit_queue.is_empty())


func test_rally_must_be_ours() -> void:
	var sim := _world()
	assert_true(SetRallyStateCommand.create("AAA", 2).validate(sim.state, sim.defs) != "", "estado de outro país")
	sim.state.country("AAA").rally_state = 3
	sim.state.set_control(sim.state.state(3), "BBB")
	assert_eq(ArmySystem.rally_state(sim.state, "AAA"), 1, "favorito ocupado: volta para a capital")


func test_disband() -> void:
	var sim := _world()
	var g := _spawn(sim)
	sim.submit(DisbandGroupCommand.create("AAA", g.id))
	sim.apply_pending()
	assert_eq(sim.state.groups.size(), 0)


func test_march_takes_days() -> void:
	var sim := _world()
	var g := _spawn(sim)
	sim.submit(MoveGroupCommand.create("AAA", g.id, 4))
	sim.apply_pending()
	assert_eq(g.path, [3, 4], "caminho por terra")
	# 24 km/dia, ~111 km por trecho: chega ao 3 no 5º dia e ao 4 no 10º.
	sim.advance_hours(24 * 4)
	assert_eq(g.state_id, 1, "dia 4: ainda no caminho do 3")
	assert_true(g.progress_km > 90.0, "andou ~96 km")
	sim.advance_hours(24 * 1)
	assert_eq(g.state_id, 3, "dia 5: no 3")
	sim.advance_hours(24 * 5)
	assert_eq(g.state_id, 4, "dia 10: chegou")
	assert_true(not g.moving(), "parou")
	assert_true(sim.state.events.back().text.contains("chegou a Estado 4"), "aviso de chegada")


func test_tanks_march_faster_and_general_helps() -> void:
	var sim := _world()
	var inf := _spawn(sim)
	var tank := ArmySystem.new_group(sim.state, "AAA", 3)
	ArmySystem.add_troops(sim.defs, tank, "tanques", "tank", 2.0, 100.0)
	assert_eq(ArmySystem.march_km_day(sim.state, sim.defs, tank), 48.0)
	var gen := ArmySystem.new_general(sim.state, sim.defs, "AAA", 1)
	gen.speed = 3
	inf.general_id = gen.id
	assert_true(absf(ArmySystem.march_km_day(sim.state, sim.defs, inf) - 28.8) < 0.001, "+20% com velocidade 3")


func test_cannot_march_abroad() -> void:
	var sim := _world()
	var g := _spawn(sim)
	var reasons: Array = []
	sim.command_rejected.connect(func(_c, r): reasons.append(r))
	sim.submit(MoveGroupCommand.create("AAA", g.id, 2))
	sim.apply_pending()
	assert_eq(reasons, ["não estamos em guerra com País B"])


func test_change_route_while_marching() -> void:
	var sim := _world()
	var g := _spawn(sim)
	sim.submit(MoveGroupCommand.create("AAA", g.id, 4))
	sim.advance_hours(24)
	sim.submit(MoveGroupCommand.create("AAA", g.id, 1))
	sim.apply_pending()
	assert_eq(g.path, [3, 1], "termina o trecho até o 3 e volta")


func test_generals() -> void:
	var sim := _world()
	sim.submit(RecruitGeneralCommand.create("AAA"))
	sim.apply_pending()
	var gens := sim.state.generals_of("AAA")
	assert_eq(gens.size(), 1)
	assert_true(gens[0].name.begins_with("Ana "), "nome do idioma do país")
	assert_eq(sim.state.country("AAA").money, 700.0, "custou 300")
	for k in ["attack", "defense", "speed"]:
		assert_true(gens[0].get(k) >= 1 and gens[0].get(k) <= 3, k)
	var ids: Array = []
	for sid in [1, 3, 4]:
		var g := ArmySystem.new_group(sim.state, "AAA", sid)
		ArmySystem.add_troops(sim.defs, g, "infantaria", "rifle", 10.0, 100.0)
		ids.append(g.id)
	for i in 3:
		sim.submit(AssignGeneralCommand.create("AAA", ids[i], gens[0].id))
	var reasons: Array = []
	sim.command_rejected.connect(func(_c, r): reasons.append(r))
	sim.apply_pending()
	assert_eq(ArmySystem.groups_of_general(sim.state, gens[0].id).size(), 2, "no máximo 2 neste teste")
	assert_eq(reasons.size(), 1, "o terceiro foi recusado")


func test_army_commands_serialize() -> void:
	for cmd in [RecruitTroopsCommand.create("AAA", "infantaria", 3), CancelRecruitCommand.create("AAA", 2),
			SetRallyStateCommand.create("AAA", 4), DisbandGroupCommand.create("AAA", 2),
			MoveGroupCommand.create("AAA", 1, 4, {"infantaria": 10}), RecruitGeneralCommand.create("AAA"),
			AssignGeneralCommand.create("AAA", 1, 2)]:
		var copy := CommandRegistry.from_dict(cmd.to_dict())
		assert_eq(copy.to_dict(), cmd.to_dict(), cmd.type_name())


func test_real_scenario_armies() -> void:
	var defs := ScenarioLoader.load_defs()
	var gs := ScenarioLoader.load_scenario("1936", defs)
	assert_eq(gs.groups_of("ALE").size(), 1, "Alemanha começa com uma pilha na capital")
	assert_true(gs.groups_of("ALE")[0].count_of("tanques") > 0.0, "com tanques")
	assert_eq(gs.generals_of("ALE").size(), 4, "e 4 generais")
	assert_true(gs.groups_of("BRA").size() >= 1, "Brasil tem tropa")
	var sp := -1
	var rj := -1
	for s in gs.states.values():
		if s.code == "BRA-1311":
			sp = s.id
		elif s.code == "BRA-627":
			rj = s.id
	var path := ArmySystem.find_path(gs, sp, rj, "BRA")
	assert_eq(path, [rj], "São Paulo faz fronteira com o Rio")
	var km := MapGeo.km(gs.state(sp).center, gs.state(rj).center)
	assert_true(km > 650.0 and km < 800.0, "SP-RJ entre os centros dos estados: %.0f km" % km)
