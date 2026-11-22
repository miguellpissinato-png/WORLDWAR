class_name DisbandGroupCommand
extends Command
## Dispensa uma pilha de tropas (ela deixa de existir).

var group_id: int


static func create(tag: String, p_group: int) -> DisbandGroupCommand:
	var c := DisbandGroupCommand.new()
	c.country_tag = tag
	c.group_id = p_group
	return c


func type_name() -> String:
	return "disband_group"


func validate(state: GameState, _defs: Dictionary) -> String:
	var g := state.group(group_id)
	if g == null or g.owner != country_tag:
		return "grupo desconhecido"
	return ""


func apply(state: GameState, _defs: Dictionary) -> void:
	ArmySystem.disband(state, state.group(group_id))


func _fields() -> Dictionary:
	return {"group_id": group_id}


func _load_fields(d: Dictionary) -> void:
	group_id = int(d.group_id)
