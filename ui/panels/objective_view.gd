class_name ObjectiveView
extends RefCounted
## Desenha um objetivo de vitória: nome e uma barra por alvo ("Europa: 12% de 90%").


static func build(state: GameState, defs: Dictionary, tag: String, id: String, width: float = 300.0, title_size: int = 16) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	v.custom_minimum_size = Vector2(width, 0)
	var obj := ObjectiveSystem.find(defs, id)
	if obj.is_empty():
		v.add_child(UiStyle.small_label("Sem objetivo definido.", 12))
		return v
	var name := UiStyle.title_label(String(obj.name), title_size, UiStyle.TEXT)
	name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(name)
	var p := ObjectiveSystem.progress(state, defs, tag, id)
	for part in p.parts:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		v.add_child(row)
		var l := UiStyle.small_label(String(part.label), 12, UiStyle.TEXT)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		var n := UiStyle.small_label("%d%% de %d%%" % [roundi(part.share * 100), roundi(part.target * 100)], 12,
			UiStyle.GOOD if part.share >= part.target else UiStyle.MUTED)
		row.add_child(n)
		var bar := ProgressBar.new()
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(width, 8)
		bar.max_value = 1.0
		bar.value = clampf(part.share / maxf(part.target, 0.001), 0.0, 1.0)
		bar.add_theme_stylebox_override("background", UiStyle.box(Color("#2a2d31"), Color(0, 0, 0, 0), 0, 3))
		bar.add_theme_stylebox_override("fill", UiStyle.box(UiStyle.GOOD if part.share >= part.target else UiStyle.ACCENT, Color(0, 0, 0, 0), 0, 3))
		v.add_child(bar)
	return v
