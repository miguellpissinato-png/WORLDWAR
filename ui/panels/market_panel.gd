class_name MarketPanel
extends PanelContainer
## Mercado de recursos: comprar lotes que outros países colocam à venda, vender o seu estoque
## a quem quer comprar, doar recursos e responder propostas de outros jogadores.
## Só mostra o que é público (lotes à venda e preços); produção e estoques dos outros ficam ocultos.

const MAX_ROWS := 5

var _main
var _resource: OptionButton
var _price_info: Label
var _sellers: VBoxContainer
var _buyers: VBoxContainer
var _offers: VBoxContainer
var _donate_to: OptionButton
var _donate_qty: SpinBox
var _donate_label: Label


func setup(main) -> void:
	_main = main
	add_theme_stylebox_override("panel", UiStyle.panel().get_theme_stylebox("panel"))
	set_anchors_preset(Control.PRESET_CENTER_TOP)
	offset_left = -330
	offset_right = 450
	offset_top = 70
	visible = false

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	v.add_child(UiStyle.header("Mercado de recursos", func(): visible = false))
	var rh := HBoxContainer.new()
	v.add_child(rh)
	var rl := Label.new()
	rl.text = "Recurso:"
	rh.add_child(rl)
	_resource = OptionButton.new()
	var res_list: Array = main.sim.defs.resources
	for i in res_list.size():
		_resource.add_item(res_list[i].name)
		_resource.set_item_metadata(i, res_list[i].id)
	_resource.item_selected.connect(func(_i): refresh())
	rh.add_child(_resource)
	_price_info = Label.new()
	_price_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_price_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	rh.add_child(_price_info)

	# O conteúdo rola quando passa da altura disponível.
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 470)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	v.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	scroll.add_child(body)
	v = body
	v.add_child(UiStyle.section("Lotes à venda (proponha um preço; o vendedor aceita a partir de 95% do mercado)"))
	_sellers = VBoxContainer.new()
	v.add_child(_sellers)
	v.add_child(UiStyle.section("Querem comprar (venda do seu estoque)"))
	_buyers = VBoxContainer.new()
	v.add_child(_buyers)

	v.add_child(UiStyle.section("Doar do seu estoque"))
	var dh := HBoxContainer.new()
	v.add_child(dh)
	_donate_to = OptionButton.new()
	_donate_to.custom_minimum_size = Vector2(220, 0)
	dh.add_child(_donate_to)
	_donate_qty = SpinBox.new()
	_donate_qty.min_value = 1
	dh.add_child(_donate_qty)
	var donate := Button.new()
	donate.text = "Doar"
	donate.pressed.connect(func():
		var to: String = _donate_to.get_item_metadata(_donate_to.selected)
		_main.submit(DonateResourcesCommand.create(_main.player_tag, to, _res(), int(_donate_qty.value)))
		_main.write_log("Doação de %d de %s para %s." % [int(_donate_qty.value), _res_name(), _main.sim.state.country(to).name]))
	dh.add_child(donate)
	_donate_label = UiStyle.dim_label("")
	dh.add_child(_donate_label)

	v.add_child(UiStyle.section("Propostas recebidas"))
	_offers = VBoxContainer.new()
	v.add_child(_offers)

	var tags: Array = main.sim.state.countries.keys()
	tags.sort_custom(func(a, b): return main.sim.state.country(a).name < main.sim.state.country(b).name)
	for i in tags.size():
		_donate_to.add_item(main.sim.state.country(tags[i]).name)
		_donate_to.set_item_metadata(i, tags[i])


func _res() -> String:
	return _resource.get_item_metadata(_resource.selected)


func _res_name() -> String:
	return _resource.get_item_text(_resource.selected)


func toggle() -> void:
	visible = not visible
	if visible:
		refresh()


func refresh() -> void:
	if not visible:
		return
	var sim: Simulation = _main.sim
	var st := sim.state
	var me: Country = st.country(_main.player_tag)
	var res := _res()
	var cur: String = sim.defs.currency
	var cap := MarketSystem.max_price(st, sim.defs, res)
	_price_info.text = "Preço mundial: %s %s   ·   teto: %s %s   ·   seu estoque: %s   ·   tesouro: %s" % [
		cur, UiStyle.price(st.price(res)), cur, UiStyle.price(cap), UiStyle.num(me.stock(res)), UiStyle.money(me.money, cur)]
	for box in [_sellers, _buyers, _offers]:
		for c in box.get_children():
			c.queue_free()

	# Lotes à venda: a IA coloca metade do estoque no mercado.
	var lots: Array = []
	for tag in st.countries:
		if tag == _main.player_tag or st.is_human(tag):
			continue
		var lot := int(floor(st.country(tag).stock(res) * 0.5 / 5.0)) * 5
		if lot > 0:
			lots.append([tag, lot])
	lots.sort_custom(func(a, b): return a[1] > b[1])
	if lots.is_empty():
		_sellers.add_child(UiStyle.dim_label("Ninguém está vendendo este recurso agora."))
	for pair in lots.slice(0, MAX_ROWS):
		var tag: String = pair[0]
		var ask := TradeSystem.ai_ask_price(st, sim.defs, tag, res)
		_sellers.add_child(_deal_row(tag, "lote de %s, pede %s %s" % [UiStyle.num(pair[1]), cur, UiStyle.price(ask)],
			pair[1], ask, cap, "Propor compra", "buy"))

	# Interessados: países da IA cuja indústria precisa de mais do que produzem.
	var res_def: Dictionary = sim.defs.resources[sim.defs.resource_ids.find(res)]
	var bid := TradeSystem.ai_bid_price(st, sim.defs, res)
	var wants: Array = []
	for tag in st.countries:
		if tag == _main.player_tag or st.is_human(tag):
			continue
		var need := st.civil_factories(tag) * float(res_def.demand_per_factory) - st.resource_production(tag, res)
		var can_pay := int(st.country(tag).money / maxf(bid, 0.01))
		var qty := mini(int(need * 30.0), can_pay)
		if qty >= 5:
			wants.append([tag, qty])
	wants.sort_custom(func(a, b): return a[1] > b[1])
	if wants.is_empty():
		_buyers.add_child(UiStyle.dim_label("Ninguém está procurando este recurso agora."))
	for pair in wants.slice(0, MAX_ROWS):
		var qmax := mini(pair[1], int(me.stock(res)))
		_buyers.add_child(_deal_row(pair[0], "quer até %s, paga ~%s %s" % [UiStyle.num(pair[1]), cur, UiStyle.price(bid)],
			maxi(qmax, 1), bid, cap, "Propor venda", "sell", qmax <= 0))

	# Propostas recebidas de outros jogadores.
	var mine: Array = st.offers.values().filter(func(o): return o.to == _main.player_tag)
	if mine.is_empty():
		_offers.add_child(UiStyle.dim_label("Nenhuma proposta."))
	for o in mine:
		var row := HBoxContainer.new()
		var l := Label.new()
		var verb := "quer vender a você" if o.kind == "sell" else "quer comprar de você"
		l.text = "%s %s %d de %s a %s %s (total %s)" % [st.country(o.from).name, verb, o.amount, o.resource, cur, UiStyle.price(o.price), UiStyle.money(o.total(), cur)]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		for ans in [["Aceitar", true], ["Recusar", false]]:
			var b := Button.new()
			b.text = ans[0]
			var id: int = o.id
			var accept: bool = ans[1]
			b.pressed.connect(func(): _main.submit(RespondTradeCommand.create(_main.player_tag, id, accept)))
			row.add_child(b)
		_offers.add_child(row)

	_donate_qty.max_value = maxf(1.0, me.stock(res))
	_donate_label.text = "de %s" % UiStyle.num(me.stock(res))


func _deal_row(tag: String, info: String, qmax: int, default_price: float, cap: float, action: String, kind: String, disabled := false) -> HBoxContainer:
	var sim: Simulation = _main.sim
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(UiStyle.flag(sim.state.country(tag).color))
	var l := Label.new()
	l.text = "%s — %s" % [sim.state.country(tag).name, info]
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.clip_text = true
	row.add_child(l)
	var qty := SpinBox.new()
	qty.min_value = 1
	qty.max_value = qmax
	qty.value = mini(qmax, 10)
	qty.tooltip_text = "Quantidade"
	row.add_child(qty)
	var price := SpinBox.new()
	price.min_value = 0
	price.max_value = cap
	price.step = 0.05
	price.value = minf(default_price, cap)
	price.prefix = sim.defs.currency
	price.tooltip_text = "Preço por unidade (teto %s)" % UiStyle.price(cap)
	row.add_child(price)
	var b := Button.new()
	b.text = action
	b.disabled = disabled
	b.pressed.connect(func():
		var cmd := ProposeTradeCommand.create(_main.player_tag, tag, kind, _res(), int(qty.value), price.value)
		_main.submit(cmd)
		if cmd.result != "":
			var what := "compra" if kind == "buy" else "venda"
			_main.write_log("%s %s a proposta de %s de %d %s a %s %s." % [sim.state.country(tag).name, cmd.result, what, int(qty.value), _res_name(), sim.defs.currency, UiStyle.price(price.value)])
		refresh())
	row.add_child(b)
	return row
