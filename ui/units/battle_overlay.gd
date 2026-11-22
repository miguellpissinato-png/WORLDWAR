class_name BattleOverlay
extends Control
## Desenha por cima de tudo (inclusive dos bonecos 3D), em tamanho fixo na tela:
## o quadro de cada batalha (força e moral dos dois lados) e a previsão do ataque ao estado sob o mouse.

var _main


func setup(main) -> void:
	_main = main
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _process(_delta: float) -> void:
	if _main != null and _main.started:
		queue_redraw()


func _draw() -> void:
	if _main == null or not _main.started:
		return
	var st: GameState = _main.sim.state
	var xf: Transform2D = _main.units.get_viewport().get_canvas_transform()
	var units: UnitLayer = _main.units
	var zoom: float = _main.camera.zoom.x
	for sid in units.battle_pos:
		if st.battles.has(sid):
			var r := clampf(units._px * 0.55, 10.0, 22.0)
			_draw_battle_box(st, sid, xf * units.battle_pos[sid] + Vector2(0, -r * 1.4))
	if st.group(units.selected) != null and not units.preview_forecast().is_empty() and units._preview_target != -1:
		var c: Vector2 = _main.camera.near(st.state(units._preview_target).center)
		_draw_forecast(xf * c + Vector2(0, -24))
	draw_set_transform(Vector2.ZERO)


## Quadro em cima da marca de batalha: moral dos dois lados e quem leva vantagem (tamanho fixo na tela).
func _draw_battle_box(st: GameState, sid: int, at: Vector2) -> void:
	var b: Dictionary = st.battles[sid]
	var defs: Dictionary = _main.sim.defs
	var att: Array = b.attackers.map(func(i): return st.group(i)).filter(func(g): return g != null)
	var dfn: Array = b.defenders.map(func(i): return st.group(i)).filter(func(g): return g != null)
	if att.is_empty() or dfn.is_empty():
		return
	var font := UiStyle.font("bold")
	draw_set_transform(at)
	var w := 150.0
	draw_rect(Rect2(-w * 0.5, -34, w, 30), Color(0.07, 0.08, 0.09, 0.88))
	draw_rect(Rect2(-w * 0.5, -34, w, 30), Color(0.85, 0.31, 0.24, 0.9), false, 1.0)
	var ca: Color = st.country(att[0].owner).color
	var cd: Color = st.country(dfn[0].owner).color
	var share := float(b.get("p_att", 0.0)) / maxf(float(b.get("p_att", 0.0)) + float(b.get("p_def", 0.0)), 0.001)
	var txt := "%d%%  FORÇA  %d%%" % [roundi(share * 100), 100 - roundi(share * 100)]
	var tw := font.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10).x
	draw_string(font, Vector2(-tw * 0.5, -23), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, 10, Color("#f0e6cc"))
	# barras de moral: atacante à esquerda, defensor à direita
	var half := w * 0.5 - 8
	var oa := UnitLayer._side_org(defs, att)
	var od := UnitLayer._side_org(defs, dfn)
	draw_rect(Rect2(-half, -16, half - 4, 6), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(-4 - (half - 4) * oa, -16, (half - 4) * oa, 6), ca.lightened(0.15))
	draw_rect(Rect2(4, -16, half - 4, 6), Color(1, 1, 1, 0.12))
	draw_rect(Rect2(4, -16, (half - 4) * od, 6), cd.lightened(0.15))
	draw_set_transform(Vector2.ZERO)


## Quadro da previsão de ataque, no estado alvo sob o mouse.
func _draw_forecast(at: Vector2) -> void:
	var f: Dictionary = _main.units.preview_forecast()
	var win: bool = f.winner == "att"
	var safe: bool = f.share >= 0.6
	var l1 := ("VITÓRIA PROVÁVEL" if safe else "VITÓRIA APERTADA") if win else "DERROTA PROVÁVEL"
	l1 += "  ·  %d%% × %d%%" % [roundi(f.share * 100), 100 - roundi(f.share * 100)]
	var l2 := "Força: nós %s · eles %s (com +25%% de defesa)" % [BattlePanel.power_text(f.p_att), BattlePanel.power_text(f.p_def)]
	var days := float(f.hours) / 24.0
	var l3 := ("%s em ~%s" % ["eles recuam" if win else "nosso ataque cede", ("%d horas" % roundi(f.hours)) if days < 1.0 else ("%s dias" % ("%.1f" % days).replace(".", ","))])
	if int(f.soldiers_needed) > 0:
		l3 += "  ·  leve mais ~%s soldados" % UiStyle.num(f.soldiers_needed)
	var font := UiStyle.font("bold")
	var body := UiStyle.font("regular")
	var w := maxf(font.get_string_size(l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x, maxf(body.get_string_size(l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x, body.get_string_size(l3, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x)) + 20
	var col := Color("#8fc46a") if win and safe else (Color("#e0b050") if win else Color("#d9503c"))
	draw_set_transform(at)
	var r := Rect2(-w * 0.5, -78, w, 58)
	draw_rect(r, Color(0.07, 0.08, 0.09, 0.93))
	draw_rect(r, col, false, 1.5)
	draw_string(font, Vector2(-w * 0.5 + 10, -61), l1, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, col)
	draw_string(body, Vector2(-w * 0.5 + 10, -45), l2, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#e6e1d6"))
	draw_string(body, Vector2(-w * 0.5 + 10, -30), l3, HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("#b9b4a8"))
	draw_set_transform(Vector2.ZERO)


