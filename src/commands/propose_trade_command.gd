class_name ProposeTradeCommand
extends Command
## Propõe um negócio (lote único) a outro país. kind "sell" = vender para ele; "buy" = comprar dele.
## O preço por unidade não pode passar do teto (mercado + max_markup).
## Se o outro país é da IA, ela responde na hora.

var to: String
var kind: String
var resource: String
var amount: int
var price: float
## Resultado depois de aplicado (não é serializado): "aceita", "recusada" ou "aguardando".
var result: String = ""


static func create(tag: String, p_to: String, p_kind: String, p_resource: String, p_amount: int, p_price: float) -> ProposeTradeCommand:
	var c := ProposeTradeCommand.new()
	c.country_tag = tag
	c.to = p_to
	c.kind = p_kind
	c.resource = p_resource
	c.amount = p_amount
	c.price = p_price
	return c


func type_name() -> String:
	return "propose_trade"


func validate(state: GameState, defs: Dictionary) -> String:
	var me := state.country(country_tag)
	if me == null or state.country(to) == null:
		return "país desconhecido"
	if to == country_tag:
		return "não dá para negociar consigo mesmo"
	if not resource in defs.get("resource_ids", []):
		return "recurso desconhecido"
	if not kind in ["sell", "buy"]:
		return "tipo de negócio inválido"
	if amount <= 0 or price < 0.0:
		return "quantidade ou preço inválido"
	if price > MarketSystem.max_price(state, defs, resource) + 0.001:
		return "preço acima do teto permitido"
	if kind == "sell" and me.stock(resource) < amount:
		return "estoque insuficiente"
	if kind == "buy" and me.money < amount * price:
		return "dinheiro insuficiente"
	return ""


func apply(state: GameState, defs: Dictionary) -> void:
	var o := TradeOffer.new()
	o.id = state.next_offer_id
	state.next_offer_id += 1
	o.from = country_tag
	o.to = to
	o.kind = kind
	o.resource = resource
	o.amount = amount
	o.price = price
	o.created_hours = state.hours
	if state.is_human(to):
		state.offers[o.id] = o   # fica aguardando o outro jogador
		result = "aguardando"
		return
	if TradeSystem.ai_accepts(state, defs, o):
		TradeSystem.execute(state, o)
		result = "aceita"
	else:
		result = "recusada"


func _fields() -> Dictionary:
	return {"to": to, "kind": kind, "resource": resource, "amount": amount, "price": price}


func _load_fields(d: Dictionary) -> void:
	to = d.to
	kind = d.kind
	resource = d.resource
	amount = int(d.amount)
	price = float(d.price)
