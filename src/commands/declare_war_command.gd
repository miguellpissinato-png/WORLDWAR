class_name DeclareWarCommand
extends Command
## Declara guerra a um país contra o qual a justificativa já terminou.

var target: String


static func create(tag: String, p_target: String) -> DeclareWarCommand:
	var c := DeclareWarCommand.new()
	c.country_tag = tag
	c.target = p_target
	return c


func type_name() -> String:
	return "declare_war"


func validate(state: GameState, _defs: Dictionary) -> String:
	return DiplomacySystem.can_declare(state, country_tag, target)


func apply(state: GameState, _defs: Dictionary) -> void:
	DiplomacySystem.declare(state, country_tag, target)


func _fields() -> Dictionary:
	return {"target": target}


func _load_fields(d: Dictionary) -> void:
	target = d.target
