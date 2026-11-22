class_name Country
extends RefCounted
## Um país do jogo. Indústria e recursos ficam nos estados; aqui fica o que é nacional.

var tag: String              # código de 3 letras, ex.: "GER"
var name: String
var leader: String
var ideology: String
var color: Color
var capital_state: int
var capital_city: String = ""   # nome da cidade (só exibição)
## Fila de construção: Array de Dictionary {state_id, building, progress}
var construction_queue: Array = []

# Economia
var money: float = 0.0
var stockpile: Dictionary = {}      # recurso -> unidades em estoque
var goods_share: Dictionary = {}    # recurso -> fração (0..1) da produção que vira bens de consumo
var last_income: float = 0.0        # renda do último dia (para a interface)
var last_goods: Dictionary = {}     # recurso -> unidades transformadas em bens no último dia


# Indústria: as fábricas são uma só reserva, divididas entre uso civil e militar.
var civil_share: float = 0.7        # fração atual das fábricas em uso civil
var civil_share_target: float = 0.7 # alvo escolhido pelo jogador (a conversão leva dias)

# Pesquisa
var researched: Array = []          # ids de tecnologias concluídas
var research: Array = []            # [{tech, progress, days}] pesquisas em andamento (uma por vaga)
var research_slots: int = 3

# Exército: lotes encomendados às fábricas militares (RecruitSystem)
var recruit_queue: Array = []       # [{id, type, model, count, work, work_done, days, days_done}]
var next_recruit_id: int = 1
var rally_state: int = -1           # estado favorito: as tropas novas nascem ali (-1 = capital)
var last_recruited: Dictionary = {} # tipo -> unidades prontas no último dia
var last_shortage: Dictionary = {}  # recurso -> quanto faltou no último dia


# Inteligência
var intel_offense: int = 1          # nível de espionagem
var intel_defense: int = 1          # nível de contraespionagem
var intel_reports: Dictionary = {}  # tag -> relatório congelado (ver IntelligenceSystem.make_report)


func stock(resource: String) -> float:
	return float(stockpile.get(resource, 0.0))


func has_tech(tech: String) -> bool:
	return tech in researched


static func from_dict(d: Dictionary) -> Country:
	var c := Country.new()
	c.tag = d.tag
	c.name = d.name
	c.leader = d.get("leader", "")
	c.ideology = d.get("ideology", "")
	c.color = Color(d.get("color", "#888888"))
	c.capital_city = d.get("capital_city", "")
	if d.has("civil_share"):
		c.civil_share = float(d.civil_share)
		c.civil_share_target = c.civil_share
	# Nos cenários a capital vem como código do mapa e o ScenarioLoader resolve o id.
	var cap = d.get("capital_state", -1)
	c.capital_state = -1 if cap is String else int(cap)
	return c
