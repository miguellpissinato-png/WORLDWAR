class_name ClaimCountryCommand
extends Command
## Um jogador assume o controle de um país (a IA deixa de decidir por ele).
## `release` é o país que o jogador deixa (troca de país no jogo solo), ou "".

var release: String = ""


static func create(tag: String, p_release: String = "") -> ClaimCountryCommand:
	var c := ClaimCountryCommand.new()
	c.country_tag = tag
	c.release = p_release
	return c


func type_name() -> String:
	return "claim_country"


func validate(state: GameState, _defs: Dictionary) -> String:
	if state.country(country_tag) == null:
		return "país desconhecido"
	return ""


func apply(state: GameState, _defs: Dictionary) -> void:
	state.human_tags.erase(release)
	if not country_tag in state.human_tags:
		state.human_tags.append(country_tag)


func _fields() -> Dictionary:
	return {"release": release}


func _load_fields(d: Dictionary) -> void:
	release = d.get("release", "")
