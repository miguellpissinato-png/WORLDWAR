class_name PeaceDialog
extends Control
## Janela de paz: propor paz a um inimigo (pedindo dinheiro, estados e recursos, ou nada) e
## responder a uma proposta recebida.

var _main
var _box: VBoxContainer
var _target := ""
var _money: SpinBox
var _res := {}          # recurso -> SpinBox
var _checks := {}       # estado -> CheckBox
var _forecast: Label
var _status: Label


func setup(main) -> void:
	_main = main
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiStyle.scrim(0.55))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var p := UiStyle.panel(22)
	p.custom_minimum_size = Vector2(620, 0)
	center.add_child(p)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	p.add_child(_box)
	visible = false


func _header(tag: String, kicker: String, title: String) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	_box.add_child(h)
	var fb := UiStyle.flag_box(Vector2(66, 44))
	UiStyle.set_flag(fb, tag, _main.sim.state.country(tag).color)
	h.add_child(fb)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(UiStyle.small_label(kicker.to_upper(), 12, UiStyle.ACCENT))
	v.add_child(UiStyle.title_label(title, 24, UiStyle.TEXT))
	_box.add_child(UiStyle.rule())


func _war_line(me: String, them: String) -> void:
	var st: GameState = _main.sim.state
	var score := PeaceSystem.war_score(st, _main.sim.defs, me, them)
	var txt := "equilibrada"
	var col := UiStyle.WARN
	if score > 0.15:
		txt = "a nosso favor"
		col = UiStyle.GOOD
	elif score < -0.15:
		txt = "contra nós"
		col = UiStyle.BAD
	var occ_us := roundi(PeaceSystem.occupied_share(st, me, them) * 100)
	var occ_them := roundi(PeaceSystem.occupied_share(st, them, me) * 100)
	_box.add_child(UiStyle.small_label("A guerra está %s. Ocupamos %d%% %s; eles ocupam %d%% do nosso território. %d meses de guerra." % [
		txt, occ_us, NewsText.of(st.country(them).name), occ_them, roundi(PeaceSystem.war_months(st, me, them))], 13, col))


# ---------------------------------------------------------------- propor

func open_proposal(tag: String) -> void:
	_target = tag
	UiStyle.clear(_box)
	var st: GameState = _main.sim.state
	var defs: Dictionary = _main.sim.defs
	var me: String = _main.player_tag
	_header(tag, "Proposta de paz", st.country(tag).name)
	_war_line(me, tag)
	_box.add_child(UiStyle.dim_label("Peça o que quiser em troca da paz, ou nada. Quanto mais pedir, mais a guerra precisa estar a seu favor."))

	_box.add_child(UiStyle.section("Dinheiro"))
	_money = SpinBox.new()
	_money.max_value = 1000000
	_money.step = 50
	_money.prefix = defs.currency
	_money.custom_minimum_size = Vector2(160, 0)
	_money.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_money.value_changed.connect(func(_v): _update_forecast())
	_box.add_child(_money)

	_box.add_child(UiStyle.section("Recursos"))
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 14)
	_box.add_child(grid)
	_res = {}
	for r in defs.resources:
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 6)
		h.add_child(UiStyle.icon(r.id, Color(r.color), 16))
		var sb := SpinBox.new()
		sb.max_value = 100000
		sb.step = 10
		sb.custom_minimum_size = Vector2(110, 0)
		sb.tooltip_text = r.name
		sb.value_changed.connect(func(_v): _update_forecast())
		h.add_child(sb)
		grid.add_child(h)
		_res[r.id] = sb

	_box.add_child(UiStyle.section("Território"))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 130)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box.add_child(scroll)
	var list := GridContainer.new()
	list.columns = 2
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)
	_checks = {}
	var options := _state_options(me, tag)
	if options.is_empty():
		list.add_child(UiStyle.dim_label("Nenhum estado %s perto das nossas linhas." % NewsText.of(st.country(tag).name)))
	for s: MapState in options:
		var cb := CheckBox.new()
		cb.text = s.name + ("  (ocupado por nós)" if s.control() == me else "")
		cb.custom_minimum_size = Vector2(280, 0)
		cb.toggled.connect(func(_on): _update_forecast())
		list.add_child(cb)
		_checks[s.id] = cb

	_forecast = UiStyle.small_label("", 13)
	_box.add_child(_forecast)
	_status = UiStyle.small_label("", 13, UiStyle.ACCENT)
	_box.add_child(_status)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	_box.add_child(row)
	var cancel := Button.new()
	cancel.text = "Fechar"
	cancel.custom_minimum_size = Vector2(110, 40)
	cancel.pressed.connect(func(): visible = false)
	row.add_child(cancel)
	var white := Button.new()
	white.text = "Paz sem exigências"
	white.custom_minimum_size = Vector2(170, 40)
	white.pressed.connect(func(): _send(true))
	row.add_child(white)
	var send := UiStyle.primary_button("Enviar proposta", 40)
	send.custom_minimum_size = Vector2(180, 40)
	send.pressed.connect(func(): _send(false))
	row.add_child(send)
	_update_forecast()
	visible = true


## Estados do inimigo que dá para pedir: os que ocupamos e os vizinhos das nossas linhas.
func _state_options(me: String, them: String) -> Array:
	var st: GameState = _main.sim.state
	var out := []
	for s: MapState in st.states.values():
		if s.owner != them:
			continue
		var ok := s.control() == me
		if not ok:
			for n in st.adjacency.get(s.id, []):
				var ns := st.state(n)
				if ns != null and ns.control() == me:
					ok = true
					break
		if ok:
			out.append(s)
	out.sort_custom(func(a, b): return (a.control() == me and b.control() != me) or (a.control() == b.control() and a.name < b.name))
	return out.slice(0, 60)


func _terms() -> Dictionary:
	var states := []
	for sid in _checks:
		if _checks[sid].button_pressed:
			states.append(sid)
	var res := {}
	for r in _res:
		if _res[r].value > 0:
			res[r] = _res[r].value
	return {"money": _money.value, "states": states, "resources": res}


func _update_forecast() -> void:
	var st: GameState = _main.sim.state
	if _target in st.human_tags:
		_forecast.text = "%s é de um jogador: ele decide." % st.country(_target).name
		_forecast.add_theme_color_override("font_color", UiStyle.MUTED)
		return
	var t := _terms()
	var o := {"from": _main.player_tag, "to": _target, "money": t.money, "states": t.states, "resources": t.resources}
	var yes := PeaceSystem.ai_accepts(st, _main.sim.defs, o)
	_forecast.text = "Previsão: devem aceitar." if yes else "Previsão: devem recusar. Peça menos ou avance na guerra."
	_forecast.add_theme_color_override("font_color", UiStyle.GOOD if yes else UiStyle.BAD)


func _send(white: bool) -> void:
	var st: GameState = _main.sim.state
	var t := {"money": 0.0, "states": [], "resources": {}} if white else _terms()
	var cmd := ProposePeaceCommand.create(_main.player_tag, _target, t.money, t.states, t.resources)
	var why := cmd.validate(st, _main.sim.defs)
	if why != "":
		_status.text = why
		return
	_main.submit(cmd)
	if _main.mp and not Net.is_host:
		_status.text = "Proposta enviada."
	elif not st.at_war(_main.player_tag, _target):
		_status.text = "Paz assinada com %s!" % st.country(_target).name
		_status.add_theme_color_override("font_color", UiStyle.GOOD)
	elif not PeaceSystem.pending(st, _main.player_tag, _target).is_empty():
		_status.text = "Proposta enviada; aguardando a resposta."
	else:
		_status.text = "%s recusou a proposta." % st.country(_target).name
		_status.add_theme_color_override("font_color", UiStyle.BAD)
	_main._refresh_all()


# ---------------------------------------------------------------- responder

func open_incoming(o: Dictionary) -> void:
	UiStyle.clear(_box)
	var st: GameState = _main.sim.state
	var defs: Dictionary = _main.sim.defs
	_header(o.from, "Proposta de paz recebida", st.country(o.from).name)
	_war_line(_main.player_tag, o.from)
	var t := UiStyle.rich(570)
	t.text = "%s quer encerrar a guerra.\n[b]Termos:[/b] %s" % [NewsText.the(st.country(o.from).name, true),
		PeaceSystem.describe(st, defs, o).replace("paz sem exigências", "paz sem exigências (ninguém paga nada)")]
	_box.add_child(t)
	_box.add_child(UiStyle.dim_label("Aceitando, a guerra entre os dois acaba, as ocupações são desfeitas e você paga os termos (até o que tiver)."))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_END
	_box.add_child(row)
	var later := Button.new()
	later.text = "Decidir depois"
	later.custom_minimum_size = Vector2(140, 40)
	later.pressed.connect(func(): visible = false)
	row.add_child(later)
	var no := Button.new()
	no.text = "Recusar"
	no.custom_minimum_size = Vector2(120, 40)
	var id := int(o.id)
	no.pressed.connect(func():
		_main.submit(RespondPeaceCommand.create(_main.player_tag, id, false))
		visible = false
		_main._refresh_all())
	row.add_child(no)
	var yes := UiStyle.primary_button("Aceitar a paz", 40)
	yes.custom_minimum_size = Vector2(160, 40)
	yes.pressed.connect(func():
		_main.submit(RespondPeaceCommand.create(_main.player_tag, id, true))
		visible = false
		_main._refresh_all())
	row.add_child(yes)
	visible = true
