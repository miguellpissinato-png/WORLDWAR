class_name UpgradeIntelligenceCommand
extends Command
## Investe dinheiro para subir um nível de espionagem ("offense") ou contraespionagem ("defense").

var branch: String


static func create(tag: String, p_branch: String) -> UpgradeIntelligenceCommand:
	var c := UpgradeIntelligenceCommand.new()
	c.country_tag = tag
	c.branch = p_branch
	return c


func type_name() -> String:
	return "upgrade_intelligence"


func _level(c: Country) -> int:
	return c.intel_offense if branch == "offense" else c.intel_defense


func validate(state: GameState, defs: Dictionary) -> String:
	var me := state.country(country_tag)
	if me == null:
		return "país desconhecido"
	if not branch in ["offense", "defense"]:
		return "ramo inválido"
	if _level(me) >= int(defs.get("intelligence", {}).get("max_level", 5)):
		return "nível máximo atingido"
	if me.money < IntelligenceSystem.upgrade_cost(defs, _level(me)):
		return "dinheiro insuficiente"
	return ""


func apply(state: GameState, defs: Dictionary) -> void:
	var me := state.country(country_tag)
	me.money -= IntelligenceSystem.upgrade_cost(defs, _level(me))
	if branch == "offense":
		me.intel_offense += 1
	else:
		me.intel_defense += 1


func _fields() -> Dictionary:
	return {"branch": branch}


func _load_fields(d: Dictionary) -> void:
	branch = d.branch
