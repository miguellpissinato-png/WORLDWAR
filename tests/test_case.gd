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
## AAA: 2 fábricas, sem recursos. BBB: 1 fábrica, 20 de petróleo por dia.
## As fábricas começam todas em uso civil (civil_share = 1); os testes militares mudam isso.
func make_world() -> Simulation:
	var gs := GameState.new()
	gs.countries["AAA"] = Country.from_dict({"tag": "AAA", "name": "País A", "capital_state": 1})
	gs.countries["BBB"] = Country.from_dict({"tag": "BBB", "name": "País B", "capital_state": 2})
	gs.states[1] = MapState.from_dict({"id": 1, "name": "Estado 1", "owner": "AAA", "building_slots": 4,
		"buildings": {"factory": 2}})
	gs.states[2] = MapState.from_dict({"id": 2, "name": "Estado 2", "owner": "BBB", "building_slots": 4,
		"buildings": {"factory": 1}, "resources": {"oil": 20}})
	var defs := {
		"construction": {"output_per_factory": 5.0, "max_factories_per_project": 15},
		"buildings": {
			"factory": {"cost": 100, "uses_slot": true, "money_cost": 100},
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
		"industry": {"default_civil_share": 1.0, "conversion_per_day": 0.25},
		"military_production": {"efficiency_start": 0.5, "efficiency_gain_per_day": 0.1, "efficiency_max": 1.0,
			"shortage_floor": 0.25, "max_factories_per_line": 15},
		"equipment": {
			"rifle": {"name": "Fuzil", "cost": 1.0, "resources": {"iron": 1.0}},
			"tank": {"name": "Tanque", "cost": 4.0, "resources": {"iron": 2.0, "oil": 1.0}},
		},
		"research": {
			"rules": {"slots": 2, "max_years_ahead": 2, "ahead_penalty_per_year": 0.5, "foreign_design_penalty": 0.75},
			"techs": {
				"t_base": {"name": "Base", "area": "tropas", "year": 1936, "days": 10, "money_cost": 100, "origin": []},
				"tech_rifle": {"name": "Fuzil", "area": "armas", "year": 1936, "days": 20, "money_cost": 50,
					"origin": ["AAA"], "unlocks_equipment": ["rifle"]},
				"tech_tank": {"name": "Tanque", "area": "blindados", "year": 1937, "days": 40, "money_cost": 100,
					"origin": ["AAA"], "requires": ["tech_rifle"], "unlocks_equipment": ["tank"]},
				"tech_future": {"name": "Futuro", "area": "blindados", "year": 1940, "days": 10, "money_cost": 10, "origin": []},
			},
		},
		"market": {"elasticity": 0.5, "min_factor": 0.4, "max_factor": 3.0, "price_speed": 0.05,
			"max_markup": 0.25, "ai_accept_buy_below": 1.10, "ai_accept_sell_above": 0.95},
	}
	for c in gs.countries.values():
		c.money = 1000.0
		c.goods_share = {"oil": 0.5, "iron": 0.5}
		c.civil_share = 1.0
		c.civil_share_target = 1.0
		c.research_slots = 2
	gs.prices = {"oil": 10.0, "iron": 5.0}
	return Simulation.new(gs, defs)
