class_name CombatSystem
extends RefCounted
## Combate terrestre, hora a hora (depois da marcha).
## Uma batalha acontece quando um grupo em marcha chega na divisa de um estado onde há grupos
## de um país com quem está em guerra: ele para na divisa (MovementSystem) e ataca.
## Cada hora, os dois lados perdem organização (0–100) na proporção da força do outro, e um pouco
## de equipamento. Quando todos os regimentos de um lado ficam abaixo de `break_org`, esse lado perde:
## o defensor recua para um estado vizinho amigo (ou é destruído, se não há para onde ir) e o
## atacante desiste da marcha. Fora de batalha, a organização volta aos poucos.
## Regras e valores (de jogo) em `combat` de data/common/army.json.


static func rules(defs: Dictionary) -> Dictionary:
	return defs.get("army", {}).get("combat", {})


static func org_of(defs: Dictionary, r: Dictionary) -> float:
	return float(r.get("org", rules(defs).get("max_org", 100)))


## Organização média do grupo (0–100).
static func group_org(defs: Dictionary, g: ArmyGroup) -> float:
	if g.regiments.is_empty():
		return 0.0
	var t := 0.0
	for r in g.regiments:
		t += org_of(defs, r)
	return t / g.regiments.size()


## Grupos parados ou de passagem no estado `sid` que são inimigos (em guerra) de `tag`.
static func enemy_groups_in(state: GameState, sid: int, tag: String) -> Array:
	var out := []
	for g: ArmyGroup in state.groups.values():
		if g.state_id == sid and g.owner != tag and state.at_war(tag, g.owner) and not g.regiments.is_empty():
			out.append(g)
	return out


## Grupo atacando: em marcha, parado na divisa do próximo estado, que tem inimigos.
static func attack_target(state: GameState, g: ArmyGroup) -> int:
	if not g.moving() or g.regiments.is_empty():
		return -1
	var nxt: int = g.path[0]
	var leg := MapGeo.km(state.state(g.state_id).center, state.state(nxt).center)
	if g.progress_km + 0.001 < leg:
		return -1
	return nxt if not enemy_groups_in(state, nxt, g.owner).is_empty() else -1


static func hourly_update(state: GameState, defs: Dictionary) -> void:
	var cr := rules(defs)
	# 1. Montar as batalhas desta hora.
	var battles := {}
	for g: ArmyGroup in state.groups.values():
		var sid := attack_target(state, g)
		if sid == -1:
			continue
		if not battles.has(sid):
			battles[sid] = {"attackers": [], "defenders": [], "since": state.hours}
		battles[sid].attackers.append(g.id)
	for sid in battles:
		var b: Dictionary = battles[sid]
		var att_owners := {}
		for gid in b.attackers:
			att_owners[state.group(gid).owner] = true
		for g: ArmyGroup in state.groups.values():
			if g.state_id != sid or g.regiments.is_empty() or att_owners.has(g.owner):
				continue
			for t in att_owners:
				if state.at_war(t, g.owner):
					b.defenders.append(g.id)
					break
		if state.battles.has(sid):
			b.since = state.battles[sid].since
		else:
			var att_tags: Array = att_owners.keys()
			var def_tags := _owners(state, b.defenders)
			state.add_event(att_tags + def_tags, "Batalha em %s." % state.state(sid).name, "Guerra")
	state.battles = battles

	# 2. Resolver cada batalha.
	var fighting := {}
	for sid in battles:
		var b: Dictionary = battles[sid]
		_resolve(state, defs, cr, sid, b)
		for gid in b.attackers + b.defenders:
			fighting[gid] = true

	# 3. Quem não lutou recupera organização.
	var regen := float(cr.get("org_regen_per_hour", 1.0))
	var max_org := float(cr.get("max_org", 100))
	for g: ArmyGroup in state.groups.values():
		if fighting.has(g.id):
			continue
		for r in g.regiments:
			r.org = minf(max_org, org_of(defs, r) + regen)


static func _owners(state: GameState, ids: Array) -> Array:
	var out := {}
	for gid in ids:
		var g := state.group(gid)
		if g != null:
			out[g.owner] = true
	return out.keys()


static func _resolve(state: GameState, defs: Dictionary, cr: Dictionary, sid: int, b: Dictionary) -> void:
	var att: Array = b.attackers.map(func(i): return state.group(i))
	var dfn: Array = b.defenders.map(func(i): return state.group(i))
	var p_att := side_power(state, defs, att, dfn, false)
	var p_def := side_power(state, defs, dfn, att, true)
	var share := p_att / maxf(p_att + p_def, 0.001)   # 0–1: quanto do dano vai para o defensor
	var base := float(cr.get("org_loss_per_hour", 4.0))
	var spread := float(cr.get("random_spread", 0.2))
	var loss_def := base * 2.0 * share * (1.0 + state.rng.randf_range(-spread, spread))
	var loss_att := base * 2.0 * (1.0 - share) * (1.0 + state.rng.randf_range(-spread, spread))
	_damage(defs, cr, dfn, loss_def)
	_damage(defs, cr, att, loss_att)

	var brk := float(cr.get("break_org", 15))
	var att_broken := att.all(func(g): return group_broken(defs, g, brk))
	var def_broken := dfn.all(func(g): return group_broken(defs, g, brk))
	var place: String = state.state(sid).name
	var att_tags := _owners(state, b.attackers)
	var def_tags := _owners(state, b.defenders)
	if def_broken:
		for g: ArmyGroup in dfn:
			_retreat(state, g)
		state.add_event(att_tags, "Vencemos a batalha em %s; o inimigo recuou." % place, "Guerra")
		state.add_event(def_tags, "Perdemos a batalha em %s." % place, "Guerra")
		state.battles.erase(sid)
	elif att_broken:
		for g: ArmyGroup in att:
			g.path = []
			g.progress_km = 0.0
		state.add_event(att_tags, "O ataque a %s fracassou; as tropas pararam." % place, "Guerra")
		state.add_event(def_tags, "Seguramos %s; o ataque inimigo fracassou." % place, "Guerra")
		state.battles.erase(sid)


static func group_broken(defs: Dictionary, g: ArmyGroup, brk: float) -> bool:
	for r in g.regiments:
		if org_of(defs, r) > brk:
			return false
	return true


## Força de um lado contra o outro: ataque do equipamento (contra alvos leves ou blindados, na
## proporção de blindados do inimigo), vezes a organização, o general e o bônus de quem defende.
static func side_power(state: GameState, defs: Dictionary, side: Array, enemy: Array, defending: bool) -> float:
	var cr := rules(defs)
	var hard := hardness(defs, enemy)
	var soft_w: Dictionary = cr.get("soft_weights", {"soft_attack": 1.0})
	var hard_w: Dictionary = cr.get("hard_weights", {"hard_attack": 1.0})
	var floor_ := float(cr.get("org_power_floor", 0.4))
	var max_org := float(cr.get("max_org", 100))
	var gen_bonus := float(cr.get("general_bonus_per_level", 0.1))
	var total := 0.0
	for g: ArmyGroup in side:
		var gp := 0.0
		for r in g.regiments:
			var rp := 0.0
			for eq in r.equipment:
				var st: Dictionary = defs.equipment.get(eq, {}).get("stats", {})
				var soft := 0.0
				for k in soft_w:
					soft += float(st.get(k, 0.0)) * float(soft_w[k])
				var hrd := 0.0
				for k in hard_w:
					hrd += float(st.get(k, 0.0)) * float(hard_w[k])
				rp += (soft * (1.0 - hard) + hrd * hard) * float(r.equipment[eq])
			gp += rp * (floor_ + (1.0 - floor_) * org_of(defs, r) / max_org)
		var gen := state.general(g.general_id)
		if gen != null:
			gp *= 1.0 + gen_bonus * ((gen.defense if defending else gen.attack) - 1)
		total += gp
	if defending:
		total *= float(cr.get("defender_bonus", 1.25))
	return total


## Parte blindada do lado (0–1): unidades das categorias blindadas sobre o total de unidades.
static func hardness(defs: Dictionary, side: Array) -> float:
	var hard_cats: Array = rules(defs).get("hard_categories", ["tank"])
	var h := 0.0
	var n := 0.0
	for g: ArmyGroup in side:
		for r in g.regiments:
			for eq in r.equipment:
				var q := float(r.equipment[eq])
				n += q
				if defs.equipment.get(eq, {}).get("category", "") in hard_cats:
					h += q
	return h / n if n > 0.0 else 0.0


## Tira organização de todos os regimentos do lado e um pouco de equipamento (perdas).
static func _damage(defs: Dictionary, cr: Dictionary, side: Array, org_loss: float) -> void:
	var eq_loss := float(cr.get("equipment_loss_per_org", 0.0008)) * org_loss
	for g: ArmyGroup in side:
		for r in g.regiments:
			r.org = maxf(0.0, org_of(defs, r) - org_loss)
			for eq in r.equipment.keys():
				r.equipment[eq] = maxf(0.0, float(r.equipment[eq]) * (1.0 - eq_loss))


## Defensor derrotado: recua para o vizinho mais perto que seu lado controla e que não tem inimigos.
## Sem saída, o grupo é destruído (o equipamento se perde).
static func _retreat(state: GameState, g: ArmyGroup) -> void:
	var here := state.state(g.state_id)
	var best := -1
	var best_km := INF
	for n in state.adjacency.get(g.state_id, []):
		var s := state.state(n)
		if s == null:
			continue
		var ctl := s.control()
		if not (ctl == g.owner or state.allied(g.owner, ctl)):
			continue
		if not enemy_groups_in(state, n, g.owner).is_empty():
			continue
		var km := MapGeo.km(here.center, s.center)
		if km < best_km:
			best_km = km
			best = n
	if best == -1:
		state.add_event([g.owner], "%s foi cercado em %s e destruído." % [g.name, here.name], "Guerra")
		state.groups.erase(g.id)
		return
	g.state_id = best
	g.path = []
	g.progress_km = 0.0


## Ao entrar num estado: se é de um inimigo em guerra (ou é nosso e estava ocupado), passa a ser
## controlado por quem chegou.
static func on_enter(state: GameState, g: ArmyGroup) -> void:
	var s := state.state(g.state_id)
	var ctl := s.control()
	if ctl == g.owner:
		return
	if s.owner == g.owner or state.at_war(g.owner, ctl):
		var before := ctl
		# estado de um aliado ocupado volta para o dono (libertação)
		var friend := s.owner != g.owner and state.allied(g.owner, s.owner)
		state.set_control(s, s.owner if friend else g.owner)
		if s.owner == g.owner or friend:
			state.add_event([g.owner, before, s.owner], "%s foi libertado." % s.name, "Guerra")
			var home := state.country(s.owner)
			if home != null and home.capital_state == s.id:
				var city := home.capital_city if home.capital_city != "" else s.name
				state.add_news("%s é libertada" % city, "Tropas %s expulsam o ocupante." % NewsText.of(state.country(g.owner).name),
					"Multidões foram às ruas de %s para receber as forças %s, que retomaram a capital %s." % [city,
						NewsText.of(state.country(g.owner).name), NewsText.of(home.name)], s.id, [g.owner, s.owner], "Guerra")
		else:
			state.add_event([g.owner, before], "%s ocupou %s." % [state.country(g.owner).name, s.name], "Guerra")
			var victim := state.country(s.owner)
			if victim != null and victim.capital_state == s.id:
				var me := state.country(g.owner)
				state.add_news("%s cai: tropas %s tomam a capital" % [victim.capital_city if victim.capital_city != "" else s.name, NewsText.of(me.name)],
					"Golpe duro para %s; o governo foge." % NewsText.the(victim.name),
					"Depois de dias de combate, as forças %s entraram em %s, capital %s." % [NewsText.of(me.name),
						victim.capital_city if victim.capital_city != "" else s.name, NewsText.of(victim.name)],
					s.id, [g.owner, s.owner], "Guerra")
