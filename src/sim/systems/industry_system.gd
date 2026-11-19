class_name IndustrySystem
extends RefCounted
## Converte fábricas entre uso civil e militar. Mais fábricas militares = menos fábricas civis,
## e portanto menos bens de consumo (dinheiro) e menos construção. A conversão não é instantânea:
## a parte civil anda `conversion_per_day` por dia até o alvo escolhido pelo jogador.


static func daily_update(state: GameState, defs: Dictionary) -> void:
	var step := float(defs.get("industry", {}).get("conversion_per_day", 0.02))
	for c: Country in state.countries.values():
		var diff := c.civil_share_target - c.civil_share
		if absf(diff) <= step:
			c.civil_share = c.civil_share_target
		else:
			c.civil_share += signf(diff) * step


## Quantos dias faltam para a divisão chegar ao alvo.
static func days_to_target(c: Country, defs: Dictionary) -> int:
	var step := float(defs.get("industry", {}).get("conversion_per_day", 0.02))
	return ceili(absf(c.civil_share_target - c.civil_share) / step - 0.0001)
