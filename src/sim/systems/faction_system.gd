class_name FactionSystem
extends RefCounted
## Alianças (facções). Membros da mesma facção são aliados: passam pelas terras uns dos outros e
## entram juntos nas guerras (DiplomacySystem.declare). As facções históricas e as datas de entrada
## estão em `factions` de data/common/ai.json; os países da IA seguem essas datas.


static func can_join(state: GameState, tag: String, id: String) -> String:
	if state.country(tag) == null or not state.factions.has(id):
		return "aliança desconhecida"
	var cur := state.faction_of(tag)
	if cur == id:
		return "já fazemos parte desta aliança"
	if cur != "":
		return "saia da aliança atual antes"
	for m in state.factions[id].members:
		if state.at_war(tag, m):
			return "estamos em guerra com %s" % state.country(m).name
	return ""


static func join(state: GameState, tag: String, id: String) -> void:
	var f: Dictionary = state.factions[id]
	f.members.append(tag)
	var c := state.country(tag)
	state.add_event(f.members, "%s entrou para a aliança %s." % [c.name, f.name], "Diplomacia")
	state.add_news("%s adere %s" % [NewsText.the(c.name, true), NewsText.to(f.name)],
		"Pacto amplia a aliança liderada %s." % NewsText.by(state.country(f.leader).name),
		"O governo %s assinou o tratado que o une aos países %s: %s." % [NewsText.of(c.name), NewsText.of(f.name),
			", ".join(f.members.map(func(t): return state.country(t).name))],
		c.capital_state, [tag], "Diplomacia")
	# Entra nas guerras da aliança.
	for m in f.members:
		if m == tag:
			continue
		for enemy in state.enemies_of(m):
			if not state.at_war(tag, enemy) and not state.allied(tag, enemy):
				DiplomacySystem.start_war(state, tag, enemy)
	state.invalidate_owners()


static func leave(state: GameState, tag: String) -> void:
	var id := state.faction_of(tag)
	if id == "":
		return
	var f: Dictionary = state.factions[id]
	f.members.erase(tag)
	state.add_event([tag] + f.members, "%s deixou a aliança %s." % [state.country(tag).name, f.name], "Diplomacia")
	if f.members.is_empty() or f.leader == tag:
		state.factions.erase(id)


## Cria as facções nas datas previstas e põe os países da IA nelas (diariamente).
static func daily_update(state: GameState, defs: Dictionary) -> void:
	var ym := _ym(state)
	for fd in defs.get("ai", {}).get("factions", []):
		var leader: String = fd.leader
		if state.country(leader) == null:
			continue
		if not state.factions.has(fd.id):
			if ym < String(fd.from) or state.faction_of(leader) != "" or leader in state.human_tags:
				continue
			if fd.id in state.factions_created:
				continue
			state.factions[fd.id] = {"name": fd.name, "leader": leader, "members": [leader]}
			state.factions_created.append(fd.id)
			var c := state.country(leader)
			state.add_news("%s %s" % ["Nascem" if NewsText.art(fd.name) in ["os", "as"] else "Nasce", NewsText.the(fd.name)], "%s lidera a nova aliança." % NewsText.the(c.name, true),
				"Diplomatas confirmaram hoje a criação %s, uma aliança militar liderada %s." % [NewsText.of(fd.name), NewsText.by(c.name)],
				c.capital_state, [leader], "Diplomacia")
		for m in fd.members:
			var tag: String = m.tag
			if tag in state.human_tags or state.country(tag) == null or ym < String(m.from):
				continue
			if m.has("if_at_war_with"):
				var other: Dictionary = state.factions.get(m.if_at_war_with, {})
				if other.is_empty() or not other.members.any(func(x): return state.at_war(tag, x)):
					continue
			if state.factions.has(fd.id) and can_join(state, tag, fd.id) == "":
				join(state, tag, fd.id)


static func _ym(state: GameState) -> String:
	var d := GameDate.from_hours(state.hours)
	return "%04d-%02d" % [d.year, d.month]
