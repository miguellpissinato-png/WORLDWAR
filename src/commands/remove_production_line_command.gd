class_name RemoveProductionLineCommand
extends Command
## Fecha uma linha de produção (a unidade incompleta se perde).

var line_id: int


static func create(tag: String, p_line_id: int) -> RemoveProductionLineCommand:
	var c := RemoveProductionLineCommand.new()
	c.country_tag = tag
	c.line_id = p_line_id
	return c


func type_name() -> String:
	return "remove_production_line"


func validate(state: GameState, _defs: Dictionary) -> String:
	var c := state.country(country_tag)
	if c == null:
		return "país desconhecido"
	if ProductionSystem.line(c, line_id).is_empty():
		return "linha de produção desconhecida"
	return ""


func apply(state: GameState, _defs: Dictionary) -> void:
	var c := state.country(country_tag)
	c.production_lines.erase(ProductionSystem.line(c, line_id))


func _fields() -> Dictionary:
	return {"line_id": line_id}


func _load_fields(d: Dictionary) -> void:
	line_id = int(d.line_id)
