class_name CreateTradeCommand
extends Command
## Compra `amount` unidades/dia de um recurso de outro país (country_tag = comprador).
## O pagamento é feito cedendo fábricas civis ao vendedor enquanto o contrato durar.

var seller: String
var resource: String
var amount: int


static func create(buyer: String, p_seller: String, p_resource: String, p_amount: int) -> CreateTradeCommand:
	var c := CreateTradeCommand.new()
	c.country_tag = buyer
	c.seller = p_seller
	c.resource = p_resource
	c.amount = p_amount
	return c


func type_name() -> String:
	return "create_trade"


func validate(state: GameState, defs: Dictionary) -> String:
	if state.country(country_tag) == null or state.country(seller) == null:
		return "país desconhecido"
	if seller == country_tag:
		return "não dá para comerciar consigo mesmo"
	if not resource in defs.get("resource_ids", []):
		return "recurso desconhecido"
	if amount <= 0:
		return "quantidade inválida"
	if state.exportable(seller, resource, TradeSystem.max_export_share(defs)) < amount:
		return "o vendedor não tem esse excedente"
	if state.available_civilian_factories(country_tag) < TradeSystem.cost_in_factories(amount, defs):
		return "fábricas civis insuficientes para pagar"
	return ""


func apply(state: GameState, defs: Dictionary) -> void:
	var t := TradeContract.new()
	t.id = state.next_trade_id
	state.next_trade_id += 1
	t.buyer = country_tag
	t.seller = seller
	t.resource = resource
	t.amount = amount
	t.factories = TradeSystem.cost_in_factories(amount, defs)
	state.trades[t.id] = t


func _fields() -> Dictionary:
	return {"seller": seller, "resource": resource, "amount": amount}


func _load_fields(d: Dictionary) -> void:
	seller = d.seller
	resource = d.resource
	amount = int(d.amount)
