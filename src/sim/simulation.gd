class_name Simulation
extends RefCounted
## Motor do jogo. Avança o tempo hora a hora e aplica comandos.
## Não sabe nada de interface: quem chama advance_hours() é a UI (ou o host, no multiplayer).

signal day_passed(hours: int)
signal command_rejected(command: Command, reason: String)

var state: GameState
var defs: Dictionary          # definições de data/common (construções, regras)
var _pending: Array = []      # comandos aguardando a próxima hora


func _init(p_state: GameState, p_defs: Dictionary) -> void:
	state = p_state
	defs = p_defs


## Agenda um comando para o início da próxima hora.
func submit(command: Command) -> void:
	_pending.append(command)


func advance_hours(n: int) -> void:
	for i in n:
		_tick_hour()


func _tick_hour() -> void:
	var batch := _pending
	_pending = []
	for cmd: Command in batch:
		var reason: String = cmd.validate(state, defs)
		if reason == "":
			cmd.apply(state, defs)
		else:
			command_rejected.emit(cmd, reason)
	state.hours += 1
	if state.hours % 24 == 0:
		_daily_update()
		day_passed.emit(state.hours)


func _daily_update() -> void:
	ConstructionSystem.daily_update(state, defs)
