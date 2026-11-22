class_name RecruitTroopsCommand
extends Command
## Encomenda `batches` lotes de um tipo de tropa às fábricas militares (botão + da aba Exército).

var type: String
var batches: int = 1


static func create(tag: String, p_type: String, p_batches: int = 1) -> RecruitTroopsCommand:
	var c := RecruitTroopsCommand.new()
	c.country_tag = tag
	c.type = p_type
	c.batches = p_batches
	return c


func type_name() -> String:
	return "recruit_troops"


func validate(state: GameState, defs: Dictionary) -> String:
	return ArmySystem.can_recruit(state, defs, country_tag, type, batches)


func apply(state: GameState, defs: Dictionary) -> void:
	ArmySystem.enqueue(state, defs, country_tag, type, batches)


func _fields() -> Dictionary:
	return {"type": type, "batches": batches}


func _load_fields(d: Dictionary) -> void:
	type = d.type
	batches = int(d.batches)
