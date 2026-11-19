class_name AddProductionLineCommand
extends Command
## Abre uma linha de produção de um equipamento já pesquisado.

var equipment: String
var factories: int


static func create(tag: String, p_equipment: String, p_factories: int) -> AddProductionLineCommand:
	var c := AddProductionLineCommand.new()
	c.country_tag = tag
	c.equipment = p_equipment
	c.factories = p_factories
	return c


func type_name() -> String:
	return "add_production_line"


func validate(state: GameState, defs: Dictionary) -> String:
	var c := state.country(country_tag)
	if c == null:
		return "país desconhecido"
	if ProductionSystem.equipment_def(defs, equipment).is_empty():
		return "equipamento desconhecido"
	if not ResearchSystem.can_produce(defs, c, equipment):
		return "o equipamento ainda não foi pesquisado"
	if factories < 1 or factories > int(ProductionSystem.rules(defs).get("max_factories_per_line", 15)):
		return "número de fábricas inválido"
	return ""


func apply(state: GameState, defs: Dictionary) -> void:
	ProductionSystem.new_line(state.country(country_tag), defs, equipment, factories)


func _fields() -> Dictionary:
	return {"equipment": equipment, "factories": factories}


func _load_fields(d: Dictionary) -> void:
	equipment = d.equipment
	factories = int(d.factories)
