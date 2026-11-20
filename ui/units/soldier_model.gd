class_name SoldierModel
extends Node3D
## Soldado 3D articulado (quadris, joelhos, ombros, cotovelos, cabeça), com o uniforme e o equipamento
## de cada exército (data/common/uniforms.json). Medidas em metros, pés em y = 0, frente = +Z.
## Modelo original do WorldWar, feito com formas simples (nada copiado de outros jogos).

const SKIN := Color("#d6a27c")
const SKIN_DARK := Color("#b07e5c")
const WOOD := Color("#6e4526")
const METAL := Color("#2d2e30")

static var _cache := {}    # uniforme -> malhas prontas

var _body: Node3D
var _torso: Node3D
var _head: Node3D
var _hips: Array[Node3D] = []
var _knees: Array[Node3D] = []
var _shoulders: Array[Node3D] = []
var _elbows: Array[Node3D] = []
var _phase := 0.0
var marching := false
var walk_speed := 6.5


static func create(key: String, u: Dictionary) -> SoldierModel:
	var s := SoldierModel.new()
	var m: Dictionary = _cache.get(key, {})
	if m.is_empty():
		m = _build(u)
		_cache[key] = m
	s._body = Node3D.new()
	s.add_child(s._body)
	for side in [-1, 1]:
		var hip := Node3D.new()
		hip.position = Vector3(0.1 * side, 0.93, 0)
		s._body.add_child(hip)
		MeshKit.attach(hip, m.thigh)
		var knee := Node3D.new()
		knee.position = Vector3(0, -0.44, 0)
		hip.add_child(knee)
		MeshKit.attach(knee, m.shin)
		s._hips.append(hip)
		s._knees.append(knee)
	s._torso = Node3D.new()
	s._torso.position = Vector3(0, 0.93, 0)
	s._body.add_child(s._torso)
	MeshKit.attach(s._torso, m.torso)
	s._head = Node3D.new()
	s._head.position = Vector3(0, 0.55, 0)
	s._torso.add_child(s._head)
	MeshKit.attach(s._head, m.head)
	for side in [-1, 1]:
		var sh := Node3D.new()
		sh.position = Vector3(0.235 * side, 0.45, 0)
		sh.rotation.z = 0.07 * side
		s._torso.add_child(sh)
		MeshKit.attach(sh, m.upper_arm)
		var el := Node3D.new()
		el.position = Vector3(0, -0.29, 0)
		sh.add_child(el)
		MeshKit.attach(el, m.forearm)
		s._shoulders.append(sh)
		s._elbows.append(el)
	s.animate(0.0)
	return s


## Ciclo de marcha: pernas e braços alternados, joelho dobra ao levar a perna à frente,
## corpo sobe e desce e gira um pouco.
func animate(delta: float) -> void:
	if marching:
		_phase += delta * walk_speed
	else:
		_phase = lerpf(_phase, roundf(_phase / PI) * PI, minf(1.0, delta * 6.0))
	var a := 1.0 if marching else 0.0
	for i in 2:
		var ph := _phase + PI * i
		_hips[i].rotation.x = sin(ph) * 0.5 * a
		_knees[i].rotation.x = (0.08 + maxf(0.0, -cos(ph)) * 0.85) * a
		_shoulders[i].rotation.x = -sin(ph) * 0.42 * a
		_elbows[i].rotation.x = -(0.15 + maxf(0.0, -sin(ph)) * 0.35) * a - 0.05
	_body.position.y = (absf(cos(_phase)) * 0.035 - 0.02) * a
	_torso.rotation = Vector3(0.06 * a, sin(_phase) * 0.07 * a, 0)
	_head.rotation.y = -sin(_phase) * 0.05 * a


static func _c(u: Dictionary, k: String, fallback: String) -> Color:
	return Color(u.get(k, fallback))


static func _build(u: Dictionary) -> Dictionary:
	var tunic := _c(u, "tunic", "#7d7452")
	var trousers := _c(u, "trousers", "#736b4b")
	var belt := _c(u, "belt", "#5a4129")
	var pouch := _c(u, "pouches", "#5a4129")
	var boots := _c(u, "boots_color", "#3b2a1c")
	var legc := _c(u, "leg_color", "#7d7452")
	var pack := _c(u, "pack", "#6b5f40")
	var helmet := _c(u, "helmet_color", "#5a5c42")
	var collar := Color(u.get("collar", u.get("tunic", "#7d7452")))
	var buckle := _c(u, "buckle", "#8a8a7a")
	var battledress: bool = u.get("battledress", false)
	var kit: Array = u.get("kit", [])
	var out := {}

	# ---------------- coxa (do quadril ao joelho)
	var k := MeshKit.new()
	k.capsule(0.088, 0.52, Vector3(0, -0.21, 0), trousers, Vector3.ZERO, Vector3(1.08, 1, 1.12))
	k.capsule(0.07, 0.2, Vector3(0, -0.42, 0), trousers)
	if battledress:
		k.box(Vector3(0.02, 0.15, 0.13), Vector3(-0.1 if true else 0.1, -0.2, 0.0), trousers.darkened(0.12))
	out.thigh = k.build()

	# ---------------- canela, bota e pé (do joelho ao chão)
	k = MeshKit.new()
	var style: String = u.get("boots", "faixas")
	match style:
		"alta":   # bota de cano alto de couro, com dobras no cano
			k.capsule(0.068, 0.14, Vector3(0, -0.03, 0), trousers)
			k.cylinder(0.078, 0.068, 0.36, Vector3(0, -0.24, 0), boots)
			for y in [-0.14, -0.2, -0.26]:
				k.cylinder(0.08, 0.08, 0.012, Vector3(0, y, 0), boots.lightened(0.12))
		"perneira":  # bota curta e perneira de lona com fivelas
			k.capsule(0.066, 0.24, Vector3(0, -0.08, 0), trousers)
			k.cylinder(0.071, 0.064, 0.2, Vector3(0, -0.3, 0), legc)
			for y in [-0.24, -0.3, -0.36]:
				k.box(Vector3(0.012, 0.015, 0.012), Vector3(0.072, y, 0.0), legc.darkened(0.45))
			k.cylinder(0.064, 0.062, 0.06, Vector3(0, -0.41, 0), boots)
		"polaina":   # polainas curtas por cima da bota
			k.capsule(0.066, 0.32, Vector3(0, -0.13, 0), trousers)
			k.cylinder(0.068, 0.065, 0.09, Vector3(0, -0.36, 0), legc)
			k.cylinder(0.064, 0.062, 0.05, Vector3(0, -0.42, 0), boots)
		_:          # faixas enroladas da canela ao tornozelo
			k.capsule(0.066, 0.14, Vector3(0, -0.03, 0), trousers)
			k.cylinder(0.068, 0.06, 0.32, Vector3(0, -0.24, 0), legc)
			for i in 6:
				k.cylinder(0.07 - i * 0.0012, 0.07 - i * 0.0012, 0.01, Vector3(0, -0.12 - i * 0.05, 0), legc.darkened(0.22),
					Vector3(0.25, 0, 0.1))
			k.cylinder(0.062, 0.06, 0.05, Vector3(0, -0.42, 0), boots)
	k.box(Vector3(0.11, 0.075, 0.25), Vector3(0, -0.455, 0.045), boots)          # pé
	k.box(Vector3(0.115, 0.022, 0.26), Vector3(0, -0.485, 0.045), boots.darkened(0.5))  # sola
	out.shin = k.build()

	# ---------------- tronco (origem no quadril)
	k = MeshKit.new()
	if battledress:
		# Battledress britânico: jaqueta curta com cós; calça sobe até a cintura.
		k.frustum(Vector2(0.4, 0.26), Vector2(0.37, 0.24), 0.16, Vector3(0, -0.05, 0), trousers)
		k.box(Vector3(0.39, 0.07, 0.255), Vector3(0, 0.06, 0), tunic.darkened(0.1))
		k.frustum(Vector2(0.37, 0.24), Vector2(0.44, 0.25), 0.36, Vector3(0, 0.27, 0), tunic)
	else:
		k.frustum(Vector2(0.43, 0.29), Vector2(0.38, 0.25), 0.22, Vector3(0, -0.04, 0), tunic)   # aba da túnica
		k.frustum(Vector2(0.37, 0.24), Vector2(0.44, 0.25), 0.4, Vector3(0, 0.27, 0), tunic)      # peito
		for side in [-1, 1]:   # bolsos de baixo
			k.box(Vector3(0.11, 0.12, 0.012), Vector3(0.105 * side, -0.05, 0.145), tunic.darkened(0.06))
			k.box(Vector3(0.115, 0.035, 0.016), Vector3(0.105 * side, 0.005, 0.146), tunic.darkened(0.18))
	k.capsule(0.078, 0.44, Vector3(0, 0.44, 0), tunic, Vector3(0, 0, PI / 2))                # ombros
	k.cylinder(0.075, 0.085, 0.07, Vector3(0, 0.5, 0), collar)                                 # gola
	k.cylinder(0.05, 0.055, 0.1, Vector3(0, 0.56, 0), SKIN)                                   # pescoço
	for side in [-1, 1]:   # bolsos do peito com lapela
		k.box(Vector3(0.1, 0.11, 0.012), Vector3(0.1 * side, 0.3, 0.127), tunic.darkened(0.06))
		k.box(Vector3(0.105, 0.035, 0.016), Vector3(0.1 * side, 0.355, 0.128), tunic.darkened(0.18))
	if u.get("pullover", false):
		k.box(Vector3(0.05, 0.14, 0.012), Vector3(0, 0.42, 0.128), tunic.darkened(0.08))
		for y in [0.38, 0.44]:
			k.sphere(0.009, Vector3(0, y, 0.136), buckle, Vector3.ONE, false, 8)
	elif not battledress:
		for y in [0.1, 0.19, 0.28, 0.37, 0.45]:
			k.sphere(0.01, Vector3(0, y, 0.13), buckle.darkened(0.2), Vector3.ONE, false, 8)
	# Cinto, fivela e bolsas de munição
	k.box(Vector3(0.405, 0.055, 0.275), Vector3(0, 0.07, 0), belt)
	k.box(Vector3(0.055, 0.045, 0.012), Vector3(0, 0.07, 0.143), buckle)
	var n := int(u.get("pouch_count", 2))
	for side in [-1, 1]:
		for i in n:
			var x: float = (0.07 + i * 0.058) * side
			k.box(Vector3(0.052, 0.08, 0.05), Vector3(x, 0.055, 0.155), pouch)
			k.box(Vector3(0.056, 0.025, 0.054), Vector3(x, 0.095, 0.156), pouch.darkened(0.25))
	if u.get("chest_pouches", false):
		for side in [-1, 1]:
			k.box(Vector3(0.12, 0.13, 0.06), Vector3(0.1 * side, 0.29, 0.15), pouch)
			k.box(Vector3(0.124, 0.04, 0.064), Vector3(0.1 * side, 0.35, 0.151), pouch.darkened(0.15))
	for side in [-1, 1]:   # tirantes (frente e costas)
		k.box(Vector3(0.032, 0.42, 0.012), Vector3(0.09 * side, 0.29, 0.133), belt, Vector3(-0.05, 0, 0.1 * side))
		k.box(Vector3(0.032, 0.42, 0.012), Vector3(0.07 * side, 0.29, -0.133), belt, Vector3(0.05, 0, -0.18 * side))
	# Equipamento nas costas e no quadril
	if "mochila" in kit:
		k.box(Vector3(0.3, 0.3, 0.12), Vector3(0, 0.28, -0.19), pack)
		k.box(Vector3(0.31, 0.11, 0.125), Vector3(0, 0.39, -0.19), pack.darkened(0.15))
		k.box(Vector3(0.24, 0.07, 0.07), Vector3(0, 0.46, -0.2), pack.darkened(0.05))
	if "porta_pao" in kit:
		k.box(Vector3(0.07, 0.17, 0.2), Vector3(0.2, -0.04, -0.07), pack)
		k.box(Vector3(0.074, 0.06, 0.204), Vector3(0.2, 0.02, -0.07), pack.darkened(0.15))
	if "cantil" in kit:
		k.cylinder(0.045, 0.045, 0.15, Vector3(-0.2, -0.05, -0.08), pack.darkened(0.2), Vector3(0, 0, 0), 12)
		k.cylinder(0.018, 0.018, 0.03, Vector3(-0.2, 0.04, -0.08), METAL)
	if "mascara" in kit:   # porta-máscara de gás alemão, canelado
		k.cylinder(0.055, 0.055, 0.27, Vector3(0.04, 0.02, -0.2), tunic.darkened(0.05), Vector3(0, 0, 0.25), 14)
		for i in 5:
			k.cylinder(0.058, 0.058, 0.01, Vector3(0.04 + (i - 2) * 0.012, 0.02 + (i - 2) * 0.05, -0.2),
				tunic.darkened(0.25), Vector3(0, 0, 0.25), 14)
	# Fuzil pendurado no ombro direito (cano para cima), com a bandoleira
	var r := Transform3D(Basis.from_euler(Vector3(0.1, 0, -0.16)), Vector3(0.19, 0.2, -0.13))
	var rifle := MeshKit.new()
	rifle.box(Vector3(0.045, 0.24, 0.07), Vector3(0, -0.36, 0), WOOD)            # coronha
	rifle.box(Vector3(0.04, 0.5, 0.05), Vector3(0, -0.02, 0), WOOD)              # corpo
	rifle.cylinder(0.011, 0.011, 0.4, Vector3(0, 0.42, 0), METAL)                 # cano
	rifle.box(Vector3(0.03, 0.08, 0.04), Vector3(0, -0.2, 0.01), METAL)          # ferrolho
	rifle.box(Vector3(0.06, 0.012, 0.012), Vector3(0.03, -0.18, 0.02), METAL)
	k.merge(rifle, r)
	k.box(Vector3(0.02, 0.6, 0.012), Vector3(0.17, 0.25, 0.1), belt.darkened(0.2), Vector3(0.0, 0, 0.32))
	out.torso = k.build()

	# ---------------- cabeça e capacete (origem no pescoço)
	k = MeshKit.new()
	k.sphere(0.105, Vector3(0, 0.12, 0.005), SKIN, Vector3(0.92, 1.1, 1.0), false, 18)
	k.box(Vector3(0.03, 0.05, 0.04), Vector3(0, 0.11, 0.105), SKIN_DARK, Vector3(-0.35, 0, 0))   # nariz
	for side in [-1, 1]:
		k.sphere(0.028, Vector3(0.096 * side, 0.12, 0.0), SKIN_DARK, Vector3(0.5, 1, 0.8), false, 8)  # orelhas
		k.sphere(0.011, Vector3(0.036 * side, 0.145, 0.093), Color("#2a2420"), Vector3.ONE, false, 6)  # olhos
		k.box(Vector3(0.04, 0.008, 0.01), Vector3(0.036 * side, 0.168, 0.094), Color("#4a3a2a"))       # sobrancelhas
	k.box(Vector3(0.045, 0.008, 0.01), Vector3(0, 0.065, 0.098), Color("#8a5040"))                    # boca
	_helmet(k, str(u.get("helmet", "m1")), helmet)
	out.head = k.build()

	# ---------------- braço (ombro ao cotovelo) e antebraço com mão
	k = MeshKit.new()
	k.capsule(0.062, 0.34, Vector3(0, -0.14, 0), tunic)
	out.upper_arm = k.build()
	k = MeshKit.new()
	k.capsule(0.056, 0.3, Vector3(0, -0.12, 0), tunic)
	k.cylinder(0.06, 0.062, 0.05, Vector3(0, -0.22, 0), tunic.darkened(0.1))
	k.sphere(0.05, Vector3(0, -0.3, 0.01), SKIN, Vector3(0.75, 1.15, 0.95), false, 10)
	out.forearm = k.build()
	return out


## Capacetes: cada um com o formato que o identifica de longe. Origem no pescoço; cabeça em y = 0.12.
static func _helmet(k: MeshKit, style: String, c: Color) -> void:
	var dark := c.darkened(0.25)
	match style:
		"stahlhelm":   # M35 alemão: domo alto e saia que se abre nas laterais e na nuca
			k.sphere(0.128, Vector3(0, 0.145, -0.005), c, Vector3(1.0, 1.0, 1.08), true, 20)
			k.cylinder(0.128, 0.152, 0.065, Vector3(0, 0.12, -0.012), c, Vector3(-0.1, 0, 0), 20, Vector3(1, 1, 1.06))
			k.cylinder(0.153, 0.156, 0.01, Vector3(0, 0.086, -0.015), dark, Vector3(-0.1, 0, 0), 20, Vector3(1, 1, 1.06))
			for side in [-1, 1]:
				k.sphere(0.012, Vector3(0.122 * side, 0.18, 0.0), dark, Vector3.ONE, false, 6)
		"m1":          # M1 americano: domo redondo e aba igual em volta; jugular solta
			k.sphere(0.135, Vector3(0, 0.15, 0), c, Vector3(1.0, 0.92, 1.06), true, 20)
			k.cylinder(0.138, 0.146, 0.035, Vector3(0, 0.14, 0), c, Vector3.ZERO, 20, Vector3(1, 1, 1.06))
			k.cylinder(0.147, 0.148, 0.008, Vector3(0, 0.123, 0), dark, Vector3.ZERO, 20, Vector3(1, 1, 1.06))
			for side in [-1, 1]:
				k.box(Vector3(0.008, 0.1, 0.018), Vector3(0.118 * side, 0.08, 0.02), Color("#6a5a3a"), Vector3(0, 0, -0.15 * side))
		"brodie":      # Mk II britânico: copa rasa e aba larga ("prato")
			k.sphere(0.112, Vector3(0, 0.19, 0), c, Vector3(1.0, 0.62, 1.1), true, 20)
			k.cylinder(0.12, 0.2, 0.03, Vector3(0, 0.19, 0), c, Vector3.ZERO, 22, Vector3(1, 1, 1.06))
			k.cylinder(0.201, 0.202, 0.006, Vector3(0, 0.175, 0), dark, Vector3.ZERO, 22, Vector3(1, 1, 1.06))
		"ssh40":       # SSh-40 soviético: domo fundo e liso, borda curta, estrela vermelha
			k.sphere(0.137, Vector3(0, 0.135, 0), c, Vector3(1.0, 1.05, 1.06), true, 20)
			k.cylinder(0.138, 0.145, 0.03, Vector3(0, 0.125, 0), c, Vector3.ZERO, 20, Vector3(1, 1, 1.06))
			k.cylinder(0.022, 0.022, 0.006, Vector3(0, 0.215, 0.115), Color("#b0302a"), Vector3(1.15, 0, 0), 5)
		"adrian":      # Adrian francês: crista no alto e aba na frente e atrás
			k.sphere(0.12, Vector3(0, 0.165, 0), c, Vector3(1.0, 0.95, 1.12), true, 20)
			k.box(Vector3(0.02, 0.045, 0.2), Vector3(0, 0.29, 0), c)
			k.cylinder(0.15, 0.158, 0.012, Vector3(0, 0.162, 0), c, Vector3.ZERO, 20, Vector3(1, 1, 1.22))
		"m33":         # M33 italiano: domo fundo e arredondado cobrindo a nuca
			k.sphere(0.138, Vector3(0, 0.13, 0), c, Vector3(1.0, 1.08, 1.07), true, 20)
			k.cylinder(0.139, 0.146, 0.012, Vector3(0, 0.128, 0), dark, Vector3.ZERO, 20, Vector3(1, 1, 1.07))
		"tipo90":      # Tipo 90 japonês: domo baixo, aba curta, estrela amarela
			k.sphere(0.132, Vector3(0, 0.15, 0), c, Vector3(1.0, 0.92, 1.06), true, 20)
			k.cylinder(0.136, 0.145, 0.014, Vector3(0, 0.148, 0), dark, Vector3.ZERO, 20, Vector3(1, 1, 1.06))
			k.cylinder(0.02, 0.02, 0.006, Vector3(0, 0.235, 0.105), Color("#d6b23c"), Vector3(1.1, 0, 0), 5)
		_:
			k.sphere(0.135, Vector3(0, 0.15, 0), c, Vector3(1.0, 0.92, 1.06), true, 20)
