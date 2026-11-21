class_name MultiplayerScreen
extends Control
## Fluxo do Multiplayer, por cima do menu inicial:
## 1. Perfil: apelido e insígnia (guardados no computador).
## 2. Servidor: criar um servidor nesta máquina ou entrar num servidor (endereço IP:porta).
## 3. Sala: quem está conectado. A escolha de países e o início da partida em rede vêm depois.

signal back_requested

var _pages: Dictionary = {}
var _nick: LineEdit
var _avatar_buttons: Dictionary = {}
var _chosen_avatar := ""
var _profile_error: Label
var _me_box: HBoxContainer
var _host_name: LineEdit
var _host_port: SpinBox
var _host_max: SpinBox
var _join_addr: LineEdit
var _recent_box: VBoxContainer
var _server_status: Label
var _lobby_title: Label
var _lobby_sub: Label
var _lobby_list: VBoxContainer
var _lobby_hint: Label
var _main
var _picker: OptionButton
var _picker_tags: Array = []
var _start_button: Button
var _mode_pick: OptionButton
var _mode_label: Label
var _vote_row: HBoxContainer
var _vote_pick: OptionButton
var _vote_ids: Array = []
var _tally: Label


func setup(main) -> void:
	_main = main


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiStyle.scrim(0.6))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var holder := VBoxContainer.new()
	center.add_child(holder)
	for id in ["profile", "servers", "lobby"]:
		var p := UiStyle.panel(24)
		p.custom_minimum_size = Vector2(760, 0)
		p.visible = false
		holder.add_child(p)
		_pages[id] = p
	_build_profile(_pages.profile)
	_build_servers(_pages.servers)
	_build_lobby(_pages.lobby)
	Net.players_changed.connect(_refresh_lobby)
	Net.room_code_ready.connect(func(_c): _refresh_lobby())
	Net.connected_to_server.connect(func():
		_server_status.text = ""
		_show("lobby"))
	Net.connection_failed.connect(func(reason):
		_server_status.text = reason
		_show("servers"))
	Net.session_ended.connect(func(reason):
		_show("servers")
		_server_status.text = reason)


## Abre o fluxo (sempre começa pelo perfil, já preenchido se existir).
func open() -> void:
	_nick.text = Net.nick
	_select_avatar(Net.avatar)
	_profile_error.text = ""
	visible = true
	_show("lobby" if Net.in_session() else "profile")


func _show(id: String) -> void:
	for k in _pages:
		_pages[k].visible = k == id
	if id == "servers":
		_refresh_me()
		_refresh_recent()
	if id == "lobby":
		_refresh_lobby()


func _head(parent: VBoxContainer, title: String, step: String, on_back: Callable) -> void:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	parent.add_child(h)
	var back := UiStyle.icon_button("back", "Voltar", 30, 16)
	back.pressed.connect(on_back)
	h.add_child(back)
	h.add_child(UiStyle.icon("people", UiStyle.ACCENT, 20))
	var t := UiStyle.title_label(title, 21)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(t)
	h.add_child(UiStyle.small_label(step, 12))
	parent.add_child(UiStyle.rule())


# ---------------------------------------------------------------- 1. perfil

func _build_profile(p: PanelContainer) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	_head(v, "Multiplayer · seu perfil", "1 de 2", func():
		visible = false
		back_requested.emit())
	v.add_child(UiStyle.section("Apelido"))
	_nick = LineEdit.new()
	_nick.placeholder_text = "Como os outros jogadores vão te ver"
	_nick.max_length = Net.MAX_NICK
	_nick.custom_minimum_size = Vector2(0, 40)
	_nick.text_submitted.connect(func(_t): _confirm_profile())
	v.add_child(_nick)
	v.add_child(UiStyle.section("Insígnia"))
	var grid := GridContainer.new()
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 8)
	v.add_child(grid)
	for id in Net.AVATARS:
		var b := Button.new()
		b.toggle_mode = true
		b.icon = Net.avatar_texture(id)
		b.expand_icon = true
		b.custom_minimum_size = Vector2(72, 72)
		b.tooltip_text = id.replace("_", " ").capitalize()
		b.pressed.connect(func(): _select_avatar(id))
		grid.add_child(b)
		_avatar_buttons[id] = b
	_profile_error = UiStyle.small_label("", 12, UiStyle.WARN)
	v.add_child(_profile_error)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	v.add_child(row)
	var ok := UiStyle.primary_button("Continuar", 44)
	ok.custom_minimum_size.x = 220
	ok.pressed.connect(_confirm_profile)
	row.add_child(ok)


func _select_avatar(id: String) -> void:
	_chosen_avatar = id
	for k in _avatar_buttons:
		_avatar_buttons[k].button_pressed = k == id


func _confirm_profile() -> void:
	var n := _nick.text.strip_edges()
	if n.length() < 2:
		_profile_error.text = "Escolha um apelido com pelo menos 2 letras."
		return
	Net.set_profile(n, _chosen_avatar)
	_show("servers")


# ---------------------------------------------------------------- 2. servidor

func _build_servers(p: PanelContainer) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	p.add_child(v)
	_head(v, "Multiplayer · servidor", "2 de 2", func(): _show("profile"))
	_me_box = HBoxContainer.new()
	_me_box.add_theme_constant_override("separation", 10)
	v.add_child(_me_box)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 18)
	v.add_child(cols)
	# criar
	var c1 := VBoxContainer.new()
	c1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c1.add_theme_constant_override("separation", 10)
	cols.add_child(c1)
	c1.add_child(UiStyle.section("Criar sala"))
	c1.add_child(UiStyle.small_label("Online: você recebe um código curto e os amigos entram com ele, sem IP nem roteador.", 12))
	_host_name = LineEdit.new()
	_host_name.placeholder_text = "Nome da sala"
	_host_name.custom_minimum_size = Vector2(0, 38)
	c1.add_child(_host_name)
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 8)
	c1.add_child(r)
	r.add_child(UiStyle.small_label("Porta", 12))
	_host_port = SpinBox.new()
	_host_port.min_value = 1024
	_host_port.max_value = 65535
	_host_port.value = Net.DEFAULT_PORT
	r.add_child(_host_port)
	r.add_child(UiStyle.small_label("Jogadores", 12))
	_host_max = SpinBox.new()
	_host_max.min_value = 2
	_host_max.max_value = 16
	_host_max.value = 8
	r.add_child(_host_max)
	var create := UiStyle.primary_button("Criar sala online", 42)
	create.pressed.connect(_create_online)
	c1.add_child(create)
	var lan := Button.new()
	lan.text = "Criar na rede local (por IP e porta)"
	lan.flat = true
	lan.pressed.connect(_create)
	lan.disabled = OS.has_feature("web")
	c1.add_child(lan)
	# entrar
	var c2 := VBoxContainer.new()
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	c2.add_theme_constant_override("separation", 10)
	cols.add_child(c2)
	c2.add_child(UiStyle.section("Entrar"))
	c2.add_child(UiStyle.small_label("Código da sala (4 letras) ou, na rede local, o IP:porta do host.", 12))
	_join_addr = LineEdit.new()
	_join_addr.placeholder_text = "ex.: K7PX  ou  192.168.0.10:%d" % Net.DEFAULT_PORT
	_join_addr.custom_minimum_size = Vector2(0, 38)
	_join_addr.text_submitted.connect(func(_t): _join())
	c2.add_child(_join_addr)
	var join := UiStyle.primary_button("Entrar", 42)
	join.pressed.connect(_join)
	c2.add_child(join)
	_recent_box = VBoxContainer.new()
	c2.add_child(_recent_box)

	_server_status = UiStyle.small_label("", 12, UiStyle.WARN)
	_server_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_server_status)


func _refresh_me() -> void:
	UiStyle.clear(_me_box)
	_me_box.add_child(_avatar_rect(Net.avatar, 40))
	var l := UiStyle.title_label(Net.nick, 18, UiStyle.TEXT)
	_me_box.add_child(l)
	var edit := Button.new()
	edit.text = "trocar"
	edit.flat = true
	edit.pressed.connect(func(): _show("profile"))
	_me_box.add_child(edit)


func _refresh_recent() -> void:
	UiStyle.clear(_recent_box)
	if Net.recent_servers.is_empty():
		return
	_recent_box.add_child(UiStyle.small_label("Recentes", 11))
	for a in Net.recent_servers:
		var b := Button.new()
		b.text = a
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): _join_addr.text = a)
		_recent_box.add_child(b)


func _create() -> void:
	var err := Net.host(_host_name.text, int(_host_port.value), int(_host_max.value))
	if err != "":
		_server_status.text = err
		return
	_show("lobby")


func _create_online() -> void:
	var err := Net.host_online(_host_name.text, int(_host_max.value))
	if err != "":
		_server_status.text = err
		return
	_server_status.text = "Criando a sala..."
	_show("lobby")


func _join() -> void:
	var a := _join_addr.text.strip_edges()
	var is_code := a.length() == 4 and not "." in a and not ":" in a
	var err := Net.join_online(a) if is_code else Net.join(a)
	_server_status.text = err if err != "" else "Conectando a %s..." % a


# ---------------------------------------------------------------- 3. sala

func _build_lobby(p: PanelContainer) -> void:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	p.add_child(v)
	_head(v, "Sala", "", func():
		Net.leave()
		_show("servers"))
	_lobby_title = UiStyle.title_label("", 19, UiStyle.TEXT)
	v.add_child(_lobby_title)
	_lobby_sub = UiStyle.small_label("", 12)
	_lobby_sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lobby_sub)
	v.add_child(UiStyle.section("Jogadores"))
	_lobby_list = VBoxContainer.new()
	_lobby_list.add_theme_constant_override("separation", 6)
	v.add_child(_lobby_list)
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 10)
	v.add_child(pr)
	pr.add_child(UiStyle.section("Seu país"))
	_picker = OptionButton.new()
	_picker.custom_minimum_size = Vector2(320, 38)
	_picker.add_theme_constant_override("icon_max_width", 26)
	_picker.item_selected.connect(func(i): Net.pick_country(_picker_tags[i]))
	pr.add_child(_picker)
	var orow := HBoxContainer.new()
	orow.add_theme_constant_override("separation", 10)
	v.add_child(orow)
	orow.add_child(UiStyle.section("Objetivos"))
	_mode_pick = OptionButton.new()
	_mode_pick.add_item("Individual: um sorteado e secreto para cada um")
	_mode_pick.add_item("Comum: todos votam num objetivo")
	_mode_pick.custom_minimum_size = Vector2(400, 36)
	_mode_pick.item_selected.connect(func(i): Net.set_objective_mode("comum" if i == 1 else "individual"))
	orow.add_child(_mode_pick)
	_mode_label = UiStyle.small_label("", 12, UiStyle.TEXT)
	orow.add_child(_mode_label)
	_vote_row = HBoxContainer.new()
	_vote_row.add_theme_constant_override("separation", 10)
	v.add_child(_vote_row)
	_vote_row.add_child(UiStyle.small_label("Seu voto", 12))
	_vote_pick = OptionButton.new()
	_vote_pick.custom_minimum_size = Vector2(360, 36)
	_vote_pick.item_selected.connect(func(i): Net.vote_objective(_vote_ids[i]))
	_vote_row.add_child(_vote_pick)
	_tally = UiStyle.small_label("", 11)
	_tally.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_tally.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_vote_row.add_child(_tally)
	_lobby_hint = UiStyle.small_label("Cada jogador escolhe um país; os que ninguém escolher ficam com a IA. "
		+ "O host inicia a partida e controla o tempo (pausa e velocidade).", 12)
	_lobby_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_lobby_hint)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_END
	row.add_theme_constant_override("separation", 10)
	v.add_child(row)
	_start_button = UiStyle.primary_button("Iniciar partida", 40)
	_start_button.custom_minimum_size.x = 220
	_start_button.pressed.connect(func(): Net.start_game())
	row.add_child(_start_button)
	var leave := Button.new()
	leave.text = "Sair da sala"
	leave.custom_minimum_size = Vector2(160, 40)
	leave.pressed.connect(func():
		Net.leave()
		_show("servers"))
	row.add_child(leave)


func _refresh_lobby() -> void:
	if _lobby_list == null:
		return
	_lobby_title.text = Net.server_name if Net.server_name != "" else "Conectando..."
	if Net.is_host and Net.room_code != "":
		_lobby_sub.text = "Código da sala: %s   ·   passe este código para os amigos entrarem (Multiplayer > Entrar)." % Net.room_code
	elif Net.is_host and Net.signaling_url != "" and not Net.in_session():
		_lobby_sub.text = "Criando a sala no servidor de sinalização..."
	elif Net.is_host:
		var ips := Array(IP.get_local_addresses()).filter(func(a): return a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254"))
		var port := int(_host_port.value)
		_lobby_sub.text = "Você é o host. Passe para os amigos: %s (porta %d). Fora da sua rede, é preciso liberar a porta no roteador." % [
			(", ".join(ips.map(func(a): return "%s:%d" % [a, port])) if not ips.is_empty() else "seu IP"), port]
	else:
		_lobby_sub.text = "Conectado. Aguardando o host."
	UiStyle.clear(_lobby_list)
	var ids: Array = Net.players.keys()
	ids.sort()
	for id in ids:
		var pl: Dictionary = Net.players[id]
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		h.add_child(_avatar_rect(pl.avatar, 36))
		var n := Label.new()
		n.text = pl.nick + ("  (você)" if id == multiplayer.get_unique_id() else "")
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h.add_child(n)
		var tag := String(pl.get("tag", ""))
		if tag != "" and _main != null:
			var c: Country = _main.sim.state.country(tag)
			var fb := UiStyle.flag_box(Vector2(30, 20))
			UiStyle.set_flag(fb, tag, c.color)
			h.add_child(fb)
			h.add_child(UiStyle.small_label(c.name, 12, UiStyle.TEXT))
		else:
			h.add_child(UiStyle.small_label("escolhendo país...", 12))
		if int(id) == 1:
			h.add_child(UiStyle.small_label("HOST", 11, UiStyle.ACCENT))
		_lobby_list.add_child(h)
	_lobby_list.add_child(UiStyle.small_label("%d de %d" % [ids.size(), Net.max_players], 11))
	_fill_picker()
	_fill_objectives()
	_start_button.visible = Net.is_host
	_start_button.disabled = not Net.can_start()
	_start_button.tooltip_text = "" if Net.can_start() else "Todos precisam escolher um país."


func _fill_objectives() -> void:
	if _main == null:
		return
	var comum := Net.objective_mode == "comum"
	_mode_pick.visible = Net.is_host
	_mode_pick.select(1 if comum else 0)
	_mode_label.visible = not Net.is_host
	_mode_label.text = "Comum (votação)" if comum else "Individual (sorteado e secreto)"
	_vote_row.visible = comum
	if not comum:
		return
	var defs: Dictionary = _main.sim.defs
	if _vote_ids.is_empty():
		_vote_ids = [""] + ObjectiveSystem.list(defs).map(func(o): return o.id)
	var counts := {}
	var mine := ""
	for id in Net.players:
		var vt := String(Net.players[id].get("vote", ""))
		if vt != "":
			counts[vt] = int(counts.get(vt, 0)) + 1
		if id == multiplayer.get_unique_id():
			mine = vt
	_vote_pick.clear()
	for i in _vote_ids.size():
		var oid: String = _vote_ids[i]
		if oid == "":
			_vote_pick.add_item("Escolha um objetivo")
		else:
			var n := int(counts.get(oid, 0))
			_vote_pick.add_item(ObjectiveSystem.find(defs, oid).name + ("  (%d voto%s)" % [n, "" if n == 1 else "s"] if n > 0 else ""))
	_vote_pick.select(maxi(0, _vote_ids.find(mine)))
	_tally.text = "Empate: sorteio entre os mais votados." if counts.size() > 1 else ""


func _fill_picker() -> void:
	if _main == null:
		return
	var taken := {}
	for id in Net.players:
		if id != multiplayer.get_unique_id():
			taken[String(Net.players[id].get("tag", ""))] = Net.players[id].nick
	var st: GameState = _main.sim.state
	if _picker_tags.is_empty():
		var tags: Array = st.countries.keys()
		tags.sort_custom(func(a, b):
			var ma := StartScreen.MAJORS.find(a)
			var mb := StartScreen.MAJORS.find(b)
			if ma != mb and (ma == -1 or mb == -1):
				return ma != -1
			if ma != -1:
				return ma < mb
			return StartScreen._plain(st.country(a).name) < StartScreen._plain(st.country(b).name))
		_picker_tags = [""] + tags
	_picker.clear()
	for i in _picker_tags.size():
		var tag: String = _picker_tags[i]
		if tag == "":
			_picker.add_item("Escolha um país")
			continue
		var c: Country = st.country(tag)
		_picker.add_icon_item(UiStyle.flag_texture(tag), c.name + ("  (%s)" % taken[tag] if taken.has(tag) else ""))
		_picker.set_item_disabled(i, taken.has(tag))
	_picker.select(maxi(0, _picker_tags.find(Net.my_tag())))


func _avatar_rect(id: String, size: float) -> TextureRect:
	var t := TextureRect.new()
	t.texture = Net.avatar_texture(id)
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	t.custom_minimum_size = Vector2(size, size)
	return t


func _unhandled_input(event: InputEvent) -> void:
	if visible and event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		if _pages.lobby.visible:
			return
		visible = false
		back_requested.emit()
