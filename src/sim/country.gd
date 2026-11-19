class_name Country
extends RefCounted
## Um país do jogo. Indústria e recursos ficam nos estados; aqui fica o que é nacional.

var tag: String              # código de 3 letras, ex.: "GER"
var name: String
var leader: String
var ideology: String
var color: Color
var capital_state: int
## Fila de construção: Array de Dictionary {state_id, building, progress}
var construction_queue: Array = []


static func from_dict(d: Dictionary) -> Country:
	var c := Country.new()
	c.tag = d.tag
	c.name = d.name
	c.leader = d.get("leader", "")
	c.ideology = d.get("ideology", "")
	c.color = Color(d.get("color", "#888888"))
	c.capital_state = int(d.get("capital_state", -1))
	return c
