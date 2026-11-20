class_name GameState
extends RefCounted
## Tudo o que define uma partida num instante. Salvar o jogo = salvar isto.

var hours: int = 0                 # tempo do jogo, ver GameDate
var scenario_name: String = ""
var countries: Dictionary = {}     # tag -> Country
var states: Dictionary = {}        # id -> MapState
var sea_zones: Dictionary = {}     # id -> SeaZone
var offers: Dictionary = {}        # id -> TradeOffer (propostas aguardando resposta)
var next_offer_id: int = 1
var prices: Dictionary = {}        # recurso -> preço no mercado mundial
var human_tags: Array = []         # países controlados por jogadores (a IA não responde por eles)
var operations: Dictionary = {}    # id -> IntelOperation
var next_operation_id: int = 1
var events: Array = []             # [{hours, tags, text}] avisos para os países envolvidos
var groups: Dictionary = {}        # id -> ArmyGroup
var next_group_id: int = 1
var group_counters: Dictionary = {} # tag -> quantos grupos o país já criou (para numerar "3º Grupo")
var generals: Dictionary = {}      # id -> General
var next_general_id: int = 1
var adjacency: Dictionary = {}     # id do estado -> [ids vizinhos por terra] (geografia, não muda)

const MAX_EVENTS := 300
var rng := RandomNumberGenerator.new()   # único gerador aleatório da simulação


func country(tag: String) -> Country:
	return countries.get(tag)


func state(id: int) -> MapState:
	return states.get(id)


func group(id: int) -> ArmyGroup:
	return groups.get(id)


func general(id: int) -> General:
	return generals.get(id)


func groups_of(tag: String) -> Array:
	var out := groups.values().filter(func(g): return g.owner == tag)
	out.sort_custom(func(a, b): return a.id < b.id)
	return out


func generals_of(tag: String) -> Array:
	var out := generals.values().filter(func(g): return g.owner == tag)
	out.sort_custom(func(a, b): return a.id < b.id)
	return out


func states_of(tag: String) -> Array:
	return states.values().filter(func(s): return s.owner == tag)


## Total de uma construção somando todos os estados do país.
func total_building(tag: String, building: String) -> int:
	var total := 0
	for s in states_of(tag):
		total += s.level(building)
	return total


## Fábricas do país (uma só reserva) e a divisão entre uso civil e militar.
func factories(tag: String) -> int:
	return total_building(tag, "factory")


func civil_factories(tag: String) -> int:
	var c := country(tag)
	var n := factories(tag)
	return n if c == null else clampi(roundi(n * c.civil_share), 0, n)


func military_factories(tag: String) -> int:
	return factories(tag) - civil_factories(tag)


## Extração diária de um recurso somando os estados do país.
func resource_production(tag: String, resource: String) -> int:
	var total := 0
	for s in states_of(tag):
		total += s.extraction(resource)
	return total


func world_production(resource: String) -> int:
	var total := 0
	for s in states.values():
		total += s.extraction(resource)
	return total


func price(resource: String) -> float:
	return float(prices.get(resource, 0.0))


func is_human(tag: String) -> bool:
	return tag in human_tags


func add_event(tags: Array, text: String, kind: String = "Inteligência") -> void:
	events.append({"hours": hours, "tags": tags, "text": text, "kind": kind})
	if events.size() > MAX_EVENTS:
		events.pop_front()


func date_text() -> String:
	return GameDate.format(hours)
