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
var last_message := ""             # aviso para mostrar no menu depois de voltar (ex.: host saiu)


func _ready() -> void:
	_load_profile()
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


func leave() -> void:
	if in_session():
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null
	players = {}
	is_host = false
	server_name = ""
	playing = false


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
		_sync.rpc(players, server_name, max_players)
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
	_sync.rpc(players, server_name, max_players)
	players_changed.emit()


## Servidor -> todos: lista atual da sala.
@rpc("authority", "reliable")
func _sync(p_players: Dictionary, p_name: String, p_max: int) -> void:
	players = p_players
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
	_sync.rpc(players, server_name, max_players)
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
