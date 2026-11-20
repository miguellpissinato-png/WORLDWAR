class_name MapCamera
extends Camera2D
## Câmera do mapa: roda do mouse = zoom (na direção do cursor), botão direito ou do meio
## arrasta, WASD/setas movem. Avisa quando o zoom muda.

signal zoom_changed(zoom: float)

const MIN_ZOOM := 0.35
const MAX_ZOOM := 10.0
const KEY_SPEED := 900.0   # pixels da tela por segundo

var map_size := Vector2(3600, 1800)
var _dragging := false


func _ready() -> void:
	make_current()
	get_viewport().size_changed.connect(_clamp)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_at(1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_at(1.0 / 1.15, event.position)
		elif event.button_index in [MOUSE_BUTTON_RIGHT, MOUSE_BUTTON_MIDDLE]:
			_dragging = event.pressed
	elif event is InputEventMouseMotion and _dragging:
		position -= event.relative / zoom.x
		_clamp()


func _process(delta: float) -> void:
	var dir := Vector2(
		Input.get_axis("ui_left", "ui_right") + float(Input.is_key_pressed(KEY_D)) - float(Input.is_key_pressed(KEY_A)),
		Input.get_axis("ui_up", "ui_down") + float(Input.is_key_pressed(KEY_S)) - float(Input.is_key_pressed(KEY_W)))
	if dir != Vector2.ZERO:
		position += dir.normalized() * KEY_SPEED * delta / zoom.x
		_clamp()


## Zoom mínimo: o mapa sempre cobre a tela toda na altura (nada de faixa cinza em cima ou embaixo)
## e a largura visível nunca passa de uma volta ao mundo.
func min_zoom() -> float:
	var vp := get_viewport_rect().size
	return maxf(MIN_ZOOM, maxf(vp.y / map_size.y, vp.x / map_size.x) * 1.001)


func set_zoom_level(z: float) -> void:
	z = clampf(z, min_zoom(), MAX_ZOOM)
	zoom = Vector2(z, z)
	_clamp()
	zoom_changed.emit(z)


func _zoom_at(factor: float, screen_pos: Vector2) -> void:
	var before := get_global_mouse_position()
	set_zoom_level(zoom.x * factor)
	# Mantém o ponto sob o cursor no mesmo lugar.
	var vp := get_viewport_rect().size
	position = before - (screen_pos - vp * 0.5) / zoom.x
	_clamp()


func _clamp() -> void:
	if zoom.x < min_zoom():
		zoom = Vector2.ONE * min_zoom()
		zoom_changed.emit(zoom.x)
	var half := get_viewport_rect().size * 0.5 / zoom.x
	# Em x o mundo dá a volta: a câmera fica sempre sobre o mapa original (as cópias cobrem as bordas).
	position.x = fposmod(position.x, map_size.x)
	position.y = clampf(position.y, minf(half.y, map_size.y * 0.5), maxf(map_size.y - half.y, map_size.y * 0.5))


## Leva um ponto do mapa para a cópia mais perto da câmera (para desenhar tropas e setas).
func near(p: Vector2) -> Vector2:
	return Vector2(p.x + roundf((position.x - p.x) / map_size.x) * map_size.x, p.y)
