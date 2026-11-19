extends TestCase
# Mundo de teste (test_case.gd): AAA 2 fábricas civis, sem recursos, $1000.
# BBB 1 fábrica civil, 20 de petróleo/dia, $1000. Petróleo a $10. Metade vira bens (0,5).


func test_goods_and_stock() -> void:
	var sim := make_world()
	sim.state.prices["oil"] = 10.0
	EconomySystem.daily_update(sim.state, sim.defs)
	var b := sim.state.country("BBB")
	# 20 x 0,5 = 10 viram bens (cabe: 1 fábrica x 10); renda = 10 x $10 x 1,5 = 150; 10 vão ao estoque.
	assert_eq(b.last_goods["oil"], 10.0)
	assert_eq(b.last_income, 150.0)
	assert_eq(b.stock("oil"), 10.0)
	assert_eq(b.money, 1150.0)


func test_factories_limit_goods() -> void:
	var sim := make_world()
	sim.state.country("BBB").goods_share["oil"] = 1.0   # quer tudo em bens: 20, mas 1 fábrica processa 10
	EconomySystem.daily_update(sim.state, sim.defs)
	assert_eq(sim.state.country("BBB").last_goods["oil"], 10.0)
	assert_eq(sim.state.country("BBB").stock("oil"), 10.0, "o excedente vai para o estoque")


func test_set_goods_share_command() -> void:
	var sim := make_world()
	sim.submit(SetGoodsShareCommand.create("BBB", "oil", 0.0))
	sim.advance_hours(24)
	assert_eq(sim.state.country("BBB").stock("oil"), 20.0, "tudo para o estoque")
	assert_eq(sim.state.country("BBB").last_income, 0.0)


func test_extraction_levels_up_to_deposit() -> void:
	var sim := make_world()
	var s := sim.state.state(2)
	assert_eq(s.extraction_step("oil"), 2, "10% de 20")
	assert_eq(s.max_extraction_levels("oil", 2.0), 10, "até dobrar")
	s.buildings["extraction_oil"] = 3
	assert_eq(s.extraction("oil"), 26)
	assert_eq(sim.state.resource_production("BBB", "oil"), 26)


func test_build_extraction_needs_deposit_and_money() -> void:
	var sim := make_world()
	var reasons: Array = []
	sim.command_rejected.connect(func(_c, r): reasons.append(r))
	sim.submit(QueueConstructionCommand.create("AAA", 1, "extraction_oil"))   # sem jazida
	sim.submit(QueueConstructionCommand.create("BBB", 2, "extraction_oil"))   # ok, custa $50
	sim.apply_pending()
	assert_eq(reasons, ["o estado não tem jazida desse recurso"])
	assert_eq(sim.state.country("BBB").money, 950.0)
	assert_eq(sim.state.country("BBB").construction_queue.size(), 1)


func test_market_price_rises_with_scarcity() -> void:
	var sim := make_world()
	# Ferro: demanda de 3 fábricas, oferta zero -> preço sobe em direção ao alvo.
	var before := sim.state.price("iron")
	MarketSystem.daily_update(sim.state, sim.defs)
	assert_true(sim.state.price("iron") > before, "ferro escasso fica mais caro")
	# Petróleo: oferta 20 >> demanda 3 -> preço cai.
	assert_true(sim.state.price("oil") < 10.0, "petróleo abundante fica mais barato")


func test_buy_from_ai_at_fair_price() -> void:
	var sim := make_world()
	sim.state.country("BBB").stockpile["oil"] = 50.0
	var cmd := ProposeTradeCommand.create("AAA", "BBB", "buy", "oil", 20, 10.0)
	sim.submit(cmd)
	sim.apply_pending()
	assert_eq(cmd.result, "aceita")
	assert_eq(sim.state.country("AAA").stock("oil"), 20.0)
	assert_eq(sim.state.country("AAA").money, 800.0)
	assert_eq(sim.state.country("BBB").money, 1200.0)
	assert_eq(sim.state.country("BBB").stock("oil"), 30.0)


func test_ai_refuses_lowball() -> void:
	var sim := make_world()
	sim.state.country("BBB").stockpile["oil"] = 50.0
	var cmd := ProposeTradeCommand.create("AAA", "BBB", "buy", "oil", 20, 5.0)   # metade do mercado
	sim.submit(cmd)
	sim.apply_pending()
	assert_eq(cmd.result, "recusada")
	assert_eq(sim.state.country("AAA").money, 1000.0)


func test_price_cap() -> void:
	var sim := make_world()
	sim.state.country("BBB").stockpile["oil"] = 50.0
	var reasons: Array = []
	sim.command_rejected.connect(func(_c, r): reasons.append(r))
	sim.submit(ProposeTradeCommand.create("BBB", "AAA", "sell", "oil", 10, 13.0))   # teto: 12,50
	sim.apply_pending()
	assert_eq(reasons, ["preço acima do teto permitido"])


func test_offer_between_players_waits_for_answer() -> void:
	var sim := make_world()
	sim.state.human_tags = ["AAA", "BBB"]
	sim.state.country("BBB").stockpile["oil"] = 50.0
	sim.submit(ProposeTradeCommand.create("BBB", "AAA", "sell", "oil", 10, 12.0))
	sim.apply_pending()
	assert_eq(sim.state.offers.size(), 1, "aguardando")
	var id: int = sim.state.offers.keys()[0]
	sim.submit(RespondTradeCommand.create("AAA", id, true))
	sim.apply_pending()
	assert_eq(sim.state.offers.size(), 0)
	assert_eq(sim.state.country("AAA").stock("oil"), 10.0)
	assert_eq(sim.state.country("BBB").money, 1120.0)


func test_only_receiver_can_answer() -> void:
	var sim := make_world()
	sim.state.human_tags = ["AAA", "BBB"]
	sim.state.country("BBB").stockpile["oil"] = 50.0
	sim.submit(ProposeTradeCommand.create("BBB", "AAA", "sell", "oil", 10, 12.0))
	sim.apply_pending()
	var reasons: Array = []
	sim.command_rejected.connect(func(_c, r): reasons.append(r))
	sim.submit(RespondTradeCommand.create("BBB", sim.state.offers.keys()[0], true))
	sim.apply_pending()
	assert_eq(reasons, ["a proposta não é para este país"])


func test_offers_expire() -> void:
	var sim := make_world()
	sim.state.human_tags = ["AAA", "BBB"]
	sim.state.country("BBB").stockpile["oil"] = 50.0
	sim.submit(ProposeTradeCommand.create("BBB", "AAA", "sell", "oil", 10, 12.0))
	sim.advance_hours(24 * 31)
	assert_eq(sim.state.offers.size(), 0)


func test_donate() -> void:
	var sim := make_world()
	sim.state.country("BBB").stockpile["oil"] = 50.0
	sim.submit(DonateResourcesCommand.create("BBB", "AAA", "oil", 30))
	sim.submit(DonateResourcesCommand.create("BBB", "AAA", "oil", 30))   # sobra só 20
	sim.apply_pending()
	assert_eq(sim.state.country("AAA").stock("oil"), 30.0)
	assert_eq(sim.state.country("BBB").stock("oil"), 20.0)


func test_claim_country() -> void:
	var sim := make_world()
	sim.submit(ClaimCountryCommand.create("AAA"))
	sim.apply_pending()
	sim.submit(ClaimCountryCommand.create("BBB", "AAA"))
	sim.apply_pending()
	assert_eq(sim.state.human_tags, ["BBB"])


func test_economy_commands_serialize() -> void:
	for original in [SetGoodsShareCommand.create("AAA", "oil", 0.3),
			ProposeTradeCommand.create("AAA", "BBB", "buy", "oil", 7, 9.5),
			RespondTradeCommand.create("AAA", 4, false),
			DonateResourcesCommand.create("AAA", "BBB", "oil", 3),
			ClaimCountryCommand.create("AAA", "BBB")]:
		var copy := CommandRegistry.from_dict(original.to_dict())
		assert_eq(copy.to_dict(), original.to_dict())
