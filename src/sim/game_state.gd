class_name GameState
extends RefCounted
## Tudo o que define uma partida num instante. Salvar o jogo = salvar isto.

var hours: int = 0                 # tempo do jogo, ver GameDate
var scenario_name: String = ""
var countries: Dictionary = {}     # tag -> Country
var states: Dictionary = {}        # id -> MapState
var sea_zones: Dictionary = {}     # id -> SeaZone
var offers: Dictionary = {}        # id -> TradeOffer (propostas aguardando resposta)
var next_offer_id: int = 1
var prices: Dictionary = {}        # recurso -> preço no mercado mundial
var human_tags: Array = []         # países controlados por jogadores (a IA não responde por eles)
var operations: Dictionary = {}    # id -> IntelOperation
var next_operation_id: int = 1
var events: Array = []             # [{hours, tags, text}] avisos para os países envolvidos
var groups: Dictionary = {}        # id -> ArmyGroup
var next_group_id: int = 1
var group_counters: Dictionary = {} # tag -> quantos grupos o país já criou (para numerar "3º Grupo")
var generals: Dictionary = {}      # id -> General
var next_general_id: int = 1
var adjacency: Dictionary = {}     # id do estado -> [ids vizinhos por terra] (geografia, não muda)
## Objetivo de vitória de cada jogador humano (tag -> id do objetivo) e o vencedor, quando houver.
var objectives: Dictionary = {}
var winner: String = ""
var wars: Array = []               # [[tagA, tagB]] pares em guerra (em ordem alfabética)
var justifications: Array = []     # [{owner, target, days_done, days_needed, done}]
var alliances: Array = []          # (antigo; as alianças agora são as facções abaixo)
## Facções (alianças): id -> {name, leader, members: [tags]}. Membros da mesma facção são aliados.
var factions: Dictionary = {}
var factions_created: Array = []   # ids já criados uma vez (não renascem)
## Jornal: notícias do mundo, as mais novas no fim. {hours, headline, sub, body, state, tags, kind}
var news: Array = []
var news_count := 0
var war_started: Dictionary = {}   # "A|B" (ordem alfabética) -> hora em que a guerra começou
var peace_offers: Dictionary = {}  # id -> {id, from, to, money, states, resources, hours}
var next_peace_id: int = 1
var battle_results: Dictionary = {}  # estado -> última batalha encerrada (CombatSystem._store_result)
var declared: Array = []           # "quem|alvo" de toda declaração de guerra (planos da IA não se repetem)
var peace_last: Dictionary = {}    # "de|para" -> hora da última proposta (a IA espera para insistir)                # quantas notícias já saíram (o jornal guarda só as últimas)
const MAX_NEWS := 300
## Passagem militar: [quem passa, por onde] (ex.: Japão em Manchukuo). Vem do cenário.
var access: Array = []

const MAX_EVENTS := 300
var rng := RandomNumberGenerator.new()   # único gerador aleatório da simulação


func country(tag: String) -> Country:
	return countries.get(tag)


func state(id: int) -> MapState:
	return states.get(id)


func group(id: int) -> ArmyGroup:
	return groups.get(id)


func general(id: int) -> General:
	return generals.get(id)


func groups_of(tag: String) -> Array:
	var out := groups.values().filter(func(g): return g.owner == tag)
	out.sort_custom(func(a, b): return a.id < b.id)
	return out


func generals_of(tag: String) -> Array:
	var out := generals.values().filter(func(g): return g.owner == tag)
	out.sort_custom(func(a, b): return a.id < b.id)
	return out


static func pair_key(a: String, b: String) -> String:
	return "%s|%s" % [a, b] if a < b else "%s|%s" % [b, a]


func at_war(a: String, b: String) -> bool:
	var pair := [a, b]
	pair.sort()
	return pair in wars


func allied(a: String, b: String) -> bool:
	if a == b:
		return true
	var fa := faction_of(a)
	return fa != "" and fa == faction_of(b)


## Facção do país ("" se nenhuma).
func faction_of(tag: String) -> String:
	for id in factions:
		if tag in factions[id].members:
			return id
	return ""


func add_news(headline: String, sub: String, body: String, state_id: int, tags: Array, kind: String) -> void:
	news_count += 1
	news.append({"hours": hours, "headline": headline, "sub": sub, "body": body, "state": state_id,
		"tags": tags, "kind": kind})
	if news.size() > MAX_NEWS:
		news.pop_front()


## Tropas de `tag` podem entrar em estados de `owner`: próprio, aliado ou inimigo em guerra.
func can_enter(tag: String, owner: String) -> bool:
	return allied(tag, owner) or at_war(tag, owner) or [tag, owner] in access


func enemies_of(tag: String) -> Array:
	var out := []
	for w in wars:
		if tag in w:
			out.append(w[1] if w[0] == tag else w[0])
	return out


## Justificativa de guerra de `owner` contra `target` ({} se não houver).
func justification(owner: String, target: String) -> Dictionary:
	for j in justifications:
		if j.owner == owner and j.target == target:
			return j
	return {}


func states_of(tag: String) -> Array:
	if _owned_stamp != hours:
		_rebuild_owned()
	return _owned.get(tag, [])


## Índice de estados por quem controla (dono, ou ocupante), refeito no máximo uma vez por hora (e depois de cada comando,
## via invalidate_owners). Sem ele, cada consulta varria os 3.681 estados.
var _owned: Dictionary = {}
## Batalhas em andamento: id do estado -> {attackers: [grupos], defenders: [grupos], since: hora}.
var battles: Dictionary = {}
## Sobe a cada mudança de controle de estado (a interface repinta o mapa quando muda).
var control_version := 0
var _owned_stamp := -1


func invalidate_owners() -> void:
	_owned_stamp = -1


## Muda quem controla o estado (ocupação ou libertação).
func set_control(s: MapState, tag: String) -> void:
	s.controller = "" if tag == s.owner else tag
	control_version += 1
	invalidate_owners()


func _rebuild_owned() -> void:
	_owned = {}
	_by_owner = {}
	for st in states.values():
		var c: String = st.control()
		if not _owned.has(c):
			_owned[c] = []
		_owned[c].append(st)
		_by_owner[st.owner] = int(_by_owner.get(st.owner, 0)) + 1
	_owned_stamp = hours


var _by_owner: Dictionary = {}


## Quantos estados o país possui (é dono), ocupados ou não.
func owned_count(tag: String) -> int:
	if _owned_stamp != hours:
		_rebuild_owned()
	return int(_by_owner.get(tag, 0))


## Total de uma construção somando todos os estados do país.
func total_building(tag: String, building: String) -> int:
	var total := 0
	for s in states_of(tag):
		total += s.level(building)
	return total


## Fábricas do país (uma só reserva) e a divisão entre uso civil e militar.
func factories(tag: String) -> int:
	return total_building(tag, "factory")


func civil_factories(tag: String) -> int:
	var c := country(tag)
	var n := factories(tag)
	return n if c == null else clampi(roundi(n * c.civil_share), 0, n)


func military_factories(tag: String) -> int:
	return factories(tag) - civil_factories(tag)


## Extração diária de um recurso somando os estados do país.
func resource_production(tag: String, resource: String) -> int:
	var total := 0
	for s in states_of(tag):
		total += s.extraction(resource)
	return total


func world_production(resource: String) -> int:
	var total := 0
	for s in states.values():
		total += s.extraction(resource)
	return total


func price(resource: String) -> float:
	return float(prices.get(resource, 0.0))


func is_human(tag: String) -> bool:
	return tag in human_tags


func add_event(tags: Array, text: String, kind: String = "Inteligência") -> void:
	events.append({"hours": hours, "tags": tags, "text": text, "kind": kind})
	if events.size() > MAX_EVENTS:
		events.pop_front()


func date_text() -> String:
	return GameDate.format(hours)
