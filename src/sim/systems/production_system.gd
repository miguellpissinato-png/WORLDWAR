class_name ProductionSystem
extends RefCounted
## Linhas de produção militar. As fábricas militares do país são distribuídas entre as linhas, em ordem.
## Cada fábrica entrega `efficiency` dias-fábrica por dia; uma unidade custa `cost` dias-fábrica e
## consome recursos do estoque. A eficiência começa baixa e sobe a cada dia de trabalho.
## Faltando recurso, a linha anda na proporção do que há, mas nunca abaixo de `shortage_floor`
## (improviso e substitutos); o estoque nunca fica negativo.


static func rules(defs: Dictionary) -> Dictionary:
	return defs.get("military_production", {})


static func equipment_def(defs: Dictionary, eq: String) -> Dictionary:
	return defs.get("equipment", {}).get(eq, {})


static func line(c: Country, id: int) -> Dictionary:
	for l in c.production_lines:
		if int(l.id) == id:
			return l
	return {}


static func new_line(c: Country, defs: Dictionary, eq: String, factories: int) -> void:
	c.production_lines.append({"id": c.next_line_id, "equipment": eq, "factories": factories,
		"assigned": 0, "efficiency": float(rules(defs).get("efficiency_start", 0.3)), "progress": 0.0})
	c.next_line_id += 1


## Unidades por dia que a linha faria com as fábricas atribuídas e sem faltar recurso.
static func daily_output(defs: Dictionary, l: Dictionary) -> float:
	var cost := float(equipment_def(defs, l.equipment).get("cost", 1.0))
	return int(l.get("assigned", 0)) * float(l.efficiency) / maxf(cost, 0.01)


static func daily_update(state: GameState, defs: Dictionary) -> void:
	var r := rules(defs)
	var floor_speed := float(r.get("shortage_floor", 0.25))
	var gain := float(r.get("efficiency_gain_per_day", 0.01))
	var cap := float(r.get("efficiency_max", 1.0))
	for tag in state.countries:
		var c: Country = state.countries[tag]
		var free := state.military_factories(tag)
		c.last_production = {}
		c.last_shortage = {}
		for l in c.production_lines:
			var assigned := mini(int(l.factories), free)
			free -= assigned
			l.assigned = assigned
			if assigned <= 0:
				continue
			var def := equipment_def(defs, l.equipment)
			var per_unit: Dictionary = def.get("resources", {})
			var units := daily_output(defs, l)
			var ratio := 1.0
			for res in per_unit:
				var need := float(per_unit[res]) * units
				if need > 0.0:
					ratio = minf(ratio, c.stock(res) / need)
			units *= clampf(maxf(ratio, floor_speed), 0.0, 1.0)
			for res in per_unit:
				var need := float(per_unit[res]) * units
				var used := minf(need, c.stock(res))
				c.stockpile[res] = c.stock(res) - used
				if need - used > 0.0001:
					c.last_shortage[res] = float(c.last_shortage.get(res, 0.0)) + need - used
			l.progress = float(l.progress) + units
			var whole := floori(l.progress)
			if whole > 0:
				l.progress -= whole
				c.equipment[l.equipment] = c.equipment_count(l.equipment) + whole
				c.last_production[l.equipment] = int(c.last_production.get(l.equipment, 0)) + whole
			l.efficiency = minf(cap, float(l.efficiency) + gain)
