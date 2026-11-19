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
## Nível de cada construção, ex.: {"factory": 3, "infrastructure": 2}
var buildings: Dictionary = {}
## Produção de recursos por dia em 1936 (a "jazida explorada"), ex.: {"oil": 12}.
## A extração atual soma os níveis das construções de extração (ver extraction()).
var resources: Dictionary = {}

## Fração da produção de 1936 que cada nível de extração acrescenta (definida pelo carregador).
static var extraction_step_share := 0.1


func level(building: String) -> int:
	return int(buildings.get(building, 0))


## Unidades/dia que cada nível de extração do recurso acrescenta (mínimo 1).
func extraction_step(resource: String) -> int:
	return maxi(1, int(round(float(resources.get(resource, 0)) * extraction_step_share)))


## Extração atual por dia: produção de 1936 + níveis construídos.
func extraction(resource: String) -> int:
	var base := int(resources.get(resource, 0))
	if base <= 0:
		return 0
	return base + level("extraction_" + resource) * extraction_step(resource)


## Quantos níveis de extração a jazida ainda comporta no total.
func max_extraction_levels(resource: String, deposit_factor: float) -> int:
	var base := int(resources.get(resource, 0))
	if base <= 0:
		return 0
	return int(ceil(base * (deposit_factor - 1.0) / float(extraction_step(resource))))


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
	for k in d.get("resources", {}):
		s.resources[k] = int(d.resources[k])
	return s
