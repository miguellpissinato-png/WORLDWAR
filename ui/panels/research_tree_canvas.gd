class_name ResearchTreeCanvas
extends Control
## Fundo da árvore de pesquisa: anos no topo de cada coluna e as linhas em cotovelo que ligam
## cada tecnologia ao que ela exige (verdes quando o requisito já foi pesquisado).

var links: Array = []    # [{from: Vector2, to: Vector2, done: bool}]
var years: Array = []    # [{x: float, text: String}]


func _draw() -> void:
	var font := UiStyle.font("title")
	for y in years:
		var w := font.get_string_size(y.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13).x
		draw_string(font, Vector2(y.x - w / 2, 22), y.text, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, UiStyle.MUTED)
		draw_line(Vector2(y.x, 28), Vector2(y.x, size.y), Color(1, 1, 1, 0.03), 1.0)
	for l in links:
		var a: Vector2 = l.from
		var b: Vector2 = l.to
		var mid := (a.x + b.x) / 2.0
		var col: Color = UiStyle.GOOD if l.done else Color("#5a564a")
		var pts := PackedVector2Array([a, Vector2(mid, a.y), Vector2(mid, b.y), b])
		draw_polyline(pts, col, 2.0, true)
		draw_colored_polygon(PackedVector2Array([b, b + Vector2(-7, -4), b + Vector2(-7, 4)]), col)
