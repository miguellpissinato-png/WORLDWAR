extends Node
## Sessão de multiplayer (autoload "Net"): perfil do jogador (apelido e insígnia), criar servidor,
## entrar num servidor e a lista de jogadores da sala. Usa WebSocket (o mesmo protocolo serve para
## o jogo instalado e, no futuro, para o navegador). Quem cria o servidor é o host: no jogo, só ele
## aplica os comandos (regra 2 do CLAUDE.md).

signal players_changed
signal connected_to_server
signal connection_failed(reason: String)
signal session_ended(reason: String)
signal game_started(my_tag: String)
signal host_command(d: Dictionary)      # no host: comando que um cliente mandou (já conferido)
signal net_command(d: Dictionary)       # nos clientes: comando aplicado pelo host
signal net_advance(hours: int)          # nos clientes: o host avançou o tempo
signal time_changed(paused: bool, speed: int)
signal player_left(tag: String)

const SETTINGS_PATH := "user://settings.cfg"
const DEFAULT_PORT := 7036
const MAX_NICK := 20
const AVATARS := ["cobra_fumante", "estrela", "estrela_vermelha", "tanque", "asas", "ancora",
	"paraquedas", "raio", "canhoes"]

var nick := ""
var avatar := "cobra_fumante"
var recent_servers: Array = []     # ["ip:porta", ...]

var server_name := ""
var max_players := 8
var players: Dictionary = {}       # id do par -> {nick, avatar}
var is_host := false
var playing := false               # a partida em rede já começou
var objective_mode := "individual"  # "individual" (sorteado e secreto) ou "comum" (votação)
var last_message := ""             # aviso para mostrar no menu depois de voltar (ex.: host saiu)

# ---- modo online (P2P): sala com código, apresentada pelo servidor de sinalização
signal room_code_ready(code: String)
var room_code := ""
var signaling_url := ""
var _ice: Array = []
var _sig: WebSocketPeer = null
var _sig_open := false
var _rtc: WebRTCMultiplayerPeer = null
var _conns: Dictionary = {}        # id do par -> WebRTCPeerConnection
var _online_role := ""             # "host" / "client" enquanto fala com a sinalização


func _ready() -> void:
	_load_profile()
	var f := FileAccess.open("res://data/common/network.json", FileAccess.READ)
	if f != null:
		var cfg = JSON.parse_string(f.get_as_text())
		if cfg is Dictionary:
			signaling_url = String(cfg.get("signaling_url", ""))
			_ice = cfg.get("ice_servers", [])
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected)
	multiplayer.connection_failed.connect(func(): _fail("Não foi possível conectar ao servidor."))
	multiplayer.server_disconnected.connect(func(): _end("O servidor foi fechado."))


static func avatar_texture(id: String) -> Texture2D:
	var p := "res://ui/avatars/%s.svg" % id
	return load(p) if ResourceLoader.exists(p) else null


func has_profile() -> bool:
	return nick.strip_edges() != ""


func set_profile(p_nick: String, p_avatar: String) -> void:
	nick = p_nick.strip_edges().left(MAX_NICK)
	avatar = p_avatar if p_avatar in AVATARS else AVATARS[0]
	_save_profile()


func in_session() -> bool:
	return multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer)


## Cria o servidor nesta máquina. Devolve "" ou o motivo do erro.
func host(p_name: String, port: int, p_max: int) -> String:
	leave()
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_server(port)
	if err != OK:
		return "Não foi possível abrir a porta %d (erro %d). Ela pode estar em uso." % [port, err]
	multiplayer.multiplayer_peer = peer
	is_host = true
	server_name = p_name.strip_edges() if p_name.strip_edges() != "" else "Sala de %s" % nick
	max_players = clampi(p_max, 2, 16)
	players = {1: {"nick": nick, "avatar": avatar, "tag": ""}}
	players_changed.emit()
	return ""


## Entra num servidor ("ip", "ip:porta" ou "ws://..."). A resposta chega pelos sinais.
func join(address: String) -> String:
	leave()
	var url := address.strip_edges()
	if url == "":
		return "Digite o endereço do servidor."
	if not url.begins_with("ws://") and not url.begins_with("wss://"):
		if not ":" in url:
			url += ":%d" % DEFAULT_PORT
		url = "ws://" + url
	var peer := WebSocketMultiplayerPeer.new()
	var err := peer.create_client(url)
	if err != OK:
		return "Endereço inválido (erro %d)." % err
	multiplayer.multiplayer_peer = peer
	is_host = false
	_remember(address.strip_edges())
	return ""


func my_tag() -> String:
	var me: Dictionary = players.get(multiplayer.get_unique_id(), {})
	return String(me.get("tag", ""))


## Escolhe (ou larga, com "") o país na sala.
func pick_country(tag: String) -> void:
	if is_host:
		_apply_pick(1, tag)
	else:
		_pick.rpc_id(1, tag)


## Host: modo dos objetivos da sala.
func set_objective_mode(mode: String) -> void:
	if is_host and not playing and mode in ["individual", "comum"]:
		objective_mode = mode
		_sync.rpc(players, server_name, max_players, objective_mode)
		players_changed.emit()


## Voto no objetivo comum.
func vote_objective(id: String) -> void:
	if is_host:
		_apply_vote(1, id)
	else:
		_vote.rpc_id(1, id)


@rpc("any_peer", "reliable")
func _vote(id: String) -> void:
	if is_host:
		_apply_vote(multiplayer.get_remote_sender_id(), id)


func _apply_vote(peer: int, id: String) -> void:
	if playing or not players.has(peer):
		return
	players[peer]["vote"] = id
	_sync.rpc(players, server_name, max_players, objective_mode)
	players_changed.emit()


func can_start() -> bool:
	if not is_host or players.size() < 1:
		return false
	for p in players.values():
		if String(p.get("tag", "")) == "":
			return false
	return true


## Host: começa a partida para todos.
func start_game() -> void:
	if can_start():
		_sig_send({"type": "lock"})   # sala online: ninguém mais entra pelo código
		_begin.rpc(players)


func send_command(d: Dictionary) -> void:
	_cmd_from_client.rpc_id(1, d)


func broadcast_command(d: Dictionary) -> void:
	if is_host and playing:
		_cmd.rpc(d)


func broadcast_advance(hours: int) -> void:
	if is_host and playing:
		_adv.rpc(hours)


func broadcast_time(p_paused: bool, p_speed: int) -> void:
	if is_host and playing:
		_time.rpc(p_paused, p_speed)


## Pode jogar online neste computador? ("" = sim; senão, o motivo)
func online_unavailable() -> String:
	if signaling_url == "":
		return "O servidor de sinalização ainda não foi configurado (data/common/network.json)."
	var test := WebRTCPeerConnection.new()
	if test.initialize({}) != OK:
		return "Falta o plugin WebRTC no jogo instalado (Godot: AssetLib > WebRTC plugin)."
	test.close()
	return ""


## Cria uma sala online: a sinalização devolve um código (room_code_ready).
func host_online(p_name: String, p_max: int) -> String:
	var why := online_unavailable()
	if why != "":
		return why
	leave()
	is_host = true
	server_name = p_name.strip_edges() if p_name.strip_edges() != "" else "Sala de %s" % nick
	max_players = clampi(p_max, 2, 16)
	_open_signaling("host")
	return ""


## Entra numa sala online pelo código.
func join_online(code: String) -> String:
	var why := online_unavailable()
	if why != "":
		return why
	if code.strip_edges().length() < 4:
		return "Digite o código da sala (4 letras)."
	leave()
	room_code = code.strip_edges().to_upper()
	_open_signaling("client")
	return ""


func _open_signaling(role: String) -> void:
	_online_role = role
	_sig = WebSocketPeer.new()
	_sig_open = false
	if _sig.connect_to_url(signaling_url) != OK:
		_sig = null
		_fail("Não foi possível falar com o servidor de sinalização.")


func _process(_delta: float) -> void:
	if _sig == null:
		return
	_sig.poll()
	var st := _sig.get_ready_state()
	if st == WebSocketPeer.STATE_OPEN:
		if not _sig_open:
			_sig_open = true
			_sig_send({"type": "host"} if _online_role == "host" else {"type": "join", "code": room_code})
		while _sig.get_available_packet_count() > 0:
			var msg = JSON.parse_string(_sig.get_packet().get_string_from_utf8())
			if msg is Dictionary:
				_on_signal(msg)
	elif st == WebSocketPeer.STATE_CLOSED:
		var was_open := _sig_open
		_sig = null
		if not was_open:
			_fail("Não foi possível falar com o servidor de sinalização.")
		# depois que todos se conectaram, a sinalização pode cair sem afetar a partida


func _sig_send(msg: Dictionary) -> void:
	if _sig != null and _sig.get_ready_state() == WebSocketPeer.STATE_OPEN:
		_sig.send_text(JSON.stringify(msg))


func _on_signal(msg: Dictionary) -> void:
	match String(msg.get("type", "")):
		"hosted":
			room_code = String(msg.code)
			_rtc = WebRTCMultiplayerPeer.new()
			_rtc.create_server()
			multiplayer.multiplayer_peer = _rtc
			players = {1: {"nick": nick, "avatar": avatar, "tag": ""}}
			room_code_ready.emit(room_code)
			players_changed.emit()
		"joined":
			_rtc = WebRTCMultiplayerPeer.new()
			_rtc.create_client(int(msg.id))
			multiplayer.multiplayer_peer = _rtc
			_new_connection(1)   # o cliente só se liga ao host; o host manda a oferta
		"peer":
			if is_host:
				var c := _new_connection(int(msg.id))
				c.create_offer()
		"signal":
			var c: WebRTCPeerConnection = _conns.get(int(msg.from))
			if c == null:
				return
			var d: Dictionary = msg.data
			if d.kind == "sdp":
				c.set_remote_description(d.sdp_type, d.sdp)
			elif d.kind == "ice":
				c.add_ice_candidate(d.media, int(d.index), d.name)
		"peer_left":
			_conns.erase(int(msg.id))
		"closed":
			if not playing:
				_end("O host fechou a sala.")
		"error":
			_fail(String(msg.get("message", "Erro na sala.")))


func _new_connection(id: int) -> WebRTCPeerConnection:
	var c := WebRTCPeerConnection.new()
	c.initialize({"iceServers": _ice})
	c.session_description_created.connect(func(type: String, sdp: String):
		c.set_local_description(type, sdp)
		_sig_send({"type": "signal", "to": id, "data": {"kind": "sdp", "sdp_type": type, "sdp": sdp}}))
	c.ice_candidate_created.connect(func(media: String, index: int, name: String):
		_sig_send({"type": "signal", "to": id, "data": {"kind": "ice", "media": media, "index": index, "name": name}}))
	_rtc.add_peer(c, id)
	_conns[id] = c
	return c


func leave() -> void:
	if _sig != null:
		_sig.close()
	_sig = null
	_rtc = null
	_conns = {}
	room_code = ""
	_online_role = ""
	if in_session():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	players = {}
	is_host = false
	server_name = ""
	playing = false
	objective_mode = "individual"


# ---------------------------------------------------------------- troca de mensagens

func _on_connected() -> void:
	_register.rpc_id(1, nick, avatar)
	connected_to_server.emit()


func _on_peer_connected(_id: int) -> void:
	pass   # o servidor espera o cliente se apresentar (_register)


func _on_peer_disconnected(id: int) -> void:
	if is_host and players.has(id):
		var tag := String(players[id].get("tag", ""))
		players.erase(id)
		if playing and tag != "":
			player_left.emit(tag)
		_sync.rpc(players, server_name, max_players, objective_mode)
		players_changed.emit()


## Cliente -> servidor: apelido e insígnia de quem acabou de entrar.
@rpc("any_peer", "reliable")
func _register(p_nick: String, p_avatar: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if playing:
		_refused.rpc_id(id, "A partida já começou nesta sala.")
		return
	if players.size() >= max_players:
		_refused.rpc_id(id, "A sala está cheia.")
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	players[id] = {"nick": p_nick.strip_edges().left(MAX_NICK), "avatar": p_avatar if p_avatar in AVATARS else AVATARS[0], "tag": ""}
	_sync.rpc(players, server_name, max_players, objective_mode)
	players_changed.emit()


## Servidor -> todos: lista atual da sala.
@rpc("authority", "reliable")
func _sync(p_players: Dictionary, p_name: String, p_max: int, p_mode: String) -> void:
	players = p_players
	objective_mode = p_mode
	server_name = p_name
	max_players = p_max
	players_changed.emit()


@rpc("any_peer", "reliable")
func _pick(tag: String) -> void:
	if is_host:
		_apply_pick(multiplayer.get_remote_sender_id(), tag)


func _apply_pick(id: int, tag: String) -> void:
	if playing or not players.has(id):
		return
	for other in players:
		if other != id and String(players[other].get("tag", "")) == tag and tag != "":
			return   # já é de outro jogador
	players[id]["tag"] = tag
	_sync.rpc(players, server_name, max_players, objective_mode)
	players_changed.emit()


@rpc("authority", "call_local", "reliable")
func _begin(p_players: Dictionary) -> void:
	players = p_players
	playing = true
	game_started.emit(my_tag())


## Cliente -> host: uma ordem do jogador. O host confere se o país é mesmo dele.
@rpc("any_peer", "reliable")
func _cmd_from_client(d: Dictionary) -> void:
	if not is_host or not playing:
		return
	var id := multiplayer.get_remote_sender_id()
	if not players.has(id) or String(d.get("country", "")) != String(players[id].get("tag", "")):
		return
	host_command.emit(d)


@rpc("authority", "reliable")
func _cmd(d: Dictionary) -> void:
	net_command.emit(d)


@rpc("authority", "reliable")
func _adv(hours: int) -> void:
	net_advance.emit(hours)


@rpc("authority", "reliable")
func _time(p_paused: bool, p_speed: int) -> void:
	time_changed.emit(p_paused, p_speed)


@rpc("authority", "reliable")
func _refused(reason: String) -> void:
	_end(reason)


func _fail(reason: String) -> void:
	leave()
	connection_failed.emit(reason)


func _end(reason: String) -> void:
	last_message = reason if playing else ""
	leave()
	session_ended.emit(reason)


# ---------------------------------------------------------------- perfil guardado

func _remember(address: String) -> void:
	recent_servers.erase(address)
	recent_servers.push_front(address)
	recent_servers = recent_servers.slice(0, 5)
	_save_profile()


func _load_profile() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		nick = String(cfg.get_value("perfil", "apelido", ""))
		avatar = String(cfg.get_value("perfil", "insignia", avatar))
		recent_servers = cfg.get_value("perfil", "servidores", [])


func _save_profile() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("perfil", "apelido", nick)
	cfg.set_value("perfil", "insignia", avatar)
	cfg.set_value("perfil", "servidores", recent_servers)
	cfg.save(SETTINGS_PATH)
