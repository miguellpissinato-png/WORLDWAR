class_name EconomyPanel
extends PanelContainer
## Economia do país do jogador: para cada recurso, quanto vai para bens de consumo (dinheiro)
## e quanto vai para o estoque. As fábricas civis limitam o que dá para transformar em bens.

var _main
var _rows := {}        # recurso -> {slider, pct, prod, goods, stock, price}
var _summary: RichTextLabel


func setup(main) -> void:
	_main = main
	var sb: StyleBox = UiStyle.panel().get_theme_stylebox("panel")
	add_theme_stylebox_override("panel", sb)
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -330
	offset_right = 430
	offset_top = 70
	visible = false

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	v.add_child(UiStyle.header("Economia", func(): visible = false))
	v.add_child(UiStyle.dim_label("Arraste para escolher quanto de cada recurso vira bens de consumo (gera dinheiro). "
		+ "O resto vai para o estoque, que você pode vender, doar ou usar na produção militar."))
	var grid := GridContainer.new()
	grid.columns = 7
	grid.add_theme_constant_override("h_separation", 14)
	v.add_child(grid)
	for title in ["Recurso", "Extração/dia", "Bens de consumo", "", "Estoque/dia", "Estoque", "Preço mundial"]:
		var l := UiStyle.section(title)
		grid.add_child(l)
	for r in main.sim.defs.resources:
		var res_label := Label.new()
		res_label.text = r.name
		res_label.add_theme_color_override("font_color", Color(r.color))
		grid.add_child(res_label)
		var prod := Label.new()
		grid.add_child(prod)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 5
		slider.custom_minimum_size = Vector2(150, 0)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var res_id: String = r.id
		slider.value_changed.connect(func(val): _rows[res_id].pct.text = "%d%%" % int(val))
		slider.drag_ended.connect(func(_changed): _commit(res_id))
		grid.add_child(slider)
		var pct := Label.new()
		pct.custom_minimum_size = Vector2(44, 0)
		grid.add_child(pct)
		var to_stock := Label.new()
		grid.add_child(to_stock)
		var stock := Label.new()
		grid.add_child(stock)
		var price := Label.new()
		grid.add_child(price)
		_rows[res_id] = {"slider": slider, "pct": pct, "prod": prod, "to_stock": to_stock, "stock": stock, "price": price}
	_summary = RichTextLabel.new()
	_summary.bbcode_enabled = true
	_summary.fit_content = true
	v.add_child(_summary)


func _commit(res_id: String) -> void:
	var share: float = _rows[res_id].slider.value / 100.0
	_main.submit(SetGoodsShareCommand.create(_main.player_tag, res_id, share))


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	if not visible:
		return
	var sim: Simulation = _main.sim
	var c: Country = sim.state.country(_main.player_tag)
	for r in sim.defs.resources:
		var row: Dictionary = _rows[r.id]
		var prod := sim.state.resource_production(_main.player_tag, r.id)
		var share := float(c.goods_share.get(r.id, 0.7))
		if not row.slider.has_focus():
			row.slider.set_value_no_signal(share * 100.0)
			row.pct.text = "%d%%" % int(share * 100.0)
		var goods := float(c.last_goods.get(r.id, prod * share))
		row.prod.text = str(prod)
		row.to_stock.text = "+%s" % UiStyle.num(prod - goods)
		row.stock.text = UiStyle.num(c.stock(r.id))
		row.price.text = "%s %s" % [sim.defs.currency, UiStyle.price(sim.state.price(r.id))]
	var cap: float = sim.state.total_building(_main.player_tag, "civilian_factory") * float(sim.defs.economy.goods_per_factory)
	var used := 0.0
	for r in c.last_goods:
		used += c.last_goods[r]
	var a := UiStyle.ACCENT_HEX
	_summary.text = "[color=%s]Capacidade das fábricas civis:[/color] %s de %s unidades/dia em uso     [color=%s]Renda de ontem:[/color] %s     [color=%s]Tesouro:[/color] %s" % [
		a, UiStyle.num(used), UiStyle.num(cap), a, UiStyle.money(c.last_income, sim.defs.currency), a, UiStyle.money(c.money, sim.defs.currency)]
	if used >= cap - 0.01 and cap > 0:
		_summary.text += "\n[color=#e0a060]As fábricas civis estão no limite: o que passar disso vai para o estoque. Construa mais fábricas civis para ganhar mais.[/color]"
