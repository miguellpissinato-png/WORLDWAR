class_name StartInvestigationCommand
extends Command
## Manda a agência de inteligência investigar outro país (custa dinheiro e leva dias).

var target: String
## Resultado depois de aplicado (não serializado): "iniciada" ou "barrada".
var result: String = ""


static func create(tag: String, p_target: String) -> StartInvestigationCommand:
	var c := StartInvestigationCommand.new()
	c.country_tag = tag
	c.target = p_target
	return c


func type_name() -> String:
	return "start_investigation"


func validate(state: GameState, defs: Dictionary) -> String:
	var me := state.country(country_tag)
	if me == null or state.country(target) == null:
		return "país desconhecido"
	if target == country_tag:
		return "não dá para investigar o próprio país"
	for op in state.operations.values():
		if op.owner == country_tag and op.target == target:
			return "já existe uma investigação em andamento nesse país"
	if me.money < float(IntelligenceSystem.rules(defs).get("cost", 400)):
		return "dinheiro insuficiente"
	return ""


func apply(state: GameState, defs: Dictionary) -> void:
	var me := state.country(country_tag)
	me.money -= float(IntelligenceSystem.rules(defs).get("cost", 400))
	var op := IntelOperation.new()
	op.id = state.next_operation_id
	state.next_operation_id += 1
	op.owner = country_tag
	op.target = target
	op.days_total = IntelligenceSystem.investigation_days(defs, me.intel_offense)
	if IntelligenceSystem.try_infiltrate(state, defs, op):
		state.operations[op.id] = op
		result = "iniciada"
	else:
		result = "barrada"


func _fields() -> Dictionary:
	return {"target": target}


func _load_fields(d: Dictionary) -> void:
	target = d.target
