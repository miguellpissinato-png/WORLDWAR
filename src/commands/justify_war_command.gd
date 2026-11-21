class_name JustifyWarCommand
extends Command
## Começa a justificar uma guerra contra outro país (leva dias; depois é preciso declarar).

var target: String


static func create(tag: String, p_target: String) -> JustifyWarCommand:
	var c := JustifyWarCommand.new()
	c.country_tag = tag
	c.target = p_target
	return c


func type_name() -> String:
	return "justify_war"


func validate(state: GameState, defs: Dictionary) -> String:
	return DiplomacySystem.can_justify(state, defs, country_tag, target)


func apply(state: GameState, defs: Dictionary) -> void:
	DiplomacySystem.justify(state, defs, country_tag, target)


func _fields() -> Dictionary:
	return {"target": target}


func _load_fields(d: Dictionary) -> void:
	target = d.target
