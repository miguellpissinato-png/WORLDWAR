class_name ResearchPanel
extends PanelContainer
## Pesquisa em organograma: vagas em andamento no topo, abas por área e a árvore da área
## (colunas por ano, linhas ligando cada tecnologia ao que ela exige). Cada cartão tem a ilustração
## do item (ui/research/<id>.svg, ou um PNG com o mesmo nome, se existir). À direita, a ficha.

const COL_W := 176.0
const ROW_H := 136.0
const CARD := Vector2(150, 118)
const PAD := Vector2(14, 34)

var _main
var _area := "armas"
var _show_foreign := false
var _foreign_toggle: CheckBox
var _selected := ""
var _area_buttons := {}
var _slots: HBoxContainer
var _scroll: ScrollContainer
var _canvas: ResearchTreeCanvas
var _detail_img: TextureRect
var _detail: RichTextLabel
var _sheet: RichTextLabel
var _go: Button


func setup(main) -> void:
	_main = main
	UiStyle.place(self, 1070)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	add_child(v)
	UiStyle.window_header(v, "Pesquisa", "", func(): visible = false,
		"Cada vaga pesquisa uma tecnologia por vez.\nAntes do ano histórico leva mais tempo (até 2 anos antes).\n"
		+ "Projetos de outros países também levam mais tempo.")
	_slots = HBoxContainer.new()
	_slots.add_theme_constant_override("separation", 10)
	v.add_child(_slots)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	v.add_child(tabs)
	for a in main.sim.defs.research.areas:
		var b := Button.new()
		b.text = a.name
		b.custom_minimum_size = Vector2(0, 36)
		b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
		var id: String = a.id
		b.pressed.connect(func():
			_area = id
			_selected = ""
			_scroll.scroll_horizontal = 0
			_scroll.scroll_vertical = 0
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
	body.add_theme_constant_override("separation", 14)
	v.add_child(body)
	var tree_box := PanelContainer.new()
	tree_box.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.BG_DARK, UiStyle.LINE, 1, 4, 0))
	tree_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(tree_box)
	_scroll = ScrollContainer.new()
	_scroll.custom_minimum_size = Vector2(690, 430)
	tree_box.add_child(_scroll)
	_canvas = ResearchTreeCanvas.new()
	_scroll.add_child(_canvas)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", 8)
	right.custom_minimum_size = Vector2(320, 0)
	body.add_child(right)
	var img_box := PanelContainer.new()
	img_box.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.BG_DARK, UiStyle.LINE_WARM, 1, 4, 6))
	right.add_child(img_box)
	_detail_img = TextureRect.new()
	_detail_img.custom_minimum_size = Vector2(300, 136)
	_detail_img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_detail_img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	img_box.add_child(_detail_img)
	_detail = UiStyle.rich(320)
	right.add_child(_detail)
	_go = UiStyle.primary_button("Pesquisar", 42)
	_go.clip_text = true
	_go.pressed.connect(func():
		if _selected != "":
			_main.submit(StartResearchCommand.create(_main.player_tag, _selected)))
	right.add_child(_go)
	var full := UiStyle.details(right, "Ficha completa (dados históricos e fontes)", "Esconder ficha")
	var fscroll := ScrollContainer.new()
	fscroll.custom_minimum_size = Vector2(320, 170)
	fscroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	full.add_child(fscroll)
	_sheet = RichTextLabel.new()
	_sheet.bbcode_enabled = true
	_sheet.fit_content = true
	_sheet.custom_minimum_size = Vector2(300, 0)
	_sheet.meta_clicked.connect(func(meta): OS.shell_open(str(meta)))
	fscroll.add_child(_sheet)


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


## Ilustração do item: PNG com o nome da tecnologia, se existir; senão o desenho SVG.
static func art(id: String) -> Texture2D:
	for ext in ["png", "svg"]:
		var p := "res://ui/research/%s.%s" % [id, ext]
		if ResourceLoader.exists(p):
			return load(p)
	return null


func refresh() -> void:
	if not visible:
		return
	var sim: Simulation = _main.sim
	var c: Country = sim.state.country(_main.player_tag)
	for id in _area_buttons:
		var on: bool = id == _area
		var b: Button = _area_buttons[id]
		var sb := UiStyle.box(UiStyle.BG_HOVER if on else UiStyle.BG_BUTTON, UiStyle.ACCENT if on else UiStyle.LINE_WARM, 1, 3)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_color_override("font_color", UiStyle.ACCENT_LIGHT if on else UiStyle.TEXT)
	_foreign_toggle.set_pressed_no_signal(_show_foreign)
	_fill_slots(c)
	_build_tree(c)
	_show_detail()


# ---------------------------------------------------------------- vagas

func _fill_slots(c: Country) -> void:
	UiStyle.clear(_slots)
	var sim: Simulation = _main.sim
	for r in c.research:
		var t := ResearchSystem.tech(sim.defs, r.tech)
		var card := PanelContainer.new()
		var sb := UiStyle.box(UiStyle.BG_DARK, UiStyle.ACCENT, 1, 4, 6)
		card.add_theme_stylebox_override("panel", sb)
		card.custom_minimum_size = Vector2(250, 0)
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 8)
		card.add_child(h)
		var img := TextureRect.new()
		img.texture = art(r.tech)
		img.custom_minimum_size = Vector2(70, 34)
		img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(img)
		var vv := VBoxContainer.new()
		vv.add_theme_constant_override("separation", 2)
		vv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(vv)
		var name_l := Label.new()
		name_l.text = t.get("name", r.tech)
		name_l.clip_text = true
		name_l.custom_minimum_size = Vector2(120, 0)
		name_l.add_theme_font_size_override("font_size", 13)
		vv.add_child(name_l)
		var bar := ProgressBar.new()
		bar.max_value = float(r.days)
		bar.value = float(r.progress)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 6)
		vv.add_child(bar)
		vv.add_child(UiStyle.small_label("faltam %d dias" % maxi(0, int(ceil(float(r.days) - float(r.progress)))), 11))
		var cancel := UiStyle.icon_button("close", "Cancelar pesquisa", 26, 12)
		cancel.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var tid: String = r.tech
		cancel.pressed.connect(func(): _main.submit(CancelResearchCommand.create(_main.player_tag, tid)))
		h.add_child(cancel)
		_slots.add_child(card)
	var free := c.research_slots - c.research.size()
	for i in free:
		var empty := PanelContainer.new()
		empty.add_theme_stylebox_override("panel", UiStyle.box(Color(0, 0, 0, 0), UiStyle.LINE_WARM, 1, 4, 6))
		empty.custom_minimum_size = Vector2(150, 50)
		var l := UiStyle.small_label("Vaga livre", 12)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		empty.add_child(l)
		_slots.add_child(empty)


# ---------------------------------------------------------------- árvore

func _status(id: String, c: Country) -> String:
	if c.has_tech(id):
		return "pesquisada"
	if ResearchSystem.in_progress(c, id):
		return "em andamento"
	return ""


func _visible_ids(c: Country) -> Array:
	var sim: Simulation = _main.sim
	var techs: Dictionary = sim.defs.research.techs
	var own := 0
	for id in techs:
		if techs[id].area == _area and not ResearchSystem.is_foreign(techs[id], c.tag):
			own += 1
	# Sem projetos próprios na área (países menores), a árvore mostra os estrangeiros.
	var foreign_ok := _show_foreign or own == 0
	var ids: Array = []
	for id in techs:
		if techs[id].area == _area and (foreign_ok or not ResearchSystem.is_foreign(techs[id], c.tag)):
			ids.append(id)
	ids.sort_custom(func(a, b):
		var ya := int(techs[a].year)
		var yb := int(techs[b].year)
		return ya < yb if ya != yb else str(techs[a].name) < str(techs[b].name))
	return ids


## Colunas = anos que existem na área; cada tecnologia fica na linha de quem ela exige
## (se a casa estiver livre), assim as famílias (Panzer II, III, IV...) ficam alinhadas.
func _layout(ids: Array) -> Dictionary:
	var techs: Dictionary = _main.sim.defs.research.techs
	var years: Array = []
	for id in ids:
		if not int(techs[id].year) in years:
			years.append(int(techs[id].year))
	years.sort()
	var pos := {}          # id -> Vector2i(coluna, linha)
	var taken := {}        # "col,row" -> true
	var rows := 0
	for id in ids:
		var col := years.find(int(techs[id].year))
		var row := -1
		for req in techs[id].get("requires", []):
			if pos.has(req) and not taken.has("%d,%d" % [col, pos[req].y]):
				row = pos[req].y
				break
		if row == -1:
			row = 0
			while taken.has("%d,%d" % [col, row]):
				row += 1
			# linha nova para famílias novas, para não misturar com outras
			var parent_in_area := false
			for req in techs[id].get("requires", []):
				if pos.has(req):
					parent_in_area = true
			if not parent_in_area:
				row = rows
		pos[id] = Vector2i(col, row)
		taken["%d,%d" % [col, row]] = true
		rows = maxi(rows, row + 1)
	return {"pos": pos, "years": years, "rows": rows}


func _build_tree(c: Country) -> void:
	var sim: Simulation = _main.sim
	var techs: Dictionary = sim.defs.research.techs
	var ids := _visible_ids(c)
	if (_selected == "" or not _selected in ids) and not ids.is_empty():
		_selected = ids[0]
	var lay := _layout(ids)
	UiStyle.clear(_canvas)
	_canvas.links.clear()
	_canvas.years.clear()
	var years: Array = lay.years
	for i in years.size():
		_canvas.years.append({"x": PAD.x + i * COL_W + CARD.x / 2, "text": str(years[i])})
	var centers := {}
	for id in ids:
		var p: Vector2i = lay.pos[id]
		var at := PAD + Vector2(p.x * COL_W, p.y * ROW_H)
		var card := _card(id, techs[id], c)
		card.position = at
		_canvas.add_child(card)
		centers[id] = at
	for id in ids:
		for req in techs[id].get("requires", []):
			if centers.has(req):
				_canvas.links.append({"from": centers[req] + Vector2(CARD.x, CARD.y / 2), "to": centers[id] + Vector2(0, CARD.y / 2),
					"done": c.has_tech(req)})
	_canvas.custom_minimum_size = PAD + Vector2(years.size() * COL_W, int(lay.rows) * ROW_H) + Vector2(0, 10)
	_canvas.queue_redraw()


func _card(id: String, t: Dictionary, c: Country) -> Button:
	var sim: Simulation = _main.sim
	var st := _status(id, c)
	var why := ResearchSystem.can_start(sim.state, sim.defs, c.tag, id)
	var locked := st == "" and why not in ["", "todas as vagas de pesquisa estão ocupadas", "dinheiro insuficiente"]
	var b := Button.new()
	b.custom_minimum_size = CARD
	b.size = CARD
	var border: Color = UiStyle.LINE_WARM
	var bg: Color = UiStyle.BG_BUTTON
	if st == "pesquisada":
		border = UiStyle.GOOD
		bg = Color("#1b2419")
	elif st == "em andamento":
		border = UiStyle.ACCENT
	if id == _selected:
		border = UiStyle.ACCENT_LIGHT
	var width := 2 if id == _selected or st != "" else 1
	b.add_theme_stylebox_override("normal", UiStyle.box(bg, border, width, 5))
	b.add_theme_stylebox_override("hover", UiStyle.box(UiStyle.BG_HOVER, UiStyle.ACCENT, width, 5))
	b.add_theme_stylebox_override("pressed", UiStyle.box(UiStyle.BG_HOVER, UiStyle.ACCENT, 2, 5))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.tooltip_text = "%s (%d)" % [t.name, int(t.year)] + ("\n" + why if locked else "")
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	v.offset_left = 6
	v.offset_right = -6
	v.offset_top = 5
	v.offset_bottom = -5
	v.add_theme_constant_override("separation", 2)
	b.add_child(v)
	var img := TextureRect.new()
	img.texture = art(id)
	img.custom_minimum_size = Vector2(0, 58)
	img.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	img.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(img)
	var name_l := Label.new()
	name_l.text = t.name
	name_l.add_theme_font_size_override("font_size", 12)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.max_lines_visible = 2
	name_l.custom_minimum_size = Vector2(0, 30)
	name_l.add_theme_color_override("font_color", UiStyle.ACCENT_LIGHT if id == _selected else UiStyle.TEXT)
	v.add_child(name_l)
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 6)
	v.add_child(line)
	if ResearchSystem.is_foreign(t, c.tag) and not t.origin.is_empty():
		var fb := UiStyle.flag_box(Vector2(15, 10), false)
		var oc: Country = sim.state.country(t.origin[0])
		UiStyle.set_flag(fb, t.origin[0], oc.color if oc else Color.GRAY)
		line.add_child(fb)
	var tail := ""
	var col := UiStyle.MUTED
	if st == "pesquisada":
		tail = "pesquisada"
		col = UiStyle.GOOD
	elif st == "em andamento":
		for r in c.research:
			if r.tech == id:
				tail = "%d%%" % int(100.0 * float(r.progress) / maxf(1.0, float(r.days)))
		col = UiStyle.ACCENT
	else:
		var max_ahead := int(ResearchSystem.rules(sim.defs).get("max_years_ahead", 2))
		if ResearchSystem.years_ahead(sim.state, t) > max_ahead:
			tail = "a partir de %d" % (int(t.year) - max_ahead)
		else:
			tail = "%d · %d dias" % [int(t.year), ResearchSystem.days_needed(sim.state, sim.defs, c.tag, id)]
	line.add_child(UiStyle.small_label(tail, 11, col))
	if locked:
		b.modulate = Color(1, 1, 1, 0.5)
	UiStyle.passthrough(v)
	b.pressed.connect(func():
		_selected = id
		refresh())
	return b


# ---------------------------------------------------------------- ficha

func _show_detail() -> void:
	var sim: Simulation = _main.sim
	var c: Country = sim.state.country(_main.player_tag)
	var a := UiStyle.ACCENT_HEX
	if _selected == "":
		_detail.text = ""
		_sheet.text = ""
		_go.visible = false
		_detail_img.texture = null
		return
	var t := ResearchSystem.tech(sim.defs, _selected)
	_detail_img.texture = art(_selected)
	var s := "[font=res://ui/fonts/Oswald-Medium.ttf][font_size=20][color=%s]%s[/color][/font_size][/font]\n" % [a, str(t.name).to_upper()]
	var days := ResearchSystem.days_needed(sim.state, sim.defs, c.tag, _selected)
	s += "%s  ·  %s  ·  %d\n" % [UiStyle.kv("Tempo", "%d dias" % days), UiStyle.kv("Custo", UiStyle.money(float(t.money_cost), sim.defs.currency)), int(t.year)]
	var notes: Array = []
	var ahead := ResearchSystem.years_ahead(sim.state, t)
	if ahead > 0:
		notes.append("antes da época (%d)" % int(t.year))
	if ResearchSystem.is_foreign(t, c.tag):
		var oc: Country = sim.state.country(t.origin[0])
		notes.append("projeto de %s" % (oc.name if oc else t.origin[0]))
	if not notes.is_empty():
		s += "[color=%s]Mais lento: %s[/color]\n" % [UiStyle.MUTED_HEX, ", ".join(notes)]
	var missing: Array = []
	for r in t.get("requires", []):
		if not c.has_tech(r):
			missing.append(ResearchSystem.tech(sim.defs, r).get("name", r))
	if not missing.is_empty():
		s += "[color=%s]Antes pesquise: %s[/color]\n" % [UiStyle.BAD_HEX, ", ".join(missing)]
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
	_go.text = "PESQUISAR" if why == "" else why.to_upper()
	_go.tooltip_text = why


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
