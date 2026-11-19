class_name ResearchSystem
extends RefCounted
## Pesquisa em 5 áreas (armas, tropas, blindados, aviação, artilharia). Cada país tem algumas vagas;
## cada vaga pesquisa uma tecnologia por vez, avançando 1 dia de trabalho por dia de jogo.
##
## Tempo de pesquisa = dias da tecnologia x (1 + penalidade por ano adiantado) x (1 + penalidade de projeto
## estrangeiro). Pesquisar antes do ano histórico custa mais e há um limite de anos adiantados.


static func tech(defs: Dictionary, id: String) -> Dictionary:
	return defs.get("research", {}).get("techs", {}).get(id, {})


static func rules(defs: Dictionary) -> Dictionary:
	return defs.get("research", {}).get("rules", {})


static func is_foreign(t: Dictionary, tag: String) -> bool:
	var origin: Array = t.get("origin", [])
	return not origin.is_empty() and not tag in origin


static func years_ahead(state: GameState, t: Dictionary) -> int:
	return maxi(0, int(t.get("year", 1936)) - GameDate.from_hours(state.hours).year)


## Dias que a pesquisa levaria se começasse agora.
static func days_needed(state: GameState, defs: Dictionary, tag: String, id: String) -> int:
	var t := tech(defs, id)
	var r := rules(defs)
	var days := float(t.get("days", 0))
	days *= 1.0 + float(r.get("ahead_penalty_per_year", 0.5)) * years_ahead(state, t)
	if is_foreign(t, tag):
		days *= 1.0 + float(r.get("foreign_design_penalty", 0.75))
	return maxi(1, ceili(days))


static func in_progress(c: Country, id: String) -> bool:
	for r in c.research:
		if r.tech == id:
			return true
	return false


## "" se o país pode começar a pesquisa agora; senão, o motivo.
static func can_start(state: GameState, defs: Dictionary, tag: String, id: String) -> String:
	var c := state.country(tag)
	var t := tech(defs, id)
	if c == null:
		return "país desconhecido"
	if t.is_empty():
		return "tecnologia desconhecida"
	if c.has_tech(id):
		return "já pesquisada"
	if in_progress(c, id):
		return "já em pesquisa"
	for req in t.get("requires", []):
		if not c.has_tech(req):
			return "falta pesquisar: %s" % tech(defs, req).get("name", req)
	if years_ahead(state, t) > int(rules(defs).get("max_years_ahead", 2)):
		return "ainda não é possível (ano histórico: %d)" % int(t.year)
	if c.research.size() >= c.research_slots:
		return "todas as vagas de pesquisa estão ocupadas"
	if c.money < float(t.get("money_cost", 0)):
		return "dinheiro insuficiente"
	return ""


static func start(state: GameState, defs: Dictionary, tag: String, id: String) -> void:
	var c := state.country(tag)
	c.money -= float(tech(defs, id).get("money_cost", 0))
	c.research.append({"tech": id, "progress": 0.0, "days": days_needed(state, defs, tag, id)})


static func daily_update(state: GameState, defs: Dictionary) -> void:
	for tag in state.countries:
		var c: Country = state.countries[tag]
		var done: Array = []
		for r in c.research:
			r.progress += 1.0
			if r.progress >= float(r.days):
				done.append(r)
		for r in done:
			c.research.erase(r)
			if not c.has_tech(r.tech):
				c.researched.append(r.tech)
			state.add_event([tag], "Pesquisa concluída: %s." % tech(defs, r.tech).get("name", r.tech), "Pesquisa")


## Equipamentos que o país já pode produzir.
static func unlocked_equipment(defs: Dictionary, c: Country) -> Array:
	var out: Array = []
	for id in c.researched:
		for eq in tech(defs, id).get("unlocks_equipment", []):
			if not eq in out:
				out.append(eq)
	return out


static func can_produce(defs: Dictionary, c: Country, eq: String) -> bool:
	return eq in unlocked_equipment(defs, c)
