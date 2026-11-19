class_name ScenarioLoader
extends RefCounted
## Lê os arquivos JSON de data/ e monta um GameState pronto para jogar.

const COMMON_DIR := "res://data/common"
const SCENARIOS_DIR := "res://data/scenarios"


static func read_json(path: String) -> Variant:
	var text := FileAccess.get_file_as_string(path)
	if text == "":
		push_error("Não foi possível ler %s" % path)
		return null
	return JSON.parse_string(text)


## Definições gerais: {"buildings": {...}, "construction": {...}}
static func load_defs() -> Dictionary:
	var d: Dictionary = read_json(COMMON_DIR + "/buildings.json")
	return d


static func load_scenario(scenario: String) -> GameState:
	var dir := SCENARIOS_DIR + "/" + scenario
	var info: Dictionary = read_json(dir + "/scenario.json")
	var gs := GameState.new()
	gs.scenario_name = info.name
	var start: Dictionary = info.start
	gs.hours = GameDate.to_hours(int(start.year), int(start.month), int(start.day), int(start.get("hour", 0)))
	gs.rng.seed = int(info.get("seed", 1936))
	for c in read_json(dir + "/countries.json"):
		var country := Country.from_dict(c)
		gs.countries[country.tag] = country
	for s in read_json(dir + "/states.json"):
		var st := MapState.from_dict(s)
		gs.states[st.id] = st
	return gs
