class_name GameState
extends RefCounted
## Tudo o que define uma partida num instante. Salvar o jogo = salvar isto.

var hours: int = 0                 # tempo do jogo, ver GameDate
var scenario_name: String = ""
var countries: Dictionary = {}     # tag -> Country
var states: Dictionary = {}        # id -> MapState
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


func date_text() -> String:
	return GameDate.format(hours)
