class_name BriefingScreen
extends Control
## Janela grande do comando: o briefing no começo da partida (seu país, seu objetivo e os primeiros
## passos) e o anúncio de vitória ou derrota quando alguém cumpre o objetivo.

signal reroll_requested
signal closed
signal quit_requested

var _main
var _box: VBoxContainer


func setup(main) -> void:
	_main = main
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiStyle.scrim(0.55))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var p := UiStyle.panel(28)
	p.custom_minimum_size = Vector2(620, 0)
	center.add_child(p)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	p.add_child(_box)
	visible = false


func _header(tag: String, kicker: String, title: String) -> void:
	var st: GameState = _main.sim.state
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 16)
	_box.add_child(h)
	var fb := UiStyle.flag_box(Vector2(84, 56))
	UiStyle.set_flag(fb, tag, st.country(tag).color)
	h.add_child(fb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	h.add_child(v)
	v.add_child(UiStyle.small_label(kicker.to_upper(), 12, UiStyle.ACCENT))
	v.add_child(UiStyle.title_label(title, 28, UiStyle.TEXT))
	_box.add_child(UiStyle.rule())


## Briefing do começo: `can_reroll` mostra "Sortear outro" (só no jogo solo).
func open_briefing(tag: String, can_reroll: bool, multiplayer_game: bool) -> void:
	UiStyle.clear(_box)
	var st: GameState = _main.sim.state
	var d := GameDate.from_hours(st.hours)
	_header(tag, "Ordens do comando · %d de %s de %d" % [d.day, GameDate.MONTH_NAMES[d.month - 1], d.year], st.country(tag).name)
	_box.add_child(UiStyle.section("Seu objetivo"))
	var obj_id: String = st.objectives.get(tag, "")
	_box.add_child(ObjectiveView.build(st, _main.sim.defs, tag, obj_id, 560, 20))
	var how := UiStyle.small_label("Vence quem cumprir o próprio objetivo primeiro. Conta o território que você controla: "
		+ "o seu e o que suas tropas ocuparem em guerra.", 12)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_box.add_child(how)
	_box.add_child(UiStyle.section("Primeiros passos"))
	var steps := UiStyle.rich(560)
	steps.text = "\n".join([
		"[color=#c9b37a]1.[/color] Fortaleça a indústria: clique num estado seu → [b]Construir[/b] fábricas (o topo mostra civis | militares).",
		"[color=#c9b37a]2.[/color] Arme o país: [b]Exército[/b] → botões [b]+[/b] encomendam soldados, artilharia, tanques e aviões; [b]Pesquisa[/b] → modelos melhores.",
		"[color=#c9b37a]3.[/color] Marque o [b]estado favorito[/b] (estrela na ficha de um estado seu): as tropas novas nascem lá.",
		"[color=#c9b37a]4.[/color] Escolha o alvo: selecione uma pilha de tropas e clique num estado vizinho → justificar e declarar guerra. Para encerrar, a ficha do inimigo tem [b]Propor paz[/b].",
		"[color=#c9b37a]5.[/color] O tempo começa pausado: [b]espaço[/b] solta o relógio; 1 a 5 mudam a velocidade."])
	_box.add_child(steps)
	if multiplayer_game:
		_box.add_child(UiStyle.small_label("Partida em rede: o host controla o tempo.", 12, UiStyle.WARN))
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	_box.add_child(row)
	if can_reroll:
		var re := Button.new()
		re.text = "Sortear outro objetivo"
		re.custom_minimum_size = Vector2(220, 42)
		re.pressed.connect(func(): reroll_requested.emit())
		row.add_child(re)
	var go := UiStyle.primary_button("Assumir o comando", 42)
	go.custom_minimum_size.x = 240
	go.pressed.connect(func():
		visible = false
		closed.emit())
	row.add_child(go)
	visible = true


## Fim da guerra: vitória do jogador ou de outro país.
func open_result(my_tag: String) -> void:
	UiStyle.clear(_box)
	var st: GameState = _main.sim.state
	var won := st.winner == my_tag
	var obj := ObjectiveSystem.find(_main.sim.defs, String(st.objectives.get(st.winner, "")))
	_header(st.winner, "Fim da guerra", "Vitória!" if won else "Derrota")
	var t := UiStyle.rich(560)
	if won:
		t.text = "Seu país cumpriu o objetivo [b]%s[/b]. O mundo agora conhece o seu comando." % obj.get("name", "")
	else:
		t.text = "[b]%s[/b] cumpriu o objetivo [b]%s[/b] antes de você." % [st.country(st.winner).name, obj.get("name", "")]
	_box.add_child(t)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	_box.add_child(row)
	var quit := Button.new()
	quit.text = "Sair para o menu"
	quit.custom_minimum_size = Vector2(180, 42)
	quit.pressed.connect(func(): quit_requested.emit())
	row.add_child(quit)
	var go := UiStyle.primary_button("Continuar jogando", 42)
	go.custom_minimum_size.x = 220
	go.pressed.connect(func():
		visible = false
		closed.emit())
	row.add_child(go)
	visible = true
