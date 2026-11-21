class_name ObjectiveSystem
extends RefCounted
## Objetivos de vitória, no estilo do jogo de tabuleiro: dominar uma parte da área do mundo ou de
## continentes (data/common/objectives.json). Conta a área que o país controla (dele ou ocupada).
## Quem cumpre primeiro o próprio objetivo vence (GameState.winner); a partida pode continuar.


static func list(defs: Dictionary) -> Array:
	return defs.get("objectives", {}).get("objectives", [])


static func find(defs: Dictionary, id: String) -> Dictionary:
	for o in list(defs):
		if o.id == id:
			return o
	return {}


static func region_name(defs: Dictionary, region: String) -> String:
	return String(defs.get("objectives", {}).get("region_names", {}).get(region, region))


## Área total e área controlada por `tag`, por continente ("mundo" = soma de tudo).
static func areas(state: GameState, tag: String) -> Dictionary:
	var total := {"mundo": 0.0}
	var mine := {"mundo": 0.0}
	for s: MapState in state.states.values():
		var a := float(s.area_km2)
		total.mundo += a
		total[s.continent] = total.get(s.continent, 0.0) + a
		if s.control() == tag:
			mine.mundo += a
			mine[s.continent] = mine.get(s.continent, 0.0) + a
	return {"total": total, "mine": mine}


## Andamento do objetivo: {value (0–1, o pior alvo), done, parts: [{label, share, target}]}.
static func progress(state: GameState, defs: Dictionary, tag: String, id: String, cached: Dictionary = {}) -> Dictionary:
	var obj := find(defs, id)
	if obj.is_empty():
		return {"value": 0.0, "done": false, "parts": []}
	var ar: Dictionary = cached if not cached.is_empty() else areas(state, tag)
	var parts := []
	var value := 1.0
	for t in obj.targets:
		var tot := 0.0
		var have := 0.0
		var names := []
		for r in t.regions:
			tot += float(ar.total.get(r, 0.0))
			have += float(ar.mine.get(r, 0.0))
			names.append(region_name(defs, r))
		var share := have / tot if tot > 0.0 else 0.0
		var target := float(t.share)
		parts.append({"label": " + ".join(names), "share": share, "target": target})
		value = minf(value, clampf(share / target, 0.0, 1.0))
	return {"value": value, "done": value >= 1.0, "parts": parts}


## Objetivos possíveis para um país: os que ele ainda está longe de cumprir.
static func candidates(state: GameState, defs: Dictionary, tag: String) -> Array:
	var limit := float(defs.get("objectives", {}).get("max_start_progress", 0.4))
	var ar := areas(state, tag)
	return list(defs).filter(func(o): return progress(state, defs, tag, o.id, ar).value < limit).map(func(o): return o.id)


static func daily_update(state: GameState, defs: Dictionary) -> void:
	if state.winner != "":
		return
	var tags: Array = state.objectives.keys()
	tags.sort()
	for tag in tags:
		if progress(state, defs, tag, state.objectives[tag]).done:
			state.winner = tag
			var obj := find(defs, state.objectives[tag])
			state.add_event(state.countries.keys(), "%s cumpriu o objetivo \"%s\" e venceu a guerra." % [
				state.country(tag).name, obj.get("name", "")], "Vitória")
			return
