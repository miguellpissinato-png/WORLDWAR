extends Node
## Áudio do jogo (autoload "Audio"): barramento de música, volumes guardados em user://settings.cfg
## e as músicas de fundo tocando uma depois da outra, alternando. Não faz parte da simulação.

const SETTINGS_PATH := "user://settings.cfg"
const MUSIC_BUS := "Musica"

var master_volume := 100.0   # 0–100
var music_volume := 50.0     # 0–100

var _player: AudioStreamPlayer
var _tracks: Array = []
var _index := -1


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if AudioServer.get_bus_index(MUSIC_BUS) == -1:
		AudioServer.add_bus()
		var i := AudioServer.bus_count - 1
		AudioServer.set_bus_name(i, MUSIC_BUS)
		AudioServer.set_bus_send(i, "Master")
	var info: Dictionary = {}
	var f := FileAccess.open("res://data/common/music.json", FileAccess.READ)
	if f != null:
		info = JSON.parse_string(f.get_as_text())
	_tracks = info.get("tracks", [])
	master_volume = float(info.get("default_master", 100))
	music_volume = float(info.get("default_music", 50))
	_load_settings()
	_apply_volumes()
	_player = AudioStreamPlayer.new()
	_player.bus = MUSIC_BUS
	_player.finished.connect(_next_track)
	add_child(_player)
	_next_track()


func _next_track() -> void:
	if _tracks.is_empty():
		return
	_index = (_index + 1) % _tracks.size()
	var stream = load(_tracks[_index].file)
	if stream == null:
		return
	if stream is AudioStreamMP3:
		stream.loop = false
	_player.stream = stream
	_player.play()


func current_title() -> String:
	return "" if _index < 0 else String(_tracks[_index].get("title", ""))


func set_master(v: float) -> void:
	master_volume = clampf(v, 0, 100)
	_apply_volumes()
	_save_settings()


func set_music(v: float) -> void:
	music_volume = clampf(v, 0, 100)
	_apply_volumes()
	_save_settings()


func _apply_volumes() -> void:
	_set_bus(0, master_volume)
	_set_bus(AudioServer.get_bus_index(MUSIC_BUS), music_volume)


func _set_bus(i: int, v: float) -> void:
	if i < 0:
		return
	AudioServer.set_bus_mute(i, v <= 0.0)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(v, 0.001) / 100.0))


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		master_volume = float(cfg.get_value("audio", "master", master_volume))
		music_volume = float(cfg.get_value("audio", "music", music_volume))


func _save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("audio", "master", master_volume)
	cfg.set_value("audio", "music", music_volume)
	cfg.save(SETTINGS_PATH)
