class_name CommandRegistry
extends RefCounted
## Recria comandos a partir de dicionários (rede, replays, saves).
## Todo comando novo precisa ser registrado aqui.

const TYPES := {
	"queue_construction": preload("res://src/commands/queue_construction_command.gd"),
	"set_goods_share": preload("res://src/commands/set_goods_share_command.gd"),
	"propose_trade": preload("res://src/commands/propose_trade_command.gd"),
	"respond_trade": preload("res://src/commands/respond_trade_command.gd"),
	"donate_resources": preload("res://src/commands/donate_resources_command.gd"),
	"claim_country": preload("res://src/commands/claim_country_command.gd"),
	"start_investigation": preload("res://src/commands/start_investigation_command.gd"),
	"upgrade_intelligence": preload("res://src/commands/upgrade_intelligence_command.gd"),
	"set_civil_share": preload("res://src/commands/set_civil_share_command.gd"),
	"start_research": preload("res://src/commands/start_research_command.gd"),
	"cancel_research": preload("res://src/commands/cancel_research_command.gd"),
	"add_production_line": preload("res://src/commands/add_production_line_command.gd"),
	"set_line_factories": preload("res://src/commands/set_line_factories_command.gd"),
	"remove_production_line": preload("res://src/commands/remove_production_line_command.gd"),
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
