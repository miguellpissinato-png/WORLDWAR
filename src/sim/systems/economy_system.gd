class_name EconomySystem
extends RefCounted
## Uma vez por dia, para cada país: a extração de cada recurso é dividida conforme
## `goods_share` entre bens de consumo (viram dinheiro) e estoque.
## As fábricas civis limitam quanto dá para transformar em bens; o que passar disso vai para o estoque.


static func daily_update(state: GameState, defs: Dictionary) -> void:
	var eco: Dictionary = defs.get("economy", {})
	var per_factory := float(eco.get("goods_per_factory", 10))
	var value := float(eco.get("goods_value", 1.5))
	var ids: Array = defs.get("resource_ids", [])
	for tag in state.countries:
		var c: Country = state.countries[tag]
		var capacity := state.total_building(tag, "civilian_factory") * per_factory
		var produced := {}
		var wanted := {}
		var wanted_total := 0.0
		for r in ids:
			var p := float(state.resource_production(tag, r))
			produced[r] = p
			wanted[r] = p * float(c.goods_share.get(r, eco.get("default_goods_share", 0.7)))
			wanted_total += wanted[r]
		var scale := 1.0 if wanted_total <= capacity or wanted_total == 0.0 else capacity / wanted_total
		var income := 0.0
		c.last_goods = {}
		for r in ids:
			var goods: float = wanted[r] * scale
			c.last_goods[r] = goods
			income += goods * state.price(r) * value
			c.stockpile[r] = c.stock(r) + produced[r] - goods
		c.money += income
		c.last_income = income
