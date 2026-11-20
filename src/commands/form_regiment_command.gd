class_name FormRegimentCommand
extends Command
## Forma um regimento na hora com equipamento do depósito. group_id = -1 cria um grupo novo na capital.

var regiment_type: String
var group_id: int = -1
var created_group: int = -1   # preenchido ao aplicar (só informativo, não vai pela rede)


static func create(tag: String, p_type: String, p_group: int = -1) -> FormRegimentCommand:
	var c := FormRegimentCommand.new()
	c.country_tag = tag
	c.regiment_type = p_type
	c.group_id = p_group
	return c


func type_name() -> String:
	return "form_regiment"


func validate(state: GameState, defs: Dictionary) -> String:
	return ArmySystem.can_form(state, defs, country_tag, regiment_type, group_id)


func apply(state: GameState, defs: Dictionary) -> void:
	created_group = ArmySystem.form_regiment(state, defs, country_tag, regiment_type, group_id).id


func _fields() -> Dictionary:
	return {"regiment_type": regiment_type, "group_id": group_id}


func _load_fields(d: Dictionary) -> void:
	regiment_type = d.regiment_type
	group_id = int(d.group_id)
