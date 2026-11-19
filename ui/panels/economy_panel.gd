class_name EconomyPanel
extends PanelContainer
## Economia: para cada recurso, quanto vira dinheiro (bens de consumo) e quanto vai para o estoque.
## Na tela fica só o essencial; preço e quanto entra no estoque por dia aparecem ao passar o mouse.

var _main
var _rows := {}        # recurso -> {slider, pct, prod, stock, name}
var _summary: RichTextLabel
var _warn: Label


func setup(main) -> void:
	_main = main
	UiStyle.place(self, 620)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	UiStyle.window_header(v, "Economia", "Quanto de cada recurso vira dinheiro. O resto vai para o estoque.",
		func(): visible = false,
		"O estoque serve para vender, doar ou fabricar equipamento militar.\nAs fábricas civis limitam quanto dá para transformar em dinheiro.")
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for title in ["Recurso", "Extração", "Vira dinheiro", "", "Estoque"]:
		grid.add_child(UiStyle.section(title))
	for r in main.sim.defs.resources:
		var res_label := Label.new()
		res_label.text = r.name
		res_label.mouse_filter = Control.MOUSE_FILTER_STOP
		res_label.add_theme_color_override("font_color", Color(r.color))
		grid.add_child(res_label)
		var prod := Label.new()
		grid.add_child(prod)
		var slider := HSlider.new()
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 5
		slider.custom_minimum_size = Vector2(190, 0)
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var res_id: String = r.id
		slider.value_changed.connect(func(val): _rows[res_id].pct.text = "%d%%" % int(val))
		slider.drag_ended.connect(func(_changed): _commit(res_id))
		grid.add_child(slider)
		var pct := Label.new()
		pct.custom_minimum_size = Vector2(44, 0)
		grid.add_child(pct)
		var stock := Label.new()
		grid.add_child(stock)
		_rows[res_id] = {"slider": slider, "pct": pct, "prod": prod, "stock": stock, "name": res_label}
	_summary = UiStyle.rich()
	v.add_child(_summary)
	_warn = UiStyle.dim_label("")
	_warn.modulate = Color(1.0, 0.75, 0.45)
	v.add_child(_warn)


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
	var cur: String = sim.defs.currency
	for r in sim.defs.resources:
		var row: Dictionary = _rows[r.id]
		var prod := sim.state.resource_production(_main.player_tag, r.id)
		var share := float(c.goods_share.get(r.id, 0.7))
		if not row.slider.has_focus():
			row.slider.set_value_no_signal(share * 100.0)
			row.pct.text = "%d%%" % int(share * 100.0)
		var goods := float(c.last_goods.get(r.id, prod * share))
		row.prod.text = "%d/dia" % prod
		row.stock.text = UiStyle.num(c.stock(r.id))
		var tip := "%s\nPreço mundial: %s %s\nVira dinheiro: %s/dia\nVai para o estoque: %s/dia" % [
			r.name, cur, UiStyle.price(sim.state.price(r.id)), UiStyle.num(goods), UiStyle.num(prod - goods)]
		for k in ["name", "prod", "stock"]:
			row[k].mouse_filter = Control.MOUSE_FILTER_STOP
			row[k].tooltip_text = tip
		var dim := prod == 0 and c.stock(r.id) <= 0
		for k in ["name", "prod", "stock", "pct"]:
			row[k].modulate = Color(1, 1, 1, 0.45) if dim else Color(1, 1, 1)
	var cap: float = sim.state.civil_factories(_main.player_tag) * float(sim.defs.economy.goods_per_factory)
	var used := 0.0
	for r in c.last_goods:
		used += c.last_goods[r]
	_summary.text = UiStyle.kv("Renda de ontem:", UiStyle.money(c.last_income, cur)) + "      " + \
		UiStyle.kv("Uso das fábricas civis:", "%d%%" % int(round(100.0 * used / maxf(cap, 0.001))))
	_warn.text = "Fábricas civis no limite: o excesso vai para o estoque. Mais fábricas civis = mais dinheiro." \
		if used >= cap - 0.01 and cap > 0 else ""
	_warn.visible = _warn.text != ""
