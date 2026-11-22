class_name ArmyGroup
extends RefCounted
## Uma pilha de tropas no mapa: soldados, artilharia, tanques e aviões que andam juntos, talvez sob
## um general. Tropas paradas no mesmo estado viram uma pilha só (ArmySystem.merge_stacks).
## Posição: está no estado `state_id`; se `path` não está vazio, marcha para path[0] e já andou
## `progress_km` desse trecho.

var id: int
var owner: String
var name: String
var troops: Array = []         # [{type, model, count, org}] uma entrada por tipo e modelo
var state_id: int = -1
var path: Array = []           # próximos estados até o destino (ids)
var progress_km: float = 0.0
var general_id: int = -1


func moving() -> bool:
	return not path.is_empty()


func destination() -> int:
	return path.back() if moving() else state_id


func empty() -> bool:
	return troops.is_empty()


## Quantas unidades do tipo (soma dos modelos).
func count_of(type: String) -> float:
	var n := 0.0
	for t in troops:
		if t.type == type:
			n += float(t.count)
	return n


## Tipos presentes, na ordem em que aparecem.
func types() -> Array:
	var out := []
	for t in troops:
		if not t.type in out:
			out.append(t.type)
	return out


func to_dict() -> Dictionary:
	return {"id": id, "owner": owner, "name": name, "troops": troops, "state_id": state_id,
		"path": path, "progress_km": progress_km, "general_id": general_id}
