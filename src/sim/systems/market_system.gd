class_name MarketSystem
extends RefCounted
## Preço mundial de cada recurso. Demanda = fábricas civis do mundo x demanda por fábrica;
## oferta = extração mundial. O preço anda aos poucos em direção ao alvo:
## alvo = preço base x (demanda / oferta) ^ elasticidade, limitado entre min e max vezes o preço base.


static func target_price(state: GameState, defs: Dictionary, res: Dictionary, world_civil: int = -1) -> float:
	var m: Dictionary = defs.get("market", {})
	var factories := world_civil
	if factories < 0:
		factories = 0
		for tag in state.countries:
			factories += state.civil_factories(tag)
	var demand := factories * float(res.get("demand_per_factory", 1.0))
	var supply := float(state.world_production(res.id))
	var ratio := (demand + 1.0) / (supply + 1.0)
	var factor := clampf(pow(ratio, float(m.get("elasticity", 0.5))), float(m.get("min_factor", 0.4)), float(m.get("max_factor", 3.0)))
	return float(res.base_price) * factor


static func daily_update(state: GameState, defs: Dictionary) -> void:
	var speed := float(defs.get("market", {}).get("price_speed", 0.05))
	var civil := 0
	for tag in state.countries:
		civil += state.civil_factories(tag)
	for res in defs.get("resources", []):
		var target := target_price(state, defs, res, civil)
		var current := state.price(res.id)
		state.prices[res.id] = target if current <= 0.0 else lerpf(current, target, speed)


## Preço máximo que um vendedor pode pedir.
static func max_price(state: GameState, defs: Dictionary, resource: String) -> float:
	return state.price(resource) * (1.0 + float(defs.get("market", {}).get("max_markup", 0.25)))
