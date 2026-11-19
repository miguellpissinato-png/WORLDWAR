class_name CancelTradeCommand
extends Command
## Cancela um contrato de comércio. Pode ser dado pelo comprador ou pelo vendedor.

var trade_id: int


static func create(tag: String, p_trade_id: int) -> CancelTradeCommand:
	var c := CancelTradeCommand.new()
	c.country_tag = tag
	c.trade_id = p_trade_id
	return c


func type_name() -> String:
	return "cancel_trade"


func validate(state: GameState, _defs: Dictionary) -> String:
	var t: TradeContract = state.trades.get(trade_id)
	if t == null:
		return "contrato inexistente"
	if country_tag != t.buyer and country_tag != t.seller:
		return "o contrato não é deste país"
	return ""


func apply(state: GameState, _defs: Dictionary) -> void:
	state.trades.erase(trade_id)


func _fields() -> Dictionary:
	return {"trade_id": trade_id}


func _load_fields(d: Dictionary) -> void:
	trade_id = int(d.trade_id)
