class_name ArmySystem
extends RefCounted
## Exército: regimentos (prontos na hora, com equipamento do depósito), grupos e generais fictícios.


static func army(defs: Dictionary) -> Dictionary:
	return defs.get("army", {})


static func regiment_def(defs: Dictionary, type: String) -> Dictionary:
	return army(defs).get("regiments", {}).get(type, {})


## Equipamentos do depósito que servem para uma categoria, do melhor para o pior.
static func ranked_equipment(defs: Dictionary, c: Country, categories: Array) -> Array:
	var stat_of: Dictionary = army(defs).get("rank_stat", {})
	var out: Array = []
	for eq in c.equipment:
		var e: Dictionary = defs.equipment.get(eq, {})
		if e.get("category", "") in categories and c.equipment_count(eq) > 0:
			out.append(eq)
	out.sort_custom(func(a, b):
		var ea: Dictionary = defs.equipment[a]
		var eb: Dictionary = defs.equipment[b]
		return float(ea.stats.get(stat_of.get(ea.category, ""), 0)) > float(eb.stats.get(stat_of.get(eb.category, ""), 0)))
	return out


## Equipamento que o regimento levaria do depósito agora: {equipamento: unidades}, ou {} se falta.
static func pick_equipment(defs: Dictionary, c: Country, type: String) -> Dictionary:
	var taken := {}
	for need in regiment_def(defs, type).get("needs", []):
		var left := int(need.qty)
		for eq in ranked_equipment(defs, c, need.categories):
			var have := int(c.equipment_count(eq)) - int(taken.get(eq, 0))
			var use := mini(have, left)
			if use > 0:
				taken[eq] = int(taken.get(eq, 0)) + use
				left -= use
			if left <= 0:
				break
		if left > 0:
			return {}
	return taken


## O que falta para formar o regimento, em texto ("" = dá para formar).
static func can_form(state: GameState, defs: Dictionary, tag: String, type: String, group_id: int) -> String:
	var c := state.country(tag)
	if c == null:
		return "país desconhecido"
	var rd := regiment_def(defs, type)
	if rd.is_empty():
		return "tipo de regimento desconhecido"
	if not c.has_tech("t_" + type):
		return "pesquise %s primeiro" % rd.name
	if group_id != -1:
		var g := state.group(group_id)
		if g == null or g.owner != tag:
			return "grupo desconhecido"
		if g.regiments.size() >= int(army(defs).get("max_regiments_per_group", 4)):
			return "o grupo já está cheio"
	if pick_equipment(defs, c, type).is_empty():
		var parts: Array = []
		for need in rd.needs:
			parts.append("%d %s" % [int(need.qty), "/".join(need.categories.map(func(x): return category_plural(x)))])
		return "falta equipamento no depósito (precisa de %s)" % ", ".join(parts)
	return ""


static func category_plural(cat: String) -> String:
	return {"rifle": "lotes de fuzis", "sniper": "lotes de fuzis de precisão", "smg": "lotes de submetralhadoras",
		"tank": "tanques", "artillery": "peças de artilharia"}.get(cat, cat)


static func home_state(state: GameState, tag: String) -> int:
	var c := state.country(tag)
	if c != null and state.state(c.capital_state) != null and state.state(c.capital_state).owner == tag:
		return c.capital_state
	var mine := state.states_of(tag)
	return mine[0].id if not mine.is_empty() else -1


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


## Forma o regimento (tirando o equipamento do depósito) num grupo; group_id = -1 cria um grupo novo
## na capital. Devolve o grupo.
static func form_regiment(state: GameState, defs: Dictionary, tag: String, type: String, group_id: int) -> ArmyGroup:
	var c := state.country(tag)
	var eq := pick_equipment(defs, c, type)
	for k in eq:
		c.equipment[k] = c.equipment_count(k) - eq[k]
		if c.equipment_count(k) <= 0:
			c.equipment.erase(k)
	var g := state.group(group_id) if group_id != -1 else new_group(state, tag, home_state(state, tag))
	g.regiments.append({"type": type, "equipment": eq})
	return g


## Dissolve o grupo: o equipamento volta ao depósito.
static func disband(state: GameState, g: ArmyGroup) -> void:
	var c := state.country(g.owner)
	for r in g.regiments:
		for k in r.equipment:
			c.equipment[k] = c.equipment_count(k) + float(r.equipment[k])
	state.groups.erase(g.id)


## Quilômetros por dia que o grupo marcha (o regimento mais lento manda), com o bônus do general.
static func march_km_day(state: GameState, defs: Dictionary, g: ArmyGroup) -> float:
	var km := 25.0
	if not g.regiments.is_empty():
		km = 1e9
		for r in g.regiments:
			km = minf(km, float(regiment_def(defs, r.type).get("march_km_day", 25)))
	var gen := state.general(g.general_id)
	if gen != null:
		km *= 1.0 + float(army(defs).get("movement", {}).get("general_speed_bonus_per_level", 0.1)) * (gen.speed - 1)
	return km


## Soma do poder do grupo (para a interface e, na parte 3, para o combate).
static func strength(defs: Dictionary, g: ArmyGroup) -> Dictionary:
	var out := {"soft_attack": 0.0, "hard_attack": 0.0, "armour": 0.0}
	for r in g.regiments:
		for eq in r.equipment:
			var st: Dictionary = defs.equipment.get(eq, {}).get("stats", {})
			for k in out:
				out[k] += float(st.get(k, 0.0)) * float(r.equipment[eq])
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
	if from == to or state.state(to) == null or state.state(to).owner != tag:
		return []
	var dist := {from: 0.0}
	var prev := {}
	var open := [from]
	var done := {}
	while not open.is_empty():
		var best := 0
		for i in open.size():
			if dist[open[i]] < dist[open[best]]:
				best = i
		var cur: int = open[best]
		open.remove_at(best)
		if cur == to:
			break
		done[cur] = true
		var cs := state.state(cur)
		for nb in state.adjacency.get(cur, []):
			if done.has(nb):
				continue
			var ns := state.state(nb)
			if ns == null or ns.owner != tag:
				continue
			var d: float = dist[cur] + MapGeo.km(cs.center, ns.center)
			if not dist.has(nb) or d < dist[nb]:
				if not dist.has(nb):
					open.append(nb)
				dist[nb] = d
				prev[nb] = cur
	if not prev.has(to):
		return []
	var path: Array = []
	var at := to
	while at != from:
		path.push_front(at)
		at = prev[at]
	return path


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
