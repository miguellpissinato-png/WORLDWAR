class_name Country
extends RefCounted
## Um país do jogo. Indústria e recursos ficam nos estados; aqui fica o que é nacional.

var tag: String              # código de 3 letras, ex.: "GER"
var name: String
var leader: String
var ideology: String
var color: Color
var capital_state: int
var capital_city: String = ""   # nome da cidade (só exibição)
## Fila de construção: Array de Dictionary {state_id, building, progress}
var construction_queue: Array = []


static func from_dict(d: Dictionary) -> Country:
	var c := Country.new()
	c.tag = d.tag
	c.name = d.name
	c.leader = d.get("leader", "")
	c.ideology = d.get("ideology", "")
	c.color = Color(d.get("color", "#888888"))
	c.capital_city = d.get("capital_city", "")
	# Nos cenários a capital vem como código do mapa e o ScenarioLoader resolve o id.
	var cap = d.get("capital_state", -1)
	c.capital_state = -1 if cap is String else int(cap)
	return c
