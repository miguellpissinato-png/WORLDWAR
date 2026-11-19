class_name DonateResourcesCommand
extends Command
## Doa recursos do estoque para outro país (ex.: um aliado).

var to: String
var resource: String
var amount: int


static func create(tag: String, p_to: String, p_resource: String, p_amount: int) -> DonateResourcesCommand:
	var c := DonateResourcesCommand.new()
	c.country_tag = tag
	c.to = p_to
	c.resource = p_resource
	c.amount = p_amount
	return c


func type_name() -> String:
	return "donate_resources"


func validate(state: GameState, defs: Dictionary) -> String:
	var me := state.country(country_tag)
	if me == null or state.country(to) == null:
		return "país desconhecido"
	if to == country_tag:
		return "não dá para doar para si mesmo"
	if not resource in defs.get("resource_ids", []):
		return "recurso desconhecido"
	if amount <= 0:
		return "quantidade inválida"
	if me.stock(resource) < amount:
		return "estoque insuficiente"
	return ""


func apply(state: GameState, _defs: Dictionary) -> void:
	var me := state.country(country_tag)
	var other := state.country(to)
	me.stockpile[resource] = me.stock(resource) - amount
	other.stockpile[resource] = other.stock(resource) + amount


func _fields() -> Dictionary:
	return {"to": to, "resource": resource, "amount": amount}


func _load_fields(d: Dictionary) -> void:
	to = d.to
	resource = d.resource
	amount = int(d.amount)
