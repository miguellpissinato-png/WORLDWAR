class_name TestCase
extends RefCounted
## Base dos testes. Cada método test_* de uma subclasse é um teste.

var failures: Array[String] = []


func assert_eq(actual, expected, msg: String = "") -> void:
	if actual != expected:
		failures.append("%s esperado <%s>, obtido <%s>" % [msg, str(expected), str(actual)])


func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		failures.append("%s (esperado verdadeiro)" % msg)


## Cenário pequeno, só com o que o teste precisa (não depende dos JSON).
func make_world() -> Simulation:
	var gs := GameState.new()
	var c := Country.from_dict({"tag": "AAA", "name": "País A", "capital_state": 1})
	gs.countries["AAA"] = c
	gs.countries["BBB"] = Country.from_dict({"tag": "BBB", "name": "País B", "capital_state": 2})
	gs.states[1] = MapState.from_dict({"id": 1, "name": "Estado 1", "owner": "AAA", "building_slots": 4,
		"buildings": {"civilian_factory": 2}})
	gs.states[2] = MapState.from_dict({"id": 2, "name": "Estado 2", "owner": "BBB", "building_slots": 4,
		"buildings": {"civilian_factory": 1}, "resources": {"oil": 20}})
	var defs := {
		"construction": {"output_per_factory": 5.0, "max_factories_per_project": 15},
		"buildings": {
			"civilian_factory": {"cost": 100, "uses_slot": true},
			"military_factory": {"cost": 100, "uses_slot": true},
			"infrastructure": {"cost": 50, "max_level": 1},
		},
		"resource_ids": ["oil", "iron"],
		"trade": {"units_per_factory": 5, "max_export_share": 0.75},
	}
	return Simulation.new(gs, defs)
