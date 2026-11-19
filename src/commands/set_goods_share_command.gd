class_name SetGoodsShareCommand
extends Command
## Define quanto (0..1) da extração de um recurso vira bens de consumo; o resto vai para o estoque.

var resource: String
var share: float


static func create(tag: String, p_resource: String, p_share: float) -> SetGoodsShareCommand:
	var c := SetGoodsShareCommand.new()
	c.country_tag = tag
	c.resource = p_resource
	c.share = p_share
	return c


func type_name() -> String:
	return "set_goods_share"


func validate(state: GameState, defs: Dictionary) -> String:
	if state.country(country_tag) == null:
		return "país desconhecido"
	if not resource in defs.get("resource_ids", []):
		return "recurso desconhecido"
	if share < 0.0 or share > 1.0:
		return "percentual inválido"
	return ""


func apply(state: GameState, _defs: Dictionary) -> void:
	state.country(country_tag).goods_share[resource] = share


func _fields() -> Dictionary:
	return {"resource": resource, "share": share}


func _load_fields(d: Dictionary) -> void:
	resource = d.resource
	share = float(d.share)
