class_name RespondPeaceCommand
extends Command
## Resposta de um jogador a uma proposta de paz recebida.

var offer_id: int
var accept: bool


static func create(tag: String, p_offer: int, p_accept: bool) -> RespondPeaceCommand:
	var c := RespondPeaceCommand.new()
	c.country_tag = tag
	c.offer_id = p_offer
	c.accept = p_accept
	return c


func type_name() -> String:
	return "respond_peace"


func validate(state: GameState, _defs: Dictionary) -> String:
	var o: Dictionary = state.peace_offers.get(offer_id, {})
	if o.is_empty() or o.to != country_tag:
		return "proposta desconhecida"
	return ""


func apply(state: GameState, defs: Dictionary) -> void:
	var o: Dictionary = state.peace_offers[offer_id]
	if accept:
		PeaceSystem.accept(state, defs, o)
	else:
		PeaceSystem.reject(state, o)


func _fields() -> Dictionary:
	return {"offer_id": offer_id, "accept": accept}


func _load_fields(d: Dictionary) -> void:
	offer_id = int(d.offer_id)
	accept = bool(d.accept)
