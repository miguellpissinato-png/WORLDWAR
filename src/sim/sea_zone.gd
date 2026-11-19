class_name SeaZone
extends RefCounted
## Uma zona marítima (região do oceano). Base para a marinha e a guerra naval (Fase 5).

var id: int
var code: String     # ex.: "MAR-0123"
var name: String
var center: Vector2  # coordenadas do mapa


static func from_dict(d: Dictionary) -> SeaZone:
	var z := SeaZone.new()
	z.id = int(d.id)
	z.code = d.get("code", str(z.id))
	z.name = d.name
	var c: Array = d.get("center", [0, 0])
	z.center = Vector2(c[0], c[1])
	return z
