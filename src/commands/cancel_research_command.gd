class_name CancelResearchCommand
extends Command
## Cancela uma pesquisa em andamento. O dinheiro gasto não volta e o progresso se perde.

var tech: String


static func create(tag: String, p_tech: String) -> CancelResearchCommand:
	var c := CancelResearchCommand.new()
	c.country_tag = tag
	c.tech = p_tech
	return c


func type_name() -> String:
	return "cancel_research"


func validate(state: GameState, _defs: Dictionary) -> String:
	var c := state.country(country_tag)
	if c == null:
		return "país desconhecido"
	if not ResearchSystem.in_progress(c, tech):
		return "essa pesquisa não está em andamento"
	return ""


func apply(state: GameState, _defs: Dictionary) -> void:
	var c := state.country(country_tag)
	for r in c.research.duplicate():
		if r.tech == tech:
			c.research.erase(r)


func _fields() -> Dictionary:
	return {"tech": tech}


func _load_fields(d: Dictionary) -> void:
	tech = d.tech
