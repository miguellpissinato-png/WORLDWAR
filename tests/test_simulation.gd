extends TestCase


func test_command_waits_for_next_hour() -> void:
	var sim := make_world()
	sim.submit(QueueConstructionCommand.create("AAA", 1, "factory"))
	assert_eq(sim.state.country("AAA").construction_queue.size(), 0, "antes da hora")
	sim.advance_hours(1)
	assert_eq(sim.state.country("AAA").construction_queue.size(), 1, "depois da hora")


func test_construction_finishes() -> void:
	# 2 fábricas x 5 por dia = 10 por dia; custo 100 -> 10 dias.
	var sim := make_world()
	sim.submit(QueueConstructionCommand.create("AAA", 1, "factory"))
	sim.advance_hours(24 * 9 + 1)
	assert_eq(sim.state.state(1).level("factory"), 2, "dia 9")
	sim.advance_hours(24)
	assert_eq(sim.state.state(1).level("factory"), 3, "dia 10")
	assert_eq(sim.state.country("AAA").construction_queue.size(), 0)


func test_cannot_build_in_foreign_state() -> void:
	var sim := make_world()
	var reasons: Array = []
	sim.command_rejected.connect(func(_c, r): reasons.append(r))
	sim.submit(QueueConstructionCommand.create("AAA", 2, "factory"))
	sim.advance_hours(1)
	assert_eq(reasons, ["o estado não pertence ao país"])


func test_slots_limit() -> void:
	# 4 vagas, 2 já usadas: só cabem mais 2 fábricas.
	var sim := make_world()
	for i in 3:
		sim.submit(QueueConstructionCommand.create("AAA", 1, "factory"))
	sim.advance_hours(1)
	assert_eq(sim.state.country("AAA").construction_queue.size(), 2)


func test_infrastructure_max_level() -> void:
	var sim := make_world()
	sim.submit(QueueConstructionCommand.create("AAA", 1, "infrastructure"))
	sim.submit(QueueConstructionCommand.create("AAA", 1, "infrastructure"))
	sim.advance_hours(1)
	assert_eq(sim.state.country("AAA").construction_queue.size(), 1)


func test_command_serialization() -> void:
	var original := QueueConstructionCommand.create("AAA", 1, "factory")
	var copy := CommandRegistry.from_dict(original.to_dict())
	assert_true(copy is QueueConstructionCommand, "tipo")
	assert_eq(copy.to_dict(), original.to_dict())


func test_same_commands_same_result() -> void:
	# Determinismo: duas simulações com os mesmos comandos terminam iguais.
	var a := make_world()
	var b := make_world()
	for sim in [a, b]:
		sim.submit(QueueConstructionCommand.create("AAA", 1, "factory"))
		sim.submit(QueueConstructionCommand.create("AAA", 1, "infrastructure"))
		sim.advance_hours(24 * 30)
	assert_eq(a.state.state(1).buildings, b.state.state(1).buildings)


func test_apply_pending_without_time() -> void:
	var sim := make_world()
	sim.submit(QueueConstructionCommand.create("AAA", 1, "factory"))
	sim.apply_pending()
	assert_eq(sim.state.country("AAA").construction_queue.size(), 1)
	assert_eq(sim.state.hours, 0, "o tempo não andou")


func test_save_and_replay() -> void:
	# Salvar = diário de comandos; carregar refaz a partida e chega no mesmo estado.
	var a := make_world()
	a.submit(QueueConstructionCommand.create("AAA", 1, "factory"))
	a.advance_hours(24 * 5 + 7)
	a.submit(QueueConstructionCommand.create("AAA", 1, "infrastructure"))
	a.apply_pending()   # com o jogo pausado
	a.submit(QueueConstructionCommand.create("BBB", 2, "factory"))   # recusado: não entra no diário
	a.advance_hours(24 * 40)
	var data := SaveGame.to_dict(a, "teste", "AAA")
	data = JSON.parse_string(JSON.stringify(data))   # como no arquivo
	var b := SaveGame.replay(data, make_world().state, make_world().defs)
	assert_eq(b.state.hours, a.state.hours, "mesma hora")
	assert_eq(b.state.state(1).buildings, a.state.state(1).buildings)
	assert_eq(b.state.country("AAA").money, a.state.country("AAA").money)
	assert_eq(b.journal.size(), a.journal.size())
