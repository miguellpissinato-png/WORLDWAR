class_name ArmySystem
extends RefCounted
## Exército: tropas em pilhas por estado, encomenda de lotes (RecruitSystem), generais fictícios e caminhos.


static func army(defs: Dictionary) -> Dictionary:
	return defs.get("army", {})


static func troop_def(defs: Dictionary, type: String) -> Dictionary:
	return army(defs).get("troops", {}).get(type, {})


static func troop_types(defs: Dictionary) -> Array:
	return army(defs).get("troops", {}).keys()


static func recruit_rules(defs: Dictionary) -> Dictionary:
	return army(defs).get("recruit", {})


## Nota de um modelo para o tipo de tropa (o melhor é o que mais pesa no combate).
static func model_score(defs: Dictionary, type: String, model: String) -> float:
	var st: Dictionary = defs.equipment.get(model, {}).get("stats", {})
	return float(st.get(troop_def(defs, type).get("rank", "soft_attack"), 0.0)) + 0.5 * float(st.get("air_attack", 0.0)) \
		+ 0.3 * float(st.get("soft_attack", 0.0))


## Melhor modelo já pesquisado para o tipo ("" se nenhum).
static func best_model(defs: Dictionary, c: Country, type: String) -> String:
	var cats: Array = troop_def(defs, type).get("categories", [])
	var best := ""
	for eq in ResearchSystem.unlocked_equipment(defs, c):
		if defs.equipment[eq].get("category", "") in cats and (best == "" or model_score(defs, type, eq) > model_score(defs, type, best)):
			best = eq
	return best


## Custo de `batches` lotes: {count, work (dias-fábrica), days (mínimo), resources {recurso: quantidade}}.
static func batch_cost(defs: Dictionary, type: String, model: String, batches: int) -> Dictionary:
	var td := troop_def(defs, type)
	var e: Dictionary = defs.equipment.get(model, {})
	var count := int(td.get("batch", 10)) * batches
	var res := {}
	for r in e.get("resources", {}):
		res[r] = float(e.resources[r]) * float(td.get("resources_per_unit", 1.0)) * count
	return {"count": count, "work": float(td.get("work_per_unit", 1.0)) * float(e.get("cost", 1.0)) * count,
		"days": int(td.get("days", 5)), "resources": res}


## O que impede encomendar o lote ("" = pode).
static func can_recruit(state: GameState, defs: Dictionary, tag: String, type: String, batches: int) -> String:
	var c := state.country(tag)
	if c == null:
		return "país desconhecido"
	var td := troop_def(defs, type)
	if td.is_empty():
		return "tipo de tropa desconhecido"
	if batches < 1 or batches > int(recruit_rules(defs).get("max_batches_per_click", 10)):
		return "quantidade inválida"
	if best_model(defs, c, type) == "":
		return "pesquise um modelo de %s primeiro" % str(td.name).to_lower()
	return ""


static func enqueue(state: GameState, defs: Dictionary, tag: String, type: String, batches: int) -> void:
	var c := state.country(tag)
	var model := best_model(defs, c, type)
	var cost := batch_cost(defs, type, model, batches)
	c.recruit_queue.append({"id": c.next_recruit_id, "type": type, "model": model, "count": cost.count,
		"work": cost.work, "work_done": 0.0, "days": cost.days, "days_done": 0})
	c.next_recruit_id += 1


static func home_state(state: GameState, tag: String) -> int:
	var c := state.country(tag)
	if c != null and state.state(c.capital_state) != null and state.state(c.capital_state).control() == tag:
		return c.capital_state
	var mine := state.states_of(tag)
	return mine[0].id if not mine.is_empty() else -1


## Estado onde as tropas novas nascem: o favorito, se ainda é nosso; senão a capital.
static func rally_state(state: GameState, tag: String) -> int:
	var c := state.country(tag)
	if c != null and c.rally_state != -1 and state.state(c.rally_state) != null and state.state(c.rally_state).control() == tag:
		return c.rally_state
	return home_state(state, tag)


## Espaço que as tropas ocupam (soma de size x unidades).
static func stack_size(defs: Dictionary, g: ArmyGroup) -> float:
	var n := 0.0
	for t in g.troops:
		n += float(troop_def(defs, t.type).get("size", 1)) * float(t.count)
	return n


## Espaço ocupado pelas tropas paradas de `tag` no estado.
static func state_load(state: GameState, defs: Dictionary, sid: int, tag: String) -> float:
	var n := 0.0
	for g: ArmyGroup in state.groups.values():
		if g.owner == tag and g.state_id == sid and not g.moving():
			n += stack_size(defs, g)
	return n


## Onde nasce um lote de tamanho `size`: o favorito ou, se cheio, o vizinho nosso mais perto com espaço.
static func spawn_state(state: GameState, defs: Dictionary, tag: String, size: float) -> int:
	var start := rally_state(state, tag)
	if start == -1:
		return -1
	var cap := float(recruit_rules(defs).get("state_capacity", 600))
	var depth := int(recruit_rules(defs).get("spill_depth", 3))
	var seen := {start: true}
	var ring := [start]
	for d in depth + 1:
		var options := []
		for sid in ring:
			if state_load(state, defs, sid, tag) + size <= cap:
				options.append(sid)
		if not options.is_empty():
			var here := state.state(start).center
			options.sort_custom(func(a, b): return MapGeo.km(here, state.state(a).center) < MapGeo.km(here, state.state(b).center) \
				or (MapGeo.km(here, state.state(a).center) == MapGeo.km(here, state.state(b).center) and a < b))
			return options[0]
		var nxt := []
		for sid in ring:
			for n in state.adjacency.get(sid, []):
				var s := state.state(n)
				if s != null and not seen.has(n) and s.control() == tag:
					seen[n] = true
					nxt.append(n)
		nxt.sort()
		ring = nxt
		if ring.is_empty():
			break
	return start   # tudo cheio: nasce no favorito mesmo assim


## Põe tropas prontas no mapa (junta com a pilha parada que já estiver no estado).
static func spawn(state: GameState, defs: Dictionary, tag: String, type: String, model: String, count: float) -> ArmyGroup:
	var size := float(troop_def(defs, type).get("size", 1)) * count
	var sid := spawn_state(state, defs, tag, size)
	if sid == -1:
		return null
	var g := idle_stack(state, tag, sid)
	if g == null:
		g = new_group(state, tag, sid)
	add_troops(defs, g, type, model, count, float(CombatSystem.rules(defs).get("max_org", 100)))
	return g


static func idle_stack(state: GameState, tag: String, sid: int) -> ArmyGroup:
	var ids: Array = state.groups.keys()
	ids.sort()
	for gid in ids:
		var g: ArmyGroup = state.groups[gid]
		if g.owner == tag and g.state_id == sid and not g.moving():
			return g
	return null


static func add_troops(_defs: Dictionary, g: ArmyGroup, type: String, model: String, count: float, org: float) -> void:
	for t in g.troops:
		if t.type == type and t.model == model:
			var total := float(t.count) + count
			t.org = (float(t.org) * float(t.count) + org * count) / maxf(total, 0.001)
			t.count = total
			return
	g.troops.append({"type": type, "model": model, "count": count, "org": org})
	g.troops.sort_custom(func(a, b): return troop_order(a.type) < troop_order(b.type))


static func troop_order(type: String) -> int:
	return ["infantaria", "artilharia", "tanques", "avioes"].find(type)


static func new_group(state: GameState, tag: String, state_id: int) -> ArmyGroup:
	var g := ArmyGroup.new()
	g.id = state.next_group_id
	state.next_group_id += 1
	g.owner = tag
	var n := int(state.group_counters.get(tag, 0)) + 1
	state.group_counters[tag] = n
	g.name = "%dº Grupo" % n
	g.state_id = state_id
	state.groups[g.id] = g
	return g


## Pilhas paradas do mesmo país no mesmo estado (fora de batalha) viram uma só, a de menor id.
static func merge_stacks(state: GameState, defs: Dictionary) -> void:
	var first := {}
	var ids: Array = state.groups.keys()
	ids.sort()
	for gid in ids:
		var g: ArmyGroup = state.groups.get(gid)
		if g == null or g.moving() or state.battles.has(g.state_id):
			continue
		var key := "%s|%d" % [g.owner, g.state_id]
		if not first.has(key):
			first[key] = g
			continue
		var into: ArmyGroup = first[key]
		for t in g.troops:
			add_troops(defs, into, t.type, t.model, float(t.count), float(t.org))
		if into.general_id == -1:
			into.general_id = g.general_id
		state.groups.erase(gid)


## Separa da pilha as unidades pedidas ({tipo: quantidade}) numa pilha nova, que é devolvida.
## Se pedir tudo, devolve a própria pilha.
static func split(state: GameState, defs: Dictionary, g: ArmyGroup, counts: Dictionary) -> ArmyGroup:
	var all := true
	for type in g.types():
		if float(counts.get(type, 0)) < g.count_of(type) - 0.001:
			all = false
	if all:
		return g
	var ng := new_group(state, g.owner, g.state_id)
	for type in counts:
		var want := minf(float(counts[type]), g.count_of(type))
		for t in g.troops.duplicate():
			if want <= 0.001 or t.type != type:
				continue
			var take := minf(want, float(t.count))
			add_troops(defs, ng, type, t.model, take, float(t.org))
			t.count = float(t.count) - take
			want -= take
			if t.count <= 0.001:
				g.troops.erase(t)
	if g.empty():
		state.groups.erase(g.id)
	return ng


## Dispensa a pilha (as tropas voltam para casa e deixam de existir).
static func disband(state: GameState, g: ArmyGroup) -> void:
	state.groups.erase(g.id)


## Quilômetros por dia que a pilha anda (o tipo mais lento manda), com o bônus do general.
static func march_km_day(state: GameState, defs: Dictionary, g: ArmyGroup) -> float:
	var km := 25.0
	if not g.empty():
		km = 1e9
		for t in g.troops:
			km = minf(km, float(troop_def(defs, t.type).get("march_km_day", 25)))
	var gen := state.general(g.general_id)
	if gen != null:
		km *= 1.0 + float(army(defs).get("movement", {}).get("general_speed_bonus_per_level", 0.1)) * (gen.speed - 1)
	return km


## Atributo de combate de uma entrada de tropa: estatística do modelo x unidades x escala do tipo.
static func troop_stat(defs: Dictionary, t: Dictionary, stat: String) -> float:
	var st: Dictionary = defs.equipment.get(t.model, {}).get("stats", {})
	return float(st.get(stat, 0.0)) * float(t.count) * float(troop_def(defs, t.type).get("stat_scale", 1.0))


## Soma do poder da pilha (para a interface).
static func strength(defs: Dictionary, g: ArmyGroup) -> Dictionary:
	var out := {"soft_attack": 0.0, "hard_attack": 0.0, "armour": 0.0, "ground_attack": 0.0}
	for t in g.troops:
		for k in out:
			out[k] += troop_stat(defs, t, k)
	return out


# ---------------------------------------------------------------- generais

static func new_general(state: GameState, defs: Dictionary, tag: String, skill_max: int) -> General:
	var names: Dictionary = defs.get("general_names", {})
	var pool: Dictionary = names.get("pools", {}).get(names.get("country_pool", {}).get(tag, "en"), {})
	var gen := General.new()
	gen.id = state.next_general_id
	state.next_general_id += 1
	gen.owner = tag
	var taken := state.generals.values().map(func(x): return x.name)
	for _try in 20:
		gen.name = "%s %s" % [_pick(state, pool.get("first", ["General"])), _pick(state, pool.get("last", [str(gen.id)]))]
		if not gen.name in taken:
			break
	gen.attack = state.rng.randi_range(1, skill_max)
	gen.defense = state.rng.randi_range(1, skill_max)
	gen.speed = state.rng.randi_range(1, skill_max)
	state.generals[gen.id] = gen
	return gen


static func _pick(state: GameState, arr: Array) -> String:
	return str(arr[state.rng.randi_range(0, arr.size() - 1)])


static func groups_of_general(state: GameState, general_id: int) -> Array:
	return state.groups.values().filter(func(g): return g.general_id == general_id)


# ---------------------------------------------------------------- caminhos

## Caminho mais curto (em km) por terra, só por estados do próprio país. Devolve os estados depois
## da origem até o destino; vazio se não há caminho.
static func find_path(state: GameState, from: int, to: int, tag: String) -> Array:
	if state.state(to) == null or not state.can_enter(tag, state.state(to).owner):
		return []
	return _dijkstra(state, from, to, func(s: MapState): return state.can_enter(tag, s.owner))


## Primeiro país no caminho por terra onde as tropas de `tag` não podem entrar ("" se nenhum
## ou se não há caminho nenhum). Serve para avisar "é preciso estar em guerra com X".
static func route_blocker(state: GameState, from: int, to: int, tag: String) -> String:
	var path := _dijkstra(state, from, to, func(_s): return true)
	for sid in path:
		var owner: String = state.state(sid).owner
		if not state.can_enter(tag, owner):
			return owner
	return ""


## Caminho mais curto em km entre dois estados, só por estados em que `passable(estado)` é verdade.
static func _dijkstra(state: GameState, from: int, to: int, passable: Callable) -> Array:
	if from == to or state.state(to) == null:
		return []
	var dist := {from: 0.0}
	var prev := {}
	var done := {}
	var heap: Array = [[0.0, from]]   # fila de prioridade (heap binário) por distância
	var goal := state.state(to).center
	while not heap.is_empty():
		var top: Array = _heap_pop(heap)
		var cur: int = top[1]
		if done.has(cur):
			continue
		if cur == to:
			break
		done[cur] = true
		var cs := state.state(cur)
		for nb in state.adjacency.get(cur, []):
			if done.has(nb):
				continue
			var ns := state.state(nb)
			if ns == null or not passable.call(ns):
				continue
			var d: float = dist[cur] + MapGeo.km(cs.center, ns.center)
			if not dist.has(nb) or d < dist[nb]:
				dist[nb] = d
				prev[nb] = cur
				# A*: soma uma estimativa da distância que falta (nunca maior que a real)
				_heap_push(heap, [d + MapGeo.km(ns.center, goal) * 0.999, nb])
	if not prev.has(to):
		return []
	var path: Array = []
	var at := to
	while at != from:
		path.push_front(at)
		at = prev[at]
	return path


static func _heap_push(h: Array, item: Array) -> void:
	h.append(item)
	var i := h.size() - 1
	while i > 0:
		var p := (i - 1) / 2
		if h[p][0] <= h[i][0]:
			break
		var t = h[p]
		h[p] = h[i]
		h[i] = t
		i = p


static func _heap_pop(h: Array) -> Array:
	var top: Array = h[0]
	var last: Array = h.pop_back()
	if not h.is_empty():
		h[0] = last
		var i := 0
		var n := h.size()
		while true:
			var l := i * 2 + 1
			var r := l + 1
			var m := i
			if l < n and h[l][0] < h[m][0]:
				m = l
			if r < n and h[r][0] < h[m][0]:
				m = r
			if m == i:
				break
			var t = h[m]
			h[m] = h[i]
			h[i] = t
			i = m
	return top


## Quilômetros que faltam até o destino.
static func remaining_km(state: GameState, g: ArmyGroup) -> float:
	if not g.moving():
		return 0.0
	var total := -g.progress_km
	var at := g.state_id
	for nxt in g.path:
		total += MapGeo.km(state.state(at).center, state.state(nxt).center)
		at = nxt
	return maxf(total, 0.0)


## Dias que faltam até o destino na marcha atual.
static func eta_days(state: GameState, defs: Dictionary, g: ArmyGroup) -> float:
	return remaining_km(state, g) / maxf(march_km_day(state, defs, g), 0.1)
