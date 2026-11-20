class_name MeshKit
extends RefCounted
## Junta várias formas (caixas, troncos de pirâmide, esferas, cilindros, cápsulas) num único ArrayMesh
## com cor por vértice. Cada peça móvel de um modelo vira uma malha só (rápido também na versão web).

var _verts := PackedVector3Array()
var _normals := PackedVector3Array()
var _colors := PackedColorArray()
var _indices := PackedInt32Array()


func add(mesh: PrimitiveMesh, xf: Transform3D, color: Color) -> MeshKit:
	var arr := mesh.get_mesh_arrays()
	var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var n: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
	var base := _verts.size()
	var nb := xf.basis.inverse().transposed()
	for i in v.size():
		_verts.append(xf * v[i])
		_normals.append((nb * n[i]).normalized())
		_colors.append(color)
	for i in idx:
		_indices.append(base + i)
	return self


## Junta outro kit (com as cores dele) aplicando uma transformação.
func merge(other: MeshKit, t: Transform3D) -> MeshKit:
	var base := _verts.size()
	var nb := t.basis.inverse().transposed()
	for i in other._verts.size():
		_verts.append(t * other._verts[i])
		_normals.append((nb * other._normals[i]).normalized())
		_colors.append(other._colors[i])
	for i in other._indices:
		_indices.append(base + i)
	return self


static func xf(pos: Vector3, rot := Vector3.ZERO, scale := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled(scale), pos)


func box(size: Vector3, pos: Vector3, color: Color, rot := Vector3.ZERO) -> MeshKit:
	var m := BoxMesh.new()
	m.size = size
	return add(m, xf(pos, rot), color)


## Tronco de pirâmide: base (x, z) embaixo, topo (x, z) em cima, altura h; o topo pode ser deslocado
## (dx, dz). Bom para blindagem inclinada, túnicas que alargam, torres e fuselagens.
func frustum(bottom: Vector2, top: Vector2, h: float, pos: Vector3, color: Color, top_shift := Vector2.ZERO,
		rot := Vector3.ZERO) -> MeshKit:
	var t := xf(pos, rot)
	var p := [
		Vector3(-bottom.x / 2, -h / 2, -bottom.y / 2), Vector3(bottom.x / 2, -h / 2, -bottom.y / 2),
		Vector3(bottom.x / 2, -h / 2, bottom.y / 2), Vector3(-bottom.x / 2, -h / 2, bottom.y / 2),
		Vector3(-top.x / 2 + top_shift.x, h / 2, -top.y / 2 + top_shift.y), Vector3(top.x / 2 + top_shift.x, h / 2, -top.y / 2 + top_shift.y),
		Vector3(top.x / 2 + top_shift.x, h / 2, top.y / 2 + top_shift.y), Vector3(-top.x / 2 + top_shift.x, h / 2, top.y / 2 + top_shift.y)]
	for face in [[0, 1, 2, 3], [7, 6, 5, 4], [3, 2, 6, 7], [1, 0, 4, 5], [0, 3, 7, 4], [2, 1, 5, 6]]:
		var a: Vector3 = t * p[face[0]]
		var b: Vector3 = t * p[face[1]]
		var c: Vector3 = t * p[face[2]]
		var d: Vector3 = t * p[face[3]]
		var n := (b - a).cross(c - a).normalized()
		if n.length() < 0.5:
			n = (c - b).cross(d - b).normalized()
		var base := _verts.size()
		for q in [a, b, c, d]:
			_verts.append(q)
			_normals.append(n)
			_colors.append(color)
		_indices.append_array([base, base + 2, base + 1, base, base + 3, base + 2])
	return self


func sphere(radius: float, pos: Vector3, color: Color, scale := Vector3.ONE, hemisphere := false, seg := 16) -> MeshKit:
	var m := SphereMesh.new()
	m.radius = radius
	m.height = radius * (1.0 if hemisphere else 2.0)
	m.is_hemisphere = hemisphere
	m.radial_segments = seg
	m.rings = seg / 2
	return add(m, xf(pos, Vector3.ZERO, scale), color)


func cylinder(top: float, bottom: float, height: float, pos: Vector3, color: Color, rot := Vector3.ZERO, seg := 16,
		scale := Vector3.ONE) -> MeshKit:
	var m := CylinderMesh.new()
	m.top_radius = top
	m.bottom_radius = bottom
	m.height = height
	m.radial_segments = seg
	m.rings = 1
	return add(m, xf(pos, rot, scale), color)


func capsule(radius: float, height: float, pos: Vector3, color: Color, rot := Vector3.ZERO, scale := Vector3.ONE) -> MeshKit:
	var m := CapsuleMesh.new()
	m.radius = radius
	m.height = height
	m.radial_segments = 14
	m.rings = 4
	return add(m, xf(pos, rot, scale), color)


func build() -> ArrayMesh:
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = _verts
	arrays[Mesh.ARRAY_NORMAL] = _normals
	arrays[Mesh.ARRAY_COLOR] = _colors
	arrays[Mesh.ARRAY_INDEX] = _indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh


static var _material: StandardMaterial3D


## Material único dos modelos: cor de cada vértice, fosco, com um leve brilho nas bordas.
static func material() -> StandardMaterial3D:
	if _material == null:
		_material = StandardMaterial3D.new()
		_material.vertex_color_use_as_albedo = true
		_material.roughness = 0.82
		_material.metallic_specular = 0.25
		_material.rim_enabled = true
		_material.rim = 0.25
		_material.rim_tint = 0.6
	return _material


## Liga uma malha num nó (com o material dos modelos) e devolve a instância.
static func attach(parent: Node3D, mesh: Mesh, pos := Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.material_override = material()
	parent.add_child(mi)
	return mi
