extends TestCase
# Mundo de teste: AAA tem 2 fábricas civis e nenhum recurso; BBB tem 1 fábrica e 20 de petróleo.
# Exportação máxima: 75% de 20 = 15. Pagamento: 1 fábrica a cada 5 unidades.


func test_production_and_balance() -> void:
	var sim := make_world()
	assert_eq(sim.state.resource_production("BBB", "oil"), 20)
	assert_eq(sim.state.resource_balance("AAA", "oil"), 0)


func test_buy_oil() -> void:
	var sim := make_world()
	sim.submit(CreateTradeCommand.create("AAA", "BBB", "oil", 10))
	sim.advance_hours(1)
	assert_eq(sim.state.trades.size(), 1)
	assert_eq(sim.state.resource_balance("AAA", "oil"), 10, "comprador")
	assert_eq(sim.state.resource_balance("BBB", "oil"), 10, "vendedor")
	assert_eq(sim.state.available_civilian_factories("AAA"), 0, "pagou 2 fábricas")
	assert_eq(sim.state.available_civilian_factories("BBB"), 3, "recebeu 2 fábricas")


func test_cannot_exceed_export_share() -> void:
	var sim := make_world()
	var reasons: Array = []
	sim.command_rejected.connect(func(_c, r): reasons.append(r))
	sim.submit(CreateTradeCommand.create("AAA", "BBB", "oil", 16))
	sim.advance_hours(1)
	assert_eq(reasons, ["o vendedor não tem esse excedente"])


func test_cannot_pay_without_factories() -> void:
	var sim := make_world()
	var reasons: Array = []
	sim.command_rejected.connect(func(_c, r): reasons.append(r))
	sim.submit(CreateTradeCommand.create("AAA", "BBB", "oil", 10))   # 2 fábricas: ok
	sim.submit(CreateTradeCommand.create("AAA", "BBB", "oil", 5))    # mais 1: não tem
	sim.advance_hours(1)
	assert_eq(sim.state.trades.size(), 1)
	assert_eq(reasons, ["fábricas civis insuficientes para pagar"])


func test_cannot_trade_with_itself_or_unknown_resource() -> void:
	var sim := make_world()
	var reasons: Array = []
	sim.command_rejected.connect(func(_c, r): reasons.append(r))
	sim.submit(CreateTradeCommand.create("BBB", "BBB", "oil", 5))
	sim.submit(CreateTradeCommand.create("AAA", "BBB", "ouro", 5))
	sim.advance_hours(1)
	assert_eq(reasons, ["não dá para comerciar consigo mesmo", "recurso desconhecido"])


func test_cancel_trade() -> void:
	var sim := make_world()
	sim.submit(CreateTradeCommand.create("AAA", "BBB", "oil", 5))
	sim.advance_hours(1)
	var id: int = sim.state.trades.keys()[0]
	sim.submit(CancelTradeCommand.create("BBB", id))
	sim.advance_hours(1)
	assert_eq(sim.state.trades.size(), 0)
	assert_eq(sim.state.available_civilian_factories("AAA"), 2)


func test_payment_slows_buyer_construction() -> void:
	# AAA paga as 2 fábricas: a construção dela para. BBB constrói com 1 + 2 = 3.
	var sim := make_world()
	sim.submit(CreateTradeCommand.create("AAA", "BBB", "oil", 10))
	sim.submit(QueueConstructionCommand.create("AAA", 1, "civilian_factory"))
	sim.submit(QueueConstructionCommand.create("BBB", 2, "civilian_factory"))
	sim.advance_hours(24 * 7)
	assert_eq(sim.state.country("AAA").construction_queue[0].progress, 0.0, "comprador parado")
	assert_true(sim.state.state(2).level("civilian_factory") == 2, "vendedor terminou (3 fábricas x 5 x 7 dias >= 100)")


func test_contract_ends_when_seller_loses_production() -> void:
	var sim := make_world()
	sim.submit(CreateTradeCommand.create("AAA", "BBB", "oil", 10))
	sim.advance_hours(1)
	sim.state.state(2).resources["oil"] = 4   # simula perda do campo de petróleo
	sim.advance_hours(24)
	assert_eq(sim.state.trades.size(), 0)


func test_trade_commands_serialize() -> void:
	for original in [CreateTradeCommand.create("AAA", "BBB", "oil", 7), CancelTradeCommand.create("AAA", 3)]:
		var copy := CommandRegistry.from_dict(original.to_dict())
		assert_eq(copy.to_dict(), original.to_dict())
