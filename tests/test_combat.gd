extends TestCase
# Combate e ocupação. Mundo: AAA tem 1, 3 e 4 em linha (cerca de 111 km entre vizinhos); 2 é de BBB.


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
	gs.wars.append(["AAA", "BBB"])
	return sim


func _group(sim: Simulation, tag: String, sid: int, regiments: int, eq: Dictionary) -> ArmyGroup:
	var g := ArmySystem.new_group(sim.state, tag, sid)
	for i in regiments:
		g.regiments.append({"type": "infantaria", "equipment": eq.duplicate(), "org": 100.0})
	return g


func test_occupy_undefended_state() -> void:
	var sim := _world()
	var g := _group(sim, "AAA", 4, 1, {"rifle": 4})
	sim.submit(MoveGroupCommand.create("AAA", g.id, 2))
	sim.advance_hours(24 * 6)
	var s2 := sim.state.state(2)
	assert_eq(g.state_id, 2, "chegou")
	assert_eq(s2.control(), "AAA", "ocupado")
	assert_eq(s2.owner, "BBB", "o dono continua o mesmo")
	assert_true(sim.state.states_of("AAA").has(s2), "o ocupante passa a usar o estado")
	assert_true(sim.state.control_version > 0, "avisa a interface")


func test_strong_attacker_wins_and_occupies() -> void:
	var sim := _world()
	var att := _group(sim, "AAA", 4, 2, {"rifle": 10})
	var dfn := _group(sim, "BBB", 2, 1, {"rifle_old": 4})
	sim.submit(MoveGroupCommand.create("AAA", att.id, 2))
	sim.advance_hours(24 * 10)
	assert_true(sim.state.events.any(func(e): return "Batalha em Estado 2" in str(e)), "houve batalha")
	assert_true(sim.state.group(dfn.id) == null, "defensor sem saída foi destruído")
	assert_eq(sim.state.state(2).control(), "AAA", "o vencedor ocupou")
	var r: Dictionary = att.regiments[0]
	assert_true(float(r.equipment.rifle) < 10.0, "houve perdas de equipamento")


func test_weak_attacker_stops() -> void:
	var sim := _world()
	var att := _group(sim, "AAA", 4, 1, {"rifle_old": 4})
	var dfn := _group(sim, "BBB", 2, 2, {"rifle": 10})
	sim.submit(MoveGroupCommand.create("AAA", att.id, 2))
	sim.advance_hours(24 * 6)
	assert_true(not att.moving(), "o ataque parou")
	assert_eq(att.state_id, 4, "ficou do seu lado")
	assert_eq(sim.state.state(2).control(), "BBB", "não ocupou")
	assert_true(sim.state.group(dfn.id) != null, "o defensor segue lá")


func test_defender_retreats_to_friendly_neighbor() -> void:
	var sim := _world()
	sim.state.states[5] = MapState.from_dict({"id": 5, "name": "Estado 5", "owner": "BBB"})
	sim.state.states[5].center = sim.state.states[2].center + Vector2(10, 0)
	sim.state.adjacency[2] = [4, 5]
	sim.state.adjacency[5] = [2]
	var att := _group(sim, "AAA", 4, 2, {"rifle": 10})
	var dfn := _group(sim, "BBB", 2, 1, {"rifle_old": 4})
	sim.submit(MoveGroupCommand.create("AAA", att.id, 2))
	sim.advance_hours(24 * 8)
	assert_eq(dfn.state_id, 5, "recuou para o vizinho")
	assert_eq(sim.state.state(2).control(), "AAA")


func test_liberation_and_org_recovery() -> void:
	var sim := _world()
	sim.state.set_control(sim.state.state(4), "BBB")
	assert_true(sim.state.state(4).occupied())
	var g := _group(sim, "AAA", 3, 1, {"rifle": 4})
	g.regiments[0].org = 50.0
	sim.submit(MoveGroupCommand.create("AAA", g.id, 4))
	sim.advance_hours(24 * 6)
	assert_eq(sim.state.state(4).control(), "AAA", "libertado")
	assert_true(not sim.state.state(4).occupied())
	assert_true(float(g.regiments[0].org) > 90.0, "organização voltou fora da batalha")


func test_combat_is_deterministic() -> void:
	var results := []
	for i in 2:
		var sim := _world()
		sim.defs.army.combat.random_spread = 0.2
		sim.state.rng.seed = 7
		var att := _group(sim, "AAA", 4, 2, {"rifle": 6})
		_group(sim, "BBB", 2, 2, {"rifle": 5})
		sim.submit(MoveGroupCommand.create("AAA", att.id, 2))
		sim.advance_hours(24 * 5)
		results.append(att.regiments[0].org)
	assert_eq(results[0], results[1])
