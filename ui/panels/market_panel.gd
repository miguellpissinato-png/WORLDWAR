class_name MarketPanel
extends PanelContainer
## Mercado de recursos. Mostra só o que é público: quem vende, quem quer comprar e o preço mundial.
## Escolher um país abre uma caixa única de proposta (quantidade e preço). Doação fica recolhida.

const MAX_ROWS := 5

var _main
var _resource: OptionButton
var _price_info: RichTextLabel
var _offers_box: VBoxContainer
var _sellers: VBoxContainer
var _buyers: VBoxContainer
var _deal: PanelContainer
var _deal_title: Label
var _deal_qty: SpinBox
var _deal_price: SpinBox
var _deal_send: Button
var _deal_tag := ""
var _deal_kind := ""
var _donate_to: OptionButton
var _donate_qty: SpinBox
var _donate_label: Label


func setup(main) -> void:
	_main = main
	UiStyle.place(self, 660)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	UiStyle.window_header(v, "Mercado", "", func(): visible = false,
		"Você propõe um preço por unidade, até o teto (preço mundial + %d%%).\nO país da IA responde na hora; jogadores respondem quando puderem." % int(
			100 * float(main.sim.defs.market.get("max_markup", 0.25))))
	var rh := HBoxContainer.new()
	v.add_child(rh)
	_resource = OptionButton.new()
	var res_list: Array = main.sim.defs.resources
	for i in res_list.size():
		_resource.add_item(res_list[i].name)
		_resource.set_item_metadata(i, res_list[i].id)
	_resource.item_selected.connect(func(_i):
		_deal_tag = ""
		refresh())
	rh.add_child(_resource)
	_price_info = UiStyle.rich()
	_price_info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_price_info.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	rh.add_child(_price_info)

	_offers_box = VBoxContainer.new()
	v.add_child(_offers_box)

	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 16)
	v.add_child(cols)
	var lv := VBoxContainer.new()
	lv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(lv)
	lv.add_child(UiStyle.section("Comprar de"))
	_sellers = VBoxContainer.new()
	lv.add_child(_sellers)
	var rv := VBoxContainer.new()
	rv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(rv)
	rv.add_child(UiStyle.section("Vender para"))
	_buyers = VBoxContainer.new()
	rv.add_child(_buyers)

	# Caixa única de proposta (aparece ao escolher um país).
	_deal = UiStyle.panel()
	_deal.visible = false
	v.add_child(_deal)
	var dh := HBoxContainer.new()
	dh.add_theme_constant_override("separation", 8)
	_deal.add_child(dh)
	_deal_title = Label.new()
	_deal_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_deal_title.clip_text = true
	dh.add_child(_deal_title)
	_deal_qty = SpinBox.new()
	_deal_qty.min_value = 1
	_deal_qty.suffix = "un."
	dh.add_child(_deal_qty)
	_deal_price = SpinBox.new()
	_deal_price.step = 0.05
	_deal_price.prefix = main.sim.defs.currency
	dh.add_child(_deal_price)
	_deal_send = Button.new()
	_deal_send.text = "Enviar proposta"
	_deal_send.pressed.connect(_send_deal)
	dh.add_child(_deal_send)

	var donate := UiStyle.details(v, "Doar recursos a outro país", "Fechar doação")
	var doh := HBoxContainer.new()
	donate.add_child(doh)
	_donate_to = OptionButton.new()
	_donate_to.custom_minimum_size = Vector2(220, 0)
	doh.add_child(_donate_to)
	_donate_qty = SpinBox.new()
	_donate_qty.min_value = 1
	doh.add_child(_donate_qty)
	_donate_label = UiStyle.dim_label("")
	doh.add_child(_donate_label)
	var give := Button.new()
	give.text = "Doar"
	give.pressed.connect(func():
		var to: String = _donate_to.get_item_metadata(_donate_to.selected)
		_main.submit(DonateResourcesCommand.create(_main.player_tag, to, _res(), int(_donate_qty.value)))
		_main.write_log("Doação de %d de %s para %s." % [int(_donate_qty.value), _res_name(), _main.sim.state.country(to).name]))
	doh.add_child(give)

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
	_price_info.text = "   " + UiStyle.kv("Preço:", "%s %s" % [cur, UiStyle.price(st.price(res))]) + \
		"     " + UiStyle.kv("Seu estoque:", UiStyle.num(me.stock(res)))
	for box in [_sellers, _buyers, _offers_box]:
		UiStyle.clear(box)

	# Propostas recebidas de outros jogadores (só aparece quando existe alguma).
	var mine: Array = st.offers.values().filter(func(o): return o.to == _main.player_tag)
	if not mine.is_empty():
		_offers_box.add_child(UiStyle.section("Propostas para você"))
	for o in mine:
		var row := HBoxContainer.new()
		var l := Label.new()
		var verb := "vende" if o.kind == "sell" else "compra"
		l.text = "%s %s %d de %s a %s %s" % [st.country(o.from).name, verb, o.amount, o.resource, cur, UiStyle.price(o.price)]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(l)
		for ans in [["Aceitar", true], ["Recusar", false]]:
			var b := Button.new()
			b.text = ans[0]
			var id: int = o.id
			var accept: bool = ans[1]
			b.pressed.connect(func(): _main.submit(RespondTradeCommand.create(_main.player_tag, id, accept)))
			row.add_child(b)
		_offers_box.add_child(row)

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
		_sellers.add_child(UiStyle.dim_label("Ninguém vendendo agora."))
	for pair in lots.slice(0, MAX_ROWS):
		var ask := TradeSystem.ai_ask_price(st, sim.defs, pair[0], res)
		_sellers.add_child(_pick_row(pair[0], "%s un.  ·  %s %s" % [UiStyle.num(pair[1]), cur, UiStyle.price(ask)],
			"buy", pair[1], ask))

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
		_buyers.add_child(UiStyle.dim_label("Ninguém procurando agora."))
	for pair in wants.slice(0, MAX_ROWS):
		var qmax := mini(pair[1], int(me.stock(res)))
		var row := _pick_row(pair[0], "até %s un.  ·  %s %s" % [UiStyle.num(pair[1]), cur, UiStyle.price(bid)],
			"sell", qmax, bid)
		if qmax <= 0:
			row.disabled = true
			row.tooltip_text = "Você não tem %s no estoque." % _res_name().to_lower()
		_buyers.add_child(row)

	_donate_qty.max_value = maxf(1.0, me.stock(res))
	_donate_label.text = "de %s" % UiStyle.num(me.stock(res))
	if _deal_tag == "":
		_deal.visible = false


func _pick_row(tag: String, info: String, kind: String, qmax: int, default_price: float) -> Button:
	var sim: Simulation = _main.sim
	var b := Button.new()
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	b.clip_text = true
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.text = "%s   %s" % [sim.state.country(tag).name, info]
	if tag == _deal_tag and kind == _deal_kind:
		b.add_theme_color_override("font_color", UiStyle.ACCENT)
	b.pressed.connect(func(): _open_deal(tag, kind, qmax, default_price))
	return b


func _open_deal(tag: String, kind: String, qmax: int, default_price: float) -> void:
	var sim: Simulation = _main.sim
	_deal_tag = tag
	_deal_kind = kind
	var cap := MarketSystem.max_price(sim.state, sim.defs, _res())
	_deal_title.text = "%s %s %s" % ["Comprar de" if kind == "buy" else "Vender para", sim.state.country(tag).name,
		"(teto %s %s)" % [sim.defs.currency, UiStyle.price(cap)]]
	_deal_qty.max_value = maxi(qmax, 1)
	_deal_qty.value = mini(qmax, 10)
	_deal_price.max_value = cap
	_deal_price.value = minf(default_price, cap)
	_deal.visible = true
	refresh()


func _send_deal() -> void:
	var sim: Simulation = _main.sim
	var cmd := ProposeTradeCommand.create(_main.player_tag, _deal_tag, _deal_kind, _res(), int(_deal_qty.value), _deal_price.value)
	_main.submit(cmd)
	if cmd.result != "":
		var what := "compra" if _deal_kind == "buy" else "venda"
		_main.write_log("%s %s a proposta de %s de %d %s a %s %s." % [sim.state.country(_deal_tag).name, cmd.result, what,
			int(_deal_qty.value), _res_name(), sim.defs.currency, UiStyle.price(_deal_price.value)])
	_deal_tag = ""
	refresh()
