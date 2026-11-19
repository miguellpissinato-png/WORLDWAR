class_name TradeContract
extends RefCounted
## Contrato de comércio: o comprador recebe `amount` unidades/dia de um recurso e paga cedendo
## `factories` fábricas civis ao vendedor (o vendedor pode usá-las para construir).

var id: int
var buyer: String
var seller: String
var resource: String
var amount: int
var factories: int


func to_dict() -> Dictionary:
	return {"id": id, "buyer": buyer, "seller": seller, "resource": resource,
		"amount": amount, "factories": factories}
