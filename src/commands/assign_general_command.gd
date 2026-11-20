class_name AssignGeneralCommand
extends Command
## Põe um general no comando de um grupo (general_id = -1 tira o general). Cada general comanda até 5 grupos.

var group_id: int
var general_id: int


static func create(tag: String, p_group: int, p_general: int) -> AssignGeneralCommand:
	var c := AssignGeneralCommand.new()
	c.country_tag = tag
	c.group_id = p_group
	c.general_id = p_general
	return c


func type_name() -> String:
	return "assign_general"


func validate(state: GameState, defs: Dictionary) -> String:
	var g := state.group(group_id)
	if g == null or g.owner != country_tag:
		return "grupo desconhecido"
	if general_id == -1:
		return ""
	var gen := state.general(general_id)
	if gen == null or gen.owner != country_tag:
		return "general desconhecido"
	var max_groups := int(ArmySystem.army(defs).get("max_groups_per_general", 5))
	if g.general_id != general_id and ArmySystem.groups_of_general(state, general_id).size() >= max_groups:
		return "%s já comanda %d grupos" % [gen.name, max_groups]
	return ""


func apply(state: GameState, _defs: Dictionary) -> void:
	state.group(group_id).general_id = general_id


func _fields() -> Dictionary:
	return {"group_id": group_id, "general_id": general_id}


func _load_fields(d: Dictionary) -> void:
	group_id = int(d.group_id)
	general_id = int(d.general_id)
