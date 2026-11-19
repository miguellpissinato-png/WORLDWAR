class_name ResearchPanel
extends PanelContainer
## Pesquisa: vagas em andamento no topo, abas por área (armas, tropas, blindados, aviação, artilharia),
## a lista de tecnologias da área e, à direita, a ficha da tecnologia escolhida
## (dados históricos com fontes e os valores usados no jogo).

var _main
var _area := "armas"
var _show_foreign := false
var _foreign_toggle: CheckBox
var _selected := ""
var _area_buttons := {}
var _slots: VBoxContainer
var _list: VBoxContainer
var _detail: RichTextLabel
var _sheet: RichTextLabel
var _go: Button


func setup(main) -> void:
	_main = main
	UiStyle.place(self, 900)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	UiStyle.window_header(v, "Pesquisa", "", func(): visible = false,
		"Cada vaga pesquisa uma tecnologia por vez.\nAntes do ano histórico leva mais tempo (até 2 anos antes).\n"
		+ "Projetos de outros países também levam mais tempo.")
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
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	tabs.add_child(sp)
	_foreign_toggle = CheckBox.new()
	_foreign_toggle.text = "Projetos de outros países"
	_foreign_toggle.toggled.connect(func(on):
		_show_foreign = on
		refresh())
	tabs.add_child(_foreign_toggle)

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 12)
	v.add_child(body)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(420, 400)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 3)
	scroll.add_child(_list)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	body.add_child(right)
	_detail = UiStyle.rich(440)
	right.add_child(_detail)
	_go = Button.new()
	_go.clip_text = true
	_go.custom_minimum_size = Vector2(440, 0)
	_go.pressed.connect(func():
		if _selected != "":
			_main.submit(StartResearchCommand.create(_main.player_tag, _selected)))
	right.add_child(_go)
	var full := UiStyle.details(right, "Ficha completa (dados históricos e fontes)", "Esconder ficha")
	var fscroll := ScrollContainer.new()
	fscroll.custom_minimum_size = Vector2(440, 210)
	fscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	full.add_child(fscroll)
	_sheet = RichTextLabel.new()
	_sheet.bbcode_enabled = true
	_sheet.fit_content = true
	_sheet.custom_minimum_size = Vector2(420, 0)
	_sheet.meta_clicked.connect(func(meta): OS.shell_open(str(meta)))
	fscroll.add_child(_sheet)


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
	if c.research.is_empty():
		_slots.add_child(UiStyle.dim_label("%d vagas livres. Escolha uma tecnologia." % c.research_slots))
	for r in c.research:
		var t := ResearchSystem.tech(sim.defs, r.tech)
		var h := HBoxContainer.new()
		var name_l := Label.new()
		name_l.text = t.get("name", r.tech)
		name_l.custom_minimum_size = Vector2(300, 0)
		name_l.clip_text = true
		h.add_child(name_l)
		var bar := ProgressBar.new()
		bar.max_value = float(r.days)
		bar.value = float(r.progress)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(260, 14)
		bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		h.add_child(bar)
		var left := Label.new()
		left.text = "  %d dias" % maxi(0, int(ceil(float(r.days) - float(r.progress))))
		left.custom_minimum_size = Vector2(80, 0)
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
	var own := 0
	for id in techs:
		if techs[id].area == _area and not ResearchSystem.is_foreign(techs[id], c.tag):
			own += 1
	# Sem projetos próprios na área (países menores), a lista mostra os estrangeiros.
	var foreign_ok := _show_foreign or own == 0
	for id in techs:
		if techs[id].area == _area and (foreign_ok or not ResearchSystem.is_foreign(techs[id], c.tag)):
			ids.append(id)
	ids.sort_custom(func(a, b):
		var ya := int(techs[a].year)
		var yb := int(techs[b].year)
		return ya < yb if ya != yb else str(techs[a].name) < str(techs[b].name))
	if (_selected == "" or not _selected in ids) and not ids.is_empty():
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
	if ResearchSystem.is_foreign(t, c.tag):
		origin = " (%s)" % t.origin[0]
	var tail := st
	if st == "":
		var max_ahead := int(ResearchSystem.rules(sim.defs).get("max_years_ahead", 2))
		if ResearchSystem.years_ahead(sim.state, t) > max_ahead:
			tail = "a partir de %d" % (int(t.year) - max_ahead)
		else:
			tail = "%d dias" % ResearchSystem.days_needed(sim.state, sim.defs, c.tag, id)
	b.text = "%s%s  ·  %s" % [t.name, origin, tail]
	b.tooltip_text = "%s (%d)" % [t.name, int(t.year)]
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
		_sheet.text = ""
		_go.visible = false
		return
	var t := ResearchSystem.tech(sim.defs, _selected)
	var s := "[font_size=18][color=%s]%s[/color][/font_size]\n" % [a, t.name]
	var days := ResearchSystem.days_needed(sim.state, sim.defs, c.tag, _selected)
	s += "[font_size=16]%d dias  ·  %s[/font_size]\n" % [days, UiStyle.money(float(t.money_cost), sim.defs.currency)]
	var notes: Array = []
	var ahead := ResearchSystem.years_ahead(sim.state, t)
	if ahead > 0:
		notes.append("antes da época (%d)" % int(t.year))
	if ResearchSystem.is_foreign(t, c.tag):
		var oc: Country = sim.state.country(t.origin[0])
		notes.append("projeto de %s" % (oc.name if oc else t.origin[0]))
	if not notes.is_empty():
		s += "[color=#999]Mais lento: %s[/color]\n" % ", ".join(notes)
	var missing: Array = []
	for r in t.get("requires", []):
		if not c.has_tech(r):
			missing.append(ResearchSystem.tech(sim.defs, r).get("name", r))
	if not missing.is_empty():
		s += "[color=#d88]Antes pesquise: %s[/color]\n" % ", ".join(missing)
	if t.has("desc"):
		s += "\n" + t.desc + "\n"
	var sheet := ""
	for eq in t.get("unlocks_equipment", []):
		s += "\n" + key_stats(sim.defs, eq)
		sheet += equipment_sheet(sim.defs, eq)
	_detail.text = s
	_sheet.text = sheet if sheet != "" else "[color=#888]Sem ficha técnica (é uma especialização de tropa).[/color]"
	var st := _status(_selected, c)
	_go.visible = st == ""
	var why := ResearchSystem.can_start(sim.state, sim.defs, c.tag, _selected)
	_go.disabled = why != ""
	_go.text = "Pesquisar" if why == "" else "Pesquisar (%s)" % why


## Os 3 números que mais importam de cada tipo de equipamento.
const KEY_STATS := {
	"rifle": ["soft_attack", "close_attack", "range_m"], "sniper": ["soft_attack", "close_attack", "range_m"],
	"smg": ["soft_attack", "close_attack", "range_m"], "tank": ["hard_attack", "armour", "speed_kmh"],
	"fighter": ["air_attack", "speed_kmh"], "attack": ["ground_attack", "speed_kmh"],
	"bomber": ["ground_attack", "speed_kmh", "range_km"], "artillery": ["soft_attack", "casualty_radius_m", "range_km"],
}


static func key_stats(defs: Dictionary, eq: String) -> String:
	var e: Dictionary = defs.equipment.get(eq, {})
	var parts: Array = []
	for k in KEY_STATS.get(e.category, []):
		if e.stats.has(k):
			parts.append("%s [b]%s[/b]" % [STAT_NAMES.get(k, k), _fmt(e.stats[k])])
	return "[color=%s]%s[/color]\n%s\n" % [UiStyle.ACCENT_HEX, e.category_name, "\n".join(parts)]


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
