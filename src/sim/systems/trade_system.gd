class_name TradeSystem
extends RefCounted
## Regras do comércio e verificação diária dos contratos.
## Um contrato é cancelado automaticamente quando deixa de ser possível:
## o vendedor não produz mais o suficiente (ex.: perdeu o estado produtor) ou
## o comprador não tem mais fábricas civis para pagar.


## Fábricas civis necessárias para pagar `amount` unidades/dia.
static func cost_in_factories(amount: int, defs: Dictionary) -> int:
	var per := int(defs.get("trade", {}).get("units_per_factory", 5))
	return int(ceil(float(amount) / float(per)))


static func max_export_share(defs: Dictionary) -> float:
	return float(defs.get("trade", {}).get("max_export_share", 0.75))


static func daily_update(state: GameState, defs: Dictionary) -> void:
	var share := max_export_share(defs)
	# Do mais novo para o mais antigo: os contratos antigos têm prioridade.
	var ids: Array = state.trades.keys()
	ids.sort()
	ids.reverse()
	for id in ids:
		var t: TradeContract = state.trades[id]
		var seller_limit := int(floor(state.resource_production(t.seller, t.resource) * share))
		if state.resource_exports(t.seller, t.resource) > seller_limit \
				or state.available_civilian_factories(t.buyer) < 0 \
				or state.country(t.buyer) == null or state.country(t.seller) == null:
			state.trades.erase(id)
