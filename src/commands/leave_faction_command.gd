class_name LeaveFactionCommand
extends Command
## Sair da aliança atual (as guerras já começadas continuam).


static func create(tag: String) -> LeaveFactionCommand:
	var c := LeaveFactionCommand.new()
	c.country_tag = tag
	return c


func type_name() -> String:
	return "leave_faction"


func validate(state: GameState, _defs: Dictionary) -> String:
	return "" if state.faction_of(country_tag) != "" else "não estamos em nenhuma aliança"


func apply(state: GameState, _defs: Dictionary) -> void:
	FactionSystem.leave(state, country_tag)
