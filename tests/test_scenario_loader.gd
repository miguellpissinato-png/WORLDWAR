extends TestCase


func test_load_1936() -> void:
	var gs := ScenarioLoader.load_scenario("1936")
	assert_eq(gs.scenario_name, "Rearmamento")
	assert_eq(gs.hours, 0)
	assert_eq(gs.country("BRA").leader, "Getúlio Vargas")
	assert_eq(gs.state(gs.country("GER").capital_state).name, "Brandemburgo")


func test_every_capital_belongs_to_its_country() -> void:
	var gs := ScenarioLoader.load_scenario("1936")
	for tag in gs.countries:
		var cap := gs.state(gs.country(tag).capital_state)
		assert_true(cap != null and cap.owner == tag, "capital de " + tag)


func test_buildings_in_states_are_defined() -> void:
	var gs := ScenarioLoader.load_scenario("1936")
	var defs := ScenarioLoader.load_defs()
	for s in gs.states.values():
		for b in s.buildings:
			assert_true(defs.buildings.has(b), "construção %s em %s" % [b, s.name])
