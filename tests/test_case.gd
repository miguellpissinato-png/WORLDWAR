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
		"equipment": {
			"rifle": {"name": "Fuzil", "category": "rifle", "cost": 1.0, "resources": {"iron": 1.0},
				"stats": {"soft_attack": 3.0}},
			"rifle_old": {"name": "Fuzil velho", "category": "rifle", "cost": 1.0, "resources": {"iron": 1.0},
				"stats": {"soft_attack": 2.0}},
			"tank": {"name": "Tanque", "category": "tank", "cost": 4.0, "resources": {"iron": 2.0, "oil": 1.0},
				"stats": {"hard_attack": 5.0}},
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
		"diplomacy": {"justify_days": 3, "justify_cost": 10, "peace": {"army_weight": 0.6, "capital_weight": 0.25,
			"state_weight": 1.5, "money_weight": 0.4, "resource_weight": 0.15, "tired_per_month": 0.01, "tired_max": 0.3,
			"white_margin": 0.05, "offer_days": 30}},
		"objectives": {"max_start_progress": 0.4, "region_names": {"europa": "Europa"}, "objectives": [
			{"id": "europa", "name": "Conquistar a Europa", "targets": [{"regions": ["europa"], "share": 0.9}]},
			{"id": "mundo_70", "name": "Dominar 70% do mundo", "targets": [{"regions": ["mundo"], "share": 0.7}]}]},
		"army": {
			"max_groups_per_general": 2,
			"troops": {
				"infantaria": {"name": "Soldados", "short": "soldados", "categories": ["rifle"], "batch": 10, "days": 3,
					"work_per_unit": 0.1, "resources_per_unit": 0.1, "stat_scale": 1.0, "size": 1, "march_km_day": 24, "rank": "soft_attack"},
				"tanques": {"name": "Tanques", "short": "tanques", "categories": ["tank"], "batch": 2, "days": 4,
					"work_per_unit": 1.0, "resources_per_unit": 1.0, "stat_scale": 1.0, "size": 5, "march_km_day": 48, "rank": "hard_attack"},
			},
			"recruit": {"state_capacity": 50, "spill_depth": 2, "max_batches_per_click": 10, "shortage_floor": 0.25},
			"rank_stat": {"rifle": "soft_attack", "tank": "hard_attack"},
			"movement": {"infrastructure_bonus_per_level": 0.0, "general_speed_bonus_per_level": 0.1},
			"generals": {"recruit_cost": 300, "skill_start_max": 3},
			"combat": {"max_org": 100, "org_loss_per_hour": 4.0, "org_regen_per_hour": 1.0, "break_org": 15,
				"random_spread": 0.0, "defender_bonus": 1.25, "general_bonus_per_level": 0.1, "org_power_floor": 0.4,
				"equipment_loss_per_org": 0.0008, "soft_weights": {"soft_attack": 1.0}, "hard_weights": {"hard_attack": 1.0},
				"hard_categories": ["tank"]},
		},
		"general_names": {"pools": {"x": {"first": ["Ana"], "last": ["Silva", "Souza"]}}, "country_pool": {"AAA": "x"}},
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
