class_name ArmyGroup
extends RefCounted
## Um grupo do exército: alguns regimentos que andam juntos, talvez sob um general.
## Posição: está no estado `state_id`; se `path` não está vazio, marcha para path[0] e já andou
## `progress_km` desse trecho.

var id: int
var owner: String
var name: String
var regiments: Array = []      # [{type, equipment: {equipamento: unidades}}]
var state_id: int = -1
var path: Array = []           # próximos estados até o destino (ids)
var progress_km: float = 0.0
var general_id: int = -1


func moving() -> bool:
	return not path.is_empty()


func destination() -> int:
	return path.back() if moving() else state_id


func to_dict() -> Dictionary:
	return {"id": id, "owner": owner, "name": name, "regiments": regiments, "state_id": state_id,
		"path": path, "progress_km": progress_km, "general_id": general_id}
