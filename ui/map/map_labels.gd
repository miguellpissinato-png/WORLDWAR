class_name MapLabels
extends Node2D
## Nomes dos países escritos sobre o território, seguindo a forma do país (curva suave),
## e as capitais com estrela. Os nomes ficam no espaço do mapa (crescem com o zoom);
## as capitais mantêm tamanho constante na tela.

const NAME_FILL := Color(0.93, 0.94, 0.96, 0.62)
const NAME_OUTLINE := Color(0.08, 0.09, 0.12, 0.55)
const CITY_FILL := Color(0.95, 0.95, 0.95, 0.95)
const CITY_OUTLINE := Color(0, 0, 0, 0.85)
const MIN_FONT := 7.0          # nomes menores que isso (em unidades do mapa) não aparecem
const MAX_FONT := 64.0         # países enormes: letras espaçadas em vez de gigantes

var _labels: Array = []        # [{text, points: [Vector2], angles: [float], size}]
var _capitals: Array = []      # [{pos, name}]
var _zoom := 1.0
var _font: Font
var _cities: Node2D


func _ready() -> void:
	# Fonte em campo de distância (MSDF): continua nítida em qualquer zoom.
	var base := ThemeDB.fallback_font
	if base is FontFile:
		var f: FontFile = base.duplicate()
		f.multichannel_signed_distance_field = true
		f.msdf_pixel_range = 16
		f.msdf_size = 64
		_font = f
	else:
		_font = base
	_cities = Node2D.new()
	_cities.draw.connect(_draw_cities)
	add_child(_cities)


func build(state: GameState, map: MapView) -> void:
	_labels.clear()
	_capitals.clear()
	var by_owner := {}
	for s in state.states.values():
		if not by_owner.has(s.owner):
			by_owner[s.owner] = []
		by_owner[s.owner].append(s)
	for tag in by_owner:
		var country := state.country(tag)
		if country == null:
			continue
		for cluster in _clusters(by_owner[tag], map):
			var label := _make_label(country.name.to_upper(), cluster, map)
			if not label.is_empty():
				_labels.append(label)
		var cap := state.state(country.capital_state)
		if cap != null:
			_capitals.append({"pos": cap.center, "name": _capital_name(country)})
	queue_redraw()
	_cities.queue_redraw()


func set_zoom(zoom: float) -> void:
	_zoom = zoom
	# De muito perto os nomes dos países atrapalham: ficam mais transparentes.
	modulate.a = clampf(1.0 - (zoom - 2.5) / 3.0, 0.25, 1.0)
	_cities.modulate.a = 1.0 / maxf(modulate.a, 0.01)
	_cities.queue_redraw()


func _capital_name(country: Country) -> String:
	return country.capital_city


## Agrupa estados vizinhos (por proximidade) para que cada território contínuo
## (ex.: a metrópole e cada colônia) receba o seu próprio nome.
func _clusters(states: Array, map: MapView) -> Array:
	var n := states.size()
	var parent := range(n)
	var size := []
	for s in states:
		size.append(sqrt(map.area_of(s.id)))
	var find := func(i):
		while parent[i] != i:
			parent[i] = parent[parent[i]]
			i = parent[i]
		return i
	for i in n:
		for j in range(i + 1, n):
			var limit: float = 0.65 * (size[i] + size[j]) + 4.0
			if states[i].center.distance_to(states[j].center) < limit:
				var a = find.call(i)
				var b = find.call(j)
				if a != b:
					parent[a] = b
	var groups := {}
	for i in n:
		var r = find.call(i)
		if not groups.has(r):
			groups[r] = []
		groups[r].append(states[i])
	return groups.values()


## Encaixa o nome no território: eixo principal (PCA) + curva de 2º grau pelos centros.
func _make_label(text: String, states: Array, map: MapView) -> Dictionary:
	var total := 0.0
	var mean := Vector2.ZERO
	for s in states:
		var w := map.area_of(s.id)
		total += w
		mean += s.center * w
	if total <= 0.0:
		return {}
	mean /= total
	# Covariância ponderada dos centros -> direção principal.
	var cxx := 0.0
	var cyy := 0.0
	var cxy := 0.0
	for s in states:
		var w := map.area_of(s.id)
		var d: Vector2 = s.center - mean
		cxx += w * d.x * d.x
		cyy += w * d.y * d.y
		cxy += w * d.x * d.y
	var angle := 0.5 * atan2(2.0 * cxy, cxx - cyy)
	angle = clampf(angle, -0.6, 0.6)    # nomes muito inclinados ficam difíceis de ler
	var axis := Vector2.from_angle(angle)
	var perp := Vector2(-axis.y, axis.x)
	# Extensão do território ao longo dos eixos.
	var umin := INF
	var umax := -INF
	var vmin := INF
	var vmax := -INF
	# Usa os centros dos estados (± metade do tamanho de cada um) em vez de todos os pontos:
	# evita que pedaços do outro lado da linha de data puxem o nome para longe.
	for s in states:
		var d: Vector2 = s.center - mean
		var half := sqrt(map.area_of(s.id)) * 0.5
		if d.length() > map.map_size.x * 0.4:
			continue
		umin = minf(umin, d.dot(axis) - half)
		umax = maxf(umax, d.dot(axis) + half)
		vmin = minf(vmin, d.dot(perp) - half)
		vmax = maxf(vmax, d.dot(perp) + half)
	var length := (umax - umin) * 0.72
	var thickness := vmax - vmin
	var n := text.length()
	var font_size := minf(minf(length / (n * 0.78), thickness * 0.42), MAX_FONT)
	if font_size < MIN_FONT:
		return {}
	length = minf(length, font_size * n * 1.9)
	# Curva v = a*u² (ajuste pelos centros, curvatura limitada).
	var su4 := 0.0
	var su2v := 0.0
	for s in states:
		var w := map.area_of(s.id)
		var d: Vector2 = s.center - mean
		var u := d.dot(axis)
		su4 += w * u * u * u * u
		su2v += w * u * u * d.dot(perp)
	var a := 0.0 if su4 <= 0.0 else su2v / su4
	var max_bend := 0.18 * thickness / maxf(1.0, (length * 0.5) * (length * 0.5))
	a = clampf(a, -max_bend, max_bend)
	var mid_u := (umin + umax) * 0.5
	var positions: Array = []
	var angles: Array = []
	for i in n:
		var u := mid_u - length * 0.5 + length * (i + 0.5) / n
		var du := u - mid_u
		var v := a * du * du
		positions.append(mean + axis * u + perp * v)
		var slope := 2.0 * a * du
		angles.append(angle + atan(slope))
	return {"text": text, "points": positions, "angles": angles, "size": font_size}


func _draw() -> void:
	for l in _labels:
		var size := int(l.size)
		for i in l.text.length():
			var ch: String = l.text[i]
			var w := _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
			draw_set_transform(l.points[i], l.angles[i])
			var at := Vector2(-w * 0.5, size * 0.35)
			draw_char_outline(_font, at, ch, size, maxi(2, size / 7), NAME_OUTLINE)
			draw_char(_font, at, ch, size, NAME_FILL)
	draw_set_transform(Vector2.ZERO, 0.0)


func _draw_cities() -> void:
	var s := 1.0 / _zoom
	var size := int(12)
	for c in _capitals:
		_cities.draw_set_transform(c.pos, 0.0, Vector2(s, s))
		_cities.draw_colored_polygon(_star(5.5), CITY_FILL)
		_cities.draw_polyline(_star(5.5) + PackedVector2Array([_star(5.5)[0]]), CITY_OUTLINE, 1.0)
		if _zoom > 1.2 and c.name != "":
			_cities.draw_string_outline(_font, Vector2(9, 4), c.name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 3, CITY_OUTLINE)
			_cities.draw_string(_font, Vector2(9, 4), c.name, HORIZONTAL_ALIGNMENT_LEFT, -1, size, CITY_FILL)
	_cities.draw_set_transform(Vector2.ZERO, 0.0)


static func _star(r: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 10:
		var rad := r if i % 2 == 0 else r * 0.45
		var ang := -PI / 2 + i * PI / 5
		pts.append(Vector2(cos(ang), sin(ang)) * rad)
	return pts
