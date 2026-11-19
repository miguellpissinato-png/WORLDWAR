class_name CommandRegistry
extends RefCounted
## Recria comandos a partir de dicionários (rede, replays, saves).
## Todo comando novo precisa ser registrado aqui.

const TYPES := {
	"queue_construction": preload("res://src/commands/queue_construction_command.gd"),
}


static func from_dict(d: Dictionary) -> Command:
	var script = TYPES.get(d.get("type", ""))
	if script == null:
		push_error("Tipo de comando desconhecido: %s" % d.get("type"))
		return null
	var cmd: Command = script.new()
	cmd.country_tag = d.get("country", "")
	cmd._load_fields(d)
	return cmd
