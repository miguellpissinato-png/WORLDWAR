class_name MoveGroupCommand
extends Command
## Manda um grupo marchar até um estado (o caminho é calculado por terra). As tropas só passam por
## território próprio, aliado ou de quem está em guerra conosco.
## Se já estava marchando, ele termina o trecho em que está antes de mudar de rumo.

var group_id: int
var target: int


static func create(tag: String, p_group: int, p_target: int) -> MoveGroupCommand:
	var c := MoveGroupCommand.new()
	c.country_tag = tag
	c.group_id = p_group
	c.target = p_target
	return c


func type_name() -> String:
	return "move_group"


func _route(state: GameState) -> Array:
	var g := state.group(group_id)
	if g.moving():
		# Continua até o próximo estado e segue dali.
		var nxt: int = g.path[0]
		if nxt == target:
			return [nxt]
		var rest := ArmySystem.find_path(state, nxt, target, country_tag)
		return [] if rest.is_empty() else [nxt] + rest
	return ArmySystem.find_path(state, g.state_id, target, country_tag)


func validate(state: GameState, _defs: Dictionary) -> String:
	var g := state.group(group_id)
	if g == null or g.owner != country_tag:
		return "grupo desconhecido"
	var s := state.state(target)
	if s == null:
		return "estado desconhecido"
	if target == g.destination():
		return "o grupo já vai para lá"
	if not state.can_enter(country_tag, s.owner):
		return "não estamos em guerra com %s" % state.country(s.owner).name
	if not g.moving() and target == g.state_id:
		return "o grupo já está lá"
	if _route(state).is_empty():
		var from: int = g.path[0] if g.moving() else g.state_id
		var blocker := ArmySystem.route_blocker(state, from, target, country_tag)
		if blocker != "":
			return "o caminho passa por %s, com quem não estamos em guerra" % state.country(blocker).name
		return "não há caminho por terra até %s" % s.name
	return ""


func apply(state: GameState, _defs: Dictionary) -> void:
	var g := state.group(group_id)
	g.path = _route(state)


func _fields() -> Dictionary:
	return {"group_id": group_id, "target": target}


func _load_fields(d: Dictionary) -> void:
	group_id = int(d.group_id)
	target = int(d.target)
