class_name PauseMenu
extends Control
## Menu do Esc durante a partida: Continuar (single player), Salvar jogo, Configurações e Sair.
## Enquanto está aberto, o jogo fica pausado (no single player).

signal continue_chosen
signal save_chosen
signal settings_chosen
signal quit_chosen

var _status: Label
var _continue: Button


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(UiStyle.scrim(0.55))
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)
	var p := UiStyle.panel(26)
	center.add_child(p)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	p.add_child(v)
	var t := UiStyle.title_label("Menu", 24)
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(t)
	v.add_child(UiStyle.rule())
	var gap := Control.new()
	gap.custom_minimum_size = Vector2(0, 4)
	v.add_child(gap)
	_continue = UiStyle.menu_button("play", "Continuar jogo")
	_continue.pressed.connect(func(): continue_chosen.emit())
	v.add_child(_continue)
	var save := UiStyle.menu_button("save", "Salvar jogo")
	save.pressed.connect(func(): save_chosen.emit())
	v.add_child(save)
	var cfg := UiStyle.menu_button("settings", "Configurações")
	cfg.pressed.connect(func(): settings_chosen.emit())
	v.add_child(cfg)
	var quit := UiStyle.menu_button("exit", "Sair para o menu inicial")
	quit.pressed.connect(func(): quit_chosen.emit())
	v.add_child(quit)
	_status = UiStyle.small_label("", 12)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.custom_minimum_size = Vector2(300, 18)
	v.add_child(_status)


## multiplayer = true esconde "Continuar jogo" (no multiplayer o jogo não para no menu).
func open(multiplayer_game: bool = false) -> void:
	_continue.visible = not multiplayer_game
	_status.text = ""
	visible = true


func set_status(text: String) -> void:
	_status.text = text
