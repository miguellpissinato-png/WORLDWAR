class_name SaveGame
extends RefCounted
## Jogo salvo = cenário + semente + diário de comandos. Carregar refaz a partida do começo,
## hora a hora, aplicando cada comando na mesma hora em que foi aplicado (a simulação é
## determinística). Ler e gravar o arquivo fica com a interface.

const VERSION := 1

## Partida a carregar quando a cena principal reiniciar (a interface preenche e recarrega a cena).
static var pending: Dictionary = {}


static func to_dict(sim: Simulation, scenario: String, player_tag: String) -> Dictionary:
	return {
		"version": VERSION,
		"scenario": scenario,
		"seed": sim.state.rng.seed,
		"player": player_tag,
		"hours": sim.state.hours,
		"journal": sim.journal.duplicate(true),
	}


## Refaz a partida salva a partir de um estado novo do mesmo cenário.
static func replay(data: Dictionary, state: GameState, defs: Dictionary) -> Simulation:
	var sim := Simulation.new(state, defs)
	for e in data.get("journal", []):
		var h := int(e.h)
		if h > state.hours:
			sim.advance_hours(h - state.hours)
		var cmd := CommandRegistry.from_dict(e.c)
		if cmd != null:
			sim.submit(cmd)
			sim.apply_pending()
	var end := int(data.get("hours", state.hours))
	if end > state.hours:
		sim.advance_hours(end - state.hours)
	return sim
