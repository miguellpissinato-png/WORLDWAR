"""Gera o soldado 3D do WorldWar no Blender (bpy).

Uso:
  python3 tools/models/soldier.py [saida.glb] [arquivo.blend]
ou dentro do Blender (Scripting > Run Script), que monta a cena aberta.

Um modelo só serve para todas as nações: cada parte tem um material com nome
fixo (tunic, trousers, boots...) e o jogo troca as cores pelo uniforms.json.
Capacetes e equipamentos de cada exército são objetos separados (helmet_*, kit_*)
que o jogo mostra ou esconde. Animações: "marcha" e "parado".
Unidades em metros, Z para cima, soldado olhando para -Y (frente no Blender).
"""
import math
import sys

import bpy  # noqa: I001 (bpy antes de bmesh no módulo pip)
import bmesh
from mathutils import Matrix, Quaternion, Vector

FPS = 24
WALK_FRAMES = 24          # um ciclo (dois passos) por segundo

# Cores só de referência (o jogo substitui pelas do uniforms.json). Valores do alemão.
COLORS = {  # linear; uniformes vêm do uniforms.json (uniform_colors)
    "skin": (0.52, 0.29, 0.19), "eyes": (0.02, 0.015, 0.012), "hair": (0.03, 0.02, 0.012),
    "tunic": (0.11, 0.12, 0.08), "collar": (0.04, 0.06, 0.04), "trousers": (0.1, 0.11, 0.08),
    "boots": (0.008, 0.007, 0.006), "shin_upper": (0.008, 0.007, 0.006), "shin_lower": (0.008, 0.007, 0.006),
    "helmet": (0.06, 0.066, 0.05), "belt": (0.011, 0.011, 0.01), "pouch": (0.015, 0.014, 0.012),
    "buckle": (0.32, 0.32, 0.29), "bag": (0.1, 0.07, 0.04), "canteen": (0.12, 0.06, 0.025),
    "gasmask": (0.1, 0.11, 0.08), "wood": (0.13, 0.05, 0.018), "metal": (0.02, 0.02, 0.022),
}
ROUGH = {"buckle": 0.35, "metal": 0.35, "boots": 0.45, "belt": 0.5, "pouch": 0.5, "helmet": 0.65,
         "eyes": 0.3, "wood": 0.55}


def _lin(hexs):
    h = hexs.lstrip("#")
    out = []
    for i in (0, 2, 4):
        c = int(h[i:i + 2], 16) / 255
        out.append(c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4)
    return tuple(out)


def uniform_colors(tag, path=None):
    """Cores de prévia a partir do data/common/uniforms.json (o jogo faz o mesmo)."""
    import json
    import os
    path = path or os.path.join(os.path.dirname(__file__), "..", "..", "data", "common", "uniforms.json")
    data = json.load(open(path, encoding="utf-8"))
    u = dict(data.get("_padrao", {}))
    u.update(data.get(tag, {}))
    g = lambda k, d: _lin(u.get(k, d))
    out = {
        "tunic": g("tunic", "#5e6150"), "trousers": g("trousers", "#5a5c4f"), "collar": g("collar", u.get("tunic", "#5e6150")),
        "helmet": g("helmet_color", "#474a40"), "belt": g("belt", "#1c1b19"), "pouch": g("pouches", "#211f1c"),
        "buckle": g("buckle", "#9a9a92"), "boots": g("boots_color", "#151413"), "bag": g("pack", "#5b4c37"),
    }
    style = u.get("boots", "alta")
    leg = g("leg_color", u.get("boots_color", "#151413"))
    out["shin_upper"] = {"alta": out["boots"], "perneira": leg, "polaina": out["trousers"], "faixas": leg}.get(style, out["boots"])
    out["shin_lower"] = {"alta": out["boots"], "perneira": leg, "polaina": leg, "faixas": leg}.get(style, out["boots"])
    return out


def set_colors(colors):
    for k, c in colors.items():
        COLORS[k] = c
        m = bpy.data.materials.get(k)
        if m:
            p = [n for n in m.node_tree.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled"][0]
            p.inputs["Base Color"].default_value = (*c, 1)
            m.diffuse_color = (*c, 1)


# ---------------------------------------------------------------- utilidades

def mat(name):
    m = bpy.data.materials.get(name)
    if m:
        return m
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    p = [n for n in m.node_tree.nodes if n.bl_idname == "ShaderNodeBsdfPrincipled"][0]
    c = COLORS[name]
    p.inputs["Base Color"].default_value = (*c, 1)
    p.inputs["Roughness"].default_value = ROUGH.get(name, 0.85)
    p.inputs["Metallic"].default_value = 0.6 if name in ("buckle", "metal") else 0.0
    m.diffuse_color = (*c, 1)
    return m


def link(ob):
    bpy.context.scene.collection.objects.link(ob)
    return ob


def new_obj(name, bm):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    return link(bpy.data.objects.new(name, me))


def set_mat(ob, name):
    ob.data.materials.clear()
    ob.data.materials.append(mat(name))
    for p in ob.data.polygons:
        p.material_index = 0


def apply_mods(ob):
    """Aplica todos os modificadores (sem operadores, funciona fora da interface)."""
    dg = bpy.context.evaluated_depsgraph_get()
    ev = ob.evaluated_get(dg)
    me = bpy.data.meshes.new_from_object(ev)
    old = ob.data
    ob.modifiers.clear()
    ob.data = me
    bpy.data.meshes.remove(old)
    return ob


def smooth(ob, levels=1, shade=True):
    if levels:
        m = ob.modifiers.new("sub", "SUBSURF")
        m.levels = levels
        m.render_levels = levels
        apply_mods(ob)
    if shade:
        for p in ob.data.polygons:
            p.use_smooth = True


def ellipsoid(name, center, radii, matname, seg=16, rings=10):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * radii[0], v.co.y * radii[1], v.co.z * radii[2])) + Vector(center)
    ob = new_obj(name, bm)
    set_mat(ob, matname)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def box(name, center, size, matname, bevel=0.0, rot=None, sub=0):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        v.co = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
    if bevel > 0:
        bmesh.ops.bevel(bm, geom=list(bm.edges), offset=bevel, segments=2, affect="EDGES")
    if rot:
        R = rot.to_matrix().to_4x4() if isinstance(rot, Quaternion) else rot
        bmesh.ops.transform(bm, matrix=R, verts=bm.verts)
    bmesh.ops.translate(bm, vec=Vector(center), verts=bm.verts)
    ob = new_obj(name, bm)
    set_mat(ob, matname)
    if sub:
        smooth(ob, sub)
    return ob


def cylinder(name, a, b, r1, r2, matname, seg=12, cap=True):
    """Cilindro (ou cone) de a até b."""
    a, b = Vector(a), Vector(b)
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=cap, segments=seg, radius1=r1, radius2=r2, depth=(b - a).length)
    q = Vector((0, 0, 1)).rotation_difference((b - a).normalized())
    bmesh.ops.transform(bm, matrix=q.to_matrix().to_4x4(), verts=bm.verts)
    bmesh.ops.translate(bm, vec=(a + b) / 2, verts=bm.verts)
    ob = new_obj(name, bm)
    set_mat(ob, matname)
    for p in ob.data.polygons:
        p.use_smooth = len(p.vertices) == 4
    return ob


def ring_band(name, z, rx, ry, height, thick, matname, seg=32, cy=0.0, tilt=0.0):
    """Faixa em volta do corpo (cinto, gola): anel elíptico com espessura."""
    bm = bmesh.new()
    rows = []
    for k, (dz, dr) in enumerate(((-height / 2, 0), (height / 2, 0), (height / 2, thick), (-height / 2, thick))):
        row = []
        for i in range(seg):
            t = 2 * math.pi * i / seg
            x = math.sin(t) * (rx + dr)
            y = -math.cos(t) * (ry + dr) + cy
            zz = z + dz + tilt * (-math.cos(t))
            row.append(bm.verts.new((x, y, zz)))
        rows.append(row)
    for k in range(4):
        r0, r1 = rows[k], rows[(k + 1) % 4]
        for i in range(seg):
            j = (i + 1) % seg
            bm.faces.new((r0[i], r0[j], r1[j], r1[i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = new_obj(name, bm)
    set_mat(ob, matname)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def strap(name, pts, width, thick, matname):
    """Tira (alça) passando pelos pontos, com a largura no plano da superfície."""
    bm = bmesh.new()
    pts = [Vector(p) for p in pts]
    rows = []
    for i, p in enumerate(pts):
        d = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        out = Vector((p.x, p.y, 0)).normalized() if Vector((p.x, p.y)).length > 1e-4 else Vector((0, -1, 0))
        side = d.cross(out).normalized() * (width / 2)
        n = side.cross(d).normalized() * thick
        rows.append([bm.verts.new(p - side), bm.verts.new(p + side), bm.verts.new(p + side + n), bm.verts.new(p - side + n)])
    for i in range(len(rows) - 1):
        for k in range(4):
            a, b = rows[i], rows[i + 1]
            bm.faces.new((a[k], a[(k + 1) % 4], b[(k + 1) % 4], b[k]))
    bm.faces.new(rows[0][::-1])
    bm.faces.new(rows[-1])
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = new_obj(name, bm)
    set_mat(ob, matname)
    return ob


def join(name, parts):
    """Junta objetos num só (mantém materiais e grupos de vértices)."""
    parts = [p for p in parts if p]
    me = bpy.data.meshes.new(name)
    bm = bmesh.new()
    mats, groups = [], []
    tmp_me = bpy.data.meshes.new("_tmp")
    for ob in parts:
        tmp = bmesh.new()
        tmp.from_mesh(ob.data)
        tmp.transform(ob.matrix_world)
        local = [m.name for m in ob.data.materials]
        for m in local:
            if m not in mats:
                mats.append(m)
        remap = [mats.index(m) for m in local] or [0]
        for f in tmp.faces:
            f.material_index = remap[min(f.material_index, len(remap) - 1)]
        dl = tmp.verts.layers.deform.verify()
        names = [g.name for g in ob.vertex_groups]
        for g in names:
            if g not in groups:
                groups.append(g)
        gmap = {i: groups.index(g) for i, g in enumerate(names)}
        for v in tmp.verts:
            d = v[dl]
            new = {gmap[k]: w for k, w in d.items()}
            d.clear()
            for k, w in new.items():
                d[k] = w
        tmp.to_mesh(tmp_me)
        tmp.free()
        bm.from_mesh(tmp_me)
    bm.to_mesh(me)
    bm.free()
    bpy.data.meshes.remove(tmp_me)
    for ob in parts:
        bpy.data.objects.remove(ob, do_unlink=True)
    out = link(bpy.data.objects.new(name, me))
    for m in mats:
        me.materials.append(bpy.data.materials[m])
    for g in groups:
        out.vertex_groups.new(name=g)
    return out


def weight_all(ob, bone):
    g = ob.vertex_groups.get(bone) or ob.vertex_groups.new(name=bone)
    g.add(list(range(len(ob.data.vertices))), 1.0, "REPLACE")
    return ob


# ---------------------------------------------------------------- esqueleto

# Juntas do corpo vestido (posição, raio x, raio y) — o raio é o do skin antes da suavização.
PTS = {}
EDGES = []


def _pts():
    def P(n, pos, r):
        PTS[n] = (Vector(pos), r)
    P("pelvis", (0, 0.0, 0.96), (0.15, 0.108))
    P("waist", (0, 0.0, 1.08), (0.138, 0.098))
    P("chest", (0, -0.006, 1.24), (0.158, 0.112))
    P("uchest", (0, 0.004, 1.365), (0.165, 0.1))
    P("neck0", (0, 0.014, 1.47), (0.052, 0.055))
    P("neck1", (0, 0.01, 1.545), (0.047, 0.05))
    EDGES.extend([("pelvis", "waist"), ("waist", "chest"), ("chest", "uchest"), ("uchest", "neck0"), ("neck0", "neck1")])
    for s, x in (("L", 1), ("R", -1)):
        P("clav" + s, (0.09 * x, 0.012, 1.425), (0.06, 0.058))
        P("sh" + s, (0.198 * x, 0.016, 1.41), (0.058, 0.057))
        P("uarm" + s, (0.212 * x, 0.022, 1.27), (0.049, 0.05))
        P("elb" + s, (0.222 * x, 0.03, 1.12), (0.041, 0.042))
        P("farm" + s, (0.232 * x, 0.016, 1.0), (0.038, 0.036))
        P("wri" + s, (0.24 * x, 0.0, 0.875), (0.028, 0.024))
        P("hip" + s, (0.092 * x, 0.0, 0.91), (0.085, 0.088))
        P("thi" + s, (0.098 * x, -0.006, 0.74), (0.078, 0.082))
        P("kne" + s, (0.1 * x, -0.01, 0.515), (0.055, 0.058))
        P("btop" + s, (0.1 * x, 0.002, 0.405), (0.059, 0.062))
        P("calf" + s, (0.1 * x, 0.012, 0.27), (0.055, 0.058))
        P("ank" + s, (0.1 * x, 0.03, 0.13), (0.045, 0.05))
        EDGES.extend([("uchest", "clav" + s), ("clav" + s, "sh" + s), ("sh" + s, "uarm" + s), ("uarm" + s, "elb" + s),
                      ("elb" + s, "farm" + s), ("farm" + s, "wri" + s), ("pelvis", "hip" + s), ("hip" + s, "thi" + s),
                      ("thi" + s, "kne" + s), ("kne" + s, "btop" + s), ("btop" + s, "calf" + s), ("calf" + s, "ank" + s)])


SKIN_SCALE = 1.12


def build_body():
    names = list(PTS)
    me = bpy.data.meshes.new("body")
    me.from_pydata([PTS[n][0] for n in names], [(names.index(a), names.index(b)) for a, b in EDGES], [])
    ob = link(bpy.data.objects.new("Body", me))
    sk = ob.modifiers.new("skin", "SKIN")
    sk.branch_smoothing = 0.5
    sv = me.skin_vertices[0].data
    for i, n in enumerate(names):
        rx, ry = PTS[n][1]
        sv[i].radius = (rx * SKIN_SCALE, ry * SKIN_SCALE)
        sv[i].use_root = n == "pelvis"
    ob.modifiers.new("sub", "SUBSURF").levels = 2
    apply_mods(ob)
    # materiais por região: segmento do esqueleto mais perto de cada face
    order = ["tunic", "trousers", "boots", "shin_upper", "shin_lower", "skin"]
    for m in order:
        me = ob.data
        me.materials.append(mat(m))
    segs = [(a, b, PTS[a][0], PTS[b][0]) for a, b in EDGES]
    for p in ob.data.polygons:
        c = p.center
        best, bd = None, 9
        for a, b, pa, pb in segs:
            ab = pb - pa
            t = max(0, min(1, (c - pa).dot(ab) / ab.length_squared))
            d = (pa + ab * t - c).length
            if d < bd:
                bd, best = d, (a, b)
        a, b = best
        leg = any(k in a + b for k in ("hip", "thi", "kne", "btop", "calf", "ank", "toe"))
        if "neck" in b and c.z > 1.5:
            m = "skin"
        elif leg:
            if c.z < 0.27:
                m = "shin_lower"
            elif c.z < 0.41:
                m = "shin_upper"
            else:
                m = "trousers"
        elif a == "pelvis" and b == "waist" and c.z < 0.99:
            m = "trousers"
        else:
            m = "tunic"
        p.material_index = order.index(m)
        p.use_smooth = True
    return ob


HEAD_C = Vector((0, 0.004, 1.635))
HEAD_R = Vector((0.079, 0.095, 0.106))


def _face(x, y, z):
    """Deslocamento da superfície da cabeça (rosto) num ponto local."""
    if y > -0.02:
        return 0.0
    g = lambda dx, dz, sx, sz: math.exp(-(dx * dx) / (2 * sx * sx) - (dz * dz) / (2 * sz * sz))
    front = min(1.0, (-y - 0.02) / 0.05)
    d = 0.0
    d += 0.026 * g(x, z + 0.024, 0.012, 0.016) + 0.012 * g(x, z - 0.006, 0.008, 0.022)   # nariz
    for sx in (1, -1):
        d += 0.008 * g(x - 0.012 * sx, z + 0.034, 0.007, 0.006)      # narinas
    for sx in (1, -1):
        d += 0.007 * g(x - 0.03 * sx, z - 0.036, 0.018, 0.009)       # sobrancelha
        d -= 0.012 * g(x - 0.031 * sx, z - 0.01, 0.014, 0.011)       # órbita
        d += 0.006 * g(x - 0.05 * sx, z + 0.012, 0.014, 0.014)       # maçã do rosto
    d += 0.012 * g(x, z + 0.084, 0.022, 0.014)                       # queixo
    d += 0.004 * g(x, z + 0.055, 0.015, 0.006)                       # lábios
    d -= 0.002 * g(x, z + 0.062, 0.016, 0.002)                       # boca
    return d * front


def head_point(x, z, side=-1):
    """Ponto da superfície do rosto (para olhos) por busca na direção -Y."""
    best = None
    for k in range(200):
        y = -k * 0.0006
        u = Vector((x / HEAD_R.x, y / HEAD_R.y, z / HEAD_R.z))
        if u.length >= 1:
            return Vector((x, y, z))
    return Vector((x, -HEAD_R.y, z))


def build_head():
    hc = HEAD_C
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=32, v_segments=24, radius=1.0)
    for v in bm.verts:
        n = v.co.copy()
        p = Vector((n.x * HEAD_R.x, n.y * HEAD_R.y, n.z * HEAD_R.z))
        if n.z < -0.05:                        # mandíbula mais estreita
            k = 1 - 0.22 * min(1, (-n.z - 0.05) / 0.95) ** 1.5
            p.x *= k
            p.y = p.y * (0.92 + 0.08 * k)
        if p.y < -0.055:                       # rosto mais plano
            p.y = -0.055 + (p.y + 0.055) * 0.62
        if n.z > 0.2 and n.y > 0:              # nuca mais cheia
            p.y *= 1.04
        p.y -= _face(p.x, p.y, p.z)
        v.co = p + hc
    head = new_obj("head", bm)
    set_mat(head, "skin")
    for f in head.data.polygons:
        f.use_smooth = True
    parts = [head]
    for x in (1, -1):
        ear = ellipsoid("ear", hc + Vector((0.074 * x, 0.012, 0.0)), (0.011, 0.02, 0.031), "skin", 10, 8)
        parts.append(ear)
        # olho dentro da órbita (o fundo escuro dá o olhar à distância)
        e = Vector((0.031 * x, 0, 0.01))
        y = -0.055 + (-(1 - (e.x / HEAD_R.x) ** 2 - (e.z / HEAD_R.z) ** 2) ** 0.5 * HEAD_R.y + 0.055) * 0.62
        y -= _face(e.x, y, e.z)
        parts.append(ellipsoid("eye", hc + Vector((e.x, y + 0.003, e.z)), (0.0115, 0.005, 0.0065), "eyes", 10, 6))
    # cabelo curto (nuca e têmporas aparecem sob o capacete)
    hair = ellipsoid("hair", hc + Vector((0, 0.008, 0.018)), (0.079, 0.096, 0.104), "hair", 24, 14)
    for v in hair.data.vertices:
        l = v.co - hc
        if l.y < -0.035 or l.z < -0.035 + 0.04 * max(0, -l.y / 0.1):
            v.co = hc + Vector((l.x * 0.9, l.y * 0.9, max(l.z, 0.0) * 0.9))
    parts.append(hair)
    for p in parts:
        weight_all(p, "head")
    return parts


def build_hands():
    parts = []
    for s, x in (("L", 1), ("R", -1)):
        w = PTS["wri" + s][0]
        palm = box("palm", w + Vector((0.003 * x, -0.004, -0.045)), (0.027, 0.07, 0.075), "skin", bevel=0.011,
                   rot=Matrix.Rotation(math.radians(-6 * x), 4, "Y"))
        fing = box("fingers", w + Vector((-0.004 * x, -0.012, -0.092)), (0.025, 0.062, 0.04), "skin", bevel=0.011,
                   rot=Matrix.Rotation(math.radians(25), 4, "X"))
        thumb = cylinder("thumb", w + Vector((-0.008 * x, -0.035, -0.03)), w + Vector((-0.016 * x, -0.05, -0.075)),
                         0.011, 0.009, "skin", seg=8)
        for p in (palm, fing, thumb):
            for f in p.data.polygons:
                f.use_smooth = True
            weight_all(p, "hand." + s)
            parts.append(p)
    return parts


def build_boots():
    """Pé da bota com sola e salto (o cano vem do corpo)."""
    parts = []
    for s, x in (("L", 1), ("R", -1)):
        bm = bmesh.new()
        bmesh.ops.create_cube(bm, size=1.0)
        bmesh.ops.subdivide_edges(bm, edges=[e for e in bm.edges if abs(e.verts[0].co.y - e.verts[1].co.y) > 0.5],
                                  cuts=3, use_grid_fill=True)
        for v in bm.verts:
            y = v.co.y          # -0.5 bico, +0.5 calcanhar
            top = v.co.z > 0
            yy = -0.07 + y * 0.27
            wid = 0.086 if y > -0.25 else 0.086 - (-0.25 - y) * 0.08
            if top:
                h = 0.175 if y > 0.15 else 0.175 - ((0.15 - y) / 0.65) ** 0.8 * 0.1
            else:
                h = 0.0
            v.co = Vector((x * 0.1 + v.co.x * wid, yy, h))
        ob = new_obj("boot", bm)
        set_mat(ob, "boots")
        smooth(ob, 2)
        for o in (ob,):
            weight_all(o, "foot." + s)
            parts.append(o)
    return parts


def build_tunic_extras():
    """Saia da túnica, gola, bolsos e botões (comuns a todos os uniformes)."""
    parts = []
    # saia da túnica: tubo aberto da cintura até o meio da coxa
    bm = bmesh.new()
    seg, rows = 32, 5
    vs = []
    for j in range(rows):
        t = j / (rows - 1)
        z = 1.0 - 0.215 * t
        rx = 0.215 + 0.035 * t
        ry = 0.152 + 0.03 * t
        row = []
        for i in range(seg):
            a = 2 * math.pi * i / seg
            row.append(bm.verts.new((math.sin(a) * rx, -math.cos(a) * ry + 0.004, z)))
        vs.append(row)
    for j in range(rows - 1):
        for i in range(seg):
            k = (i + 1) % seg
            bm.faces.new((vs[j][i], vs[j][k], vs[j + 1][k], vs[j + 1][i]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    for f in bm.faces:              # normais para fora
        if f.normal.dot(Vector((f.calc_center_median().x, f.calc_center_median().y, 0))) < 0:
            f.normal_flip()
    skirt = new_obj("skirt", bm)
    m = skirt.modifiers.new("solid", "SOLIDIFY")
    m.thickness = 0.008
    set_mat(skirt, "tunic")
    smooth(skirt, 1)
    skirt["weights"] = "transfer"
    parts.append(skirt)
    # gola
    collar = ring_band("collar", 1.487, 0.057, 0.061, 0.062, 0.008, "collar", seg=24, cy=0.012, tilt=-0.014)
    weight_all(collar, "neck")
    parts.append(collar)
    # bolsos do peito e da saia, com aba
    for x in (1, -1):
        p = box("pocket", (0.085 * x, -0.165, 1.28), (0.085, 0.016, 0.1), "tunic", bevel=0.006,
                rot=Matrix.Rotation(math.radians(-8), 4, "X"))
        f = box("flap", (0.085 * x, -0.176, 1.325), (0.092, 0.012, 0.035), "tunic", bevel=0.005,
                rot=Matrix.Rotation(math.radians(-8), 4, "X"))
        for o in (p, f):
            weight_all(o, "chest")
            parts.append(o)
        p = box("pocket2", (0.115 * x, -0.19, 0.89), (0.1, 0.016, 0.12), "tunic", bevel=0.006,
                rot=Matrix.Rotation(math.radians(6), 4, "X") @ Matrix.Rotation(math.radians(-18 * x), 4, "Z"))
        weight_all(p, "hips")
        parts.append(p)
    for i in range(5):              # botões da frente
        z = 1.41 - i * 0.095
        y = -0.16 if z > 1.1 else -0.17
        b = ellipsoid("button", (0, y - (0.02 if 1.05 < z < 1.3 else 0.0), z), (0.008, 0.005, 0.008), "buckle", 8, 6)
        weight_all(b, "chest" if z > 1.2 else ("spine" if z > 1.0 else "hips"))
        parts.append(b)
    return parts


# ---------------------------------------------------------------- capacetes

def helmet(kind):
    """Capacete gerado por perfil girado. Ângulo 0 = frente (-Y)."""
    N, M = 18, 40
    if kind == "stahlhelm":
        c, R, sy = Vector((0, 0.008, 1.69)), 0.113, 1.07
    elif kind == "m1":
        c, R, sy = Vector((0, 0.006, 1.672)), 0.123, 1.06
    elif kind == "brodie":
        c, R, sy = Vector((0, 0.006, 1.705)), 0.112, 1.0
    elif kind == "ssh40":
        c, R, sy = Vector((0, 0.006, 1.676)), 0.12, 1.06
    else:   # adrian
        c, R, sy = Vector((0, 0.006, 1.675)), 0.118, 1.05
    bm = bmesh.new()
    grid = []
    for j in range(N + 1):
        t = j / N
        row = []
        for i in range(M):
            a = 2 * math.pi * i / M
            side = abs(math.sin(a))          # 0 frente/trás, 1 lados
            back = max(0.0, math.cos(a + math.pi))  # 1 atrás
            front = max(0.0, math.cos(a))           # 1 na frente
            if kind == "stahlhelm":
                if t <= 0.68:
                    ph = math.radians(97) * t / 0.68
                    r, z = R * math.sin(ph), R * math.cos(ph) * 0.95
                else:
                    u = (t - 0.68) / 0.32
                    depth = 0.01 + 0.062 * min(1, side * 1.15 + back * 0.95)
                    r = R * math.sin(math.radians(97)) + (0.016 + 0.006 * side) * u ** 1.4
                    z = R * math.cos(math.radians(97)) * 0.95 - depth * u
            elif kind == "m1":
                if t <= 0.84:
                    ph = math.radians(100) * t / 0.84
                    r, z = R * math.sin(ph), R * math.cos(ph) * 0.92
                    z -= 0.012 * side * (t / 0.84) ** 4
                else:
                    u = (t - 0.84) / 0.16
                    r = R * math.sin(math.radians(100)) + 0.013 * u
                    z = R * math.cos(math.radians(100)) * 0.92 - 0.012 * side - 0.004 * u
            elif kind == "brodie":
                if t <= 0.6:
                    ph = math.radians(88) * t / 0.6
                    r, z = R * math.sin(ph), R * math.cos(ph) * 0.62
                else:
                    u = (t - 0.6) / 0.4
                    r = R * math.sin(math.radians(88)) + 0.062 * u
                    z = R * math.cos(math.radians(88)) * 0.62 - 0.018 * u ** 1.5
            elif kind == "ssh40":
                if t <= 0.8:
                    ph = math.radians(102) * t / 0.8
                    r, z = R * math.sin(ph), R * math.cos(ph) * 0.95
                else:
                    u = (t - 0.8) / 0.2
                    r = R * math.sin(math.radians(102)) + (0.012 + 0.012 * front) * u
                    z = R * math.cos(math.radians(102)) * 0.95 - (0.03 * side + 0.02 * back) * u - 0.004 * front * u
                    z += 0.018 * front * u
            else:  # adrian: cúpula, abas na frente e atrás
                if t <= 0.7:
                    ph = math.radians(92) * t / 0.7
                    r, z = R * math.sin(ph), R * math.cos(ph) * 0.9
                else:
                    u = (t - 0.7) / 0.3
                    r = R + (0.01 + 0.045 * (front + back)) * u
                    z = -0.004 - (0.012 * side) * u - 0.01 * (front + back) * u ** 2
            row.append(bm.verts.new(c + Vector((math.sin(a) * r, -math.cos(a) * r * sy, z))))
        grid.append(row)
    top = bm.verts.new(c + Vector((0, 0, grid[0][0].co.z - c.z)))
    for j in range(N):
        for i in range(M):
            k = (i + 1) % M
            if j == 0:
                bm.faces.new((top, grid[1][k], grid[1][i]))
            else:
                bm.faces.new((grid[j][i], grid[j][k], grid[j + 1][k], grid[j + 1][i]))
    for v in grid[0]:
        if not v.link_faces:
            bm.verts.remove(v)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    ob = new_obj("helmet_" + kind, bm)
    s = ob.modifiers.new("solid", "SOLIDIFY")
    s.thickness = 0.007
    s.offset = 1
    set_mat(ob, "helmet")
    smooth(ob, 1)
    parts = [ob]
    if kind == "adrian":   # crista no topo
        cr = box("crest", c + Vector((0, 0.0, 0.1)), (0.022, 0.2, 0.03), "helmet", bevel=0.008)
        smooth(cr, 1)
        parts.append(cr)
    out = join("helmet_" + kind, parts) if len(parts) > 1 else ob
    weight_all(out, "head")
    return out


# ---------------------------------------------------------------- equipamento

def kit_ger():
    """Equipamento alemão: cinto, suspensório em Y, cartucheiras, bolsa de pão,
    cantil, pá e porta-máscara. Tudo pendurado no corpo (pesos rígidos)."""
    parts = []
    hips, spine, chest = [], [], []
    belt = ring_band("belt", 1.005, 0.2, 0.147, 0.048, 0.012, "belt", seg=36, cy=0.004)
    hips.append(belt)
    hips.append(box("buckle", (0, -0.168, 1.005), (0.06, 0.012, 0.045), "buckle", bevel=0.004))
    # cartucheiras: três por lado
    for x in (1, -1):
        for k in range(3):
            xx = (0.055 + k * 0.034) * x
            yy = -0.165 + (k * 0.012)
            hips.append(box("pouch", (xx, yy, 1.04), (0.032, 0.03, 0.06), "pouch", bevel=0.006,
                            rot=Matrix.Rotation(math.radians(-14 * x * k), 4, "Z")))
            hips.append(box("pflap", (xx, yy - 0.012, 1.065), (0.034, 0.012, 0.03), "pouch", bevel=0.004,
                            rot=Matrix.Rotation(math.radians(-14 * x * k), 4, "Z")))
    # suspensório em Y: duas tiras na frente, sobem pelos ombros e se juntam nas costas
    for x in (1, -1):
        chest.append(strap("ystrap", [(0.075 * x, -0.17, 1.03), (0.085 * x, -0.175, 1.16), (0.095 * x, -0.17, 1.3),
                                      (0.11 * x, -0.12, 1.42), (0.11 * x, -0.03, 1.47), (0.09 * x, 0.06, 1.44),
                                      (0.05 * x, 0.13, 1.33), (0.0, 0.15, 1.24)], 0.024, 0.006, "belt"))
    spine.append(strap("ystrap_back", [(0, 0.15, 1.245), (0, 0.155, 1.13), (0, 0.155, 1.03)], 0.026, 0.006, "belt"))
    # bolsa de pão (lado direito, atrás) com cantil por cima
    bag = box("breadbag", (-0.15, 0.1, 0.94), (0.06, 0.2, 0.15), "bag", bevel=0.025,
              rot=Matrix.Rotation(math.radians(-55), 4, "Z"))
    smooth(bag, 1)
    hips.append(bag)
    can = ellipsoid("canteen", (-0.205, 0.075, 0.92), (0.038, 0.06, 0.085), "canteen", 14, 10)
    hips.append(can)
    hips.append(cylinder("cap", (-0.205, 0.075, 1.0), (-0.205, 0.075, 1.03), 0.02, 0.018, "metal", seg=10))
    # pá na esquerda, atrás
    hips.append(box("shovel", (0.165, 0.095, 0.9), (0.03, 0.14, 0.17), "belt", bevel=0.012,
                    rot=Matrix.Rotation(math.radians(55), 4, "Z") @ Matrix.Rotation(math.radians(-10), 4, "X")))
    hips.append(cylinder("handle", (0.17, 0.1, 0.98), (0.17, 0.12, 1.12), 0.012, 0.012, "wood", seg=8))
    # porta-máscara canelado nas costas
    gm = cylinder("gasmask", (0.04, 0.215, 0.83), (0.07, 0.19, 1.1), 0.05, 0.05, "gasmask", seg=16)
    hips.append(gm)
    for k in range(4):
        z = 0.85 + k * 0.08
        a = Vector((0.04, 0.215, 0.83)).lerp(Vector((0.07, 0.19, 1.1)), (z - 0.83) / 0.27)
        hips.append(cylinder("rib", a - Vector((0, 0, 0.006)), a + Vector((0, 0, 0.006)), 0.054, 0.054, "gasmask", seg=16))
    for o in hips:
        weight_all(o, "hips")
    for o in spine:
        weight_all(o, "spine")
    for o in chest:
        weight_all(o, "chest")
    return join("kit_ger", hips + spine + chest)


def rifle():
    """Fuzil de ferrolho (tipo Kar98k / Lee-Enfield) a tiracolo no ombro direito."""
    parts = []
    butt = Vector((-0.2, 0.12, 0.84))
    muzzle = Vector((-0.17, 0.085, 1.95))
    d = (muzzle - butt).normalized()
    L = (muzzle - butt).length
    q = Vector((0, 0, 1)).rotation_difference(d)
    def at(t, off=(0, 0, 0)):
        return butt + d * (t * L) + q @ Vector(off)
    # coronha e guarda-mão em madeira
    parts.append(box("stock", at(0.13, (0, 0.012, 0)), (0.04, 0.11, 0.26), "wood", bevel=0.012, rot=q))
    parts.append(box("grip", at(0.32, (0, 0.0, 0)), (0.035, 0.05, 0.16), "wood", bevel=0.01, rot=q))
    parts.append(box("fore", at(0.6, (0, -0.008, 0)), (0.034, 0.042, 0.42), "wood", bevel=0.01, rot=q))
    parts.append(cylinder("barrel", at(0.36, (0, -0.012, 0)), at(1.0, (0, -0.012, 0)), 0.009, 0.008, "metal", seg=8))
    parts.append(box("action", at(0.4, (0, -0.012, 0)), (0.03, 0.03, 0.16), "metal", bevel=0.006, rot=q))
    parts.append(cylinder("bolt", at(0.42, (0, -0.012, 0)), at(0.42, (0.05, -0.02, -0.01)), 0.005, 0.005, "metal", seg=6))
    for t in (0.66, 0.83):
        parts.append(cylinder("band", at(t - 0.008, (0, -0.008, 0)), at(t + 0.008, (0, -0.008, 0)), 0.022, 0.022, "metal", seg=10))
    # bandoleira até a mão direita
    parts.append(strap("sling", [at(0.83, (0, -0.03, 0)), (-0.2, -0.05, 1.42), (-0.19, -0.1, 1.3),
                                 at(0.2, (0, -0.04, 0))], 0.02, 0.004, "belt"))
    for p in parts:
        weight_all(p, "chest")
    return join("rifle", parts)


# ---------------------------------------------------------------- armação e animação

BONES = [  # nome, cabeça, cauda, pai
    ("root", (0, 0, 0), (0, 0, 0.15), None),
    ("hips", (0, 0, 0.94), (0, 0, 1.07), "root"),
    ("spine", (0, 0, 1.07), (0, 0, 1.24), "hips"),
    ("chest", (0, 0, 1.24), (0, 0.01, 1.44), "spine"),
    ("neck", (0, 0.012, 1.44), (0, 0.008, 1.56), "chest"),
    ("head", (0, 0.008, 1.56), (0, 0.0, 1.76), "neck"),
]
for _s, _x in (("L", 1), ("R", -1)):
    BONES += [
        ("clavicle." + _s, (0.03 * _x, 0.01, 1.42), (0.178 * _x, 0.016, 1.415), "chest"),
        ("upper_arm." + _s, (0.198 * _x, 0.016, 1.41), (0.222 * _x, 0.03, 1.12), "clavicle." + _s),
        ("forearm." + _s, (0.222 * _x, 0.03, 1.12), (0.24 * _x, 0.0, 0.875), "upper_arm." + _s),
        ("hand." + _s, (0.24 * _x, 0.0, 0.875), (0.244 * _x, -0.01, 0.76), "forearm." + _s),
        ("thigh." + _s, (0.092 * _x, 0.0, 0.91), (0.1 * _x, -0.01, 0.515), "hips"),
        ("shin." + _s, (0.1 * _x, -0.01, 0.515), (0.1 * _x, 0.03, 0.1), "thigh." + _s),
        ("foot." + _s, (0.1 * _x, 0.03, 0.1), (0.1 * _x, -0.17, 0.03), "shin." + _s),
    ]


def build_armature():
    ad = bpy.data.armatures.new("Armature")
    arm = link(bpy.data.objects.new("Soldier", ad))
    bpy.context.view_layer.objects.active = arm
    bpy.ops.object.mode_set(mode="EDIT")
    for name, h, t, parent in BONES:
        b = ad.edit_bones.new(name)
        b.head, b.tail = h, t
        b.roll = 0
        if parent:
            b.parent = ad.edit_bones[parent]
            b.use_connect = False
    bpy.ops.object.mode_set(mode="OBJECT")
    return arm


def auto_weights(arm, body):
    """Pesos por distância aos ossos (estável e sem depender da interface)."""
    segs = []
    for b in arm.data.bones:
        if b.name == "root":
            continue
        segs.append((b.name, Vector(b.head_local), Vector(b.tail_local)))
    groups = {n: body.vertex_groups.get(n) or body.vertex_groups.new(name=n) for n, _, _ in segs}
    for v in body.data.vertices:
        p = v.co
        ds = []
        for n, a, b in segs:
            ab = b - a
            t = max(0, min(1, (p - a).dot(ab) / ab.length_squared))
            d = (a + ab * t - p).length
            ds.append((d, n))
        ds.sort()
        d0 = ds[0][0]
        # só ossos quase tão perto quanto o mais perto entram na mistura
        near = [(d, n) for d, n in ds[:4] if d < d0 + 0.045]
        ws = [(1.0 / max(d, 0.004) ** 4, n) for d, n in near]
        tot = sum(w for w, _ in ws)
        for w, n in ws:
            groups[n].add([v.index], w / tot, "REPLACE")


def transfer_weights(src, dst):
    """Copia os pesos do corpo para a saia (vértice mais perto)."""
    from mathutils.kdtree import KDTree
    kd = KDTree(len(src.data.vertices))
    for v in src.data.vertices:
        kd.insert(v.co, v.index)
    kd.balance()
    names = [g.name for g in src.vertex_groups]
    for n in names:
        if not dst.vertex_groups.get(n):
            dst.vertex_groups.new(name=n)
    for v in dst.data.vertices:
        acc = {}
        found = kd.find_n(v.co, 6)
        tw = 0
        for co, idx, dist in found:
            k = 1.0 / max(dist, 0.005) ** 2
            tw += k
            for g in src.data.vertices[idx].groups:
                acc[g.group] = acc.get(g.group, 0) + g.weight * k
        for gi, w in acc.items():
            dst.vertex_groups[names[gi]].add([v.index], w / tw, "REPLACE")


def bind(arm, ob):
    ob.parent = arm
    m = ob.modifiers.new("arm", "ARMATURE")
    m.object = arm
    return ob


def _rot(pb, axis, deg):
    """Rotação em torno de um eixo do mundo, convertida para o espaço do osso."""
    rest = pb.bone.matrix_local.to_quaternion()
    qw = Quaternion(Vector(axis), math.radians(deg))
    return rest.inverted() @ qw @ rest


def _key(arm, frame, pose):
    for name, rots in pose.items():
        pb = arm.pose.bones[name]
        pb.rotation_mode = "QUATERNION"
        q = Quaternion()
        for axis, deg in rots:
            q = _rot(pb, axis, deg) @ q
        pb.rotation_quaternion = q
        pb.keyframe_insert("rotation_quaternion", frame=frame)


X, Y, Z = (1, 0, 0), (0, 1, 0), (0, 0, 1)


def right_arm_sling(k=0.0):
    """Braço direito segurando a bandoleira na frente do ombro."""
    return {
        "upper_arm.R": [(Z, 0), (Y, -4), (X, 2 - 2 * k)],
        "forearm.R": [(Z, -34), (X, -102 - 3 * k)],
        "hand.R": [(X, 20)],
    }


def make_actions(arm):
    arm.animation_data_create()
    names = [b.name for b in arm.pose.bones]
    acts = {}
    # --- marcha
    act = bpy.data.actions.new("marcha")
    arm.animation_data.action = act
    for f in range(0, WALK_FRAMES + 1, 2):
        p = 2 * math.pi * f / WALK_FRAMES
        s, c = math.sin(p), math.cos(p)
        pose = {}
        for side, sg in (("L", 1), ("R", -1)):
            th = 22 * s * sg                     # coxa: + = para frente
            ph = p if sg > 0 else p + math.pi
            knee = 5 + 47 * max(0.0, math.cos(ph + 0.45)) ** 1.6
            pose["thigh." + side] = [(X, -th)]
            pose["shin." + side] = [(X, knee)]
            pose["foot." + side] = [(X, (th - knee) * 0.85 + 14 * max(0.0, -math.sin(ph)) ** 2)]
        pose["upper_arm.L"] = [(Y, 4), (X, 20 * s)]
        pose["forearm.L"] = [(X, -(14 + 16 * max(0.0, -s)))]
        pose["hand.L"] = [(X, -6)]
        pose.update(right_arm_sling(abs(s)))
        pose["hips"] = [(Z, 6 * s), (Y, 2.5 * c)]
        pose["spine"] = [(Z, -4 * s), (X, -3)]
        pose["chest"] = [(Z, -3 * s)]
        pose["neck"] = [(Z, 2 * s)]
        pose["head"] = [(X, 4)]
        pose["clavicle.L"] = [(X, 2 * s)]
        pose["clavicle.R"] = [(X, -1)]
        _key(arm, f, pose)
        root = arm.pose.bones["root"]
        root.location = (0, 0, 0)
        hb = arm.pose.bones["hips"]
        # sobe e desce: mais baixo com as pernas abertas (Y do osso = Z do mundo)
        hb.location = (0, 0.016 * math.cos(2 * p), 0)
        hb.keyframe_insert("location", frame=f)
    acts["marcha"] = act
    # --- parado
    act = bpy.data.actions.new("parado")
    arm.animation_data.action = act
    for f in (0, 24, 48):
        k = 0.5 - 0.5 * math.cos(math.pi * f / 24)
        pose = {n: [] for n in names if n != "root"}
        pose["thigh.L"] = [(Y, -2)]
        pose["thigh.R"] = [(Y, 2)]
        pose["upper_arm.L"] = [(Y, 4), (X, -2)]
        pose["forearm.L"] = [(X, -10)]
        pose.update(right_arm_sling(0))
        pose["chest"] = [(X, -1.2 * k)]
        pose["head"] = [(X, 3), (Z, 4 * k - 2)]
        _key(arm, f, pose)
        hb = arm.pose.bones["hips"]
        hb.location = (0, 0, 0)
        hb.keyframe_insert("location", frame=f)
    acts["parado"] = act
    for a in acts.values():
        for fc in _fcurves(a):
            for kp in fc.keyframe_points:
                kp.interpolation = "BEZIER"
        a.use_fake_user = True
    # NLA: uma faixa por ação, para o exportador levar as duas
    arm.animation_data.action = None
    for n, a in acts.items():
        tr = arm.animation_data.nla_tracks.new()
        tr.name = n
        tr.strips.new(n, 0, a)
        tr.mute = True
    return acts


def _fcurves(action):
    if hasattr(action, "fcurves"):
        return list(action.fcurves)
    out = []
    for layer in action.layers:
        for strip in layer.strips:
            for bag in strip.channelbags:
                out.extend(bag.fcurves)
    return out


# ---------------------------------------------------------------- montagem

def build():
    for ob in list(bpy.data.objects):
        bpy.data.objects.remove(ob, do_unlink=True)
    for me in list(bpy.data.meshes):
        bpy.data.meshes.remove(me)
    for a in list(bpy.data.armatures):
        bpy.data.armatures.remove(a)
    for a in list(bpy.data.actions):
        bpy.data.actions.remove(a)
    PTS.clear()
    EDGES.clear()
    _pts()
    sc = bpy.context.scene
    sc.render.fps = FPS
    arm = build_armature()
    body = build_body()
    auto_weights(arm, body)
    extras = build_tunic_extras()
    skirt = [o for o in extras if o.get("weights") == "transfer"][0]
    transfer_weights(body, skirt)
    rigid = build_head() + build_hands() + build_boots() + [o for o in extras if o is not skirt]
    body = join("soldier_body", [body, skirt] + rigid)
    bind(arm, body)
    pieces = [body]
    for k in ("stahlhelm", "m1", "brodie", "ssh40", "adrian"):
        pieces.append(bind(arm, helmet(k)))
    pieces.append(bind(arm, kit_ger()))
    pieces.append(bind(arm, rifle()))
    make_actions(arm)
    for me in list(bpy.data.meshes):
        if me.users == 0:
            bpy.data.meshes.remove(me)
    return arm, pieces


def export(path):
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=False,
                              export_animations=True, export_animation_mode="NLA_TRACKS",
                              export_skins=True, export_apply=False, export_yup=True,
                              export_cameras=False, export_lights=False)


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    arm, pieces = build()
    tris = sum(len(p.data.polygons) for p in pieces)
    print("faces:", tris, {p.name: len(p.data.polygons) for p in pieces})
    if args:
        export(args[0])
    if len(args) > 1:
        bpy.ops.wm.save_as_mainfile(filepath=args[1])
