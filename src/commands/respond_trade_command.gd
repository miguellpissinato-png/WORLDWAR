class_name RespondTradeCommand
extends Command
## Aceita ou recusa uma proposta recebida (só quem recebeu pode responder).

var offer_id: int
var accept: bool


static func create(tag: String, p_offer_id: int, p_accept: bool) -> RespondTradeCommand:
	var c := RespondTradeCommand.new()
	c.country_tag = tag
	c.offer_id = p_offer_id
	c.accept = p_accept
	return c


func type_name() -> String:
	return "respond_trade"


func validate(state: GameState, _defs: Dictionary) -> String:
	var o: TradeOffer = state.offers.get(offer_id)
	if o == null:
		return "proposta inexistente ou expirada"
	if o.to != country_tag:
		return "a proposta não é para este país"
	if accept:
		return TradeSystem.check_deal(state, o)
	return ""


func apply(state: GameState, _defs: Dictionary) -> void:
	var o: TradeOffer = state.offers[offer_id]
	state.offers.erase(offer_id)
	if accept:
		TradeSystem.execute(state, o)


func _fields() -> Dictionary:
	return {"offer_id": offer_id, "accept": accept}


func _load_fields(d: Dictionary) -> void:
	offer_id = int(d.offer_id)
	accept = bool(d.accept)
