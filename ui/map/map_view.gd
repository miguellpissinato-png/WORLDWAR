class_name MapView
extends Node2D
## Desenha o mapa e descobre qual estado está sob o mouse.
##
## Como funciona: cada estado é desenhado uma vez numa imagem escondida (SubViewport) com uma
## "cor-código" que guarda o seu id. Um shader (map.gdshader) lê essa imagem e uma tabela
## id -> dono para pintar cores, terreno, fronteiras e costa. Quando um estado muda de dono,
## só a tabela muda: a imagem não precisa ser redesenhada.
## Só lê o GameState; nunca o altera.

signal state_clicked(state_id: int)
signal state_hovered(state_id: int)

const SHAPES_PATH := "res://data/map/shapes.json"
const ID_SCALE := 2.0      # resolução da imagem de IDs em relação às coordenadas do mapa
const LOOKUP_WIDTH := 4096
const CELL := 40.0         # tamanho da célula da grade de busca (clique)
const GAP_FILL := 0.8      # quanto expandir os contornos na passada que tapa frestas

var map_size := Vector2.ZERO
var _rings := {}           # state_id -> Array[PackedVector2Array]
var _grid := {}            # Vector2i -> Array[state_id]
var _area := {}            # state_id -> área aproximada (desempate em enclaves)
var _state: GameState
var _selected := -1
var _hovered := -1
var _id_viewport: SubViewport
var _sprite: Sprite2D
var _material: ShaderMaterial
var _lookup_image: Image
var _lookup: ImageTexture
var _owner_index := {}     # tag -> número


func load_shapes() -> void:
	var data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SHAPES_PATH))
	map_size = Vector2(data.width, data.height)
	var shapes: Dictionary = data.shapes

	_id_viewport = SubViewport.new()
	_id_viewport.size = Vector2i(map_size * ID_SCALE)
	_id_viewport.transparent_bg = false
	_id_viewport.disable_3d = true
	_id_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	_id_viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	add_child(_id_viewport)
	var bg := ColorRect.new()          # id 0 = mar
	bg.color = Color.BLACK
	bg.size = map_size * ID_SCALE
	_id_viewport.add_child(bg)
	var holder := Node2D.new()
	holder.scale = Vector2(ID_SCALE, ID_SCALE)
	_id_viewport.add_child(holder)

	var order: Array = []
	for key in shapes:
		var sid := int(key)
		var rings: Array = []
		var rect := Rect2()
		var area := 0.0
		for flat in shapes[key]:
			var pts := PackedVector2Array()
			pts.resize(flat.size() / 2)
			for i in pts.size():
				pts[i] = Vector2(flat[2 * i], flat[2 * i + 1])
			rings.append(pts)
			var r := _bounds(pts)
			rect = r if rect.size == Vector2.ZERO else rect.merge(r)
			area += r.get_area()
		_rings[sid] = rings
		_area[sid] = area
		order.append(sid)
		_add_to_grid(sid, rect)
	# Maiores primeiro: enclaves (ex.: Lesoto) ficam por cima.
	order.sort_custom(func(a, b): return _area[a] > _area[b])
	# 1ª passada: contornos levemente expandidos, que tapam frestas entre vizinhos
	# (os dados originais têm pequenos buracos). 2ª passada: contornos exatos por cima.
	for sid in order:
		var code := Color8(sid % 256, sid / 256, 0)
		for pts in _rings[sid]:
			for grown in Geometry2D.offset_polygon(pts, GAP_FILL):
				var g := Polygon2D.new()
				g.polygon = grown
				g.color = code
				g.antialiased = false
				holder.add_child(g)
	for sid in order:
		var code := Color8(sid % 256, sid / 256, 0)
		for pts in _rings[sid]:
			var p := Polygon2D.new()
			p.polygon = pts
			p.color = code
			p.antialiased = false
			holder.add_child(p)

	_lookup_image = Image.create(LOOKUP_WIDTH, 2, false, Image.FORMAT_RGBA8)
	_lookup = ImageTexture.create_from_image(_lookup_image)

	_material = ShaderMaterial.new()
	_material.shader = load("res://ui/map/map.gdshader")
	_material.set_shader_parameter("lookup", _lookup)
	_material.set_shader_parameter("tex_size", map_size * ID_SCALE)
	_material.set_shader_parameter("land_noise", _noise(3, 0.012, 7))
	_material.set_shader_parameter("detail_noise", _noise(11, 0.05, 4))
	_material.set_shader_parameter("sea_noise", _noise(23, 0.008, 5))

	_sprite = Sprite2D.new()
	_sprite.texture = _id_viewport.get_texture()
	_sprite.centered = false
	_sprite.scale = Vector2(1.0 / ID_SCALE, 1.0 / ID_SCALE)
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_sprite.material = _material
	add_child(_sprite)


## Atualiza a tabela id -> dono. Chamar quando estados mudarem de dono.
func color_by_owner(state: GameState) -> void:
	_state = state
	var i := 1
	for tag in state.countries:
		if not _owner_index.has(tag):
			_owner_index[tag] = i
			i += 1
	_lookup_image.fill(Color(0, 0, 0, 0))
	for sid in _rings:
		var s: MapState = state.state(sid)
		if s == null or state.country(s.owner) == null:
			continue
		var idx: int = _owner_index[s.owner]
		_lookup_image.set_pixel(sid, 0, state.country(s.owner).color)
		_lookup_image.set_pixel(sid, 1, Color8(idx % 256, idx / 256, 255 if sid == _selected else 0))
	_lookup.update(_lookup_image)


func select(state_id: int) -> void:
	for sid in [_selected, state_id]:
		if sid > 0 and _state != null and _state.state(sid) != null:
			var idx: int = _owner_index.get(_state.state(sid).owner, 0)
			_lookup_image.set_pixel(sid, 1, Color8(idx % 256, idx / 256, 255 if sid == state_id else 0))
	_selected = state_id
	_lookup.update(_lookup_image)


## Chamado pela câmera: mantém a espessura das linhas constante na tela.
func set_zoom(zoom: float) -> void:
	_material.set_shader_parameter("texels_per_px", ID_SCALE / zoom)
	_material.set_shader_parameter("state_border_alpha", clampf((zoom - 0.6) / 1.4, 0.0, 0.6))


## Estado sob um ponto do mapa (coordenadas locais), ou -1.
func state_at(point: Vector2) -> int:
	var best := -1
	for sid in _grid.get(_cell(point), []):
		for pts in _rings[sid]:
			if Geometry2D.is_point_in_polygon(point, pts):
				if best == -1 or _area[sid] < _area[best]:
					best = sid
	return best


func rings_of(state_id: int) -> Array:
	return _rings.get(state_id, [])


func area_of(state_id: int) -> float:
	return _area.get(state_id, 0.0)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var sid := state_at(get_local_mouse_position())
		if sid != _hovered:
			_hovered = sid
			state_hovered.emit(sid)
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var sid := state_at(get_local_mouse_position())
		if sid != -1:
			state_clicked.emit(sid)
			get_viewport().set_input_as_handled()


func _noise(seed: int, frequency: float, octaves: int) -> NoiseTexture2D:
	var n := FastNoiseLite.new()
	n.seed = seed
	n.frequency = frequency
	n.fractal_octaves = octaves
	var t := NoiseTexture2D.new()
	t.noise = n
	t.width = 512
	t.height = 512
	t.seamless = true
	return t


func _add_to_grid(sid: int, rect: Rect2) -> void:
	for x in range(int(floor(rect.position.x / CELL)), int(floor(rect.end.x / CELL)) + 1):
		for y in range(int(floor(rect.position.y / CELL)), int(floor(rect.end.y / CELL)) + 1):
			var key := Vector2i(x, y)
			if not _grid.has(key):
				_grid[key] = []
			_grid[key].append(sid)


func _cell(p: Vector2) -> Vector2i:
	return Vector2i(int(floor(p.x / CELL)), int(floor(p.y / CELL)))


static func _bounds(pts: PackedVector2Array) -> Rect2:
	var r := Rect2(pts[0], Vector2.ZERO)
	for p in pts:
		r = r.expand(p)
	return r
