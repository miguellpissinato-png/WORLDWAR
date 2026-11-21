class_name DiplomacySystem
extends RefCounted
## Guerra: para entrar em outro país é preciso estar em guerra com ele. Primeiro se justifica a
## guerra (leva dias e custa dinheiro); quando a justificativa fica pronta, o país ainda precisa
## declarar a guerra de fato. Regras em data/common/diplomacy.json.


static func rules(defs: Dictionary) -> Dictionary:
	return defs.get("diplomacy", {})


static func justify_days(defs: Dictionary) -> int:
	return int(rules(defs).get("justify_days", 30))


static func justify_cost(defs: Dictionary) -> float:
	return float(rules(defs).get("justify_cost", 300))


## Motivo para não poder justificar guerra ("" = pode).
static func can_justify(state: GameState, defs: Dictionary, tag: String, target: String) -> String:
	var me := state.country(tag)
	var them := state.country(target)
	if me == null or them == null:
		return "país desconhecido"
	if tag == target:
		return "não dá para justificar guerra contra o próprio país"
	if state.allied(tag, target):
		return "%s é aliado" % them.name
	if state.at_war(tag, target):
		return "já estamos em guerra com %s" % them.name
	if not state.justification(tag, target).is_empty():
		return "a justificativa contra %s já existe" % them.name
	if me.money < justify_cost(defs):
		return "dinheiro insuficiente"
	return ""


static func can_declare(state: GameState, tag: String, target: String) -> String:
	var them := state.country(target)
	if them == null or state.country(tag) == null:
		return "país desconhecido"
	if state.at_war(tag, target):
		return "já estamos em guerra com %s" % them.name
	var j := state.justification(tag, target)
	if j.is_empty():
		return "é preciso justificar a guerra contra %s antes" % them.name
	if not j.done:
		return "a justificativa contra %s ainda não terminou (faltam %d dias)" % [them.name, days_left(j)]
	return ""


static func days_left(j: Dictionary) -> int:
	return maxi(0, int(j.days_needed) - int(j.days_done))


static func justify(state: GameState, defs: Dictionary, tag: String, target: String) -> void:
	var me := state.country(tag)
	var them := state.country(target)
	me.money -= justify_cost(defs)
	var days := justify_days(defs)
	state.justifications.append({"owner": tag, "target": target, "days_done": 0, "days_needed": days, "done": false})
	state.add_event([tag], "Começamos a justificar uma guerra contra %s (%d dias)." % [them.name, days], "Diplomacia")
	state.add_event([target], "%s começou a justificar uma guerra contra nós." % me.name, "Diplomacia")


static func declare(state: GameState, tag: String, target: String) -> void:
	var me := state.country(tag)
	var them := state.country(target)
	start_war(state, tag, target)
	state.justifications = state.justifications.filter(func(j): return not (j.owner == tag and j.target == target))
	state.add_event([tag, target], "%s declarou guerra a %s." % [me.name, them.name], "Guerra")
	var cap := state.state(them.capital_state)
	state.add_news("%s declara guerra %s" % [NewsText.the(me.name, true), NewsText.to(them.name)],
		"Tropas %s cruzam a fronteira; o mundo acompanha apreensivo." % NewsText.of(me.name),
		"Em comunicado oficial, o governo %s anunciou o estado de guerra contra %s. %s" % [
			NewsText.of(me.name), NewsText.the(them.name), _sides_text(state, tag, target)],
		them.capital_state if cap != null else -1, [tag, target], "Guerra")
	# Alianças: os membros das duas facções entram na guerra.
	for a in side_of(state, tag):
		for b in side_of(state, target):
			if a != b and not state.at_war(a, b) and not state.allied(a, b):
				start_war(state, a, b)
				state.add_event([a, b], "%s entrou na guerra contra %s (aliança)." % [state.country(a).name, state.country(b).name], "Guerra")


## O país e os membros da facção dele.
static func side_of(state: GameState, tag: String) -> Array:
	var f := state.faction_of(tag)
	return [tag] if f == "" else state.factions[f].members.duplicate()


static func start_war(state: GameState, a: String, b: String) -> void:
	var pair := [a, b]
	pair.sort()
	if not pair in state.wars:
		state.wars.append(pair)


static func _sides_text(state: GameState, tag: String, target: String) -> String:
	var out := []
	for t in [tag, target]:
		var f := state.faction_of(t)
		if f != "":
			out.append("%s, %s, conta com seus aliados." % [NewsText.the(state.country(t).name, true), NewsText.of(state.factions[f].name)])
	return " ".join(out)


static func daily_update(state: GameState, _defs: Dictionary) -> void:
	for j in state.justifications:
		if j.done:
			continue
		j.days_done = int(j.days_done) + 1
		if int(j.days_done) >= int(j.days_needed):
			j.done = true
			var them := state.country(j.target)
			state.add_event([j.owner], "Justificativa de guerra contra %s concluída. Agora é possível declarar a guerra." % them.name, "Diplomacia")
