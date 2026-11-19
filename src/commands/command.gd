class_name Command
extends RefCounted
## Base de todas as ações que mudam a simulação.
## Fluxo: interface/rede/IA cria o comando -> Simulation.submit() -> na próxima hora:
## validate() e, se estiver ok, apply().

var country_tag: String = ""   # país que deu a ordem


## Nome único do tipo, usado na serialização. Subclasses devem sobrescrever.
func type_name() -> String:
	return "command"


## Retorna "" se o comando pode ser aplicado, ou o motivo da recusa.
func validate(_state: GameState, _defs: Dictionary) -> String:
	return ""


func apply(_state: GameState, _defs: Dictionary) -> void:
	pass


## Campos próprios da subclasse (sem type e country).
func _fields() -> Dictionary:
	return {}


func _load_fields(_d: Dictionary) -> void:
	pass


func to_dict() -> Dictionary:
	var d := _fields()
	d["type"] = type_name()
	d["country"] = country_tag
	return d
