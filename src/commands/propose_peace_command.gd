class_name ProposePeaceCommand
extends Command
## Proposta de paz a um inimigo, pedindo dinheiro, estados e recursos (ou nada).

var target: String
var money: float = 0.0
var states: Array = []
var resources: Dictionary = {}


static func create(tag: String, p_target: String, p_money: float = 0.0, p_states: Array = [], p_resources: Dictionary = {}) -> ProposePeaceCommand:
	var c := ProposePeaceCommand.new()
	c.country_tag = tag
	c.target = p_target
	c.money = p_money
	c.states = p_states
	c.resources = p_resources
	return c


func type_name() -> String:
	return "propose_peace"


func validate(state: GameState, defs: Dictionary) -> String:
	return PeaceSystem.can_propose(state, defs, country_tag, target, money, states, resources)


func apply(state: GameState, defs: Dictionary) -> void:
	PeaceSystem.propose(state, defs, country_tag, target, money, states, resources)


func _fields() -> Dictionary:
	return {"target": target, "money": money, "states": states, "resources": resources}


func _load_fields(d: Dictionary) -> void:
	target = d.target
	money = float(d.get("money", 0.0))
	states = d.get("states", []).map(func(x): return int(x))
	resources = d.get("resources", {})
