class_name RecruitGeneralCommand
extends Command
## Promove um novo general (fictício). Custa dinheiro.


static func create(tag: String) -> RecruitGeneralCommand:
	var c := RecruitGeneralCommand.new()
	c.country_tag = tag
	return c


func type_name() -> String:
	return "recruit_general"


func validate(state: GameState, defs: Dictionary) -> String:
	var c := state.country(country_tag)
	if c == null:
		return "país desconhecido"
	if c.money < float(ArmySystem.army(defs).get("generals", {}).get("recruit_cost", 500)):
		return "dinheiro insuficiente"
	return ""


func apply(state: GameState, defs: Dictionary) -> void:
	var gd: Dictionary = ArmySystem.army(defs).get("generals", {})
	state.country(country_tag).money -= float(gd.get("recruit_cost", 500))
	ArmySystem.new_general(state, defs, country_tag, int(gd.get("skill_start_max", 3)))


func _fields() -> Dictionary:
	return {}


func _load_fields(_d: Dictionary) -> void:
	pass
