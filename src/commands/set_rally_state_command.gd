class_name SetRallyStateCommand
extends Command
## Marca o estado favorito: as tropas novas nascem ali (ou nos vizinhos, se estiver cheio).

var state_id: int


static func create(tag: String, p_state: int) -> SetRallyStateCommand:
	var c := SetRallyStateCommand.new()
	c.country_tag = tag
	c.state_id = p_state
	return c


func type_name() -> String:
	return "set_rally_state"


func validate(state: GameState, _defs: Dictionary) -> String:
	var s := state.state(state_id)
	if state.country(country_tag) == null or s == null:
		return "estado desconhecido"
	if s.control() != country_tag:
		return "o estado não está sob nosso controle"
	return ""


func apply(state: GameState, _defs: Dictionary) -> void:
	state.country(country_tag).rally_state = state_id


func _fields() -> Dictionary:
	return {"state_id": state_id}


func _load_fields(d: Dictionary) -> void:
	state_id = int(d.state_id)
