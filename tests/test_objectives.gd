extends TestCase
# Objetivos de vitória: AAA tem o estado 1 (1000 km²), BBB o estado 2 (1000 km²), os dois na Europa.


func _world() -> Simulation:
	var sim := make_world()
	for s in sim.state.states.values():
		s.continent = "europa"
		s.area_km2 = 1000
	return sim


func test_progress_counts_controlled_area() -> void:
	var sim := _world()
	var p := ObjectiveSystem.progress(sim.state, sim.defs, "AAA", "europa")
	assert_true(absf(p.parts[0].share - 0.5) < 0.001, "metade da Europa")
	assert_true(not p.done)
	sim.state.set_control(sim.state.state(2), "AAA")
	p = ObjectiveSystem.progress(sim.state, sim.defs, "AAA", "europa")
	assert_true(p.done, "ocupar conta")


func test_winner_and_command_roundtrip() -> void:
	var sim := _world()
	var cmd := SetObjectivesCommand.create({"AAA": "europa", "BBB": "mundo_70"})
	var back := CommandRegistry.from_dict(JSON.parse_string(JSON.stringify(cmd.to_dict())))
	sim.submit(back)
	sim.apply_pending()
	assert_eq(sim.state.objectives.AAA, "europa")
	sim.advance_hours(24)
	assert_eq(sim.state.winner, "", "ninguém cumpriu ainda")
	sim.state.set_control(sim.state.state(2), "AAA")
	sim.advance_hours(24)
	assert_eq(sim.state.winner, "AAA", "AAA venceu")
	sim.submit(SetObjectivesCommand.create({"AAA": "mundo_70"}))
	sim.apply_pending()
	assert_eq(sim.state.objectives.AAA, "europa", "depois da vitória não muda mais")


func test_rejects_unknown_objective() -> void:
	var sim := _world()
	sim.submit(SetObjectivesCommand.create({"AAA": "lua"}))
	sim.apply_pending()
	assert_true(not sim.state.objectives.has("AAA"))


func test_candidates_skip_easy_objectives() -> void:
	var sim := _world()
	sim.state.set_control(sim.state.state(2), "AAA")   # AAA já tem tudo
	assert_eq(ObjectiveSystem.candidates(sim.state, sim.defs, "AAA").size(), 0)
	assert_eq(ObjectiveSystem.candidates(sim.state, sim.defs, "BBB").size(), 2)
