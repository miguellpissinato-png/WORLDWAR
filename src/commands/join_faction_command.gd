class_name JoinFactionCommand
extends Command
## Entrar numa aliança (facção). A IA usa as datas de data/common/ai.json; o jogador pede pela
## ficha diplomática do líder da aliança.

var faction: String


static func create(tag: String, p_faction: String) -> JoinFactionCommand:
	var c := JoinFactionCommand.new()
	c.country_tag = tag
	c.faction = p_faction
	return c


func type_name() -> String:
	return "join_faction"


func validate(state: GameState, _defs: Dictionary) -> String:
	return FactionSystem.can_join(state, country_tag, faction)


func apply(state: GameState, _defs: Dictionary) -> void:
	FactionSystem.join(state, country_tag, faction)


func _fields() -> Dictionary:
	return {"faction": faction}


func _load_fields(d: Dictionary) -> void:
	faction = d.faction
