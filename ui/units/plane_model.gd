class_name PlaneModel
extends Node3D
## Avião 3D: caça monomotor ou bombardeiro bimotor, com as cores e a insígnia do país.
## Medidas em metros (aprox. do tamanho real), frente = +Z. As hélices giram sempre.

const GLASS := Color("#30404c")
const PROP := Color("#1f1f1f")

var _props: Array[Node3D] = []


static func create(kind: String, top: Color, bottom: Color, marking: String) -> PlaneModel:
	var p := PlaneModel.new()
	if kind == "bomber":
		p._bomber(top, bottom, marking)
	else:
		p._fighter(top, bottom, marking)
	return p


func _process(delta: float) -> void:
	for pr in _props:
		pr.rotation.z += delta * 40.0


func _propeller(pos: Vector3, blades: int, length: float) -> void:
	var n := Node3D.new()
	n.position = pos
	add_child(n)
	var k := MeshKit.new()
	k.sphere(0.2, Vector3(0, 0, 0.05), Color("#5a5a55"), Vector3(1, 1, 1.6), false, 12)   # cubo da hélice
	for i in blades:
		var a := TAU * i / blades
		k.box(Vector3(0.16, length, 0.03), Vector3(cos(a + PI / 2) * length * 0.5, sin(a + PI / 2) * length * 0.5, 0),
			PROP, Vector3(0.25, 0, a))
	MeshKit.attach(n, k.build())
	_props.append(n)


## Asa afilada: raiz larga junto ao corpo, ponta estreita e arredondada; cor de cima e de baixo.
func _tapered_wing(k: MeshKit, root: float, tip: float, span: float, y: float, z: float, top: Color, bottom: Color,
		thick: float = 0.22) -> void:
	for side in [-1, 1]:
		# Tronco "deitado": a base é a raiz (junto ao corpo) e o topo é a ponta da asa.
		var rot := Vector3(0, 0, -PI / 2 * side)
		k.frustum(Vector2(thick, root), Vector2(thick * 0.6, tip), span, Vector3(side * span * 0.5, y, z), top,
			Vector2(0, -(root - tip) * 0.15), rot)
		k.frustum(Vector2(thick * 0.5, root * 0.98), Vector2(thick * 0.3, tip * 0.98), span * 0.995,
			Vector3(side * span * 0.5, y - thick * 0.3, z), bottom, Vector2(0, -(root - tip) * 0.15), rot)
		k.sphere(tip * 0.5, Vector3(side * span, y, z - (root - tip) * 0.15), top, Vector3(0.18, 0.5, 1.0), false, 10)


func _marking(k: MeshKit, marking: String, pos: Vector3, size: float, rot: Vector3) -> void:
	var white := Color("#e8e6dc")
	match marking:
		"cruz":
			k.box(Vector3(size, 0.012, size * 0.34), pos, white, rot)
			k.box(Vector3(size * 0.34, 0.012, size), pos, white, rot)
			k.box(Vector3(size * 0.8, 0.016, size * 0.16), pos, Color("#141414"), rot)
			k.box(Vector3(size * 0.16, 0.016, size * 0.8), pos, Color("#141414"), rot)
		"circulo_run", "circulo_fra":
			var outer := Color("#2a3f7a") if marking == "circulo_run" else Color("#b8282a")
			var inner := Color("#b8282a") if marking == "circulo_run" else Color("#2a3f7a")
			k.cylinder(size * 0.5, size * 0.5, 0.01, pos, outer, rot, 20)
			k.cylinder(size * 0.32, size * 0.32, 0.014, pos, white, rot, 20)
			k.cylinder(size * 0.16, size * 0.16, 0.018, pos, inner, rot, 20)
		"estrela_eua":
			k.cylinder(size * 0.5, size * 0.5, 0.01, pos, Color("#22305e"), rot, 20)
			k.cylinder(size * 0.42, size * 0.42, 0.014, pos, white, rot, 5)
		"estrela_urs":
			k.cylinder(size * 0.45, size * 0.45, 0.014, pos, Color("#b8282a"), rot, 5)
		"sol":
			k.cylinder(size * 0.45, size * 0.45, 0.014, pos, Color("#b8282a"), rot, 20)
		_:
			k.cylinder(size * 0.4, size * 0.4, 0.014, pos, white, rot, 16)


func _fighter(top: Color, bottom: Color, marking: String) -> void:
	var k := MeshKit.new()
	var dark := top.darkened(0.3)
	# Fuselagem: motor na frente, cabine, cauda afinando
	k.frustum(Vector2(1.0, 1.1), Vector2(1.05, 1.1), 2.0, Vector3(0, 0, 2.6), top, Vector2.ZERO, Vector3(PI / 2, 0, 0))
	k.frustum(Vector2(1.05, 1.15), Vector2(0.95, 1.05), 2.6, Vector3(0, 0, 0.35), top, Vector2.ZERO, Vector3(PI / 2, 0, 0))
	k.frustum(Vector2(0.95, 1.05), Vector2(0.25, 0.4), 3.6, Vector3(0, 0.12, -2.75), top, Vector2(0, 0.25), Vector3(PI / 2, 0, 0))
	k.box(Vector3(0.9, 0.35, 5.5), Vector3(0, -0.45, 0.3), bottom)                       # barriga clara
	k.cylinder(0.48, 0.52, 0.2, Vector3(0, 0, 3.6), dark, Vector3(PI / 2, 0, 0), 16)      # anel do motor
	for side in [-1, 1]:
		for i in 4:   # escapamentos
			k.box(Vector3(0.06, 0.08, 0.14), Vector3(0.53 * side, 0.15, 2.9 - i * 0.22), Color("#3a3028"))
	# Cabine de vidro
	k.frustum(Vector2(0.7, 1.5), Vector2(0.45, 0.9), 0.45, Vector3(0, 0.72, 0.4), GLASS, Vector2(0, -0.15))
	k.box(Vector3(0.72, 0.04, 0.04), Vector3(0, 0.75, 0.75), dark)
	k.box(Vector3(0.6, 0.04, 0.04), Vector3(0, 0.82, 0.25), dark)
	# Asas, empenagem e leme
	_tapered_wing(k, 2.1, 1.0, 4.6, -0.3, 0.6, top, bottom, 0.24)
	_tapered_wing(k, 0.95, 0.5, 1.6, 0.25, -4.25, top, bottom, 0.1)
	k.frustum(Vector2(0.1, 1.2), Vector2(0.06, 0.6), 1.3, Vector3(0, 0.9, -4.3), top, Vector2(0, -0.25))
	# Insígnias nas asas e na fuselagem
	for side in [-1, 1]:
		_marking(k, marking, Vector3(3.0 * side, -0.16, 0.3), 0.9, Vector3.ZERO)
		_marking(k, marking, Vector3(0.5 * side, 0.15, -2.0), 0.6, Vector3(0, 0, PI / 2))
	MeshKit.attach(self, k.build())
	_propeller(Vector3(0, 0, 3.75), 3, 1.5)


func _bomber(top: Color, bottom: Color, marking: String) -> void:
	var k := MeshKit.new()
	var dark := top.darkened(0.3)
	# Fuselagem longa com nariz envidraçado
	k.frustum(Vector2(1.6, 1.8), Vector2(1.5, 1.7), 6.0, Vector3(0, 0, 1.0), top, Vector2.ZERO, Vector3(PI / 2, 0, 0))
	k.frustum(Vector2(1.5, 1.7), Vector2(0.4, 0.6), 7.0, Vector3(0, 0.15, -5.5), top, Vector2(0, 0.3), Vector3(PI / 2, 0, 0))
	k.box(Vector3(1.4, 0.5, 12.0), Vector3(0, -0.65, -1.5), bottom)
	k.sphere(0.85, Vector3(0, 0, 4.0), GLASS, Vector3(1.0, 1.05, 1.5), false, 16)        # nariz de vidro
	for i in 4:
		k.cylinder(0.86, 0.86, 0.04, Vector3(0, 0, 3.3 + i * 0.4), dark, Vector3(PI / 2, 0, 0), 16, Vector3(1, 1.05, 1))
	k.frustum(Vector2(0.6, 1.4), Vector2(0.4, 0.8), 0.5, Vector3(0, 1.0, -2.5), GLASS)    # posto do atirador
	# Asas com dois motores
	_tapered_wing(k, 4.2, 1.8, 10.5, -0.2, 0.2, top, bottom, 0.45)
	for side in [-1, 1]:
		var x: float = 3.4 * side
		k.frustum(Vector2(1.1, 1.2), Vector2(0.7, 0.8), 4.2, Vector3(x, -0.15, 0.6), top, Vector2.ZERO, Vector3(PI / 2, 0, 0))
		k.cylinder(0.6, 0.62, 0.25, Vector3(x, -0.15, 2.7), dark, Vector3(PI / 2, 0, 0), 16)
		_marking(k, marking, Vector3(7.0 * side, 0.05, -0.1), 1.6, Vector3.ZERO)
	_tapered_wing(k, 2.0, 1.0, 3.2, 0.4, -8.6, top, bottom, 0.18)
	k.frustum(Vector2(0.14, 2.4), Vector2(0.1, 1.2), 2.4, Vector3(0, 1.6, -8.8), top, Vector2(0, -0.5))
	for side in [-1, 1]:
		_marking(k, marking, Vector3(0.78 * side, 0.2, -4.5), 1.0, Vector3(0, 0, PI / 2))
	MeshKit.attach(self, k.build())
	for side in [-1, 1]:
		_propeller(Vector3(3.4 * side, -0.15, 2.95), 3, 2.0)
