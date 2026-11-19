class_name MapState
extends RefCounted
## Um estado do mapa (grupo de províncias): dono, população e construções.
## A geografia vem de data/map/states.json; o dono e as construções vêm do cenário.

var id: int
var code: String             # código estável do mapa, ex.: "DEU-1599"
var name: String
var modern_country: String   # país atual (ISO), usado só para aplicar regras de cenário
var center: Vector2          # ponto central, em coordenadas do mapa
var area_km2: int
var owner: String = ""       # tag do país dono
var population: int = 0
var building_slots: int = 0  # vagas para fábricas (civis + militares)
## Nível de cada construção, ex.: {"civilian_factory": 3, "infrastructure": 2}
var buildings: Dictionary = {}


func level(building: String) -> int:
	return int(buildings.get(building, 0))


## Aceita tanto os dados do mapa (code, country, center) quanto dados de teste (owner, buildings).
static func from_dict(d: Dictionary) -> MapState:
	var s := MapState.new()
	s.id = int(d.id)
	s.code = d.get("code", str(s.id))
	s.name = d.name
	s.modern_country = d.get("country", "")
	var c: Array = d.get("center", [0, 0])
	s.center = Vector2(c[0], c[1])
	s.area_km2 = int(d.get("area_km2", 0))
	s.owner = d.get("owner", "")
	s.population = int(d.get("population", 0))
	s.building_slots = int(d.get("building_slots", 0))
	for k in d.get("buildings", {}):
		s.buildings[k] = int(d.buildings[k])
	return s
