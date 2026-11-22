class_name CancelRecruitCommand
extends Command
## Tira um lote da fila (o trabalho e os recursos já gastos se perdem).

var item_id: int


static func create(tag: String, p_id: int) -> CancelRecruitCommand:
	var c := CancelRecruitCommand.new()
	c.country_tag = tag
	c.item_id = p_id
	return c


func type_name() -> String:
	return "cancel_recruit"


func validate(state: GameState, _defs: Dictionary) -> String:
	var c := state.country(country_tag)
	if c == null or not c.recruit_queue.any(func(i): return int(i.id) == item_id):
		return "lote desconhecido"
	return ""


func apply(state: GameState, _defs: Dictionary) -> void:
	var c := state.country(country_tag)
	for i in c.recruit_queue:
		if int(i.id) == item_id:
			c.recruit_queue.erase(i)
			return


func _fields() -> Dictionary:
	return {"item_id": item_id}


func _load_fields(d: Dictionary) -> void:
	item_id = int(d.item_id)
