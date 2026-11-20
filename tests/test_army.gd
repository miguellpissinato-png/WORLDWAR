extends TestCase
# Exército: regimentos, grupos, generais e marcha.
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
	c.researched.append_array(["t_infantaria", "t_tanquistas"])
	c.equipment = {"rifle": 6.0, "rifle_old": 4.0, "tank": 2.0}
	return sim


func test_distance_on_equator() -> void:
	var sim := _world()
	var km := MapGeo.km(sim.state.states[1].center, sim.state.states[3].center)
	assert_true(absf(km - 111.2) < 1.0, "0,1 grau no equador = 111 km (deu %.1f)" % km)


func test_form_regiment_takes_best_equipment() -> void:
	var sim := _world()
	var cmd := FormRegimentCommand.create("AAA", "infantaria")
	sim.submit(cmd)
	sim.apply_pending()
	var g := sim.state.group(cmd.created_group)
	assert_eq(g.state_id, 1, "grupo novo na capital")
	assert_eq(g.name, "1º Grupo")
	assert_eq(g.regiments[0].equipment, {"rifle": 4}, "o melhor fuzil primeiro")
	assert_eq(sim.state.country("AAA").equipment_count("rifle"), 2.0, "saiu do depósito")
	# Segundo regimento: 2 fuzis bons + 2 velhos.
	sim.submit(FormRegimentCommand.create("AAA", "infantaria", g.id))
	sim.apply_pending()
	assert_eq(g.regiments[1].equipment, {"rifle": 2, "rifle_old": 2}, "completa com o velho")


func test_form_regiment_rejections() -> void:
	var sim := _world()
	assert_true(ArmySystem.can_form(sim.state, sim.defs, "BBB", "infantaria", -1).begins_with("pesquise"), "sem a tropa")
	sim.state.country("AAA").equipment = {"rifle": 3.0}
	assert_true(ArmySystem.can_form(sim.state, sim.defs, "AAA", "infantaria", -1).begins_with("falta equipamento"), "faltam fuzis")
	sim.state.country("AAA").equipment = {"rifle": 20.0}
	var g := ArmySystem.form_regiment(sim.state, sim.defs, "AAA", "infantaria", -1)
	ArmySystem.form_regiment(sim.state, sim.defs, "AAA", "infantaria", g.id)
	assert_eq(ArmySystem.can_form(sim.state, sim.defs, "AAA", "infantaria", g.id), "o grupo já está cheio")


func test_disband_returns_equipment() -> void:
	var sim := _world()
	var g := ArmySystem.form_regiment(sim.state, sim.defs, "AAA", "tanquistas", -1)
	assert_eq(sim.state.country("AAA").equipment_count("tank"), 0.0)
	sim.submit(DisbandGroupCommand.create("AAA", g.id))
	sim.apply_pending()
	assert_eq(sim.state.country("AAA").equipment_count("tank"), 2.0, "tanques de volta")
	assert_eq(sim.state.groups.size(), 0)


func test_march_takes_days() -> void:
	var sim := _world()
	var g := ArmySystem.form_regiment(sim.state, sim.defs, "AAA", "infantaria", -1)
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
	var inf := ArmySystem.form_regiment(sim.state, sim.defs, "AAA", "infantaria", -1)
	var tank := ArmySystem.form_regiment(sim.state, sim.defs, "AAA", "tanquistas", -1)
	assert_eq(ArmySystem.march_km_day(sim.state, sim.defs, tank), 48.0)
	var gen := ArmySystem.new_general(sim.state, sim.defs, "AAA", 1)
	gen.speed = 3
	inf.general_id = gen.id
	assert_true(absf(ArmySystem.march_km_day(sim.state, sim.defs, inf) - 28.8) < 0.001, "+20% com velocidade 3")


func test_cannot_march_abroad() -> void:
	var sim := _world()
	var g := ArmySystem.form_regiment(sim.state, sim.defs, "AAA", "infantaria", -1)
	var reasons: Array = []
	sim.command_rejected.connect(func(_c, r): reasons.append(r))
	sim.submit(MoveGroupCommand.create("AAA", g.id, 2))
	sim.apply_pending()
	assert_eq(reasons, ["só dá para marchar dentro do próprio país por enquanto"])


func test_change_route_while_marching() -> void:
	var sim := _world()
	var g := ArmySystem.form_regiment(sim.state, sim.defs, "AAA", "infantaria", -1)
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
	sim.state.country("AAA").equipment = {"rifle": 40.0}
	var ids: Array = []
	for i in 3:
		ids.append(ArmySystem.form_regiment(sim.state, sim.defs, "AAA", "infantaria", -1).id)
	for i in 3:
		sim.submit(AssignGeneralCommand.create("AAA", ids[i], gens[0].id))
	var reasons: Array = []
	sim.command_rejected.connect(func(_c, r): reasons.append(r))
	sim.apply_pending()
	assert_eq(ArmySystem.groups_of_general(sim.state, gens[0].id).size(), 2, "no máximo 2 neste teste")
	assert_eq(reasons.size(), 1, "o terceiro foi recusado")


func test_army_commands_serialize() -> void:
	for cmd in [FormRegimentCommand.create("AAA", "infantaria", 3), DisbandGroupCommand.create("AAA", 2),
			MoveGroupCommand.create("AAA", 1, 4), RecruitGeneralCommand.create("AAA"), AssignGeneralCommand.create("AAA", 1, 2)]:
		var copy := CommandRegistry.from_dict(cmd.to_dict())
		assert_eq(copy.to_dict(), cmd.to_dict(), cmd.type_name())


func test_real_scenario_armies() -> void:
	var defs := ScenarioLoader.load_defs()
	var gs := ScenarioLoader.load_scenario("1936", defs)
	assert_eq(gs.groups_of("ALE").size(), 2, "Alemanha começa com 2 grupos")
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
