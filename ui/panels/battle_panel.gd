class_name BattlePanel
extends PanelContainer
## Ficha da batalha: os dois lados com força, moral (a "vida" das tropas), tropas e baixas,
## quem leva vantagem e a previsão de quando um lado cede. Atualiza sozinha enquanto está aberta.
## Depois que a batalha acaba, mostra o resultado com as baixas.

var _main
var sid := -1
var _title: Label
var _sub: Label
var _sides: HBoxContainer
var _middle: VBoxContainer
var _tick := 0.0


func setup(main) -> void:
	_main = main
	UiStyle.place(self, 640)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	var h := UiStyle.header("Batalha", func(): visible = false, "")
	v.add_child(h)
	v.add_child(UiStyle.rule())
	_title = h.get_child(0)
	_title.mouse_filter = Control.MOUSE_FILTER_STOP
	_title.tooltip_text = ("Cada hora os dois lados perdem moral. Quem tem mais força tira mais moral do outro.\n"
		+ "Cada ponto de moral perdido custa baixas (soldados e veículos mortos).\n"
		+ "Quando a moral de todas as tropas de um lado cai abaixo de 15%, ele perde:\n"
		+ "o defensor recua para um estado vizinho (sem saída, é destruído) e o atacante para.\n"
		+ "Força = armas do modelo x quantidade x moral x general; quem defende ganha +25%.")
	_sub = UiStyle.dim_label("")
	v.add_child(_sub)
	_middle = VBoxContainer.new()
	_middle.add_theme_constant_override("separation", 6)
	v.add_child(_middle)
	_sides = HBoxContainer.new()
	_sides.add_theme_constant_override("separation", 16)
	v.add_child(_sides)
	var go := Button.new()
	go.text = "Ir até a batalha"
	go.pressed.connect(func():
		if sid != -1:
			_main.camera.position = _main.camera.near(_main.sim.state.state(sid).center))
	v.add_child(go)
	visible = false


func open(p_sid: int) -> void:
	sid = p_sid
	visible = true
	refresh()


func _process(delta: float) -> void:
	if not visible:
		return
	_tick += delta
	if _tick >= 0.25:
		_tick = 0.0
		refresh()


func refresh() -> void:
	if not visible or sid == -1:
		return
	var st: GameState = _main.sim.state
	var defs: Dictionary = _main.sim.defs
	var place := st.state(sid).name
	_title.text = ("Batalha de " + place).to_upper()
	UiStyle.clear(_middle)
	UiStyle.clear(_sides)
	if st.battles.has(sid):
		var b: Dictionary = st.battles[sid]
		var att: Array = b.attackers.map(func(i): return st.group(i)).filter(func(g): return g != null)
		var dfn: Array = b.defenders.map(func(i): return st.group(i)).filter(func(g): return g != null)
		var hours := st.hours - int(b.since)
		_sub.text = "Em andamento há %s" % _duration(hours)
		var share := float(b.p_att) / maxf(float(b.p_att) + float(b.p_def), 0.001)
		_advantage(share, att, dfn)
		var f := CombatSystem.forecast(st, defs, att, sid)
		if not f.defenders.is_empty():
			var who := "o defensor recua" if f.winner == "att" else "o ataque fracassa"
			var col := UiStyle.GOOD if (f.winner == "att") == _player_attacks(att) else UiStyle.BAD
			_middle.add_child(UiStyle.small_label("Previsão: %s em ~%s." % [who, _duration(roundi(f.hours))], 14, col))
			if _player_attacks(att) and int(f.soldiers_needed) > 0:
				_middle.add_child(UiStyle.small_label("Para vencer com folga, mande mais ~%s soldados." % UiStyle.num(f.soldiers_needed), 13, UiStyle.WARN))
		_sides.add_child(_side_box("Atacante", att, b.dead_att, float(b.p_att), float(b.loss_att)))
		_sides.add_child(_side_box("Defensor", dfn, b.dead_def, float(b.p_def), float(b.loss_def)))
	elif st.battle_results.has(sid):
		var r: Dictionary = st.battle_results[sid]
		var won: String = "o atacante" if r.winner == "att" else "o defensor"
		_sub.text = "Encerrada há %s · venceu %s · durou %s" % [_duration(st.hours - int(r.ended)), won, _duration(int(r.ended) - int(r.since))]
		_middle.add_child(UiStyle.small_label("Baixas do atacante (%s): %s" % [_names(r.att_tags), CombatSystem.dead_text(defs, r.dead_att)], 14))
		_middle.add_child(UiStyle.small_label("Baixas do defensor (%s): %s" % [_names(r.def_tags), CombatSystem.dead_text(defs, r.dead_def)], 14))
	else:
		_sub.text = "Não há batalha aqui."


func _player_attacks(att: Array) -> bool:
	return att.any(func(g): return g.owner == _main.player_tag)


func _advantage(share: float, att: Array, dfn: Array) -> void:
	var st: GameState = _main.sim.state
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_middle.add_child(row)
	row.add_child(UiStyle.number_label("%d%%" % roundi(share * 100), 18, st.country(att[0].owner).color.lightened(0.2) if not att.is_empty() else UiStyle.TEXT))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 0)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(bar)
	var a := ColorRect.new()
	a.color = st.country(att[0].owner).color if not att.is_empty() else UiStyle.MUTED
	a.custom_minimum_size = Vector2(0, 12)
	a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	a.size_flags_stretch_ratio = maxf(share, 0.01)
	bar.add_child(a)
	var d := ColorRect.new()
	d.color = st.country(dfn[0].owner).color if not dfn.is_empty() else UiStyle.MUTED
	d.custom_minimum_size = Vector2(0, 12)
	d.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	d.size_flags_stretch_ratio = maxf(1.0 - share, 0.01)
	bar.add_child(d)
	row.add_child(UiStyle.number_label("%d%%" % (100 - roundi(share * 100)), 18, st.country(dfn[0].owner).color.lightened(0.2) if not dfn.is_empty() else UiStyle.TEXT))
	_middle.add_child(UiStyle.dim_label("Parte da força total de cada lado: quem tem mais tira mais moral do outro a cada hora."))


func _side_box(label: String, side: Array, dead: Dictionary, power: float, loss_per_hour: float) -> Control:
	var st: GameState = _main.sim.state
	var defs: Dictionary = _main.sim.defs
	var box := PanelContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.BG_DARK, Color(UiStyle.ACCENT, 0.2), 1, 4, 10))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 5)
	box.add_child(v)
	v.add_child(UiStyle.small_label(label.to_upper(), 12, UiStyle.ACCENT))
	var owners := {}
	for g in side:
		owners[g.owner] = true
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	if not owners.is_empty():
		var fb := UiStyle.flag_box(Vector2(36, 24))
		UiStyle.set_flag(fb, owners.keys()[0], st.country(owners.keys()[0]).color)
		head.add_child(fb)
	head.add_child(UiStyle.title_label(_names(owners.keys()), 16, UiStyle.TEXT))
	# moral
	var org := UnitLayer._side_org(defs, side)
	v.add_child(UiStyle.small_label("Moral (vida da tropa): %d%%  ·  perdendo %s por hora" % [roundi(org * 100), ("%.1f" % loss_per_hour).replace(".", ",")], 12))
	var pb := ProgressBar.new()
	pb.max_value = 1.0
	pb.value = org
	pb.show_percentage = false
	pb.custom_minimum_size = Vector2(0, 10)
	var fill := StyleBoxFlat.new()
	fill.bg_color = UnitLayer.moral_color(org)
	pb.add_theme_stylebox_override("fill", fill)
	v.add_child(pb)
	v.add_child(UiStyle.small_label("Cede abaixo de %d%%" % int(CombatSystem.rules(defs).get("break_org", 15)), 11, UiStyle.MUTED))
	var pw := UiStyle.rich()
	pw.text = UiStyle.kv("Força de combate", power_text(power))
	v.add_child(pw)
	# tropas e baixas
	var counts := {}
	for g: ArmyGroup in side:
		for t in g.types():
			counts[t] = float(counts.get(t, 0.0)) + g.count_of(t)
	for t in ["infantaria", "artilharia", "tanques", "avioes"]:
		if float(counts.get(t, 0.0)) < 0.5 and float(dead.get(t, 0.0)) < 0.5:
			continue
		var r := UiStyle.rich()
		var lost := roundi(float(dead.get(t, 0.0)))
		r.text = "%d %s%s" % [roundi(float(counts.get(t, 0.0))), ArmySystem.troop_def(defs, t).get("short", t),
			("  [color=#d9503c]−%d mortos[/color]" % lost) if lost > 0 else ""]
		v.add_child(r)
	var gens := []
	for g: ArmyGroup in side:
		var gen := st.general(g.general_id)
		if gen != null:
			gens.append("%s (atq %d, def %d)" % [gen.name, gen.attack, gen.defense])
	v.add_child(UiStyle.small_label("General: " + (", ".join(gens) if not gens.is_empty() else "nenhum"), 12, UiStyle.MUTED))
	return box


func _names(tags: Array) -> String:
	var st: GameState = _main.sim.state
	return ", ".join(tags.map(func(t): return st.country(t).name))


## Força para mostrar na tela (x10, para não aparecerem números pequenos demais).
static func power_text(p: float) -> String:
	return UiStyle.num(roundf(p * 10.0))


static func _duration(hours: int) -> String:
	if hours < 24:
		return "%d horas" % hours if hours != 1 else "1 hora"
	var d := float(hours) / 24.0
	return ("%.1f dias" % d).replace(".", ",")
