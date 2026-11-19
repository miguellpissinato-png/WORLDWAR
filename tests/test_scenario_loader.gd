extends TestCase

# Carregar o cenário inteiro é lento (milhares de estados): carrega uma vez só.
static var _gs: GameState


func gs() -> GameState:
	if _gs == null:
		_gs = ScenarioLoader.load_scenario("1936")
	return _gs


func test_load_1936() -> void:
	assert_eq(gs().scenario_name, "Rearmamento")
	assert_eq(gs().hours, 0)
	assert_eq(gs().country("BRA").leader, "Getúlio Vargas")
	assert_eq(gs().state(gs().country("ALE").capital_state).name, "Berlim")


func test_whole_world_is_loaded() -> void:
	assert_true(gs().states.size() > 3000, "mais de 3000 estados")
	assert_true(gs().countries.size() > 70, "mais de 70 países")


func test_sea_zones_are_loaded() -> void:
	assert_true(gs().sea_zones.size() > 500, "mais de 500 zonas marítimas")
	var names := {}
	for z in gs().sea_zones.values():
		assert_true(z.name != "", "zona %s sem nome" % z.code)
		names[z.name] = true
	assert_eq(names.size(), gs().sea_zones.size(), "nomes de zona repetidos")


func test_every_state_has_a_valid_owner() -> void:
	var bad: Array = []
	for s in gs().states.values():
		if gs().country(s.owner) == null:
			bad.append(s.code)
	assert_eq(bad, [], "estados sem dono válido")


func test_every_capital_belongs_to_its_country() -> void:
	for tag in gs().countries:
		var cap := gs().state(gs().country(tag).capital_state)
		assert_true(cap != null and cap.owner == tag, "capital de " + tag)


func test_every_country_can_build() -> void:
	for tag in gs().countries:
		assert_true(gs().civil_factories(tag) > 0, "fábrica civil em " + tag)


func test_1936_border_exceptions() -> void:
	var owner_of := func(code: String) -> String:
		for s in gs().states.values():
			if s.code == code:
				return s.owner
		return ""
	assert_eq(owner_of.call("RUS-2324"), "ALE", "Königsberg")
	assert_eq(owner_of.call("UKR-291"), "POL", "Lwów")
	assert_eq(owner_of.call("CHN-1839"), "MAN", "Heilongjiang")
	assert_eq(owner_of.call("KOR-2497"), "JAP", "Seul")
	assert_eq(owner_of.call("IND-2428"), "IND", "Délhi")


func test_buildings_in_states_are_defined() -> void:
	var defs := ScenarioLoader.load_defs()
	for s in gs().states.values():
		for b in s.buildings:
			assert_true(defs.buildings.has(b), "construção %s em %s" % [b, s.name])


func test_resources_are_where_expected() -> void:
	assert_true(gs().resource_production("EUA", "oil") > 100, "EUA: maior produtor de petróleo")
	assert_true(gs().resource_production("ALE", "coal") > 40, "Alemanha: muito carvão")
	assert_eq(gs().resource_production("ALE", "rubber"), 0, "Alemanha sem borracha natural")
	assert_true(gs().resource_production("RUN", "rubber") > 30, "Malásia britânica")
	assert_true(gs().resource_production("BRA", "iron") == 0 and gs().resource_production("BRA", "coal") > 0, "Brasil 1936")
	var defs := ScenarioLoader.load_defs()
	for s in gs().states.values():
		for r in s.resources:
			assert_true(r in defs.resource_ids, "recurso %s em %s" % [r, s.name])


func test_economy_starts_ready() -> void:
	for tag in gs().countries:
		assert_true(gs().country(tag).money > 0.0, "dinheiro inicial de " + tag)
	for r in ["oil", "coal", "iron", "rubber", "bauxite", "rare_metals"]:
		assert_true(gs().price(r) > 0.0, "preço de " + r)
