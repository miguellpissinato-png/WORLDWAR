class_name SetCivilShareCommand
extends Command
## Escolhe a fração (0..1) das fábricas em uso civil; o resto vai para o uso militar.

var share: float


static func create(tag: String, p_share: float) -> SetCivilShareCommand:
	var c := SetCivilShareCommand.new()
	c.country_tag = tag
	c.share = p_share
	return c


func type_name() -> String:
	return "set_civil_share"


func validate(state: GameState, _defs: Dictionary) -> String:
	if state.country(country_tag) == null:
		return "país desconhecido"
	if share < 0.0 or share > 1.0:
		return "percentual inválido"
	return ""


func apply(state: GameState, _defs: Dictionary) -> void:
	state.country(country_tag).civil_share_target = share


func _fields() -> Dictionary:
	return {"share": share}


func _load_fields(d: Dictionary) -> void:
	share = float(d.share)
