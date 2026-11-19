class_name StartResearchCommand
extends Command
## Começa a pesquisar uma tecnologia numa vaga livre (paga o custo em dinheiro na hora).

var tech: String


static func create(tag: String, p_tech: String) -> StartResearchCommand:
	var c := StartResearchCommand.new()
	c.country_tag = tag
	c.tech = p_tech
	return c


func type_name() -> String:
	return "start_research"


func validate(state: GameState, defs: Dictionary) -> String:
	return ResearchSystem.can_start(state, defs, country_tag, tech)


func apply(state: GameState, defs: Dictionary) -> void:
	ResearchSystem.start(state, defs, country_tag, tech)


func _fields() -> Dictionary:
	return {"tech": tech}


func _load_fields(d: Dictionary) -> void:
	tech = d.tech
