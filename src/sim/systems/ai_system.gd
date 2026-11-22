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
	_army(state, defs, tag, cmds)
	_trade(state, defs, tag, cmds)
	_diplomacy(state, defs, tag, cmds)
	_operations(state, defs, tag, cmds)
	if turn % 3 == 0:
		_peace(state, defs, tag, cmds)   # paz: a cada 3 rodadas basta
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


# ---------------------------------------------------------------- exército

## Encomenda tropas para manter as fábricas militares ocupadas (`queue_days` de trabalho na fila),
## escolhendo o tipo mais abaixo da proporção desejada (`mix`, pelo espaço que ocupam).
static func _army(state: GameState, defs: Dictionary, tag: String, cmds: Array) -> void:
	var r: Dictionary = rules(defs).get("army", {})
	var c := state.country(tag)
	var mil := state.military_factories(tag)
	if mil > 0:
		var queued := 0.0
		for item in c.recruit_queue:
			queued += float(item.work) - float(item.work_done)
		var room := mil * float(r.get("queue_days", 10)) - queued
		var mix: Dictionary = r.get("mix", {"infantaria": 1.0})
		var have := {}
		var total := 0.0
		for g in state.groups_of(tag):
			for t in g.troops:
				var sz := float(t.count) * float(ArmySystem.troop_def(defs, t.type).get("size", 1))
				have[t.type] = float(have.get(t.type, 0.0)) + sz
				total += sz
		for item in c.recruit_queue:
			var sz := float(item.count) * float(ArmySystem.troop_def(defs, item.type).get("size", 1))
			have[item.type] = float(have.get(item.type, 0.0)) + sz
			total += sz
		for _i in 4:
			if room <= 0.0:
				break
			var pick := ""
			var gap := -INF
			for type in mix:
				if ArmySystem.can_recruit(state, defs, tag, type, 1) != "":
					continue
				var g := float(mix[type]) - float(have.get(type, 0.0)) / maxf(total, 1.0)
				if g > gap:
					gap = g
					pick = type
			if pick == "":
				break
			var cost := ArmySystem.batch_cost(defs, pick, ArmySystem.best_model(defs, c, pick), 1)
			var n := clampi(int(room / maxf(cost.work, 0.01)), 1, int(ArmySystem.recruit_rules(defs).get("max_batches_per_click", 10)))
			cmds.append(RecruitTroopsCommand.create(tag, pick, n))
			room -= cost.work * n
			var sz := float(cost.count * n) * float(ArmySystem.troop_def(defs, pick).get("size", 1))
			have[pick] = float(have.get(pick, 0.0)) + sz
			total += sz
	# generais para as pilhas maiores
	var groups := state.groups_of(tag)
	groups.sort_custom(func(a, b): return ArmySystem.stack_size(defs, a) > ArmySystem.stack_size(defs, b))
	var free_gens := state.generals_of(tag).filter(func(gn): return ArmySystem.groups_of_general(state, gn.id).is_empty())
	for g in groups.slice(0, int(r.get("generals_for", 4))):
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


static func _diplomacy(state: GameState, defs: Dictionary, tag: String, cmds: Array) -> void:
	var ym := _ym(state)
	for p in _plans(defs, tag):
		var target: String = p.target
		if state.country(target) == null or ym < String(p.from) or state.at_war(tag, target) or state.allied(tag, target):
			continue
		if "%s|%s" % [tag, target] in state.declared:
			continue   # plano já cumprido (depois de uma paz, não volta a atacar sozinho)
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
	var war: Dictionary = rules(defs).get("war", {})
	var min_size := float(war.get("min_attack_size", 60))
	var attackers := state.groups_of(tag).filter(func(g): return not g.moving() and not g.empty() \
		and not state.battles.has(g.state_id) and ArmySystem.stack_size(defs, g) >= min_size)
	if attackers.is_empty():
		return
	# alvo de cada pilha: o estado inimigo mais perto, procurando pelos vizinhos (por onde dá para passar)
	# até `max_front_km` de distância
	var taken := {}
	var max_km := float(war.get("max_front_km", 1500))
	var orders := 0
	attackers.sort_custom(func(a, b): return ArmySystem.stack_size(defs, a) > ArmySystem.stack_size(defs, b))
	for g in attackers:
		if orders >= int(war.get("max_orders", 4)):
			break
		var best := _nearest_enemy_state(state, tag, enemies, g.state_id, max_km, taken)
		if best == null:
			continue   # nenhuma frente por perto (outro continente): fica de guarda
		orders += 1
		taken[best.id] = true
		# manda a maior parte e deixa uma guarnição
		var share := float(war.get("attack_share", 0.8))
		var counts := {}
		for type in g.types():
			counts[type] = floorf(g.count_of(type) * share)
		var cmd := MoveGroupCommand.create(tag, g.id, best.id, counts)
		if cmd.validate(state, defs) == "":
			cmds.append(cmd)


## Estado controlado por um inimigo mais perto de `start`, andando por estados em que podemos entrar.
## Um alvo já escolhido nesta rodada conta 50% mais longe (espalha as pilhas pela frente).
static func _nearest_enemy_state(state: GameState, tag: String, enemies: Array, start: int, max_km: float, taken: Dictionary) -> MapState:
	var origin := state.state(start).center
	var seen := {start: true}
	var ring := [start]
	var best: MapState = null
	var best_km := INF
	var visited := 0
	while not ring.is_empty() and visited < 600:
		var nxt := []
		for sid in ring:
			for n in state.adjacency.get(sid, []):
				if seen.has(n):
					continue
				seen[n] = true
				var s := state.state(n)
				if s == null:
					continue
				var km := MapGeo.km(origin, s.center)
				if km > max_km:
					continue
				visited += 1
				var ctl := s.control()
				if ctl in enemies:
					var score := km * (1.5 if taken.has(n) else 1.0)
					if score < best_km:
						best_km = score
						best = s
				elif state.can_enter(tag, ctl):
					nxt.append(n)
		ring = nxt
		if best != null and not ring.is_empty():
			# já achou: só mais um anel para ver se há algo mais perto
			for sid in ring:
				for n in state.adjacency.get(sid, []):
					if seen.has(n):
						continue
					var s2 := state.state(n)
					if s2 != null and s2.control() in enemies:
						var km2 := MapGeo.km(origin, s2.center) * (1.5 if taken.has(n) else 1.0)
						if km2 < best_km:
							best_km = km2
							best = s2
			break
	return best


# ---------------------------------------------------------------- paz

## Propõe paz: pede os estados ocupados quando a guerra vai bem; paz branca quando vai mal ou se arrasta.
static func _peace(state: GameState, defs: Dictionary, tag: String, cmds: Array) -> void:
	var pr := PeaceSystem.rules(defs)
	for e in state.enemies_of(tag):
		var last := int(state.peace_last.get("%s|%s" % [tag, e], -1000000))
		if state.hours - last < int(pr.get("ai_retry_days", 45)) * 24:
			continue
		if not PeaceSystem.pending(state, tag, e).is_empty():
			continue
		var months := PeaceSystem.war_months(state, tag, e)
		if months < float(pr.get("ai_min_months", 3)):
			continue
		var score := PeaceSystem.war_score(state, defs, tag, e)
		var take := []
		for s: MapState in state.states_of(tag):
			if s.owner == e:
				take.append(s.id)
		take.sort()
		var losing := PeaceSystem.occupied_share(state, e, tag) > 0.0 and score <= float(pr.get("ai_white_score", -0.3))
		if score >= float(pr.get("ai_demand_score", 0.25)) and not take.is_empty():
			cmds.append(ProposePeaceCommand.create(tag, e, 0.0, take.slice(0, int(pr.get("ai_max_states", 12))), {}))
		elif losing or (months >= float(pr.get("ai_white_after_months", 18)) and absf(score) < 0.15):
			cmds.append(ProposePeaceCommand.create(tag, e))
