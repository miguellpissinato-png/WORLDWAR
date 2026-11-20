class_name TankModel
extends Node3D
## Tanque 3D em três estilos com a silhueta de cada escola de projeto da época:
##   panzer  — casco de chapas retas, torre com cúpula atrás, canhão longo (alemão)
##   t34     — blindagem inclinada, rodas grandes, torre baixa (soviético)
##   sherman — casco alto e arredondado, rodas em truques, torre fundida (americano)
## Medidas em metros (aprox. do tamanho real), frente = +Z. As rodas giram quando ele anda.

var speed := 0.0               # m/s, para girar as rodas
var _wheels: Array[Node3D] = []
var _wheel_r := 0.3
var _turret: Node3D


static func create(style: String, color: Color, marking: String = "") -> TankModel:
	var t := TankModel.new()
	match style:
		"t34":
			t._t34(color)
		"sherman":
			t._sherman(color, marking)
		"panzer":
			t._panzer(color)
		_:
			t._generic(color)
	return t


func _process(delta: float) -> void:
	for w in _wheels:
		w.rotation.x += speed * delta / _wheel_r


func _wheel_row(xs: Array, zs: Array, y: float, r: float, w: float, color: Color) -> void:
	_wheel_r = r
	var k := MeshKit.new()
	k.cylinder(r, r, w, Vector3.ZERO, color, Vector3(0, 0, PI / 2), 18)
	k.cylinder(r * 0.45, r * 0.45, w + 0.02, Vector3.ZERO, color.darkened(0.35), Vector3(0, 0, PI / 2), 12)
	for i in 6:
		var a := TAU * i / 6.0
		k.box(Vector3(w + 0.03, r * 0.12, r * 0.12), Vector3(0, cos(a) * r * 0.7, sin(a) * r * 0.7), color.darkened(0.2))
	var mesh := k.build()
	for x in xs:
		for z in zs:
			var n := Node3D.new()
			n.position = Vector3(x, y, z)
			add_child(n)
			MeshKit.attach(n, mesh)
			_wheels.append(n)


## Lagarta: faixa de cima, de baixo e as curvas nas pontas, com as sapatas marcadas.
func _track(k: MeshKit, x: float, length: float, y_low: float, y_high: float, w: float, color: Color) -> void:
	var dark := color.darkened(0.5)
	var r := (y_high - y_low) * 0.5
	var mid := (y_high + y_low) * 0.5
	k.box(Vector3(w, 0.06, length), Vector3(x, y_low, 0), dark)
	k.box(Vector3(w, 0.06, length), Vector3(x, y_high, 0), dark)
	for side in [-1, 1]:
		k.cylinder(r + 0.03, r + 0.03, w, Vector3(x, mid, side * length * 0.5), dark, Vector3(0, 0, PI / 2), 16)
	var n := int(length / 0.16)
	for i in n:
		var z := -length * 0.5 + (i + 0.5) * length / n
		k.box(Vector3(w + 0.01, 0.075, 0.05), Vector3(x, y_low - 0.005, z), dark.darkened(0.3))
		k.box(Vector3(w + 0.01, 0.075, 0.05), Vector3(x, y_high + 0.005, z), dark.darkened(0.3))


func _panzer(c: Color) -> void:
	var k := MeshKit.new()
	var dark := c.darkened(0.25)
	for side in [-1, 1]:
		_track(k, 1.2 * side, 5.0, 0.12, 0.88, 0.4, c)
		k.box(Vector3(0.5, 0.04, 5.6), Vector3(1.22 * side, 0.98, 0), c)                 # para-lamas
		k.box(Vector3(0.05, 0.62, 3.6), Vector3(1.47 * side, 0.85, -0.2), c.darkened(0.05))  # saias de blindagem
		for i in 4:
			k.cylinder(0.09, 0.09, 0.12, Vector3(1.0 * side, 0.82, -1.9 + i * 1.25), dark, Vector3(0, 0, PI / 2), 10)
	k.box(Vector3(2.0, 0.85, 5.4), Vector3(0, 0.9, 0), c)                                 # casco
	k.frustum(Vector2(2.0, 0.6), Vector2(2.0, 0.3), 0.55, Vector3(0, 0.75, 2.85), c, Vector2(0, -0.15))
	k.box(Vector3(2.3, 0.55, 3.2), Vector3(0, 1.6, 0.6), c)                               # superestrutura
	k.box(Vector3(0.45, 0.18, 0.12), Vector3(-0.5, 1.6, 2.22), dark)                      # visor do motorista
	k.box(Vector3(1.6, 0.25, 0.08), Vector3(0, 1.0, 2.75), dark)                          # elos de lagarta reserva
	k.cylinder(0.08, 0.08, 0.4, Vector3(0.6, 1.5, -2.75), dark.darkened(0.3), Vector3(PI / 2, 0, 0), 10)  # escape
	k.box(Vector3(1.9, 0.05, 1.6), Vector3(0, 1.36, -1.8), dark)                          # grade do motor
	MeshKit.attach(self, k.build())
	_wheel_row([-1.2, 1.2], [-1.8, -1.25, -0.7, -0.15, 0.4, 0.95, 1.5, 2.05], 0.33, 0.24, 0.42, c.darkened(0.15))
	# Torre
	_turret = Node3D.new()
	_turret.position = Vector3(0, 1.87, 0.4)
	add_child(_turret)
	k = MeshKit.new()
	k.frustum(Vector2(1.95, 2.3), Vector2(1.6, 1.9), 0.75, Vector3(0, 0.38, -0.1), c)
	k.cylinder(0.33, 0.36, 0.3, Vector3(0, 0.9, -0.85), c)                               # cúpula do comandante
	k.box(Vector3(0.05, 0.4, 0.5), Vector3(0.82, 0.4, -0.2), dark)                        # escotilhas laterais
	k.box(Vector3(0.05, 0.4, 0.5), Vector3(-0.82, 0.4, -0.2), dark)
	k.box(Vector3(0.75, 0.5, 0.3), Vector3(0, 0.35, 1.1), c.darkened(0.08))              # mantelete
	k.cylinder(0.075, 0.09, 3.3, Vector3(0, 0.38, 2.8), c, Vector3(PI / 2, 0, 0), 12)     # canhão longo
	k.cylinder(0.13, 0.13, 0.32, Vector3(0, 0.38, 4.5), dark, Vector3(PI / 2, 0, 0), 12) # freio de boca
	k.box(Vector3(2.4, 0.05, 1.4), Vector3(0, 0.35, -1.4), c.darkened(0.1))              # caixa de bagagem
	MeshKit.attach(_turret, k.build())


func _t34(c: Color) -> void:
	var k := MeshKit.new()
	var dark := c.darkened(0.25)
	for side in [-1, 1]:
		_track(k, 1.3 * side, 5.4, 0.16, 1.12, 0.5, c)
	# Casco com chapas inclinadas na frente, atrás e nas laterais de cima
	k.box(Vector3(2.1, 0.6, 4.6), Vector3(0, 0.75, -0.2), c)
	k.frustum(Vector2(3.0, 4.4), Vector2(2.2, 3.4), 0.65, Vector3(0, 1.38, -0.2), c)
	k.frustum(Vector2(3.0, 1.2), Vector2(3.0, 0.05), 1.0, Vector3(0, 0.95, 2.55), c, Vector2(0, -0.55))
	k.box(Vector3(0.18, 0.18, 0.14), Vector3(-0.6, 1.4, 2.45), dark)                     # escotilha do motorista
	k.cylinder(0.1, 0.1, 0.25, Vector3(0.6, 1.2, 2.6), dark, Vector3(PI / 2.5, 0, 0), 10)  # metralhadora do casco
	for side in [-1, 1]:
		k.cylinder(0.22, 0.22, 1.2, Vector3(1.2 * side, 1.55, -2.0), dark, Vector3(PI / 2, 0, 0), 12)  # tanques extras
	MeshKit.attach(self, k.build())
	_wheel_row([-1.3, 1.3], [-2.1, -1.05, 0.0, 1.05, 2.1], 0.42, 0.4, 0.42, c.darkened(0.1))
	_turret = Node3D.new()
	_turret.position = Vector3(0, 1.72, 0.5)
	add_child(_turret)
	k = MeshKit.new()
	k.frustum(Vector2(2.2, 2.4), Vector2(1.55, 1.7), 0.7, Vector3(0, 0.35, 0), c, Vector2(0, -0.12))
	k.cylinder(0.3, 0.32, 0.22, Vector3(-0.35, 0.8, -0.3), c)
	k.cylinder(0.3, 0.32, 0.22, Vector3(0.35, 0.8, -0.3), c)
	k.box(Vector3(0.6, 0.45, 0.25), Vector3(0, 0.35, 1.2), c.darkened(0.05))
	k.cylinder(0.07, 0.085, 2.6, Vector3(0, 0.35, 2.5), c, Vector3(PI / 2, 0, 0), 12)
	k.cylinder(0.03, 0.03, 0.35, Vector3(0, 0.85, 0.4), dark, Vector3.ZERO, 6)            # antena curta
	MeshKit.attach(_turret, k.build())


func _sherman(c: Color, marking: String) -> void:
	var k := MeshKit.new()
	var dark := c.darkened(0.25)
	for side in [-1, 1]:
		_track(k, 1.2 * side, 5.0, 0.12, 0.92, 0.42, c)
		for z in [-1.6, 0.0, 1.6]:   # truques das rodas (suspensão de molas)
			k.box(Vector3(0.3, 0.45, 0.6), Vector3(1.05 * side, 0.6, z), dark)
			k.cylinder(0.1, 0.1, 0.15, Vector3(1.2 * side, 0.92, z), dark, Vector3(0, 0, PI / 2), 10)
	k.box(Vector3(2.25, 1.15, 4.6), Vector3(0, 1.35, -0.2), c)                             # casco alto
	k.frustum(Vector2(2.25, 1.0), Vector2(2.25, 0.2), 1.1, Vector3(0, 1.32, 2.4), c, Vector2(0, -0.4))
	k.sphere(0.6, Vector3(0, 0.95, 2.55), c, Vector3(1.85, 0.75, 0.8), false, 16)          # nariz fundido
	k.box(Vector3(0.6, 0.35, 0.2), Vector3(-0.55, 1.85, 2.05), c.darkened(0.08))           # capôs do motorista
	k.box(Vector3(0.6, 0.35, 0.2), Vector3(0.55, 1.85, 2.05), c.darkened(0.08))
	k.box(Vector3(2.0, 0.05, 1.5), Vector3(0, 1.94, -1.7), dark)
	MeshKit.attach(self, k.build())
	var xs := [-1.2, 1.2]
	var zs := []
	for z in [-1.6, 0.0, 1.6]:
		zs.append(z - 0.3)
		zs.append(z + 0.3)
	_wheel_row(xs, zs, 0.33, 0.26, 0.38, c.darkened(0.1))
	_turret = Node3D.new()
	_turret.position = Vector3(0, 1.95, 0.35)
	add_child(_turret)
	k = MeshKit.new()
	k.sphere(1.0, Vector3(0, 0.0, 0), c, Vector3(0.9, 0.62, 1.15), true, 20)              # torre arredondada
	k.box(Vector3(0.9, 0.42, 0.3), Vector3(0, 0.2, 1.1), c.darkened(0.05))
	k.cylinder(0.07, 0.08, 1.9, Vector3(0, 0.22, 2.1), c, Vector3(PI / 2, 0, 0), 12)        # canhão de 75 mm
	k.cylinder(0.32, 0.34, 0.2, Vector3(0.35, 0.7, -0.3), c)
	k.cylinder(0.025, 0.025, 1.6, Vector3(-0.5, 1.3, -0.6), dark, Vector3.ZERO, 6)          # antena
	MeshKit.attach(_turret, k.build())
	if marking == "estrela_eua":
		var star := MeshKit.new()
		for side in [-1, 1]:
			star.cylinder(0.38, 0.38, 0.01, Vector3(1.13 * side, 1.35, -0.6), Color("#e8e6dc"), Vector3(0, 0, PI / 2), 5)
		MeshKit.attach(self, star.build())


func _generic(c: Color) -> void:
	var k := MeshKit.new()
	for side in [-1, 1]:
		_track(k, 0.95 * side, 3.6, 0.1, 0.7, 0.32, c)
	k.box(Vector3(1.6, 0.7, 4.0), Vector3(0, 0.85, 0), c)
	k.frustum(Vector2(1.6, 0.5), Vector2(1.6, 0.2), 0.5, Vector3(0, 0.75, 2.2), c, Vector2(0, -0.12))
	MeshKit.attach(self, k.build())
	_wheel_row([-0.95, 0.95], [-1.3, -0.65, 0.0, 0.65, 1.3], 0.28, 0.2, 0.34, c.darkened(0.1))
	_turret = Node3D.new()
	_turret.position = Vector3(0, 1.2, 0.2)
	add_child(_turret)
	k = MeshKit.new()
	k.frustum(Vector2(1.3, 1.5), Vector2(1.0, 1.2), 0.55, Vector3(0, 0.28, 0), c)
	k.cylinder(0.05, 0.06, 1.6, Vector3(0, 0.3, 1.4), c, Vector3(PI / 2, 0, 0), 10)
	MeshKit.attach(_turret, k.build())
