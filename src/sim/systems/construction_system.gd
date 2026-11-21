class_name ConstructionSystem
extends RefCounted
## Fábricas civis de cada país constroem os itens da fila, em ordem, uma vez por dia.
## Cada item recebe no máximo `max_factories_per_project` fábricas.


## Definição de uma construção. As de extração ("extraction_<recurso>") são geradas a partir
## de resources.json; as demais vêm de buildings.json.
static func definition(defs: Dictionary, building: String) -> Dictionary:
	if defs.get("buildings", {}).has(building):
		return defs.buildings[building]
	if building.begins_with("extraction_"):
		var res := building.trim_prefix("extraction_")
		if res in defs.get("resource_ids", []):
			var ex: Dictionary = defs.get("extraction", {})
			var name := res
			for r in defs.get("resources", []):
				if r.id == res:
					name = r.get("extraction", res)
			return {"name": name, "cost": ex.get("cost", 2500), "money_cost": ex.get("money_cost", 0), "resource": res}
	return {}


static func daily_update(state: GameState, defs: Dictionary) -> void:
	var rules: Dictionary = defs.get("construction", {})
	var output := float(rules.get("output_per_factory", 5.0))
	var cap := int(rules.get("max_factories_per_project", 15))
	for tag in state.countries:
		var country: Country = state.countries[tag]
		var free_factories := state.civil_factories(tag)
		var finished: Array = []
		for item in country.construction_queue:
			if free_factories <= 0:
				break
			var assigned := mini(free_factories, cap)
			free_factories -= assigned
			item.progress += assigned * output
			var cost := float(definition(defs, item.building).cost)
			if item.progress >= cost:
				finished.append(item)
		for item in finished:
			country.construction_queue.erase(item)
			var s := state.state(item.state_id)
			# O estado pode ter mudado de dono durante a construção.
			if s != null and s.owner == tag and s.control() == tag:
				s.buildings[item.building] = s.level(item.building) + 1
