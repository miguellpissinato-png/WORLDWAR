class_name MapState
extends RefCounted
## Um estado do mapa (grupo de províncias): dono, população e construções.

var id: int
var name: String
var owner: String            # tag do país dono
var population: int
var building_slots: int      # vagas para fábricas (civis + militares)
## Nível de cada construção, ex.: {"civilian_factory": 3, "infrastructure": 2}
var buildings: Dictionary = {}


func level(building: String) -> int:
	return int(buildings.get(building, 0))


static func from_dict(d: Dictionary) -> MapState:
	var s := MapState.new()
	s.id = int(d.id)
	s.name = d.name
	s.owner = d.owner
	s.population = int(d.get("population", 0))
	s.building_slots = int(d.get("building_slots", 0))
	for k in d.get("buildings", {}):
		s.buildings[k] = int(d.buildings[k])
	return s
