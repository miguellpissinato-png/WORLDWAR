class_name AiSystem
extends RefCounted
## Países controlados pelo computador. Cada país "pensa" a cada `think_every_days` dias (em dias
## diferentes, para espalhar o trabalho) e devolve comandos, como um jogador faria. A simulação
## aplica esses comandos na hora (Simulation._daily_update); como tudo depende só do estado, a IA é
## determinística e não precisa entrar no diário do jogo salvo.
## Regras e planos históricos em data/common/ai.json.


static func rules(defs: Dictionary) -> Dictionary:
	return defs.get("ai", {})


## Comandos da IA para hoje.
static func decide(state: GameState, defs: Dictionary) -> Array:
	var r := rules(defs)
	if r.is_empty():
		return []   # sem regras (ex.: mundo de teste): ninguém joga pela IA
	var every := maxi(1, int(r.get("think_every_days", 5)))
	var day := state.hours / 24
	var out := []
	var i := 0
	for tag in state.countries:
		i += 1
		if tag in state.human_tags or (day + i) % every != 0:
			continue
		if state.states_of(tag).is_empty():
			continue
		out.append_array(think(state, defs, tag, day / every))
	return out


static func think(state: GameState, defs: Dictionary, tag: String, turn: int) -> Array:
	var cmds := []
	_economy(state, defs, tag, turn, cmds)
	_research(state, defs, tag, cmds)
	_production(state, defs, tag, cmds)
	_army(state, defs, tag, cmds)
	_trade(state, defs, tag, cmds)
	_diplomacy(state, defs, tag, cmds)
	_operations(state, defs, tag, cmds)
	return cmds


# ---------------------------------------------------------------- economia

static func _economy(state: GameState, defs: Dictionary, tag: String, turn: int, cmds: Array) -> void:
	var r := rules(defs)
	var c := state.country(tag)
	var cs: Dictionary = r.get("civil_share", {})
	var target := float(cs.get("peace", 0.7))
	if not state.enemies_of(tag).is_empty():
		target = float(cs.get("war", 0.45))
	elif _has_plan_soon(state, defs, tag):
		target = float(cs.get("planning", 0.55))
	if absf(c.civil_share_target - target) > 0.01:
		cmds.append(SetCivilShareCommand.create(tag, target))
	var b: Dictionary = r.get("build", {})
	if c.construction_queue.size() >= int(b.get("max_queue", 2)):
		return
	var building := "factory"
	var every := int(b.get("extraction_every", 3))
	if every > 0 and turn % every == 0:
		var res := _wanted_resource(state, defs, c)
		if res != "":
			building = "extraction_" + res
	var cost := float(ConstructionSystem.definition(defs, building).get("money_cost", 0))
	if c.money < cost + float(b.get("keep_money", 150)):
		return
	var states := state.states_of(tag).filter(func(s): return s.owner == tag)
	states.sort_custom(func(a, b2): return a.population > b2.population if a.population != b2.population else a.id < b2.id)
	for s in states:
		var cmd := QueueConstructionCommand.create(tag, s.id, building)
		if cmd.validate(state, defs) == "":
			cmds.append(cmd)
			return


## Recurso que falta (falta na produção) ou que o país não tem; "" se nada.
static func _wanted_resource(state: GameState, defs: Dictionary, c: Country) -> String:
	for res in defs.resource_ids:
		if float(c.last_shortage.get(res, 0.0)) > 0.0:
			return res
	return ""


# ---------------------------------------------------------------- pesquisa

static func _research(state: GameState, defs: Dictionary, tag: String, cmds: Array) -> void:
	var c := state.country(tag)
	var free := c.research_slots - c.research.size()
	if free <= 0:
		return
	var options := []
	for id in defs.research.techs:
		if ResearchSystem.can_start(state, defs, tag, id) == "":
			options.append(id)
	options.sort_custom(func(a, b):
		var ta: Dictionary = defs.research.techs[a]
		var tb: Dictionary = defs.research.techs[b]
		var fa := 1 if ResearchSystem.is_foreign(ta, tag) else 0
		var fb := 1 if ResearchSystem.is_foreign(tb, tag) else 0
		if fa != fb:
			return fa < fb
		if int(ta.year) != int(tb.year):
			return int(ta.year) < int(tb.year)
		return a < b)
	for id in options.slice(0, free):
		cmds.append(StartResearchCommand.create(tag, id))
		break   # uma por vez: o dinheiro sai a cada pesquisa


# ---------------------------------------------------------------- produção militar

static func _production(state: GameState, defs: Dictionary, tag: String, cmds: Array) -> void:
	var c := state.country(tag)
	var mil := state.military_factories(tag)
	var used := 0
	for l in c.production_lines:
		used += int(l.factories)
	var free := mil - used
	if free < 1:
		return
	var unlocked := ResearchSystem.unlocked_equipment(defs, c)
	var made := c.production_lines.map(func(l): return l.equipment)
	# categoria com menos estoque no depósito, entre as que o exército usa
	var best_eq := ""
	var best_stock := INF
	for cat in ["rifle", "artillery", "tank"]:
		var eq := _best_of(defs, unlocked, cat)
		if eq == "" or eq in made:
			continue
		var stock := 0.0
		for e in c.equipment:
			if defs.equipment.get(e, {}).get("category", "") == cat:
				stock += float(c.equipment[e])
		if cat == "rifle":
			stock *= 0.5   # fuzis são a base de quase todo regimento
		if stock < best_stock:
			best_stock = stock
			best_eq = eq
	if best_eq == "":
		# tudo já tem linha: reforça a primeira
		if not c.production_lines.is_empty():
			var l: Dictionary = c.production_lines[0]
			cmds.append(SetLineFactoriesCommand.create(tag, int(l.id), int(l.factories) + free))
		return
	cmds.append(AddProductionLineCommand.create(tag, best_eq, mini(free, int(rules(defs).get("army", {}).get("line_factories", 6)))))


static func _best_of(defs: Dictionary, unlocked: Array, cat: String) -> String:
	var best := ""
	var year := -1
	for eq in unlocked:
		var d: Dictionary = defs.equipment.get(eq, {})
		if d.get("category", "") == cat and int(d.get("year", 0)) > year:
			year = int(d.get("year", 0))
			best = eq
	return best


# ---------------------------------------------------------------- exército

static func _army(state: GameState, defs: Dictionary, tag: String, cmds: Array) -> void:
	var r: Dictionary = rules(defs).get("army", {})
	var c := state.country(tag)
	var groups := state.groups_of(tag)
	var want := mini(int(r.get("max_groups", 24)), int(r.get("base_groups", 1)) + state.military_factories(tag) / maxi(1, int(r.get("factories_per_group", 4))))
	var max_regs := int(ArmySystem.army(defs).get("max_regiments_per_group", 4))
	var home := ArmySystem.home_state(state, tag)
	var planned := {}   # grupo -> regimentos pedidos agora
	var new_groups := 0
	for i in int(r.get("regiments_per_think", 3)):
		for type in r.get("types", ["infantaria"]):
			var target := -1
			for g in groups:
				if g.regiments.size() + int(planned.get(g.id, 0)) < max_regs and g.state_id == home and not g.moving():
					target = g.id
					break
			if target == -1 and (groups.size() + new_groups >= want or new_groups > 0):
				continue
			var cmd := FormRegimentCommand.create(tag, type, target)
			if cmd.validate(state, defs) == "":
				cmds.append(cmd)
				if target == -1:
					new_groups += 1
				else:
					planned[target] = int(planned.get(target, 0)) + 1
				break
	# generais
	var free_gens := state.generals_of(tag).filter(func(gn): return ArmySystem.groups_of_general(state, gn.id).is_empty())
	for g in groups:
		if g.general_id == -1 or state.general(g.general_id) == null:
			if not free_gens.is_empty():
				cmds.append(AssignGeneralCommand.create(tag, g.id, free_gens.pop_front().id))
			elif c.money > 2.0 * float(ArmySystem.army(defs).get("generals", {}).get("recruit_cost", 500)):
				cmds.append(RecruitGeneralCommand.create(tag))
			return


# ---------------------------------------------------------------- comércio

## Vende o excesso de recursos para quem está com falta (o comprador da IA responde na hora;
## um jogador recebe a proposta e decide).
static func _trade(state: GameState, defs: Dictionary, tag: String, cmds: Array) -> void:
	var r: Dictionary = rules(defs).get("trade", {})
	var c := state.country(tag)
	var made := 0
	for res in defs.resource_ids:
		if made >= int(r.get("max_offers", 2)):
			return
		var stock := c.stock(res)
		if stock < float(r.get("sell_above", 120)):
			continue
		for other in state.countries:
			if other == tag or state.at_war(tag, other):
				continue
			var o := state.country(other)
			if float(o.last_shortage.get(res, 0.0)) <= 0.0:
				continue
			var amount := int(stock * float(r.get("sell_share", 0.25)))
			var price := snappedf(state.price(res), 0.01)
			if amount < 1 or o.money < amount * price:
				continue
			cmds.append(ProposeTradeCommand.create(tag, other, "sell", res, amount, price))
			made += 1
			break


# ---------------------------------------------------------------- diplomacia e guerra

static func _ym(state: GameState) -> String:
	var d := GameDate.from_hours(state.hours)
	return "%04d-%02d" % [d.year, d.month]


static func _plans(defs: Dictionary, tag: String) -> Array:
	return rules(defs).get("war_plans", []).filter(func(p): return p.tag == tag)


static func _has_plan_soon(state: GameState, defs: Dictionary, tag: String) -> bool:
	var d := GameDate.from_hours(state.hours)
	var soon := "%04d-%02d" % [d.year + (1 if d.month > 6 else 0), ((d.month + 5) % 12) + 1]
	for p in _plans(defs, tag):
		if String(p.from) <= soon and not state.at_war(tag, p.target):
			return true
	return false


static func _regiments(state: GameState, tag: String) -> int:
	var n := 0
	for g in state.groups_of(tag):
		n += g.regiments.size()
	return n


static func _diplomacy(state: GameState, defs: Dictionary, tag: String, cmds: Array) -> void:
	var ym := _ym(state)
	for p in _plans(defs, tag):
		var target: String = p.target
		if state.country(target) == null or ym < String(p.from) or state.at_war(tag, target) or state.allied(tag, target):
			continue
		if state.states_of(target).is_empty():
			continue
		if p.has("if_at_war") and not state.at_war(p.if_at_war[0], p.if_at_war[1]):
			continue
		var j := state.justification(tag, target)
		if j.is_empty():
			var cmd := JustifyWarCommand.create(tag, target)
			if cmd.validate(state, defs) == "":
				cmds.append(cmd)
			return
		if j.done:
			# Plano histórico: com a justificativa pronta, declara.
			cmds.append(DeclareWarCommand.create(tag, target))
			return


## Em guerra: manda os grupos parados atacar o estado inimigo mais perto da frente.
static func _operations(state: GameState, defs: Dictionary, tag: String, cmds: Array) -> void:
	var enemies := state.enemies_of(tag)
	if enemies.is_empty():
		return
	var groups := state.groups_of(tag).filter(func(g): return not g.moving() and not g.regiments.is_empty() and not state.battles.has(g.state_id))
	if groups.is_empty():
		return
	var keep := int(ceil(groups.size() * (1.0 - float(rules(defs).get("war", {}).get("attack_groups_share", 0.8)))))
	groups.sort_custom(func(a, b): return a.id < b.id)
	var attackers := groups.slice(keep)
	if attackers.is_empty():
		return
	# frente: estados controlados por inimigos vizinhos de estados nossos ou aliados
	var front := []
	for s: MapState in state.states.values():
		var ctl := s.control()
		if not ctl in enemies:
			continue
		for n in state.adjacency.get(s.id, []):
			var ns := state.state(n)
			if ns != null and state.can_enter(tag, ns.control()) and not ns.control() in enemies:
				front.append(s)
				break
	if front.is_empty():
		return
	var taken := {}
	for g in attackers:
		var here: Vector2 = state.state(g.state_id).center
		var best: MapState = null
		var best_km := INF
		for s: MapState in front:
			if taken.has(s.id):
				continue
			var km := here.distance_squared_to(s.center)
			if km < best_km:
				best_km = km
				best = s
		if best == null:
			best = front[0]
		taken[best.id] = true
		var cmd := MoveGroupCommand.create(tag, g.id, best.id)
		if cmd.validate(state, defs) == "":
			cmds.append(cmd)
