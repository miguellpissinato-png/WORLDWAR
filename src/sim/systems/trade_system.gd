class_name TradeSystem
extends RefCounted
## Negociação de recursos: propostas (TradeOffer), resposta da IA e execução do negócio.

const OFFER_DAYS := 30   # propostas sem resposta expiram


## Preço que a IA pede ao vender (até 10% acima do mercado, varia por país, sempre dentro do teto).
static func ai_ask_price(state: GameState, defs: Dictionary, tag: String, resource: String) -> float:
	var markup := float(abs(tag.hash()) % 11) / 100.0
	return minf(state.price(resource) * (1.0 + markup), MarketSystem.max_price(state, defs, resource))


## Preço que a IA oferece ao comprar.
static func ai_bid_price(state: GameState, defs: Dictionary, resource: String) -> float:
	return state.price(resource) * float(defs.get("market", {}).get("ai_accept_sell_above", 0.95))


## Motivo pelo qual o negócio não pode ser fechado agora, ou "".
static func check_deal(state: GameState, offer: TradeOffer) -> String:
	var s := state.country(offer.seller())
	var b := state.country(offer.buyer())
	if s == null or b == null:
		return "país desconhecido"
	if s.stock(offer.resource) < offer.amount:
		return "o vendedor não tem esse estoque"
	if b.money < offer.total():
		return "o comprador não tem dinheiro suficiente"
	return ""


static func execute(state: GameState, offer: TradeOffer) -> void:
	var s := state.country(offer.seller())
	var b := state.country(offer.buyer())
	s.stockpile[offer.resource] = s.stock(offer.resource) - offer.amount
	b.stockpile[offer.resource] = b.stock(offer.resource) + offer.amount
	b.money -= offer.total()
	s.money += offer.total()


## A IA decide uma proposta feita a ela: compra barato e vende pelo menos perto do mercado.
static func ai_accepts(state: GameState, defs: Dictionary, offer: TradeOffer) -> bool:
	if check_deal(state, offer) != "":
		return false
	var m: Dictionary = defs.get("market", {})
	var market := state.price(offer.resource)
	if offer.seller() == offer.to:   # a IA está vendendo
		return offer.price >= market * float(m.get("ai_accept_sell_above", 0.95))
	return offer.price <= market * float(m.get("ai_accept_buy_below", 1.10))


static func daily_update(state: GameState, _defs: Dictionary) -> void:
	for id in state.offers.keys():
		if state.hours - state.offers[id].created_hours > OFFER_DAYS * 24:
			state.offers.erase(id)
