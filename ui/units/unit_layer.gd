class_name UnitLayer
extends Node2D
## Tropas no mapa: um soldado 3D por grupo (com um tanque ao lado, na proporção real, se o grupo tem
## blindados), desenhados numa camada 3D por cima do mapa 2D. O soldado fica em pé sobre o ponto do
## mapa onde o grupo está, vira para o próximo estado do caminho e marcha enquanto anda.
## Debaixo dele (no mapa) vão a base oval na cor do país e a seta do caminho.
##
## Escala: o soldado tem um tamanho fixo no mapa (SOLDIER_MAP_HEIGHT unidades, ~0,9 grau), para caber
## nos países; só não fica menor que MIN_PX nem maior que MAX_PX na tela. Tanques e (no futuro) aviões
## usam a escala de miniatura VEHICLE_SCALE (menores que a proporção real, para caber nos países).

signal group_selected(group_id: int)

const PITCH := -50.0              # inclinação da câmera 3D (graus): vê os bonecos meio de cima
const SOLDIER_MAP_HEIGHT := 9.0   # altura do soldado em unidades do mapa (10 unidades = 1 grau)
const MIN_PX := 14.0
const MAX_PX := 72.0
const MIN_ZOOM_ALL := 0.8         # abaixo desse zoom só os grupos do jogador aparecem
## Veículos em escala de miniatura: em proporção real um tanque teria 3x a altura do soldado e um avião
## 6x, e não caberiam nos países menores. Por isso eles são reduzidos (o tanque fica ~2x o soldado).
const VEHICLE_SCALE := 0.55
const SAME_AS := {"CAN": "RUN", "AUS": "RUN", "NZE": "RUN", "AFS": "RUN", "MAN": "JAP", "BEL": "FRA"}

var selected := -1
var _main
var _vp: SubViewport
var _cam: Camera3D
var _root: Node3D
var _models := {}                 # id do grupo -> {holder, soldier, tank, has_tank, yaw}
var _uniforms: Dictionary
var _feet := {}                   # id do grupo -> ponto do mapa (na cópia mais perto da câmera)
var _screen := {}                 # id do grupo -> ponto da tela (pés)
var _px := 30.0
var _right_down := Vector2.INF


func setup(main) -> void:
	_main = main
	_uniforms = ScenarioLoader.read_json("res://data/common/uniforms.json")
	var layer := CanvasLayer.new()
	layer.layer = 1
	add_child(layer)
	var box := SubViewportContainer.new()
	box.stretch = true
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(box)
	_vp = SubViewport.new()
	_vp.transparent_bg = true
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_4X
	box.add_child(_vp)
	_cam = Camera3D.new()
	_cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	_cam.keep_aspect = Camera3D.KEEP_HEIGHT
	_cam.near = 1.0
	_cam.far = 20000.0
	_cam.transform = Transform3D(Basis.from_euler(Vector3(deg_to_rad(PITCH), 0, 0)), Vector3.ZERO).translated_local(Vector3(0, 0, 5000))
	_vp.add_child(_cam)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-52), deg_to_rad(-30), 0)
	sun.light_color = Color(1.0, 0.95, 0.86)
	sun.light_energy = 1.15
	_vp.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.58, 0.64)
	env.environment.ambient_light_energy = 0.65
	_vp.add_child(env)
	_root = Node3D.new()
	_vp.add_child(_root)


func uniform_key(tag: String) -> String:
	var k: String = SAME_AS.get(tag, tag)
	return k if _uniforms.has(k) else "_padrao"


func uniform_of(tag: String) -> Dictionary:
	var base: Dictionary = _uniforms.get("_padrao", {}).duplicate()
	base.merge(_uniforms.get(uniform_key(tag), {}), true)
	return base


## Ponto do chão 3D que aparece no ponto `p` da tela.
func _ground(p: Vector2) -> Vector3:
	var o := _cam.project_ray_origin(p)
	var d := _cam.project_ray_normal(p)
	return o + d * (-o.y / d.y)


func _process(delta: float) -> void:
	if _main == null or not _main.started:
		return
	var size := get_viewport().get_visible_rect().size
	if Vector2(_vp.size) != size:
		_vp.size = Vector2i(size)
	_cam.size = size.y
	var st: GameState = _main.sim.state
	var cam2d: MapCamera = _main.camera
	var ct := get_viewport().get_canvas_transform()
	var zoom: float = cam2d.zoom.x
	_px = clampf(SOLDIER_MAP_HEIGHT * zoom, MIN_PX, MAX_PX)
	var meters_to_px := _px / 1.8 / 0.72
	var screen_rect := Rect2(Vector2(-100, -100), size + Vector2(200, 200))
	# Grupos parados no mesmo estado ficam lado a lado.
	var parked := {}
	for g: ArmyGroup in st.groups.values():
		if not g.moving():
			parked[g.state_id] = parked.get(g.state_id, []) + [g.id]
	_feet.clear()
	_screen.clear()
	var alive := {}
	for g: ArmyGroup in st.groups.values():
		var mine: bool = g.owner == _main.player_tag
		if zoom < MIN_ZOOM_ALL and not mine:
			continue
		var pos: Vector2 = cam2d.near(MovementSystem.map_position(st, g))
		var has_tank := _has_tanks(g)
		if not g.moving() and parked[g.state_id].size() > 1:
			var list: Array = parked[g.state_id]
			pos.x += (list.find(g.id) - (list.size() - 1) * 0.5) * _px * 1.1 / zoom
		var sp := ct * pos
		if not screen_rect.has_point(sp):
			continue
		alive[g.id] = true
		_feet[g.id] = pos
		_screen[g.id] = sp
		var m: Dictionary = _models.get(g.id, {})
		if m.is_empty() or m.has_tank != has_tank:
			if not m.is_empty():
				m.holder.queue_free()
			m = _make_model(g, has_tank)
			_models[g.id] = m
		var holder: Node3D = m.holder
		holder.position = _ground(sp)
		holder.scale = Vector3.ONE * meters_to_px
		if g.moving():
			var nxt := _ground(ct * cam2d.near(st.state(g.path[0]).center)) - holder.position
			if nxt.length() > 0.01:
				m.yaw = atan2(nxt.x, nxt.z)
		holder.rotation.y = lerp_angle(holder.rotation.y, m.yaw, minf(1.0, delta * 6.0))
		var marching: bool = g.moving() and not _main.paused
		m.soldier.marching = marching
		m.soldier.animate(delta)
		if m.tank != null:
			m.tank.speed = 1.2 if marching else 0.0
			m.tank.visible = _px >= 24.0   # de longe, só o soldado (o tanque viraria um borrão)
	for id in _models.keys():
		if not alive.has(id):
			_models[id].holder.queue_free()
			_models.erase(id)
	queue_redraw()


func _has_tanks(g: ArmyGroup) -> bool:
	for r in g.regiments:
		if r.type == "tanquistas":
			return true
	return false


func _make_model(g: ArmyGroup, has_tank: bool) -> Dictionary:
	var holder := Node3D.new()
	_root.add_child(holder)
	var u := uniform_of(g.owner)
	var soldier := SoldierModel.create(uniform_key(g.owner), u)
	holder.add_child(soldier)
	var tank: TankModel = null
	if has_tank:
		tank = TankModel.create(str(u.get("tank", "generico")), Color(u.get("vehicle", "#5a5c45")), str(u.get("marking", "")))
		tank.scale = Vector3.ONE * VEHICLE_SCALE
		tank.position = Vector3(1.7, 0, -0.9)
		holder.add_child(tank)
	# Parado, o boneco olha um pouco de lado para a câmera.
	return {"holder": holder, "soldier": soldier, "tank": tank, "has_tank": has_tank, "yaw": 0.4}


# ---------------------------------------------------------------- base e setas (no mapa, debaixo dos bonecos)

func _draw() -> void:
	if _main == null or not _main.started:
		return
	var st: GameState = _main.sim.state
	var cam2d: MapCamera = _main.camera
	var zoom: float = cam2d.zoom.x
	var w := 2.2 / zoom
	for g: ArmyGroup in st.groups_of(_main.player_tag):
		if not g.moving():
			continue
		var col := Color("#e8d08a") if g.id == selected else Color(0.85, 0.75, 0.5, 0.75)
		var start: Vector2 = _feet.get(g.id, cam2d.near(MovementSystem.map_position(st, g)))
		var pts := PackedVector2Array([start])
		for sid in g.path:
			var c := st.state(sid).center
			pts.append(Vector2(c.x + roundf((pts[pts.size() - 1].x - c.x) / cam2d.map_size.x) * cam2d.map_size.x, c.y))
		for i in pts.size() - 1:
			draw_dashed_line(pts[i], pts[i + 1], col, w, 7.0 / zoom)
		var end := pts[pts.size() - 1]
		var dir := (end - pts[pts.size() - 2]).normalized()
		var side := Vector2(-dir.y, dir.x)
		var s := 8.0 / zoom
		draw_colored_polygon(PackedVector2Array([end, end - dir * s * 1.6 + side * s, end - dir * s * 1.6 - side * s]), col)
		draw_arc(end, s * 0.9, 0, TAU, 16, col, w * 0.8)
	var rx := _px * 0.38 / zoom
	for id in _feet:
		var g: ArmyGroup = st.group(id)
		var p: Vector2 = _feet[id]
		draw_set_transform(p, 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, rx * 1.12, Color(0, 0, 0, 0.3))
		draw_circle(Vector2.ZERO, rx, st.country(g.owner).color.darkened(0.1))
		if id == selected:
			draw_arc(Vector2.ZERO, rx * 1.35, 0, TAU, 32, Color("#e8d08a"), 2.6 / zoom / 0.38)
	draw_set_transform(Vector2.ZERO)


# ---------------------------------------------------------------- seleção e ordens

## Grupo sob o ponto da tela (mira no corpo do soldado), ou -1.
func group_at(screen_pos: Vector2) -> int:
	var best := -1
	var best_d := maxf(_px * 0.6, 12.0)
	for id in _screen:
		var d: float = screen_pos.distance_to(_screen[id] - Vector2(0, _px * 0.5))
		if d < best_d:
			best_d = d
			best = id
	return best


func select(id: int) -> void:
	selected = id
	group_selected.emit(id)


func _unhandled_input(event: InputEvent) -> void:
	if _main == null or not _main.started or not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		var id := group_at(mb.position)
		if id != -1:
			select(id)
			get_viewport().set_input_as_handled()
		elif selected != -1:
			select(-1)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		# Botão direito: arrastar move a câmera; clique rápido manda o grupo selecionado marchar.
		if mb.pressed:
			_right_down = mb.position
		elif _right_down != Vector2.INF and mb.position.distance_to(_right_down) < 6.0:
			_right_down = Vector2.INF
			var g: ArmyGroup = _main.sim.state.group(selected)
			if g != null and g.owner == _main.player_tag:
				var world := get_viewport().get_canvas_transform().affine_inverse() * mb.position
				var sid: int = _main.map.state_at(world)
				if sid != -1:
					_main.submit(MoveGroupCommand.create(_main.player_tag, g.id, sid))
					get_viewport().set_input_as_handled()
