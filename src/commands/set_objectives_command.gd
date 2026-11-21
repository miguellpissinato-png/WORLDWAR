class_name SetObjectivesCommand
extends Command
## Define o objetivo de vitória de um ou mais países (no começo da partida). No multiplayer só o
## host manda este comando; o sorteio é feito antes, na interface, e o resultado vai aqui dentro.

var assignments: Dictionary = {}   # tag -> id do objetivo


static func create(p_assignments: Dictionary) -> SetObjectivesCommand:
	var c := SetObjectivesCommand.new()
	c.assignments = p_assignments
	return c


func type_name() -> String:
	return "set_objectives"


func validate(state: GameState, defs: Dictionary) -> String:
	if state.winner != "":
		return "a guerra já tem um vencedor"
	for tag in assignments:
		if state.country(tag) == null:
			return "país desconhecido: %s" % tag
		if ObjectiveSystem.find(defs, String(assignments[tag])).is_empty():
			return "objetivo desconhecido: %s" % assignments[tag]
	return ""


func apply(state: GameState, _defs: Dictionary) -> void:
	for tag in assignments:
		state.objectives[String(tag)] = String(assignments[tag])


func _fields() -> Dictionary:
	return {"assignments": assignments}


func _load_fields(d: Dictionary) -> void:
	assignments = d.get("assignments", {})
