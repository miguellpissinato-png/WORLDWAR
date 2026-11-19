class_name GameState
extends RefCounted
## Tudo o que define uma partida num instante. Salvar o jogo = salvar isto.

var hours: int = 0                 # tempo do jogo, ver GameDate
var scenario_name: String = ""
var countries: Dictionary = {}     # tag -> Country
var states: Dictionary = {}        # id -> MapState
var sea_zones: Dictionary = {}     # id -> SeaZone
var trades: Dictionary = {}        # id -> TradeContract
var next_trade_id: int = 1
var rng := RandomNumberGenerator.new()   # único gerador aleatório da simulação


func country(tag: String) -> Country:
	return countries.get(tag)


func state(id: int) -> MapState:
	return states.get(id)


func states_of(tag: String) -> Array:
	return states.values().filter(func(s): return s.owner == tag)


## Total de uma construção somando todos os estados do país.
func total_building(tag: String, building: String) -> int:
	var total := 0
	for s in states_of(tag):
		total += s.level(building)
	return total


## Produção diária de um recurso somando os estados do país.
func resource_production(tag: String, resource: String) -> int:
	var total := 0
	for s in states_of(tag):
		total += int(s.resources.get(resource, 0))
	return total


func resource_imports(tag: String, resource: String) -> int:
	var total := 0
	for t in trades.values():
		if t.buyer == tag and t.resource == resource:
			total += t.amount
	return total


func resource_exports(tag: String, resource: String) -> int:
	var total := 0
	for t in trades.values():
		if t.seller == tag and t.resource == resource:
			total += t.amount
	return total


## Saldo diário: produção + importação - exportação. (O consumo pela produção militar virá depois.)
func resource_balance(tag: String, resource: String) -> int:
	return resource_production(tag, resource) + resource_imports(tag, resource) - resource_exports(tag, resource)


## Quanto ainda dá para exportar, respeitando a fatia máxima de exportação.
func exportable(tag: String, resource: String, max_share: float) -> int:
	return maxi(0, int(floor(resource_production(tag, resource) * max_share)) - resource_exports(tag, resource))


## Fábricas civis cedidas como pagamento de importações.
func factories_paid(tag: String) -> int:
	var total := 0
	for t in trades.values():
		if t.buyer == tag:
			total += t.factories
	return total


## Fábricas civis recebidas como pagamento de exportações.
func factories_received(tag: String) -> int:
	var total := 0
	for t in trades.values():
		if t.seller == tag:
			total += t.factories
	return total


## Fábricas civis que o país pode usar para construir.
func available_civilian_factories(tag: String) -> int:
	return total_building(tag, "civilian_factory") - factories_paid(tag) + factories_received(tag)


func date_text() -> String:
	return GameDate.format(hours)
