class_name SetLineFactoriesCommand
extends Command
## Muda quantas fábricas militares uma linha de produção pede.

var line_id: int
var factories: int


static func create(tag: String, p_line_id: int, p_factories: int) -> SetLineFactoriesCommand:
	var c := SetLineFactoriesCommand.new()
	c.country_tag = tag
	c.line_id = p_line_id
	c.factories = p_factories
	return c


func type_name() -> String:
	return "set_line_factories"


func validate(state: GameState, defs: Dictionary) -> String:
	var c := state.country(country_tag)
	if c == null:
		return "país desconhecido"
	if ProductionSystem.line(c, line_id).is_empty():
		return "linha de produção desconhecida"
	if factories < 0 or factories > int(ProductionSystem.rules(defs).get("max_factories_per_line", 15)):
		return "número de fábricas inválido"
	return ""


func apply(state: GameState, _defs: Dictionary) -> void:
	ProductionSystem.line(state.country(country_tag), line_id).factories = factories


func _fields() -> Dictionary:
	return {"line_id": line_id, "factories": factories}


func _load_fields(d: Dictionary) -> void:
	line_id = int(d.line_id)
	factories = int(d.factories)
