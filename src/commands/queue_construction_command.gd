class_name QueueConstructionCommand
extends Command
## Coloca uma construção na fila de um estado do próprio país.

var state_id: int
var building: String


static func create(tag: String, p_state_id: int, p_building: String) -> QueueConstructionCommand:
	var c := QueueConstructionCommand.new()
	c.country_tag = tag
	c.state_id = p_state_id
	c.building = p_building
	return c


func type_name() -> String:
	return "queue_construction"


func validate(state: GameState, defs: Dictionary) -> String:
	var country := state.country(country_tag)
	if country == null:
		return "país desconhecido"
	var s := state.state(state_id)
	if s == null:
		return "estado desconhecido"
	if s.owner != country_tag:
		return "o estado não pertence ao país"
	var def: Dictionary = defs.get("buildings", {}).get(building, {})
	if def.is_empty():
		return "construção desconhecida"
	var queued := 0
	var queued_slot_users := 0
	for item in country.construction_queue:
		if item.state_id != state_id:
			continue
		if item.building == building:
			queued += 1
		if defs.buildings[item.building].get("uses_slot", false):
			queued_slot_users += 1
	if def.get("uses_slot", false):
		var used := 0
		for b in s.buildings:
			if defs.buildings.get(b, {}).get("uses_slot", false):
				used += s.buildings[b]
		if used + queued_slot_users >= s.building_slots:
			return "sem vagas de construção no estado"
	if def.has("max_level") and s.level(building) + queued >= int(def.max_level):
		return "nível máximo atingido"
	return ""


func apply(state: GameState, _defs: Dictionary) -> void:
	state.country(country_tag).construction_queue.append(
		{"state_id": state_id, "building": building, "progress": 0.0})


func _fields() -> Dictionary:
	return {"state_id": state_id, "building": building}


func _load_fields(d: Dictionary) -> void:
	state_id = int(d.state_id)
	building = d.building
