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
## AAA: 2 fábricas civis, sem recursos. BBB: 1 fábrica civil, 20 de petróleo por dia.
func make_world() -> Simulation:
	var gs := GameState.new()
	gs.countries["AAA"] = Country.from_dict({"tag": "AAA", "name": "País A", "capital_state": 1})
	gs.countries["BBB"] = Country.from_dict({"tag": "BBB", "name": "País B", "capital_state": 2})
	gs.states[1] = MapState.from_dict({"id": 1, "name": "Estado 1", "owner": "AAA", "building_slots": 4,
		"buildings": {"civilian_factory": 2}})
	gs.states[2] = MapState.from_dict({"id": 2, "name": "Estado 2", "owner": "BBB", "building_slots": 4,
		"buildings": {"civilian_factory": 1}, "resources": {"oil": 20}})
	var defs := {
		"construction": {"output_per_factory": 5.0, "max_factories_per_project": 15},
		"buildings": {
			"civilian_factory": {"cost": 100, "uses_slot": true, "money_cost": 100},
			"military_factory": {"cost": 100, "uses_slot": true},
			"infrastructure": {"cost": 50, "max_level": 1},
		},
		"resources": [
			{"id": "oil", "name": "Petróleo", "base_price": 10, "demand_per_factory": 1.0},
			{"id": "iron", "name": "Ferro", "base_price": 5, "demand_per_factory": 1.0},
		],
		"resource_ids": ["oil", "iron"],
		"extraction": {"step_share": 0.1, "deposit_factor": 2.0, "cost": 100, "money_cost": 50},
		"economy": {"goods_per_factory": 10, "goods_value": 1.5, "start_money": 1000, "default_goods_share": 0.5},
		"intelligence": {"max_level": 5, "upgrade_cost": [0, 100, 200, 400, 800],
			"investigation": {"cost": 50, "base_days": 10, "days_per_level": 2, "min_days": 4,
				"block_per_defense": 0.12, "block_per_offense": 0.06, "block_max": 0.6,
				"detect_per_defense": 0.012, "detect_per_offense": 0.006, "detect_min": 0.002, "noise_base": 0.3}},
		"market": {"elasticity": 0.5, "min_factor": 0.4, "max_factor": 3.0, "price_speed": 0.05,
			"max_markup": 0.25, "ai_accept_buy_below": 1.10, "ai_accept_sell_above": 0.95},
	}
	for c in gs.countries.values():
		c.money = 1000.0
		c.goods_share = {"oil": 0.5, "iron": 0.5}
	gs.prices = {"oil": 10.0, "iron": 5.0}
	return Simulation.new(gs, defs)
