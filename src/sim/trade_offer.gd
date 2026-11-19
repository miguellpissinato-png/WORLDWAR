class_name TradeOffer
extends RefCounted
## Proposta de negócio entre dois países, aguardando resposta de `to`.
## kind "sell": `from` vende para `to`. kind "buy": `from` quer comprar de `to`.
## É um lote único: `amount` unidades do estoque, a `price` por unidade.

var id: int
var from: String
var to: String
var kind: String          # "sell" ou "buy"
var resource: String
var amount: int
var price: float          # por unidade
var created_hours: int


func seller() -> String:
	return from if kind == "sell" else to


func buyer() -> String:
	return to if kind == "sell" else from


func total() -> float:
	return amount * price
