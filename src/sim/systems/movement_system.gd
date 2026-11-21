class_name MovementSystem
extends RefCounted
## Marcha dos grupos, hora a hora: anda km/24 por hora (mais rápido com infraestrutura),
## passando de estado em estado pelo caminho até o destino. Não entra num estado com tropas
## inimigas: para na divisa e ataca (CombatSystem). Entrar em estado inimigo ocupa o estado.


static func hourly_update(state: GameState, defs: Dictionary) -> void:
	var infra_bonus := float(ArmySystem.army(defs).get("movement", {}).get("infrastructure_bonus_per_level", 0.05))
	for g: ArmyGroup in state.groups.values():
		if not g.moving():
			continue
		var here := state.state(g.state_id)
		var km_h := ArmySystem.march_km_day(state, defs, g) / 24.0 * (1.0 + infra_bonus * here.level("infrastructure"))
		g.progress_km += km_h
		while g.moving():
			var leg := MapGeo.km(state.state(g.state_id).center, state.state(g.path[0]).center)
			if g.progress_km < leg:
				break
			if not CombatSystem.enemy_groups_in(state, g.path[0], g.owner).is_empty():
				g.progress_km = leg   # para na divisa e ataca (CombatSystem)
				break
			g.progress_km -= leg
			g.state_id = g.path.pop_front()
			CombatSystem.on_enter(state, g)
		if not g.moving():
			g.progress_km = 0.0
			state.add_event([g.owner], "%s chegou a %s." % [g.name, state.state(g.state_id).name], "Exército")


## Posição no mapa agora (entre o estado atual e o próximo).
static func map_position(state: GameState, g: ArmyGroup) -> Vector2:
	var a := state.state(g.state_id).center
	if not g.moving():
		return a
	var b := state.state(g.path[0]).center
	var leg := MapGeo.km(a, b)
	var t := clampf(g.progress_km / maxf(leg, 0.001), 0.0, 1.0)
	if CombatSystem.attack_target(state, g) != -1:
		t = minf(t, ATTACK_POS)   # atacando: fica na frente do estado, não em cima do defensor
	return a.lerp(b, t)


## Onde o atacante aparece no trecho até o estado atacado (a marca da batalha fica logo à frente).
const ATTACK_POS := 0.4
