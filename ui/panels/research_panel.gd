class_name ResearchPanel
extends PanelContainer
## Pesquisa: vagas em andamento no topo, abas por área (armas, tropas, blindados, aviação, artilharia),
## a lista de tecnologias da área e, à direita, a ficha da tecnologia escolhida
## (dados históricos com fontes e os valores usados no jogo).

var _main
var _area := "armas"
var _selected := ""
var _area_buttons := {}
var _slots: VBoxContainer
var _list: VBoxContainer
var _detail: RichTextLabel
var _go: Button


func setup(main) -> void:
	_main = main
	add_theme_stylebox_override("panel", UiStyle.panel().get_theme_stylebox("panel"))
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -330
	offset_right = 610
	offset_top = 64
	visible = false

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	v.add_child(UiStyle.header("Pesquisa", func(): visible = false))
	_slots = VBoxContainer.new()
	_slots.add_theme_constant_override("separation", 4)
	v.add_child(_slots)

	var tabs := HBoxContainer.new()
	v.add_child(tabs)
	for a in main.sim.defs.research.areas:
		var b := Button.new()
		b.text = a.name
		var id: String = a.id
		b.pressed.connect(func():
			_area = id
			_selected = ""
			refresh())
		tabs.add_child(b)
		_area_buttons[id] = b

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	v.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(450, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_list)

	var right := VBoxContainer.new()
	body.add_child(right)
	_detail = RichTextLabel.new()
	_detail.bbcode_enabled = true
	_detail.custom_minimum_size = Vector2(440, 360)
	_detail.meta_clicked.connect(func(meta): OS.shell_open(str(meta)))
	right.add_child(_detail)
	_go = Button.new()
	_go.clip_text = true
	_go.custom_minimum_size = Vector2(440, 0)
	_go.pressed.connect(func():
		if _selected != "":
			_main.submit(StartResearchCommand.create(_main.player_tag, _selected)))
	right.add_child(_go)


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	if not visible:
		return
	var sim: Simulation = _main.sim
	var c: Country = sim.state.country(_main.player_tag)
	for id in _area_buttons:
		_area_buttons[id].modulate = UiStyle.ACCENT if id == _area else Color(1, 1, 1, 0.7)

	# Vagas
	for ch in _slots.get_children():
		ch.queue_free()
	var head := UiStyle.section("Vagas de pesquisa: %d de %d em uso" % [c.research.size(), c.research_slots])
	_slots.add_child(head)
	for r in c.research:
		var t := ResearchSystem.tech(sim.defs, r.tech)
		var h := HBoxContainer.new()
		var name_l := Label.new()
		name_l.text = t.get("name", r.tech)
		name_l.custom_minimum_size = Vector2(300, 0)
		h.add_child(name_l)
		var bar := ProgressBar.new()
		bar.max_value = float(r.days)
		bar.value = float(r.progress)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(260, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bar)
		var left := Label.new()
		left.text = "  faltam %d dias" % maxi(0, int(ceil(float(r.days) - float(r.progress))))
		left.custom_minimum_size = Vector2(130, 0)
		h.add_child(left)
		var cancel := Button.new()
		cancel.text = "Cancelar"
		var tid: String = r.tech
		cancel.pressed.connect(func(): _main.submit(CancelResearchCommand.create(_main.player_tag, tid)))
		h.add_child(cancel)
		_slots.add_child(h)

	# Lista da área, por ano
	for ch in _list.get_children():
		ch.queue_free()
	var ids: Array = []
	var techs: Dictionary = sim.defs.research.techs
	for id in techs:
		if techs[id].area == _area:
			ids.append(id)
	ids.sort_custom(func(a, b):
		var ya := int(techs[a].year)
		var yb := int(techs[b].year)
		return ya < yb if ya != yb else str(techs[a].name) < str(techs[b].name))
	if _selected == "" and not ids.is_empty():
		_selected = ids[0]
	for id in ids:
		_list.add_child(_row(id, techs[id], c))
	_show_detail()


func _status(id: String, c: Country) -> String:
	if c.has_tech(id):
		return "pesquisada"
	if ResearchSystem.in_progress(c, id):
		return "em andamento"
	return ""


func _row(id: String, t: Dictionary, c: Country) -> Button:
	var sim: Simulation = _main.sim
	var b := Button.new()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.clip_text = true
	var st := _status(id, c)
	var origin := ""
	if not t.get("origin", []).is_empty():
		origin = " (%s)" % t.origin[0]
	var tail := st
	if st == "":
		var max_ahead := int(ResearchSystem.rules(sim.defs).get("max_years_ahead", 2))
		if ResearchSystem.years_ahead(sim.state, t) > max_ahead:
			tail = "a partir de %d" % (int(t.year) - max_ahead)
		else:
			tail = "%d dias" % ResearchSystem.days_needed(sim.state, sim.defs, c.tag, id)
	b.text = "%d  %s%s  ·  %s" % [int(t.year), t.name, origin, tail]
	b.tooltip_text = b.text
	if st == "pesquisada":
		b.modulate = UiStyle.GOOD
	elif st == "" and ResearchSystem.can_start(sim.state, sim.defs, c.tag, id) not in ["", "todas as vagas de pesquisa estão ocupadas", "dinheiro insuficiente"]:
		b.modulate = Color(1, 1, 1, 0.45)
	if id == _selected:
		b.add_theme_color_override("font_color", UiStyle.ACCENT)
	b.pressed.connect(func():
		_selected = id
		refresh())
	return b


func _show_detail() -> void:
	var sim: Simulation = _main.sim
	var c: Country = sim.state.country(_main.player_tag)
	var a := UiStyle.ACCENT_HEX
	if _selected == "":
		_detail.text = ""
		_go.visible = false
		return
	var t := ResearchSystem.tech(sim.defs, _selected)
	var s := "[font_size=17][color=%s]%s[/color][/font_size]\n" % [a, t.name]
	var meta := "Ano histórico: %d" % int(t.year)
	if "year" in t.get("estimated", []):
		meta += " (a conferir)"
	if not t.get("origin", []).is_empty():
		var oc: Country = sim.state.country(t.origin[0])
		meta += "   ·   Projeto: %s" % (oc.name if oc else t.origin[0])
	s += "[color=#999]%s[/color]\n" % meta
	if t.has("desc"):
		s += t.desc + "\n"
	var reqs: Array = t.get("requires", [])
	if not reqs.is_empty():
		var names: Array = []
		for r in reqs:
			var ok := c.has_tech(r)
			names.append("[color=%s]%s[/color]" % ["#8c8" if ok else "#d88", ResearchSystem.tech(sim.defs, r).get("name", r)])
		s += "Requer: %s\n" % ", ".join(names)
	var days := ResearchSystem.days_needed(sim.state, sim.defs, c.tag, _selected)
	var notes: Array = []
	var ahead := ResearchSystem.years_ahead(sim.state, t)
	if ahead > 0:
		notes.append("%d ano(s) antes da época" % ahead)
	if ResearchSystem.is_foreign(t, c.tag):
		notes.append("projeto estrangeiro")
	s += "Tempo: [color=%s]%d dias[/color] (base %d%s)   Custo: [color=%s]%s[/color]\n" % [
		a, days, int(t.days), (": " + ", ".join(notes)) if not notes.is_empty() else "",
		a, UiStyle.money(float(t.money_cost), sim.defs.currency)]
	for eq in t.get("unlocks_equipment", []):
		s += "\n" + equipment_sheet(sim.defs, eq)
	_detail.text = s
	var st := _status(_selected, c)
	_go.visible = st == ""
	var why := ResearchSystem.can_start(sim.state, sim.defs, c.tag, _selected)
	_go.disabled = why != ""
	_go.text = "Pesquisar" if why == "" else "Pesquisar (%s)" % why


const STAT_NAMES := {
	"soft_attack": "Ataque contra infantaria", "close_attack": "Ataque de perto", "practical_rpm": "Cadência prática (tiros/min)",
	"range_m": "Alcance (m)", "hard_attack": "Ataque contra blindados", "penetration_mm": "Perfuração estimada (mm)",
	"effective_armour_mm": "Blindagem frontal efetiva (mm)", "armour": "Blindagem", "speed_kmh": "Velocidade (km/h)",
	"air_attack": "Ataque aéreo", "ground_attack": "Ataque ao solo", "bomb_kg": "Bombas (kg)", "range_km": "Alcance (km)",
	"casualty_radius_m": "Raio de baixas (m)", "shell_kg": "Projétil (kg)",
}
const HIST_NAMES := {
	"calibre": "Calibre", "action": "Ação", "feed": "Alimentação", "magazine": "Capacidade", "scope": "Luneta",
	"cyclic_rpm": "Cadência cíclica", "cyclic_note": "Cadência", "range_m": "Alcance efetivo (m)", "range_note": "Alcance",
	"velocity_ms": "Velocidade na boca (m/s)", "aimed_rpm_note": "Tiro mirado", "gun": "Canhão", "ammo": "Munição a bordo",
	"weight_t": "Peso (t)", "speed_kmh": "Velocidade máx. (km/h)", "speed_note": "Velocidade", "crew": "Tripulação",
	"armour_mm": "Blindagem frontal (mm)", "armour_note": "Blindagem", "slope_deg": "Inclinação (graus)",
	"guns_text": "Armamento", "bomb_kg": "Bombas (kg)", "bomb_note": "Bombas", "range_km": "Alcance (km)",
	"engines": "Motores", "calibre_mm": "Calibre (mm)", "shell_kg": "Projétil explosivo (kg)",
	"filling_kg": "Carga explosiva (kg)", "rpm": "Tiros por minuto", "rpm_note": "Cadência", "weight_kg": "Peso em ação (kg)",
	"built": "Unidades fabricadas", "built_note": "Fabricação", "unit_cost": "Custo unitário",
}


## Ficha de um equipamento: histórico (com fontes e o que falta conferir) + valores de jogo.
static func equipment_sheet(defs: Dictionary, eq: String) -> String:
	var e: Dictionary = defs.equipment.get(eq, {})
	if e.is_empty():
		return ""
	var a := UiStyle.ACCENT_HEX
	var est: Array = e.get("estimated", [])
	var s := "[color=%s]%s — %s[/color]\n" % [a, e.category_name, e.unit]
	for k in e.history:
		var v = e.history[k]
		v = UiStyle.num(v) if k == "built" and v is float else _fmt(v)
		var mark := " [color=#d9a640](a conferir)[/color]" if k in est else ""
		s += "  %s: %s%s\n" % [HIST_NAMES.get(k, k), str(v), mark]
	s += "[color=%s]No jogo[/color]\n" % a
	for k in e.stats:
		s += "  %s: %s\n" % [STAT_NAMES.get(k, k), _fmt(e.stats[k])]
	var res: Array = []
	for r in e.resources:
		res.append("%s %s" % [_fmt(e.resources[r]), _res_name(defs, r)])
	s += "  Produção: %s dias-fábrica por %s; %s\n" % [_fmt(e.cost), e.unit, ", ".join(res)]
	var links: Array = []
	for i in e.sources.size():
		links.append("[url=%s]%d[/url]" % [e.sources[i], i + 1])
	s += "[color=#999]Fontes: %s[/color]\n" % "  ".join(links)
	return s


## Número no formato brasileiro (vírgula decimal); inteiros sem casas.
static func _fmt(v) -> String:
	if v is float:
		return str(int(v)) if v == floor(v) else str(v).replace(".", ",")
	return str(v)


static func _res_name(defs: Dictionary, id: String) -> String:
	for r in defs.resources:
		if r.id == id:
			return str(r.name).to_lower()
	return id
