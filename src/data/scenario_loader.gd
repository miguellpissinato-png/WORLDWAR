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
	d["trade"] = r.trade
	return d


static func load_scenario(scenario: String) -> GameState:
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
	for d in read_json(MAP_DIR + "/states.json"):
		var st := MapState.from_dict(d)
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
		gs.countries[country.tag] = country

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
	return gs
