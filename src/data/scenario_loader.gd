class_name ScenarioLoader
extends RefCounted
## Lê os arquivos JSON de data/ e monta um GameState pronto para jogar.
##
## Ordem: estados do mapa (data/map/states.json) -> donos (owners.json do cenário)
## -> países (countries.json) -> construções iniciais (buildings.json + padrões de scenario.json).

const COMMON_DIR := "res://data/common"
const MAP_DIR := "res://data/map"
const SCENARIOS_DIR := "res://data/scenarios"


static func read_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_error("Não foi possível ler %s" % path)
		return null
	return JSON.parse_string(text)


## Definições gerais: {"buildings", "construction", "resources" (lista), "resource_ids", "trade"}
static func load_defs() -> Dictionary:
	var d: Dictionary = read_json(COMMON_DIR + "/buildings.json")
	var r: Dictionary = read_json(COMMON_DIR + "/resources.json")
	d["resources"] = r.resources
	d["resource_ids"] = r.resources.map(func(x): return x.id)
	for k in ["currency", "extraction", "economy", "market"]:
		d[k] = r.get(k, {})
	d["intelligence"] = read_json(COMMON_DIR + "/intelligence.json")
	d["equipment"] = read_json(COMMON_DIR + "/equipment.json").equipment
	d["research"] = read_json(COMMON_DIR + "/research.json")
	d["army"] = read_json(COMMON_DIR + "/army.json")
	d["general_names"] = read_json(COMMON_DIR + "/general_names.json")
	d["diplomacy"] = read_json(COMMON_DIR + "/diplomacy.json")
	d["objectives"] = read_json(COMMON_DIR + "/objectives.json")
	d["ai"] = read_json(COMMON_DIR + "/ai.json")
	MapState.extraction_step_share = float(d.extraction.get("step_share", 0.1))
	return d


static func load_scenario(scenario: String, defs: Dictionary = {}) -> GameState:
	if defs.is_empty():
		defs = load_defs()
	var dir := SCENARIOS_DIR + "/" + scenario
	var info: Dictionary = read_json(dir + "/scenario.json")
	var gs := GameState.new()
	gs.scenario_name = info.name
	var start: Dictionary = info.start
	gs.hours = GameDate.to_hours(int(start.year), int(start.month), int(start.day), int(start.get("hour", 0)))
	gs.rng.seed = int(info.get("seed", 1936))

	# Estados do mapa e seus donos.
	var owners: Dictionary = read_json(dir + "/owners.json")
	var by_country: Dictionary = owners.get("countries", {})
	var by_state: Dictionary = owners.get("states", {})
	var by_code := {}
	var default_slots := int(info.get("default_building_slots", 4))
	var continents: Dictionary = read_json(MAP_DIR + "/continents.json")
	for d in read_json(MAP_DIR + "/states.json"):
		var st := MapState.from_dict(d)
		st.continent = String(continents.get(st.code, "outros"))
		if by_state.has(st.code):
			st.owner = by_state[st.code].owner
		else:
			st.owner = by_country.get(st.modern_country, "")
		st.building_slots = default_slots
		gs.states[st.id] = st
		by_code[st.code] = st

	# Recursos (geografia: iguais em todos os cenários).
	var res: Dictionary = read_json(COMMON_DIR + "/state_resources.json")
	for code in res:
		if code.begins_with("_"):
			continue
		var st: MapState = by_code.get(code)
		if st == null:
			push_error("Estado %s de state_resources.json não existe no mapa" % code)
			continue
		for k in res[code]:
			st.resources[k] = int(res[code][k])

	# Zonas marítimas (iguais em todos os cenários).
	for d in read_json(MAP_DIR + "/sea_zones.json"):
		var z := SeaZone.from_dict(d)
		gs.sea_zones[z.id] = z

	# Países.
	for c in read_json(dir + "/countries.json"):
		var country := Country.from_dict(c)
		var cap: MapState = by_code.get(c.capital_state)
		if cap == null:
			push_error("Capital %s de %s não existe no mapa" % [c.capital_state, country.tag])
		else:
			country.capital_state = cap.id
			cap.building_slots = int(info.get("capital_building_slots", default_slots))
		if not c.has("civil_share"):
			country.civil_share = float(defs.get("industry", {}).get("default_civil_share", 0.7))
			country.civil_share_target = country.civil_share
		gs.countries[country.tag] = country

	# Economia inicial: dinheiro, divisão padrão e preços de mercado.
	var eco: Dictionary = defs.get("economy", {})
	for country in gs.countries.values():
		country.money = float(eco.get("start_money", 3000))
		for r in defs.resource_ids:
			country.goods_share[r] = float(eco.get("default_goods_share", 0.7))
			country.stockpile[r] = 0.0

	# Construções iniciais.
	var start_buildings: Dictionary = read_json(dir + "/buildings.json")
	var default_capital: Dictionary = info.get("default_capital_buildings", {})
	for country in gs.countries.values():
		var cap: MapState = gs.state(country.capital_state)
		if cap != null and not start_buildings.has(cap.code):
			for b in default_capital:
				cap.buildings[b] = int(default_capital[b])
	for code in start_buildings:
		if code.begins_with("_"):
			continue
		var st: MapState = by_code.get(code)
		if st == null:
			push_error("Estado %s de buildings.json não existe no mapa" % code)
			continue
		for b in start_buildings[code]:
			st.buildings[b] = int(start_buildings[code][b])
	# Pesquisas já concluídas no início do cenário.
	var start_research: Dictionary = read_json(dir + "/research.json")
	var slots := int(defs.get("research", {}).get("rules", {}).get("slots", 3))
	for country in gs.countries.values():
		country.research_slots = slots
		for id in start_research.get("_todos", []) + start_research.get(country.tag, []):
			if ResearchSystem.tech(defs, id).is_empty():
				push_error("Tecnologia %s de research.json não existe" % id)
			elif not id in country.researched:
				country.researched.append(id)
	# Vizinhança por terra (geografia).
	var adj: Dictionary = read_json(MAP_DIR + "/adjacency.json")
	# Travessias curtas de mar (estreitos) contam como vizinhança: tropas atravessam.
	var links: Array = []
	for section in ["land", "strait"]:
		for code in adj.get(section, {}):
			for n in adj[section][code]:
				links.append([code, n])
	for c in read_json(COMMON_DIR + "/sea_crossings.json").get("crossings", []):
		links.append([c[0], c[1]])
		links.append([c[1], c[0]])
	for l in links:
		var a: MapState = by_code.get(l[0])
		var b: MapState = by_code.get(l[1])
		if a == null or b == null:
			continue
		var ids: Array = gs.adjacency.get(a.id, [])
		if not b.id in ids:
			ids.append(b.id)
		gs.adjacency[a.id] = ids
		var back: Array = gs.adjacency.get(b.id, [])
		if not a.id in back:
			back.append(a.id)
		gs.adjacency[b.id] = back
	if FileAccess.file_exists(dir + "/access.json"):
		for pair in read_json(dir + "/access.json").get("pairs", []):
			gs.access.append([pair[0], pair[1]])

	_load_armies(gs, defs, read_json(dir + "/armies.json"))
	for rdef in defs.resources:
		gs.prices[rdef.id] = MarketSystem.target_price(gs, defs, rdef)
	return gs


## Generais e grupos iniciais. Países sem fuzil próprio recebem o fuzil representante (ver armies.json).
static func _load_armies(gs: GameState, defs: Dictionary, armies: Dictionary) -> void:
	if armies == null:
		return
	var standin: Dictionary = armies.get("rifle_standin", {})
	var gd: Dictionary = defs.get("army", {}).get("generals", {})
	var tags: Array = gs.countries.keys()
	tags.sort()
	for tag in tags:
		var c: Country = gs.countries[tag]
		if ArmySystem.home_state(gs, tag) == -1:
			continue
		var has_rifle := false
		for eq in ResearchSystem.unlocked_equipment(defs, c):
			if defs.equipment[eq].category == "rifle":
				has_rifle = true
		if not has_rifle:
			var t: String = standin.get(tag, standin.get("_padrao", ""))
			if t != "" and not c.has_tech(t):
				c.researched.append(t)
		var start: Dictionary = gd.get("start", {})
		for i in int(start.get(tag, start.get("_padrao", 1))):
			ArmySystem.new_general(gs, defs, tag, int(gd.get("skill_start_max", 3)))
		var plan: Dictionary = armies.get(tag, armies.get("_padrao", {}))
		var troops: Dictionary = plan.get("troops", {})
		var home := ArmySystem.home_state(gs, tag)
		var g: ArmyGroup = null
		for type in troops:
			var model := ArmySystem.best_model(defs, c, type)
			if model == "":
				continue
			if g == null:
				g = ArmySystem.new_group(gs, tag, home)
			ArmySystem.add_troops(defs, g, type, model, float(troops[type]), float(defs.get("army", {}).get("combat", {}).get("max_org", 100)))


static func _best_unlocked(defs: Dictionary, c: Country, category: String) -> String:
	var stat: String = defs.get("army", {}).get("rank_stat", {}).get(category, "soft_attack")
	var best := ""
	for eq in ResearchSystem.unlocked_equipment(defs, c):
		var e: Dictionary = defs.equipment[eq]
		if e.category == category and (best == "" or float(e.stats.get(stat, 0)) > float(defs.equipment[best].stats.get(stat, 0))):
			best = eq
	return best
