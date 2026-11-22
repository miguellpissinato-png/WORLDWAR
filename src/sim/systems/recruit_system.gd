class_name RecruitSystem
extends RefCounted
## Encomenda de tropas: cada país tem uma fila de lotes (soldados, artilharia, tanques, aviões).
## Por dia, as fábricas militares trabalham nos lotes em ordem: cada lote recebe só o que precisa para
## terminar no prazo mínimo (`days`); o que sobra vai para o próximo. O trabalho gasta recursos do
## estoque na mesma proporção; faltando recurso, o lote anda na proporção do que há, nunca abaixo de
## `shortage_floor`. Pronto (trabalho feito e prazo cumprido), o lote nasce no estado favorito.


static func daily_update(state: GameState, defs: Dictionary) -> void:
	var floor_speed := float(ArmySystem.recruit_rules(defs).get("shortage_floor", 0.25))
	for tag in state.countries:
		var c: Country = state.countries[tag]
		c.last_recruited = {}
		c.last_shortage = {}
		var free := float(state.military_factories(tag))
		for item in c.recruit_queue.duplicate():
			item.days_done = int(item.days_done) + 1
			var left := float(item.work) - float(item.work_done)
			if left > 0.0001 and free > 0.0:
				var days_left := maxi(1, int(item.days) - int(item.days_done) + 1)
				var use := minf(free, maxf(left / days_left, minf(left, 1.0)))
				var cost := ArmySystem.batch_cost(defs, item.type, item.model, 1)
				var per_work := {}   # recurso por dia-fábrica
				for r in cost.resources:
					per_work[r] = float(cost.resources[r]) / maxf(float(cost.work), 0.001)
				var ratio := 1.0
				for r in per_work:
					var need: float = per_work[r] * use
					if need > 0.0:
						ratio = minf(ratio, c.stock(r) / need)
				var done := use * clampf(maxf(ratio, floor_speed), 0.0, 1.0)
				for r in per_work:
					var need: float = per_work[r] * done
					var used := minf(need, c.stock(r))
					c.stockpile[r] = c.stock(r) - used
					if need - used > 0.0001:
						c.last_shortage[r] = float(c.last_shortage.get(r, 0.0)) + need - used
				item.work_done = float(item.work_done) + done
				free -= use
			if float(item.work_done) >= float(item.work) - 0.0001 and int(item.days_done) >= int(item.days):
				c.recruit_queue.erase(item)
				var g := ArmySystem.spawn(state, defs, tag, item.type, item.model, float(item.count))
				c.last_recruited[item.type] = int(c.last_recruited.get(item.type, 0)) + int(item.count)
				if g != null:
					state.add_event([tag], "%d %s prontos em %s." % [int(item.count),
						ArmySystem.troop_def(defs, item.type).get("short", item.type), state.state(g.state_id).name], "Exército")


## Dias que faltam para o lote, com as fábricas de hoje (-1 = parado, sem fábricas).
static func eta_days(state: GameState, defs: Dictionary, tag: String, id: int) -> int:
	var c := state.country(tag)
	var free := float(state.military_factories(tag))
	for item in c.recruit_queue:
		var left := float(item.work) - float(item.work_done)
		var days_left := maxi(0, int(item.days) - int(item.days_done))
		var rate := minf(free, maxf(left / maxi(1, days_left), minf(left, 1.0)))
		free -= rate
		if int(item.id) == id:
			if left <= 0.0001:
				return days_left
			if rate <= 0.0001:
				return -1
			return maxi(days_left, ceili(left / rate))
	return -1
