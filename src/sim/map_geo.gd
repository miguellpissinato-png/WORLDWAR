class_name MapGeo
extends RefCounted
## Conversão das coordenadas do mapa (projeção de Miller, 10 unidades por grau, topo em 83°N)
## para latitude/longitude, e distância real em km. Igual a tools/map/build_map.py.

const SCALE := 10.0
const LAT_TOP := 83.0
const EARTH_KM := 6371.0


static func _miller_deg(lat: float) -> float:
	return rad_to_deg(1.25 * log(tan(PI / 4.0 + 0.4 * deg_to_rad(lat))))


static func to_lonlat(p: Vector2) -> Vector2:
	var y_deg := _miller_deg(LAT_TOP) - p.y / SCALE
	var lat := rad_to_deg((atan(exp(deg_to_rad(y_deg) / 1.25)) - PI / 4.0) / 0.4)
	return Vector2(p.x / SCALE - 180.0, lat)


## Distância em km (círculo máximo) entre dois pontos do mapa.
static func km(a: Vector2, b: Vector2) -> float:
	var la := to_lonlat(a)
	var lb := to_lonlat(b)
	var p1 := deg_to_rad(la.y)
	var p2 := deg_to_rad(lb.y)
	var dp := p2 - p1
	var dl := deg_to_rad(lb.x - la.x)
	var h := sin(dp / 2) ** 2 + cos(p1) * cos(p2) * sin(dl / 2) ** 2
	return 2.0 * EARTH_KM * asin(sqrt(clampf(h, 0.0, 1.0)))
