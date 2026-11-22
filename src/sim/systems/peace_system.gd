class_name PeaceSystem
extends RefCounted
## Paz entre dois países em guerra (paz separada: os aliados de cada um continuam como estão).
## Quem propõe pode pedir dinheiro, estados (território) e recursos do inimigo, ou nada (paz branca).
## A IA decide na hora comparando o andamento da guerra com o preço dos termos; um jogador responde
## com RespondPeaceCommand. Aceita a paz: termos pagos (até o que o país tem), guerra encerrada,
## ocupações entre os dois desfeitas e as tropas voltam para dentro das próprias fronteiras.
## Regras (valores de jogo) em `peace` de data/common/diplomacy.json.


static func rules(defs: Dictionary) -> Dictionary:
	return defs.get("diplomacy", {}).get("peace", {})


static func pending(state: GameState, from: String, to: String) -> Dictionary:
	for o in state.peace_offers.values():
		if o.from == from and o.to == to:
			return o
	return {}


## Fração dos estados de `b` controlados pelo lado de `a` (a e aliados).
static func occupied_share(state: GameState, a: String, b: String) -> float:
	var taken := 0
	for t in DiplomacySystem.side_of(state, a):
		if t == b:
			continue
		for s: MapState in state.states_of(t):
			if s.owner == b:
				taken += 1
	return float(taken) / maxf(state.owned_count(b), 1.0)


## Força total das tropas do país (para comparar exércitos).
static var _power_cache := {}
static var _power_stamp := -1
static var _power_state: GameState = null


static func army_power(state: GameState, defs: Dictionary, tag: String) -> float:
	if _power_stamp != state.hours or _power_state != state:
		_power_cache = {}
		_power_stamp = state.hours
		_power_state = state
	if _power_cache.has(tag):
		return _power_cache[tag]
	var cr := CombatSystem.rules(defs)
	var p := 0.0
	for g: ArmyGroup in state.groups_of(tag):
		for r in g.troops:
			p += CombatSystem.troop_power(defs, r, 0.2, cr.get("soft_weights", {}), cr.get("hard_weights", {}))
	_power_cache[tag] = p
	return p


## Andamento da guerra do ponto de vista de `a` contra `b` (positivo = `a` vai bem; de -1,5 a 1,5).
static func war_score(state: GameState, defs: Dictionary, a: String, b: String) -> float:
	var r := rules(defs)
	var score := occupied_share(state, a, b) - occupied_share(state, b, a)
	var pa := army_power(state, defs, a)
	var pb := army_power(state, defs, b)
	if pa + pb > 0.0:
		score += float(r.get("army_weight", 0.6)) * (pa / (pa + pb) - 0.5)
	var cap_b := state.state(state.country(b).capital_state)
	var cap_a := state.state(state.country(a).capital_state)
	var cw := float(r.get("capital_weight", 0.25))
	if cap_b != null and cap_b.control() != b:
		score += cw
	if cap_a != null and cap_a.control() != a:
		score -= cw
	return score


## Meses de guerra entre os dois.
static func war_months(state: GameState, a: String, b: String) -> float:
	return float(state.hours - int(state.war_started.get(GameState.pair_key(a, b), state.hours))) / (24.0 * 30.0)


## Quanto os termos pesam para quem vai pagar (0 = paz branca).
static func terms_cost(state: GameState, defs: Dictionary, o: Dictionary) -> float:
	var r := rules(defs)
	var them := state.country(o.to)
	var cost := 0.0
	cost += float(r.get("state_weight", 1.5)) * float(o.states.size()) / maxf(state.owned_count(o.to), 1.0)
	cost += float(r.get("money_weight", 0.4)) * float(o.money) / maxf(them.money + 500.0, 1.0)
	for res in o.resources:
		cost += float(r.get("resource_weight", 0.15)) * float(o.resources[res]) / maxf(them.stock(res) + 50.0, 1.0)
	return cost


## A IA de `o.to` aceita? Aceita quando o inimigo vai bem o bastante para valer o preço; o cansaço
## de guerra ajuda, e quem não controla mais nada aceita qualquer coisa.
static func ai_accepts(state: GameState, defs: Dictionary, o: Dictionary) -> bool:
	if state.states_of(o.to).is_empty():
		return true
	var r := rules(defs)
	var tired := minf(float(r.get("tired_max", 0.3)), war_months(state, o.from, o.to) * float(r.get("tired_per_month", 0.01)))
	return war_score(state, defs, o.from, o.to) + tired >= terms_cost(state, defs, o) - float(r.get("white_margin", 0.05))


## O que impede a proposta ("" = pode).
static func can_propose(state: GameState, defs: Dictionary, from: String, to: String, money: float, states: Array, resources: Dictionary) -> String:
	if state.country(from) == null or state.country(to) == null:
		return "país desconhecido"
	if not state.at_war(from, to):
		return "não estamos em guerra com %s" % state.country(to).name
	if not pending(state, from, to).is_empty():
		return "já há uma proposta nossa esperando resposta"
	if money < 0.0:
		return "valor inválido"
	for sid in states:
		var s := state.state(int(sid))
		if s == null or s.owner != to:
			return "só dá para pedir estados de %s" % state.country(to).name
	for res in resources:
		if not res in defs.get("resource_ids", []) or float(resources[res]) < 0.0:
			return "recurso inválido"
	return ""


static func propose(state: GameState, defs: Dictionary, from: String, to: String, money: float, states: Array, resources: Dictionary) -> Dictionary:
	var o := {"id": state.next_peace_id, "from": from, "to": to, "money": money, "states": states.map(func(x): return int(x)),
		"resources": resources.duplicate(), "hours": state.hours}
	state.next_peace_id += 1
	state.peace_last["%s|%s" % [from, to]] = state.hours
	state.peace_offers[o.id] = o
	if to in state.human_tags:
		state.add_event([to], "%s propõe paz: %s." % [state.country(from).name, describe(state, defs, o)], "Diplomacia")
		state.add_event([from], "Proposta de paz enviada a %s; aguardando resposta." % state.country(to).name, "Diplomacia")
	elif ai_accepts(state, defs, o):
		accept(state, defs, o)
	else:
		reject(state, o)
	return o


## Termos em texto ("paz sem exigências" ou "500 de dinheiro, 2 estados, 30 de petróleo").
static func describe(state: GameState, defs: Dictionary, o: Dictionary) -> String:
	var parts := []
	if float(o.money) > 0.0:
		parts.append("%d de dinheiro" % roundi(o.money))
	if not o.states.is_empty():
		var names: Array = o.states.map(func(i): return state.state(i).name)
		parts.append(("o estado de %s" % names[0]) if names.size() == 1 else ("%d estados (%s)" % [names.size(), ", ".join(names.slice(0, 4))]))
	for res in o.resources:
		if float(o.resources[res]) > 0.0:
			var rd: Dictionary = {}
			for x in defs.get("resources", []):
				if x.id == res:
					rd = x
			parts.append("%d de %s" % [roundi(o.resources[res]), str(rd.get("name", res)).to_lower()])
	return "paz sem exigências" if parts.is_empty() else ", ".join(parts)


static func reject(state: GameState, o: Dictionary) -> void:
	state.peace_offers.erase(o.id)
	state.add_event([o.from, o.to], "%s recusou a proposta de paz %s." % [state.country(o.to).name, NewsText.of(state.country(o.from).name)], "Diplomacia")


## Paz assinada: paga os termos, encerra a guerra e desfaz as ocupações entre os dois.
static func accept(state: GameState, defs: Dictionary, o: Dictionary) -> void:
	state.peace_offers.erase(o.id)
	var a: String = o.from
	var b: String = o.to
	var ca := state.country(a)
	var cb := state.country(b)
	var terms := describe(state, defs, o)
	# dinheiro e recursos (até o que há)
	var money := minf(float(o.money), maxf(cb.money, 0.0))
	cb.money -= money
	ca.money += money
	for res in o.resources:
		var q := minf(float(o.resources[res]), cb.stock(res))
		cb.stockpile[res] = cb.stock(res) - q
		ca.stockpile[res] = ca.stock(res) + q
	# território
	for sid in o.states:
		var s := state.state(int(sid))
		if s != null and s.owner == b:
			s.owner = a
			if s.controller == a or s.controller == b:
				s.controller = ""
	# fim da guerra entre os dois
	state.wars = state.wars.filter(func(w): return not (a in w and b in w))
	state.war_started.erase(GameState.pair_key(a, b))
	state.justifications = state.justifications.filter(func(j): return not ((j.owner == a and j.target == b) or (j.owner == b and j.target == a)))
	for x in state.peace_offers.values().duplicate():
		if (x.from == a and x.to == b) or (x.from == b and x.to == a):
			state.peace_offers.erase(x.id)
	# ocupações entre os dois voltam ao dono
	for s: MapState in state.states.values():
		if (s.owner == b and s.controller == a) or (s.owner == a and s.controller == b):
			s.controller = ""
	state.control_version += 1
	state.invalidate_owners()
	# tropas em território que não podem mais ocupar voltam para casa; marchas bloqueadas param
	for g: ArmyGroup in state.groups.values():
		if g.owner != a and g.owner != b:
			continue
		var here := state.state(g.state_id)
		if not state.can_enter(g.owner, here.control()):
			g.path = []
			g.progress_km = 0.0
			var home := ArmySystem.home_state(state, g.owner)
			if home == -1:
				state.groups.erase(g.id)
				continue
			g.state_id = home
		for sid in g.path:
			if not state.can_enter(g.owner, state.state(sid).owner):
				g.path = []
				g.progress_km = 0.0
				break
	state.add_event([a, b], "Paz assinada entre %s e %s: %s." % [ca.name, cb.name, terms], "Diplomacia")
	state.add_news("%s e %s assinam a paz" % [NewsText.the(ca.name, true), NewsText.the(cb.name)],
		"Termos: %s." % terms,
		"Os canhões silenciaram na fronteira entre %s e %s. Pelo acordo, %s entrega %s. As tropas começam a voltar para casa." % [
			NewsText.the(ca.name), NewsText.the(cb.name), NewsText.the(cb.name), terms if terms != "paz sem exigências" else "nada: foi uma paz sem exigências"],
		cb.capital_state, [a, b], "Diplomacia")


## Propostas a jogadores que ficam sem resposta expiram.
static func daily_update(state: GameState, defs: Dictionary) -> void:
	var days := int(rules(defs).get("offer_days", 30))
	for o in state.peace_offers.values().duplicate():
		if state.hours - int(o.hours) >= days * 24:
			state.peace_offers.erase(o.id)
			state.add_event([o.from, o.to], "A proposta de paz %s expirou sem resposta." % NewsText.of(state.country(o.from).name), "Diplomacia")
