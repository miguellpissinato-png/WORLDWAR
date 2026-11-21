"""Gera as ilustrações 2D dos itens de pesquisa em ui/research/<tech_id>.svg (330x150).

Desenhos próprios, de perfil (armas, tanques, artilharia) ou de cima (aviões), com as formas e
cores características de cada modelo. Para trocar por uma imagem de verdade, coloque um PNG com o
mesmo nome (ui/research/<tech_id>.png): o jogo usa o PNG quando ele existe.

Uso: python3 tools/data/gen_research_art.py
"""
import math
import os

W, H = 330, 150
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "ui", "research")
INK = "#15140f"

_gid = [0]


def gid(prefix="g"):
    _gid[0] += 1
    return f"{prefix}{_gid[0]}"


def grad(c1, c2, vertical=True):
    """Gradiente linear (claro em cima, escuro embaixo). Devolve (defs, url)."""
    i = gid()
    x2, y2 = ("0", "1") if vertical else ("1", "0")
    d = (f'<linearGradient id="{i}" x1="0" y1="0" x2="{x2}" y2="{y2}">'
         f'<stop offset="0" stop-color="{c1}"/><stop offset="1" stop-color="{c2}"/></linearGradient>')
    return d, f"url(#{i})"


class Art:
    def __init__(self):
        self.defs = []
        self.body = []

    def g(self, c1, c2, vertical=True):
        d, u = grad(c1, c2, vertical)
        self.defs.append(d)
        return u

    def poly(self, pts, fill, stroke=INK, sw=1.6):
        p = " ".join(f"{x:.1f},{y:.1f}" for x, y in pts)
        self.body.append(f'<polygon points="{p}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"/>')

    def path(self, d, fill="none", stroke=INK, sw=1.6, cap="round"):
        self.body.append(f'<path d="{d}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}" stroke-linecap="{cap}" stroke-linejoin="round"/>')

    def rect(self, x, y, w, h, fill, stroke=INK, sw=1.4, r=0):
        self.body.append(f'<rect x="{x:.1f}" y="{y:.1f}" width="{w:.1f}" height="{h:.1f}" rx="{r}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')

    def circle(self, cx, cy, r, fill, stroke=INK, sw=1.4):
        self.body.append(f'<circle cx="{cx:.1f}" cy="{cy:.1f}" r="{r:.1f}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"/>')

    def ellipse(self, cx, cy, rx, ry, fill, stroke=INK, sw=1.4, rot=0):
        t = f' transform="rotate({rot} {cx:.1f} {cy:.1f})"' if rot else ""
        self.body.append(f'<ellipse cx="{cx:.1f}" cy="{cy:.1f}" rx="{rx:.1f}" ry="{ry:.1f}" fill="{fill}" stroke="{stroke}" stroke-width="{sw}"{t}/>')

    def raw(self, s):
        self.body.append(s)

    def svg(self):
        return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
                f'<defs>{"".join(self.defs)}</defs>{"".join(self.body)}</svg>\n')


WOOD = ("#b9773d", "#6e3f19")
WOOD_DARK = ("#8c5426", "#4c2a10")
METAL = ("#5d6166", "#24272a")
BLUED = ("#4a4f57", "#1b1d21")


# ---------------------------------------------------------------- armas de infantaria

def rifle(kind, scope=None, mag=False, wood=WOOD, length=300, pistol=False, two_piece=False):
    a = Art()
    x0 = (W - length) / 2
    y = 70
    L = length
    wood_f = a.g(*wood)
    met = a.g(*BLUED)
    # cano saindo da frente
    a.rect(x0 + L * 0.74, y - 4, L * 0.26, 4.5, met, sw=1.2)
    a.rect(x0 + L * 0.985, y - 8, 3, 5, met, sw=1)          # massa de mira
    # coronha + guarda-mão (uma peça, ou duas na Lee-Enfield)
    wrist = (x0 + L * 0.27, y + 6)
    butt = [(x0, y - 6), (x0 + L * 0.06, y - 7), (x0 + L * 0.24, y - 2), wrist,
            (x0 + L * 0.30, y + 10 if not pistol else y + 22), (x0 + L * 0.33, y + 9),
            (x0 + L * 0.36, y + 5)]
    if pistol:
        butt[4] = (x0 + L * 0.28, y + 22)
    front_end = x0 + L * (0.80 if kind != "garand" else 0.78)
    stock = butt + [(front_end, y + 4), (front_end + 4, y), (x0 + L * 0.40, y - 1), (x0 + L * 0.33, y - 2),
                    (x0 + L * 0.06, y + 22), (x0, y + 24)]
    # contorno simples da coronha (polígono principal)
    a.poly([(x0, y - 6), (x0 + L * 0.06, y - 8), (x0 + L * 0.25, y - 2), (x0 + L * 0.30, y + 1),
            (x0 + L * 0.36, y), (front_end, y - 1), (front_end + 3, y + 3), (front_end, y + 6),
            (x0 + L * 0.40, y + 7), (x0 + L * 0.335, y + 9), (x0 + L * 0.30, y + (22 if pistol else 12)),
            (x0 + L * 0.27, y + (22 if pistol else 12)), (x0 + L * 0.25, y + 8), (x0 + L * 0.07, y + 22),
            (x0 + 2, y + 25)], wood_f)
    a.rect(x0 - 1, y - 7, 5, 33, a.g("#3a3a3a", "#151515"), sw=1)      # chapa da soleira
    # guarda-mão de cima
    if not two_piece:
        a.poly([(x0 + L * 0.47, y - 1), (front_end - 2, y - 1), (front_end - 4, y - 6), (x0 + L * 0.48, y - 6)], wood_f, sw=1.2)
    else:
        a.poly([(x0 + L * 0.45, y - 1), (x0 + L * 0.62, y - 1), (x0 + L * 0.62, y - 6), (x0 + L * 0.46, y - 6)], wood_f, sw=1.2)
        a.poly([(x0 + L * 0.64, y - 1), (front_end - 2, y - 1), (front_end - 4, y - 6), (x0 + L * 0.64, y - 6)], wood_f, sw=1.2)
    # caixa da culatra e ferrolho
    a.rect(x0 + L * 0.33, y - 8, L * 0.15, 8, met, sw=1.3)
    if kind != "garand":
        a.path(f"M{x0 + L * 0.355},{y - 4} l8,10", stroke="#2a2d31", sw=3)
        a.circle(x0 + L * 0.355 + 8, y + 7, 3.2, met, sw=1)
    else:
        a.rect(x0 + L * 0.42, y - 10, 10, 4, met, sw=1)                   # alavanca de operação
    # guarda-mato e gatilho
    a.path(f"M{x0 + L * 0.335},{y + 7} q5,9 14,1", stroke="#2a2d31", sw=2.2)
    # braçadeiras
    for t in ([0.58, 0.72] if kind != "garand" else [0.73]):
        a.rect(x0 + L * t, y - 7, 4, 14, a.g("#7a7f86", "#3a3e44"), sw=0.8)
    if mag:
        a.poly([(x0 + L * 0.37, y + 7), (x0 + L * 0.43, y + 7), (x0 + L * 0.425, y + 22), (x0 + L * 0.375, y + 22)], met, sw=1.2)
    if scope:
        a.rect(x0 + L * 0.31, y - 20, L * 0.2, 7, a.g("#2f3337", "#101214"), sw=1.2, r=3)
        a.rect(x0 + L * 0.29, y - 22, 9, 11, met, sw=1, r=2)
        a.rect(x0 + L * 0.495, y - 23, 12, 13, met, sw=1, r=2)
        a.rect(x0 + L * 0.36, y - 14, 4, 7, met, sw=1)
        a.rect(x0 + L * 0.45, y - 14, 4, 7, met, sw=1)
    return a


def mp40():
    a = Art()
    met = a.g(*BLUED)
    y = 62
    # coronha rebatível de metal (aberta)
    a.path(f"M48,{y + 2} L118,{y + 2} M48,{y + 20} L104,{y + 12}", stroke="#2b2e33", sw=4)
    a.rect(42, y - 3, 8, 28, met, sw=1.2, r=2)
    # caixa da culatra (tubo)
    a.rect(110, y - 6, 120, 15, met, sw=1.4, r=3)
    a.rect(225, y - 3, 60, 7, met, sw=1.2)                      # cano
    a.rect(232, y + 4, 18, 6, met, sw=1)                        # apoio
    a.rect(282, y - 7, 4, 6, met, sw=1)
    # empunhadura de baquelite e carregador reto
    a.poly([(150, y + 9), (170, y + 9), (164, y + 40), (148, y + 40)], a.g("#5a3a22", "#2a1a0e"), sw=1.4)
    a.poly([(186, y + 9), (200, y + 9), (198, y + 64), (186, y + 64)], met, sw=1.4)
    a.path(f"M148,{y + 12} q-2,14 10,16", stroke="#2a2d31", sw=2)
    a.rect(128, y - 9, 30, 4, met, sw=1)                         # ferrolho
    return a


def ppsh41():
    a = Art()
    met = a.g(*BLUED)
    wood_f = a.g(*WOOD)
    y = 62
    a.poly([(40, y - 4), (60, y - 6), (128, y), (128, y + 12), (118, y + 14), (110, y + 24), (98, y + 24), (92, y + 14),
            (60, y + 26), (40, y + 30)], wood_f)
    a.rect(38, y - 5, 5, 36, a.g("#3a3a3a", "#151515"), sw=1)
    a.rect(126, y - 6, 62, 16, met, sw=1.4, r=2)                 # caixa
    a.rect(186, y - 6, 92, 14, met, sw=1.4, r=2)                 # capa perfurada
    for i in range(9):
        a.ellipse(196 + i * 9, y + 1, 2.6, 4, "#0e0f11", stroke="none", sw=0)
    a.poly([(276, y - 6), (288, y - 4), (288, y + 8), (276, y + 8)], met, sw=1.2)   # quebra-chamas
    a.circle(160, y + 38, 26, a.g("#4a4f57", "#16181b"), sw=1.6)   # tambor
    a.circle(160, y + 38, 8, "#2a2d31", sw=1)
    a.path(f"M118,{y + 10} q4,10 14,4", stroke="#2a2d31", sw=2.2)
    return a


def thompson(drum=True, fins=True):
    a = Art()
    met = a.g(*BLUED)
    wood_f = a.g(*WOOD)
    y = 60
    a.poly([(36, y - 2), (56, y - 6), (118, y + 2), (118, y + 12), (56, y + 26), (36, y + 30)], wood_f)
    a.rect(34, y - 3, 5, 34, a.g("#3a3a3a", "#151515"), sw=1)
    a.rect(116, y - 8, 70, 20, met, sw=1.4, r=2)                 # caixa
    a.poly([(126, y + 12), (142, y + 12), (136, y + 42), (122, y + 42)], wood_f)   # empunhadura
    a.path(f"M122,{y + 14} q-2,12 10,14", stroke="#2a2d31", sw=2)
    if fins:
        a.rect(184, y - 6, 74, 12, met, sw=1.3)
        for i in range(10):
            a.rect(190 + i * 6.5, y - 9, 3, 18, a.g("#6b7077", "#2b2e33"), sw=0.6)
        a.rect(256, y - 7, 20, 13, met, sw=1.2)                  # compensador Cutts
        a.poly([(206, y + 6), (222, y + 6), (218, y + 34), (206, y + 34)], wood_f)   # empunhadura da frente
    else:
        a.rect(184, y - 4, 92, 8, met, sw=1.3)
        a.poly([(184, y + 4), (240, y + 4), (240, y + 13), (186, y + 13)], wood_f)    # telha horizontal
    if drum:
        a.circle(166, y + 38, 24, a.g("#4a4f57", "#16181b"), sw=1.6)
        a.circle(166, y + 38, 7, "#2a2d31", sw=1)
    else:
        a.poly([(156, y + 12), (170, y + 12), (174, y + 62), (160, y + 62)], met, sw=1.4)
    return a


# ---------------------------------------------------------------- blindados

PANZERGRAU = ("#5a5f63", "#34383b")
DUNKELGELB = ("#c9b27a", "#8d7a4c")
SOV_GREEN = ("#6a7a45", "#3c4627")
OD = ("#6c6a47", "#3d3c26")


def balken(a, x, y, s=1.0):
    a.rect(x - 9 * s, y - 2.5 * s, 18 * s, 5 * s, "#111", stroke="#eee", sw=1.4 * s)
    a.rect(x - 2.5 * s, y - 9 * s, 5 * s, 18 * s, "#111", stroke="#eee", sw=1.4 * s)


def red_star(a, x, y, r):
    pts = []
    for i in range(10):
        rr = r if i % 2 == 0 else r * 0.4
        ang = math.radians(-90 + i * 36)
        pts.append((x + rr * math.cos(ang), y + rr * math.sin(ang)))
    a.poly(pts, "#c8202a", stroke="#5a0d10", sw=1)


def white_star(a, x, y, r, ring=False):
    if ring:
        a.circle(x, y, r * 1.25, "none", stroke="#e8e8e0", sw=2)
    pts = []
    for i in range(10):
        rr = r if i % 2 == 0 else r * 0.4
        ang = math.radians(-90 + i * 36)
        pts.append((x + rr * math.cos(ang), y + rr * math.sin(ang)))
    a.poly(pts, "#e8e8e0", stroke="none", sw=0)


def tank(hull_len=200, hull_h=30, front="step", turret=(0.45, 70, 24, "box"), gun=(70, 4.5, False),
         wheels=(5, 13, "plain"), color=PANZERGRAU, mark="balken", interleaved=False, sloped_side=False):
    a = Art()
    body = a.g(*color)
    dark = a.g(color[1], "#1a1b18")
    x0 = (W - hull_len) / 2 - 10
    ground = 128
    track_h = wheels[1] * 2 + 8
    ty = ground - track_h
    # esteira
    a.rect(x0 - 6, ty, hull_len + 12, track_h, "#2a2a26", sw=1.6, r=track_h / 2)
    n, r, style = wheels
    span = hull_len - 2 * r - 10
    for i in range(n):
        cx = x0 + r + 5 + (span * i / max(1, n - 1))
        cy = ground - r - 4
        a.circle(cx, cy, r, a.g("#55574f", "#25261f"), sw=1.3)
        a.circle(cx, cy, r * 0.35, "#1c1c18", sw=1)
        if interleaved and i < n - 1:
            a.circle(cx + span / max(1, n - 1) / 2, cy - 2, r, a.g("#4b4d46", "#202119"), sw=1.2)
    a.circle(x0 + 2, ty + track_h / 2, r * 0.7, "#2f302a", sw=1.2)         # roda motriz/guia
    a.circle(x0 + hull_len - 2, ty + track_h / 2, r * 0.7, "#2f302a", sw=1.2)
    # casco
    hy = ty - hull_h + 4
    if front == "slope":
        hull = [(x0 - 4, ty + 6), (x0 - 4, hy + 8), (x0 + 8, hy), (x0 + hull_len * 0.72, hy),
                (x0 + hull_len + 10, ty - 2), (x0 + hull_len + 4, ty + 6)]
    else:
        hull = [(x0 - 4, ty + 6), (x0 - 4, hy + 4), (x0 + hull_len * 0.82, hy), (x0 + hull_len * 0.86, hy - 4),
                (x0 + hull_len + 6, hy + 6), (x0 + hull_len + 6, ty + 6)]
    a.poly(hull, body, sw=1.8)
    a.rect(x0 - 6, hy + hull_h * 0.45, hull_len + 14, 5, dark, sw=1)       # para-lama
    # torre
    tx_rel, tw, th, tshape = turret
    tx = x0 + hull_len * tx_rel
    if tshape == "round":
        tur = [(tx - tw / 2, hy), (tx - tw / 2 + 6, hy - th), (tx + tw / 2 - 2, hy - th), (tx + tw / 2 + 6, hy - th * 0.35), (tx + tw / 2, hy)]
    elif tshape == "slope":
        tur = [(tx - tw / 2, hy), (tx - tw / 2 + 4, hy - th), (tx + tw / 2 - 10, hy - th), (tx + tw / 2 + 4, hy - 2), (tx + tw / 2, hy)]
    else:
        tur = [(tx - tw / 2, hy), (tx - tw / 2, hy - th + 3), (tx - tw / 2 + 4, hy - th), (tx + tw / 2, hy - th), (tx + tw / 2 + 3, hy)]
    a.poly(tur, body, sw=1.8)
    a.rect(tx - tw / 2 + 6, hy - th - 6, 16, 7, dark, sw=1.2, r=2)          # cúpula
    glen, gr, brake = gun
    gy = hy - th * 0.55
    a.rect(tx + tw / 2, gy - gr / 2, glen, gr, a.g("#4a4d48", "#1f201c"), sw=1.2)
    a.rect(tx + tw / 2 - 2, gy - gr, 10, gr * 2, dark, sw=1)                # mantelete
    if brake:
        a.rect(tx + tw / 2 + glen - 3, gy - gr * 0.9, 9, gr * 1.8, a.g("#4a4d48", "#1f201c"), sw=1)
    # marcas
    if mark == "balken":
        balken(a, x0 + hull_len * 0.25, hy + hull_h * 0.28, 0.9)
    elif mark == "red_star":
        red_star(a, tx - 2, hy - th * 0.5, 7)
    elif mark == "us_star":
        white_star(a, x0 + hull_len * 0.25, hy + hull_h * 0.3, 8, ring=True)
    return a


# ---------------------------------------------------------------- aviação (vista de cima)

def plane(span=230, length=150, wing="taper", engines=0, color=("#4d5a3c", "#2f3925"), under=None, mark="balken",
          tail_span=70, chord=34, nose="pointed", wing_pos=0.38, silver=False):
    a = Art()
    cx = W / 2
    top = (H - length) / 2 + 2
    body = a.g(*color, vertical=False) if not silver else a.g("#d6dade", "#8f969c", vertical=False)
    wing_f = a.g(*color) if not silver else a.g("#dfe3e6", "#9aa1a7")
    wy = top + length * wing_pos
    half = span / 2
    if wing == "ellipse":
        a.path(f"M{cx - half},{wy + chord * 0.45} Q{cx - half * 0.55},{wy - chord * 0.35} {cx},{wy - chord * 0.3} "
               f"Q{cx + half * 0.55},{wy - chord * 0.35} {cx + half},{wy + chord * 0.45} "
               f"Q{cx + half * 0.6},{wy + chord * 1.05} {cx},{wy + chord * 0.95} "
               f"Q{cx - half * 0.6},{wy + chord * 1.05} {cx - half},{wy + chord * 0.45} z", fill=wing_f, sw=1.8)
    elif wing == "gull":
        a.poly([(cx - half, wy + chord * 0.2), (cx - half * 0.45, wy - chord * 0.05), (cx, wy - chord * 0.15),
                (cx + half * 0.45, wy - chord * 0.05), (cx + half, wy + chord * 0.2), (cx + half - 6, wy + chord * 0.7),
                (cx + half * 0.45, wy + chord * 0.85), (cx, wy + chord), (cx - half * 0.45, wy + chord * 0.85),
                (cx - half + 6, wy + chord * 0.7)], wing_f, sw=1.8)
    else:
        a.poly([(cx - half, wy + chord * 0.15), (cx, wy - chord * 0.1), (cx + half, wy + chord * 0.15),
                (cx + half - 4, wy + chord * 0.62), (cx, wy + chord), (cx - half + 4, wy + chord * 0.62)], wing_f, sw=1.8)
    # motores nas asas
    eng = a.g("#3b3f3a", "#1c1e1b")
    for k in range(engines):
        off = (k // 2 + 1) * (half * (0.36 if engines == 2 else 0.3)) * (1 if k % 2 == 0 else -1)
        a.rect(cx + off - 6.5, wy - chord * 0.42, 13, chord * 0.95, eng, sw=1.3, r=5)
        a.ellipse(cx + off, wy - chord * 0.46, 13, 2.4, "#888", stroke="#222", sw=0.8)
    # fuselagem
    nose_y = top
    tail_y = top + length
    fw = 15 if engines < 2 else 18
    a.path(f"M{cx},{nose_y} Q{cx + fw},{nose_y + length * 0.18} {cx + fw * 0.8},{nose_y + length * 0.45} "
           f"L{cx + 3},{tail_y} L{cx - 3},{tail_y} L{cx - fw * 0.8},{nose_y + length * 0.45} "
           f"Q{cx - fw},{nose_y + length * 0.18} {cx},{nose_y} z", fill=body, sw=1.8)
    # empenagem
    ty = tail_y - 16
    a.poly([(cx - tail_span / 2, ty + 4), (cx, ty - 6), (cx + tail_span / 2, ty + 4), (cx + tail_span / 2 - 4, ty + 14),
            (cx, ty + 16), (cx - tail_span / 2 + 4, ty + 14)], wing_f, sw=1.6)
    # cabine
    if engines >= 2 and nose == "glass":
        a.ellipse(cx, nose_y + 14, 9, 14, a.g("#bcd6e6", "#5d7f95"), sw=1.2)
    else:
        a.ellipse(cx, wy - chord * 0.05, 5.5, 13, a.g("#bcd6e6", "#5d7f95"), sw=1.2)
    if engines == 0:
        a.ellipse(cx, nose_y + 2, 16, 2.6, "#999", stroke="#333", sw=0.8)       # hélice
        a.circle(cx, nose_y + 3, 3, "#222", sw=0.8)
    # marcas nas asas
    for side in (-1, 1):
        mx = cx + side * half * 0.62
        my = wy + chord * 0.38
        if mark == "balken":
            balken(a, mx, my, 0.75)
        elif mark == "raf":
            a.circle(mx, my, 9, "#1f3a8a", stroke="#111", sw=0.8)
            a.circle(mx, my, 3.8, "#b5202a", stroke="none", sw=0)
        elif mark == "us":
            a.circle(mx, my, 9, "#1f3a6a", stroke="#111", sw=0.8)
            white_star(a, mx, my, 8)
        elif mark == "jp":
            a.circle(mx, my, 8, "#c4161c", stroke="#fff", sw=1.5)
        elif mark == "red_star":
            red_star(a, mx, my, 9)
    return a


# ---------------------------------------------------------------- artilharia

def howitzer(barrel=150, cal=9.0, wheel_r=24, color=PANZERGRAU, shield=True, brake=False, spoked=False, elev=14):
    a = Art()
    body = a.g(*color)
    gx, gy = 150, 92
    ang = math.radians(-elev)
    dx, dy = math.cos(ang), math.sin(ang)
    # flechas da carreta (abertas para trás)
    a.poly([(gx - 8, gy + 2), (gx - 120, gy + 34), (gx - 124, gy + 28), (gx - 4, gy - 6)], body, sw=1.6)
    a.rect(gx - 130, gy + 26, 14, 10, a.g("#3b3d38", "#1c1d1a"), sw=1.2)
    # berço e tubo
    def seg(p0, length, w):
        px, py = -dy * w / 2, dx * w / 2
        p1 = (p0[0] + dx * length, p0[1] + dy * length)
        return [(p0[0] + px, p0[1] + py), (p1[0] + px, p1[1] + py), (p1[0] - px, p1[1] - py), (p0[0] - px, p0[1] - py)]
    a.poly(seg((gx - 30, gy - 8), 70, cal * 2.2), body, sw=1.6)
    a.poly(seg((gx - 10, gy - 12), barrel, cal), a.g("#4c4f4b", "#20221f"), sw=1.5)
    if brake:
        tip = (gx - 10 + dx * barrel, gy - 12 + dy * barrel)
        a.poly(seg((tip[0] - dx * 4, tip[1] - dy * 4), 14, cal * 1.7), a.g("#4c4f4b", "#20221f"), sw=1.2)
    if shield:
        a.poly([(gx + 4, gy - 40), (gx + 14, gy - 42), (gx + 18, gy + 12), (gx + 6, gy + 14)], body, sw=1.6)
    # roda
    wy = 132 - wheel_r
    a.circle(gx, wy, wheel_r, "#262622", sw=1.8)
    a.circle(gx, wy, wheel_r * 0.72, a.g("#4b4d47", "#23241f") if not spoked else "#5a4a30", sw=1.3)
    if spoked:
        for k in range(10):
            t = math.radians(k * 36)
            a.path(f"M{gx},{wy} L{gx + math.cos(t) * wheel_r * 0.72:.1f},{wy + math.sin(t) * wheel_r * 0.72:.1f}", stroke="#2b2418", sw=2)
    a.circle(gx, wy, wheel_r * 0.22, "#1b1b18", sw=1)
    return a


# ---------------------------------------------------------------- tropas (insígnias)

def badge(symbol, ring="#c9b37a", fill=("#4f5b3a", "#27301c")):
    a = Art()
    cx, cy, r = W / 2, H / 2, 62
    a.circle(cx, cy, r + 5, a.g("#e2cf98", "#8f7a45"), sw=1.6)
    a.circle(cx, cy, r, a.g(*fill), stroke=ring, sw=2)
    s = "#eadfbe"
    if symbol == "infantaria":
        a.path(f"M{cx - 34},{cy + 30} L{cx + 34},{cy - 30} M{cx + 34},{cy + 30} L{cx - 34},{cy - 30}", stroke=s, sw=6)
        a.path(f"M{cx - 30},{cy + 8} a30,22 0 0 1 60,0 z", fill="#3c4a2c", stroke=s, sw=3)
        a.rect(cx - 38, cy + 6, 76, 6, s, stroke="none", sw=0)
    elif symbol == "artilharia":
        a.path(f"M{cx - 38},{cy + 14} L{cx + 40},{cy - 22}", stroke=s, sw=11)
        a.circle(cx - 6, cy + 18, 18, "none", stroke=s, sw=5)
        a.path(f"M{cx - 44},{cy + 34} L{cx + 26},{cy + 34}", stroke=s, sw=5)
    elif symbol == "tanquistas":
        a.rect(cx - 40, cy + 4, 80, 20, "none", stroke=s, sw=4, r=10)
        a.path(f"M{cx - 30},{cy + 4} L{cx - 24},{cy - 10} L{cx + 24},{cy - 10} L{cx + 30},{cy + 4}", fill="none", stroke=s, sw=4)
        a.rect(cx - 14, cy - 24, 28, 14, "none", stroke=s, sw=4, r=3)
        a.path(f"M{cx + 14},{cy - 18} L{cx + 44},{cy - 18}", stroke=s, sw=4)
    elif symbol == "atiradores":
        a.circle(cx, cy, 34, "none", stroke=s, sw=4)
        a.circle(cx, cy, 6, s, stroke="none", sw=0)
        a.path(f"M{cx - 44},{cy} h28 M{cx + 16},{cy} h28 M{cx},{cy - 44} v28 M{cx},{cy + 16} v28", stroke=s, sw=4)
    elif symbol == "choque":
        a.poly([(cx + 10, cy - 46), (cx - 22, cy + 6), (cx - 2, cy + 6), (cx - 12, cy + 46), (cx + 24, cy - 8), (cx + 2, cy - 8)], s, stroke="none", sw=0)
    elif symbol == "paraquedistas":
        a.path(f"M{cx - 40},{cy - 6} a40,34 0 0 1 80,0 q-20,-10 -40,0 q-20,-10 -40,0 z", fill=s, stroke=s, sw=2)
        a.path(f"M{cx - 40},{cy - 6} L{cx},{cy + 34} L{cx + 40},{cy - 6} M{cx},{cy - 6} L{cx},{cy + 34}", stroke=s, sw=2.5)
        a.circle(cx, cy + 38, 6, s, stroke="none", sw=0)
    elif symbol == "desembarque":
        a.circle(cx, cy - 34, 8, "none", stroke=s, sw=4)
        a.path(f"M{cx},{cy - 26} V{cy + 40} M{cx - 20},{cy - 12} H{cx + 20} "
               f"M{cx - 38},{cy + 14} q6,30 38,26 q32,4 38,-26", stroke=s, sw=5)
    elif symbol == "anfibio":
        a.poly([(cx - 46, cy - 6), (cx + 30, cy - 6), (cx + 46, cy + 8), (cx + 30, cy + 20), (cx - 40, cy + 20)], "none", stroke=s, sw=4)
        a.rect(cx + 10, cy - 22, 18, 16, "none", stroke=s, sw=4)
        a.path(f"M{cx - 50},{cy + 34} q12,-10 24,0 t24,0 t24,0 t24,0", stroke=s, sw=4)
    return a


# ---------------------------------------------------------------- catálogo

ART = {
    # armas
    "tech_kar98k": lambda: rifle("kar"),
    "tech_kar98k_zf39": lambda: rifle("kar", scope=True),
    "tech_mosin_9130": lambda: rifle("mosin", wood=("#a5683a", "#5b3416"), length=310),
    "tech_mosin_pu": lambda: rifle("mosin", wood=("#a5683a", "#5b3416"), length=310, scope=True),
    "tech_m1_garand": lambda: rifle("garand", wood=("#b07a4a", "#6a4220"), length=292),
    "tech_m1903a4": lambda: rifle("kar", wood=("#b98256", "#6f4826"), scope=True, length=296, pistol=True),
    "tech_lee_enfield_no4": lambda: rifle("enfield", mag=True, two_piece=True, wood=("#a86e3c", "#5f3a18"), length=290),
    "tech_mp40": mp40,
    "tech_ppsh41": ppsh41,
    "tech_thompson_m1928a1": lambda: thompson(drum=True, fins=True),
    "tech_thompson_m1a1": lambda: thompson(drum=False, fins=False),
    # blindados
    "tech_panzer_ii": lambda: tank(170, 26, "step", (0.42, 52, 20, "box"), (34, 3.5, False), (5, 12, "plain")),
    "tech_panzer_iii_j": lambda: tank(190, 30, "step", (0.45, 64, 24, "box"), (58, 4.5, False), (6, 12, "plain")),
    "tech_panzer_iv_f2": lambda: tank(205, 30, "step", (0.44, 68, 25, "box"), (92, 4.8, True), (8, 9, "plain")),
    "tech_panzer_iv_h": lambda: tank(205, 30, "step", (0.44, 68, 25, "box"), (104, 4.8, True), (8, 9, "plain"), color=DUNKELGELB),
    "tech_panther": lambda: tank(215, 30, "slope", (0.47, 70, 26, "slope"), (112, 5.0, True), (8, 15, "plain"), color=DUNKELGELB, interleaved=True),
    "tech_tiger_i": lambda: tank(215, 34, "step", (0.47, 78, 28, "box"), (104, 6.0, True), (8, 15, "plain"), color=DUNKELGELB, interleaved=True),
    "tech_tiger_ii": lambda: tank(228, 32, "slope", (0.47, 84, 28, "slope"), (128, 6.0, True), (9, 14, "plain"), color=DUNKELGELB, interleaved=True),
    "tech_t26": lambda: tank(168, 26, "step", (0.38, 56, 22, "round"), (46, 3.8, False), (8, 7, "plain"), color=SOV_GREEN, mark="red_star"),
    "tech_bt7": lambda: tank(190, 26, "slope", (0.36, 60, 22, "round"), (50, 3.8, False), (4, 18, "plain"), color=SOV_GREEN, mark="red_star"),
    "tech_t34_76": lambda: tank(205, 30, "slope", (0.36, 66, 24, "slope"), (70, 5.0, False), (5, 17, "plain"), color=SOV_GREEN, mark="red_star"),
    "tech_m4_sherman": lambda: tank(200, 38, "slope", (0.47, 66, 28, "round"), (62, 5.0, False), (6, 11, "plain"), color=OD, mark="us_star"),
    # aviação
    "tech_bf109e": lambda: plane(210, 140, "taper", 0, ("#4b5a3a", "#2b3523"), mark="balken"),
    "tech_fw190a8": lambda: plane(220, 136, "taper", 0, ("#5d6758", "#343c31"), mark="balken", nose="round"),
    "tech_hurricane_i": lambda: plane(240, 142, "taper", 0, ("#6b5a3a", "#3f4a2e"), mark="raf"),
    "tech_spitfire_i": lambda: plane(236, 140, "ellipse", 0, ("#6f5d3c", "#3e4b2d"), mark="raf"),
    "tech_p51d": lambda: plane(232, 146, "taper", 0, mark="us", silver=True),
    "tech_a6m2": lambda: plane(250, 138, "taper", 0, ("#b8b79a", "#8a8a6f"), mark="jp", chord=36),
    "tech_yak1": lambda: plane(220, 142, "taper", 0, ("#5a6a3c", "#2f3a22"), mark="red_star"),
    "tech_ju87": lambda: plane(250, 136, "gull", 0, ("#4b5a3a", "#2b3523"), mark="balken", chord=40),
    "tech_il2": lambda: plane(256, 146, "taper", 0, ("#5f6d3a", "#333d1f"), mark="red_star", chord=40),
    "tech_he111": lambda: plane(290, 136, "taper", 2, ("#4b5a3a", "#2b3523"), mark="balken", nose="glass", chord=44, wing_pos=0.32),
    "tech_ju88": lambda: plane(270, 134, "taper", 2, ("#4b5a3a", "#2b3523"), mark="balken", nose="glass", chord=38, wing_pos=0.32),
    "tech_b17": lambda: plane(310, 136, "taper", 4, ("#6c6a47", "#3d3c26"), mark="us", nose="glass", chord=44, tail_span=90, wing_pos=0.3),
    "tech_lancaster": lambda: plane(310, 132, "taper", 4, ("#5b4e33", "#2f3a24"), mark="raf", nose="glass", chord=40, tail_span=84, wing_pos=0.3),
    # artilharia
    "tech_lefh18": lambda: howitzer(130, 8.5, 24, PANZERGRAU, shield=True, spoked=False),
    "tech_sfh18": lambda: howitzer(170, 11.0, 27, PANZERGRAU, shield=False, spoked=False, elev=18),
    "tech_m2a1_105": lambda: howitzer(135, 8.5, 22, OD, shield=True),
    "tech_qf25pdr": lambda: howitzer(120, 8.0, 24, ("#5e6a46", "#333b26"), shield=True, brake=True),
    "tech_zis3": lambda: howitzer(160, 6.5, 22, SOV_GREEN, shield=True, brake=True, elev=8),
    "tech_m30_122": lambda: howitzer(150, 10.0, 24, SOV_GREEN, shield=True, elev=16),
    # tropas
    "t_infantaria": lambda: badge("infantaria"),
    "t_artilharia": lambda: badge("artilharia"),
    "t_tanquistas": lambda: badge("tanquistas", fill=("#3d3f42", "#1d1f22")),
    "t_atiradores": lambda: badge("atiradores"),
    "t_choque": lambda: badge("choque", fill=("#5a2a22", "#2a1410")),
    "t_paraquedistas": lambda: badge("paraquedistas", fill=("#3a4a6a", "#1a2236")),
    "t_desembarque": lambda: badge("desembarque", fill=("#2a4a5e", "#12222e")),
    "t_assalto_anfibio": lambda: badge("anfibio", fill=("#2a4a5e", "#12222e")),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    for tid, make in ART.items():
        with open(os.path.join(OUT, tid + ".svg"), "w", encoding="utf-8") as f:
            f.write(make().svg())
    print(len(ART), "ilustrações")


if __name__ == "__main__":
    main()
