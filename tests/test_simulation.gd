extends TestCase


func test_command_waits_for_next_hour() -> void:
	var sim := make_world()
	sim.submit(QueueConstructionCommand.create("AAA", 1, "civilian_factory"))
	assert_eq(sim.state.country("AAA").construction_queue.size(), 0, "antes da hora")
	sim.advance_hours(1)
	assert_eq(sim.state.country("AAA").construction_queue.size(), 1, "depois da hora")


func test_construction_finishes() -> void:
	# 2 fábricas x 5 por dia = 10 por dia; custo 100 -> 10 dias.
	var sim := make_world()
	sim.submit(QueueConstructionCommand.create("AAA", 1, "civilian_factory"))
	sim.advance_hours(24 * 9 + 1)
	assert_eq(sim.state.state(1).level("civilian_factory"), 2, "dia 9")
	sim.advance_hours(24)
	assert_eq(sim.state.state(1).level("civilian_factory"), 3, "dia 10")
	assert_eq(sim.state.country("AAA").construction_queue.size(), 0)


func test_cannot_build_in_foreign_state() -> void:
	var sim := make_world()
	var reasons: Array = []
	sim.command_rejected.connect(func(_c, r): reasons.append(r))
	sim.submit(QueueConstructionCommand.create("AAA", 2, "civilian_factory"))
	sim.advance_hours(1)
	assert_eq(reasons, ["o estado não pertence ao país"])


func test_slots_limit() -> void:
	# 4 vagas, 2 já usadas: só cabem mais 2 fábricas.
	var sim := make_world()
	for i in 3:
		sim.submit(QueueConstructionCommand.create("AAA", 1, "military_factory"))
	sim.advance_hours(1)
	assert_eq(sim.state.country("AAA").construction_queue.size(), 2)


func test_infrastructure_max_level() -> void:
	var sim := make_world()
	sim.submit(QueueConstructionCommand.create("AAA", 1, "infrastructure"))
	sim.submit(QueueConstructionCommand.create("AAA", 1, "infrastructure"))
	sim.advance_hours(1)
	assert_eq(sim.state.country("AAA").construction_queue.size(), 1)


func test_command_serialization() -> void:
	var original := QueueConstructionCommand.create("AAA", 1, "civilian_factory")
	var copy := CommandRegistry.from_dict(original.to_dict())
	assert_true(copy is QueueConstructionCommand, "tipo")
	assert_eq(copy.to_dict(), original.to_dict())


func test_same_commands_same_result() -> void:
	# Determinismo: duas simulações com os mesmos comandos terminam iguais.
	var a := make_world()
	var b := make_world()
	for sim in [a, b]:
		sim.submit(QueueConstructionCommand.create("AAA", 1, "civilian_factory"))
		sim.submit(QueueConstructionCommand.create("AAA", 1, "infrastructure"))
		sim.advance_hours(24 * 30)
	assert_eq(a.state.state(1).buildings, b.state.state(1).buildings)
