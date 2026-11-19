class_name IntelligenceSystem
extends RefCounted
## Agência de inteligência: investigações levam dias, podem ser barradas na infiltração ou
## descobertas a cada dia pela contraespionagem do alvo. Ao terminar, geram um relatório
## congelado na data (com erro que diminui com o nível de espionagem).
## Todo sorteio usa state.rng (determinismo).


static func rules(defs: Dictionary) -> Dictionary:
	return defs.get("intelligence", {}).get("investigation", {})


static func investigation_days(defs: Dictionary, offense: int) -> int:
	var r := rules(defs)
	return maxi(int(r.get("min_days", 6)), int(r.get("base_days", 24)) - int(r.get("days_per_level", 4)) * (offense - 1))


static func block_chance(defs: Dictionary, offense: int, defense: int) -> float:
	var r := rules(defs)
	return clampf(float(r.get("block_per_defense", 0.12)) * defense - float(r.get("block_per_offense", 0.06)) * offense,
		0.0, float(r.get("block_max", 0.6)))


static func detect_chance(defs: Dictionary, offense: int, defense: int) -> float:
	var r := rules(defs)
	return maxf(float(r.get("detect_min", 0.002)),
		float(r.get("detect_per_defense", 0.012)) * defense - float(r.get("detect_per_offense", 0.006)) * offense)


static func upgrade_cost(defs: Dictionary, current_level: int) -> float:
	var costs: Array = defs.get("intelligence", {}).get("upgrade_cost", [])
	return float(costs[current_level]) if current_level < costs.size() else INF


## Tenta infiltrar agentes. Retorna false se a contraespionagem barrou logo no início.
static func try_infiltrate(state: GameState, defs: Dictionary, op: IntelOperation) -> bool:
	var me := state.country(op.owner)
	var them := state.country(op.target)
	if state.rng.randf() < block_chance(defs, me.intel_offense, them.intel_defense):
		state.add_event([op.owner], "A infiltração em %s foi barrada pela contraespionagem deles." % them.name)
		state.add_event([op.target], "Nossa contraespionagem barrou agentes de %s na fronteira." % me.name)
		return false
	return true


static func daily_update(state: GameState, defs: Dictionary) -> void:
	var ids: Array = state.operations.keys()
	ids.sort()
	for id in ids:
		var op: IntelOperation = state.operations[id]
		var me := state.country(op.owner)
		var them := state.country(op.target)
		if me == null or them == null:
			state.operations.erase(id)
			continue
		if state.rng.randf() < detect_chance(defs, me.intel_offense, them.intel_defense):
			state.operations.erase(id)
			state.add_event([op.owner], "Nossos agentes foram descobertos e presos em %s." % them.name)
			state.add_event([op.target], "Agentes de %s foram descobertos e presos." % me.name)
			continue
		op.days_done += 1
		if op.days_done >= op.days_total:
			state.operations.erase(id)
			me.intel_reports[op.target] = make_report(state, defs, op.target, me.intel_offense)
			state.add_event([op.owner], "Relatório de inteligência sobre %s concluído." % them.name)


## Fotografia do país alvo, com erro de até noise_base / nível de espionagem.
static func make_report(state: GameState, defs: Dictionary, target: String, offense: int) -> Dictionary:
	var noise := float(rules(defs).get("noise_base", 0.3)) / maxf(1.0, offense)
	var blur := func(v: float) -> float:
		return maxf(0.0, v * (1.0 + state.rng.randf_range(-noise, noise)))
	var c := state.country(target)
	var production := {}
	var stock := {}
	for r in defs.get("resource_ids", []):
		production[r] = roundi(blur.call(float(state.resource_production(target, r))))
		stock[r] = roundi(blur.call(c.stock(r)))
	return {
		"hours": state.hours,
		"error": noise,
		"production": production,
		"stock": stock,
		"money": roundi(blur.call(c.money)),
		"civilian_factories": roundi(blur.call(float(state.civil_factories(target)))),
		"military_factories": roundi(blur.call(float(state.military_factories(target)))),
	}
