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
## 6x, e não caberiam nos países menores. Por isso são reduzidos: o tanque fica do comprimento da
## altura do soldado e mais baixo que ele (pedido do Miguel: veículos não podem dominar o mapa).
const VEHICLE_SCALE := 0.32
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
	var fx := BattleFx.new()   # explosões, tiros e sons das batalhas (desenhados por cima das marcas)
	fx.setup(main)
	add_child(fx)
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
		var has_plane := _has_planes(g)
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
		if m.is_empty() or m.has_tank != has_tank or m.has_plane != has_plane:
			if not m.is_empty():
				m.holder.queue_free()
			m = _make_model(g, has_tank, has_plane)
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
	return g.count_of("tanques") >= 0.5


func _has_planes(g: ArmyGroup) -> bool:
	return g.count_of("avioes") >= 0.5


static func moral_color(f: float) -> Color:
	return Color("#d9503c") if f < 0.35 else (Color("#e0b050") if f < 0.7 else Color("#8fc46a"))


## Texto curto da pilha no mapa: "320 · 20 tq · 5 av".
static func stack_label(g: ArmyGroup) -> String:
	var parts := []
	for pair in [["infantaria", ""], ["artilharia", " art"], ["tanques", " tq"], ["avioes", " av"]]:
		var n := roundi(g.count_of(pair[0]))
		if n > 0:
			parts.append("%d%s" % [n, pair[1]])
	return " · ".join(parts)


func _make_model(g: ArmyGroup, has_tank: bool, has_plane: bool = false) -> Dictionary:
	var holder := Node3D.new()
	_root.add_child(holder)
	var u := uniform_of(g.owner)
	var soldier := SoldierModel.create(uniform_key(g.owner), u)
	holder.add_child(soldier)
	var tank: TankModel = null
	if has_tank:
		tank = TankModel.create(str(u.get("tank", "generico")), Color(u.get("vehicle", "#5a5c45")), str(u.get("marking", "")))
		tank.scale = Vector3.ONE * VEHICLE_SCALE
		tank.position = Vector3(1.05, 0, -0.45)
		holder.add_child(tank)
	# Parado, o boneco olha um pouco de lado para a câmera.
	if has_plane:
		var plane := PlaneModel.create("fighter", Color(u.get("vehicle", "#5a5c45")), Color(u.get("vehicle", "#5a5c45")).lightened(0.3), str(u.get("marking", "")))
		plane.scale = Vector3.ONE * VEHICLE_SCALE * 0.8
		plane.position = Vector3(-0.9, 2.3, 0.2)
		holder.add_child(plane)
	return {"holder": holder, "soldier": soldier, "tank": tank, "has_tank": has_tank, "has_plane": has_plane, "yaw": 0.4}


# ---------------------------------------------------------------- base e setas (no mapa, debaixo dos bonecos)

const ARROW_MOVE := Color("#6fbf4a")     # marcha em território próprio/aliado
const ARROW_ATTACK := Color("#d9503c")   # entrando em território inimigo
const ARROW_PREVIEW := Color(1, 1, 1, 0.55)

var _preview_target := -1
var _preview_path: Array = []


## Mostra por onde o grupo selecionado iria se o jogador clicasse no estado `sid` (-1 apaga).
var _preview_forecast := {}
var _battle_hits := {}    # estado -> retângulo (no mapa) da marca de batalha, para o clique
var battle_pos := {}      # estado -> ponto (no mapa) da marca de batalha; o BattleOverlay desenha o quadro ali


func preview(sid: int) -> void:
	_preview_target = sid
	_preview_path = []
	_preview_forecast = {}
	var g: ArmyGroup = _main.sim.state.group(selected) if _main != null else null
	if g == null or g.owner != _main.player_tag or sid == -1:
		return
	var from: int = g.path[0] if g.moving() else g.state_id
	if sid == from:
		return
	_preview_path = ArmySystem.find_path(_main.sim.state, from, sid, g.owner)
	if g.moving():
		_preview_path = [from] + _preview_path
	if not _preview_path.is_empty():
		var f := CombatSystem.forecast(_main.sim.state, _main.sim.defs, [g], sid)
		if not f.defenders.is_empty():
			_preview_forecast = f


## Previsão do ataque ao estado sob o mouse ({} se lá não há inimigo).
func preview_forecast() -> Dictionary:
	return _preview_forecast


func _draw() -> void:
	if _main == null or not _main.started:
		return
	var st: GameState = _main.sim.state
	var cam2d: MapCamera = _main.camera
	var zoom: float = cam2d.zoom.x
	for g: ArmyGroup in st.groups_of(_main.player_tag):
		if g.moving():
			_draw_route(g, g.path, 1.0)
	var sel: ArmyGroup = st.group(selected)
	if sel != null and not _preview_path.is_empty():
		_draw_route(sel, _preview_path, 0.6, true)
	_battle_hits = {}
	battle_pos = {}
	_draw_battles(st, cam2d, zoom)

	var rx := _px * 0.38 / zoom
	for id in _feet:
		var g: ArmyGroup = st.group(id)
		var p: Vector2 = _feet[id]
		draw_set_transform(p, 0.0, Vector2(1.0, 0.38))
		draw_circle(Vector2.ZERO, rx * 1.12, Color(0, 0, 0, 0.3))
		draw_circle(Vector2.ZERO, rx, st.country(g.owner).color.darkened(0.1))
		if id == selected:
			draw_arc(Vector2.ZERO, rx * 1.35, 0, TAU, 32, Color("#e8d08a"), 2.6 / zoom / 0.38)
		# número de tropas embaixo do boneco (tamanho fixo na tela)
		if _px >= 22.0 and (g.owner == _main.player_tag or zoom >= MIN_ZOOM_ALL):
			var font := UiStyle.font("bold")
			var txt := stack_label(g)
			var w := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
			draw_set_transform(p + Vector2(0, rx * 0.55), 0.0, Vector2.ONE / zoom)
			var bw := maxf(w + 8, 44.0)
			draw_rect(Rect2(-bw * 0.5, 0, bw, 19), Color(0, 0, 0, 0.6))
			draw_string(font, Vector2(-w * 0.5, 11.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#f0e6cc"))
			# barra de moral (a "vida" da tropa)
			var org := CombatSystem.group_org(_main.sim.defs, g) / 100.0
			draw_rect(Rect2(-bw * 0.5 + 3, 14, bw - 6, 3), Color(1, 1, 1, 0.15))
			draw_rect(Rect2(-bw * 0.5 + 3, 14, (bw - 6) * org, 3), moral_color(org))
	draw_set_transform(Vector2.ZERO)


static func _side_org(defs: Dictionary, side: Array) -> float:
	var t := 0.0
	var n := 0.0
	for g: ArmyGroup in side:
		var w := ArmySystem.stack_size(defs, g)
		t += CombatSystem.group_org(defs, g) * w
		n += w
	return clampf(t / maxf(n, 0.001) / 100.0, 0.0, 1.0)


## Estado da marca de batalha sob o ponto da tela (-1 = nenhuma).
func battle_at(screen_pos: Vector2) -> int:
	var world := get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	for sid in _battle_hits:
		if _main.sim.state.battles.has(sid) and _battle_hits[sid].has_point(world):
			return sid
	return -1


## Marca de batalha: anel vermelho pulsando e duas espadas cruzadas no estado em disputa.
func _draw_battles(st: GameState, cam2d: MapCamera, zoom: float) -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 260.0)
	for sid in st.battles:
		var target: Vector2 = st.state(sid).center
		var p := Vector2.ZERO
		var n := 0
		for gid in st.battles[sid].attackers:
			var ga: ArmyGroup = st.group(gid)
			if ga != null:
				p += st.state(ga.state_id).center.lerp(target, MovementSystem.ATTACK_POS + 0.25)
				n += 1
		p = cam2d.near(p / n if n > 0 else target)
		var r := clampf(_px * 0.55, 10.0, 22.0) / zoom
		battle_pos[sid] = p
		_battle_hits[sid] = Rect2(p - Vector2(r, r) * 1.3, Vector2(r, r) * 2.6)
		draw_circle(p, r * (1.25 + 0.25 * pulse), Color(0.85, 0.2, 0.15, 0.18 + 0.12 * pulse))
		draw_circle(p, r, Color(0.09, 0.1, 0.11, 0.9))
		draw_arc(p, r, 0, TAU, 32, Color(0.85, 0.31, 0.24), 2.2 / zoom)
		var w := 2.6 / zoom
		var s := r * 0.58
		for k in [-1.0, 1.0]:
			var a := p + Vector2(-s, -s * k)
			var b := p + Vector2(s, s * k)
			draw_line(a, b, Color("#e2cf98"), w, true)          # lâmina
			var hilt := a.lerp(b, 0.78)
			var gv := Vector2(s * k, -s).normalized() * s * 0.32
			draw_line(hilt - gv, hilt + gv, Color("#e2cf98"), w, true)   # guarda


## Seta grossa e curva do grupo até o destino, com contorno escuro e ponta larga.
## Verde em território próprio/aliado; vermelha quando o destino é inimigo.
func _draw_route(g: ArmyGroup, path: Array, alpha: float, is_preview: bool = false) -> void:
	var st: GameState = _main.sim.state
	var cam2d: MapCamera = _main.camera
	var zoom: float = cam2d.zoom.x
	var start: Vector2 = _feet.get(g.id, cam2d.near(MovementSystem.map_position(st, g)))
	var pts := PackedVector2Array([start])
	for sid in path:
		var c := st.state(sid).center
		pts.append(Vector2(c.x + roundf((pts[pts.size() - 1].x - c.x) / cam2d.map_size.x) * cam2d.map_size.x, c.y))
	if pts.size() < 2:
		return
	var dest_owner: String = st.state(path[path.size() - 1]).owner
	var col := ARROW_PREVIEW if is_preview else (ARROW_ATTACK if st.at_war(g.owner, dest_owner) else ARROW_MOVE)
	col.a *= alpha
	var w := clampf(_px * 0.22, 5.0, 11.0) / zoom
	var curve := _smooth(pts)
	# a ponta: os últimos ~2,6 larguras viram o triângulo
	var head_len := w * 2.6
	var end := curve[curve.size() - 1]
	var body := PackedVector2Array()
	var left := 0.0
	for i in range(curve.size() - 1, 0, -1):
		left += curve[i].distance_to(curve[i - 1])
		if left >= head_len:
			body = curve.slice(0, i)
			break
	if body.size() < 2:
		body = PackedVector2Array([curve[0], curve[0].lerp(end, 0.4)])
	var base := body[body.size() - 1]
	var dir := (end - base).normalized()
	var side := Vector2(-dir.y, dir.x)
	var head := PackedVector2Array([end, base + side * w * 1.7, base - side * w * 1.7])
	var outline := Color(0.05, 0.06, 0.05, 0.75 * alpha)
	var o := 2.4 / zoom
	draw_polyline(body, outline, w + o * 2.0, true)
	var head_out := PackedVector2Array([end + dir * o * 1.6, base + side * (w * 1.7 + o * 1.4) - dir * o,
		base - side * (w * 1.7 + o * 1.4) - dir * o])
	draw_colored_polygon(head_out, outline)
	draw_polyline(body, col, w, true)
	draw_colored_polygon(head, col)
	# brilho no meio da seta
	draw_polyline(body, Color(1, 1, 1, 0.22 * alpha), w * 0.3, true)


## Curva suave (Catmull-Rom) passando pelos pontos do caminho.
func _smooth(pts: PackedVector2Array) -> PackedVector2Array:
	if pts.size() < 3:
		return pts
	var out := PackedVector2Array()
	for i in pts.size() - 1:
		var p0 := pts[maxi(i - 1, 0)]
		var p1 := pts[i]
		var p2 := pts[i + 1]
		var p3 := pts[mini(i + 2, pts.size() - 1)]
		for k in 8:
			var t := k / 8.0
			var t2 := t * t
			var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2
				+ (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[pts.size() - 1])
	return out


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
	_preview_path = []
	group_selected.emit(id)


func _unhandled_input(event: InputEvent) -> void:
	if _main == null or not _main.started or not event is InputEventMouseButton:
		return
	var mb := event as InputEventMouseButton
	if mb.button_index == MOUSE_BUTTON_LEFT and mb.pressed:
		var bsid := battle_at(mb.position)
		if bsid != -1:
			_main.open_battle(bsid)
			get_viewport().set_input_as_handled()
			return
		var id := group_at(mb.position)
		if id != -1:
			select(id)
			get_viewport().set_input_as_handled()
			return
		# Com um grupo do jogador selecionado, clicar num estado manda marchar até lá.
		var g: ArmyGroup = _main.sim.state.group(selected)
		if g != null and g.owner == _main.player_tag:
			var sid := _state_under(mb.position)
			if sid != -1:
				_main.order_move(g.id, sid)
				get_viewport().set_input_as_handled()
				return
		if selected != -1:
			select(-1)
	elif mb.button_index == MOUSE_BUTTON_RIGHT:
		# Botão direito: arrastar move a câmera; clique rápido também manda marchar.
		if mb.pressed:
			_right_down = mb.position
		elif _right_down != Vector2.INF and mb.position.distance_to(_right_down) < 6.0:
			_right_down = Vector2.INF
			var g: ArmyGroup = _main.sim.state.group(selected)
			if g != null and g.owner == _main.player_tag:
				var sid := _state_under(mb.position)
				if sid != -1:
					_main.order_move(g.id, sid)
					get_viewport().set_input_as_handled()


func _state_under(screen_pos: Vector2) -> int:
	var world := get_viewport().get_canvas_transform().affine_inverse() * screen_pos
	return _main.map.state_at(world)
