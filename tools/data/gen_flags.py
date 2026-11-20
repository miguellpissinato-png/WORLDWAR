"""Gera as bandeiras de 1936 em ui/flags/<TAG>.svg (3:2, 300x200).

Desenhos próprios, feitos a partir da descrição histórica de cada bandeira em 1º/01/1936
(fontes em docs/fontes-bandeiras.md). Brasões e emblemas complexos são simplificados para
ficarem legíveis em tamanho pequeno; esses países estão marcados em SIMPLIFICADAS.

Alemanha: por causa da Lei 7.716/89 (Brasil), o jogo usa a bandeira preto-branco-vermelho,
oficial ao lado da outra até setembro de 1935, e não a bandeira com a suástica.

Uso: python3 tools/data/gen_flags.py
"""
import math
import os

W, H = 300, 200
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "ui", "flags")

RED = "#ce1126"
WHITE = "#ffffff"


def rect(x, y, w, h, c):
    return f'<rect x="{x:.2f}" y="{y:.2f}" width="{w:.2f}" height="{h:.2f}" fill="{c}"/>'


def circle(cx, cy, r, c, stroke=None, sw=0):
    s = f' stroke="{stroke}" stroke-width="{sw}"' if stroke else ""
    return f'<circle cx="{cx:.2f}" cy="{cy:.2f}" r="{r:.2f}" fill="{c}"{s}/>'


def poly(pts, c, stroke=None, sw=0):
    s = f' stroke="{stroke}" stroke-width="{sw}" stroke-linejoin="round"' if stroke else ""
    p = " ".join(f"{x:.2f},{y:.2f}" for x, y in pts)
    return f'<polygon points="{p}" fill="{c}"{s}/>'


def path(d, c="none", stroke=None, sw=0, extra=""):
    s = f' stroke="{stroke}" stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round"' if stroke else ""
    return f'<path d="{d}" fill="{c}"{s}{extra}/>'


def star_pts(cx, cy, r, n=5, inner=0.382, rot=-90.0):
    pts = []
    for i in range(n * 2):
        rr = r if i % 2 == 0 else r * inner
        a = math.radians(rot + i * 180.0 / n)
        pts.append((cx + rr * math.cos(a), cy + rr * math.sin(a)))
    return pts


def star(cx, cy, r, c, n=5, inner=0.382, rot=-90.0, stroke=None, sw=0):
    return poly(star_pts(cx, cy, r, n, inner, rot), c, stroke, sw)


def hstripes(colors, weights=None):
    weights = weights or [1] * len(colors)
    tot = sum(weights)
    y = 0.0
    out = []
    for c, w in zip(colors, weights):
        h = H * w / tot
        out.append(rect(0, y, W, h + 0.5, c))
        y += h
    return "".join(out)


def vstripes(colors, weights=None):
    weights = weights or [1] * len(colors)
    tot = sum(weights)
    x = 0.0
    out = []
    for c, w in zip(colors, weights):
        ww = W * w / tot
        out.append(rect(x, 0, ww + 0.5, H, c))
        x += ww
    return "".join(out)


def nordic(bg, cross, inner=None, cx=105.0, wbar=40.0, ibar=None):
    out = rect(0, 0, W, H, bg) + rect(cx - wbar / 2, 0, wbar, H, cross) + rect(0, H / 2 - wbar / 2, W, wbar, cross)
    if inner:
        ib = ibar or wbar / 2
        out += rect(cx - ib / 2, 0, ib, H, inner) + rect(0, H / 2 - ib / 2, W, ib, inner)
    return out


def union_jack(w=W, h=H, uid="u"):
    """Union Jack desenhada em 60x30 e esticada para w x h."""
    sx, sy = w / 60.0, h / 30.0
    return (f'<defs><clipPath id="{uid}t"><path d="M30,15 h30 v15 z v15 h-30 z h-30 v-15 z v-15 h30 z"/></clipPath>'
            f'<clipPath id="{uid}s"><rect width="60" height="30"/></clipPath></defs>'
            f'<g transform="scale({sx:.4f},{sy:.4f})" clip-path="url(#{uid}s)">'
            '<rect width="60" height="30" fill="#012169"/>'
            '<path d="M0,0 L60,30 M60,0 L0,30" stroke="#fff" stroke-width="6"/>'
            f'<path d="M0,0 L60,30 M60,0 L0,30" clip-path="url(#{uid}t)" stroke="#C8102E" stroke-width="4"/>'
            '<path d="M30,0 v30 M0,15 h60" stroke="#fff" stroke-width="10"/>'
            '<path d="M30,0 v30 M0,15 h60" stroke="#C8102E" stroke-width="6"/></g>')


def ensign(bg, fly):
    return rect(0, 0, W, H, bg) + union_jack(150, 100) + fly


def sun(cx, cy, r, color, rays=16, face_color=None):
    out = star(cx, cy, r, color, n=rays, inner=0.62, rot=-90)
    out += circle(cx, cy, r * 0.5, color)
    if face_color:
        out += circle(cx, cy, r * 0.5, color, face_color, 1.5)
    return out


def shield(cx, cy, w, h, fill, stroke=None, sw=0):
    x0, y0 = cx - w / 2, cy - h / 2
    d = f"M{x0},{y0} h{w} v{h * 0.55} q0,{h * 0.35} {-w / 2},{h * 0.45} q{-w / 2},{-h * 0.1} {-w / 2},{-h * 0.45} z"
    return path(d, fill, stroke, sw)


def wreath(cx, cy, r, color="#4a7a2c", sw=5):
    """Dois ramos subindo dos lados, abertos em cima (louros dos brasões)."""
    a = math.radians(222)
    b = math.radians(-42)
    left = f"M{cx - 4},{cy + r} A{r},{r} 0 0 1 {cx + r * math.cos(a):.1f},{cy + r * math.sin(a):.1f}"
    right = f"M{cx + 4},{cy + r} A{r},{r} 0 0 0 {cx + r * math.cos(b):.1f},{cy + r * math.sin(b):.1f}"
    return path(left, "none", color, sw) + path(right, "none", color, sw)


SIMPLIFICADAS = set()


def S(tag):
    SIMPLIFICADAS.add(tag)


FLAGS = {}

# ---------------------------------------------------------------- grandes potências
FLAGS["ALE"] = hstripes(["#000000", WHITE, "#dd0000"])
S("URS")
FLAGS["URS"] = (rect(0, 0, W, H, "#cc0000")
                + star(60, 30, 13, "none", stroke="#ffd700", sw=2.5)
                + path("M44,74 A22,22 0 1 0 78,52", "none", "#ffd700", 7)      # foice
                + path("M48,52 L78,82", "none", "#ffd700", 7)                     # cabo do martelo
                + poly([(42, 50), (54, 38), (60, 44), (48, 56)], "#ffd700"))      # cabeça do martelo
us = "".join(rect(0, i * H / 13, W, H / 13 + 0.3, "#b22234" if i % 2 == 0 else WHITE) for i in range(13))
us += rect(0, 0, 120, H * 7 / 13, "#3c3b6e")
for r in range(6):
    for c in range(8):
        us += star(9 + c * 14.6, 10 + r * 17.5, 4.6, WHITE)
FLAGS["EUA"] = us
FLAGS["RUN"] = union_jack()
FLAGS["FRA"] = vstripes(["#002395", WHITE, "#ed2939"])
S("ITA")
FLAGS["ITA"] = (vstripes(["#009246", WHITE, "#ce2b37"])
                + shield(150, 100, 40, 52, "#ce2b37", "#0f47af", 4)
                + rect(146, 80, 8, 42, WHITE) + rect(134, 92, 32, 8, WHITE))
FLAGS["JAP"] = rect(0, 0, W, H, WHITE) + circle(150, 100, 60, "#bc002d")
S("BRA")
bra = rect(0, 0, W, H, "#009c3b") + poly([(25, 100), (150, 17), (275, 100), (150, 183)], "#ffdf00")
bra += circle(150, 100, 52, "#002776")
bra += path("M101,88 Q150,72 199,104", "none", WHITE, 8)
for x, y in [(120, 110), (132, 124), (150, 132), (168, 122), (178, 112), (140, 108), (160, 110), (150, 145), (128, 138), (172, 136), (115, 96), (186, 96)]:
    bra += star(x, y, 3.2, WHITE)
FLAGS["BRA"] = bra
S("CHI")
FLAGS["CHI"] = (rect(0, 0, W, H, "#fe0000") + rect(0, 0, 150, 100, "#000095")
                + star(75, 50, 36, WHITE, n=12, inner=0.55) + circle(75, 50, 19, "#000095") + circle(75, 50, 16, WHITE))

# ---------------------------------------------------------------- Ásia
FLAGS["MAN"] = (rect(0, 0, W, H, "#ffd700") + rect(0, 0, 100, 16.67, "#ff0000") + rect(0, 16.67, 100, 16.67, "#0000ff")
                + rect(0, 33.33, 100, 16.67, WHITE) + rect(0, 50, 100, 16.67, "#000000"))
S("MON")
gold = "#f9cf02"
FLAGS["MON"] = (rect(0, 0, W, H, "#c4272f")
                + poly([(150, 38), (158, 54), (142, 54)], gold)      # chama
                + circle(150, 64, 8, gold)                            # sol
                + path("M138,74 A12,8 0 0 0 162,74", gold)            # lua
                + poly([(140, 86), (160, 86), (150, 96)], gold)
                + rect(132, 84, 6, 60, gold) + rect(162, 84, 6, 60, gold)
                + circle(150, 116, 11, gold) + circle(150, 116, 5, "#c4272f")
                + poly([(140, 136), (160, 136), (150, 146)], gold))
S("TUV")
FLAGS["TUV"] = (rect(0, 0, W, H, "#d21f26") + circle(150, 92, 36, "#f6c400") + circle(150, 92, 28, "#d21f26")
                + star(150, 92, 22, "#f6c400") + rect(110, 140, 80, 6, "#f6c400"))
S("TIB")
tib = rect(0, 0, W, H, "#ffd200")
cx, cy = 150, 128
rays = ""
for i in range(12):
    a0 = math.radians(-180 + i * 15)
    a1 = math.radians(-180 + (i + 1) * 15)
    col = "#c21a1e" if i % 2 == 0 else "#002b80"
    rays += poly([(cx, cy), (cx + 400 * math.cos(a0), cy + 400 * math.sin(a0)), (cx + 400 * math.cos(a1), cy + 400 * math.sin(a1))], col)
tib += f'<g><clipPath id="tb"><rect x="10" y="10" width="280" height="190"/></clipPath><g clip-path="url(#tb)">{rays}</g></g>'
tib += poly([(70, 200), (150, 112), (230, 200)], WHITE) + circle(cx, 104, 18, "#ffd200") + rect(0, 190, W, 10, "#ffd200")
FLAGS["TIB"] = tib
FLAGS["SIA"] = hstripes(["#a51931", WHITE, "#2d2a4a", WHITE, "#a51931"], [1, 1, 2, 1, 1])
S("IRA")
FLAGS["IRA"] = hstripes(["#239f40", WHITE, "#da0000"]) + sun(160, 92, 18, "#e8a317") + poly([(120, 112), (176, 112), (172, 102), (128, 102)], "#e8a317")
S("AFE")
FLAGS["AFE"] = (vstripes(["#000000", "#d32011", "#007a36"])
                + circle(150, 100, 36, "none", WHITE, 5) + path("M134,112 v-14 a16,16 0 0 1 32,0 v14 z", WHITE))
FLAGS["IRQ"] = (hstripes(["#000000", WHITE, "#007a3d"]) + poly([(0, 0), (90, 66.7), (90, 133.3), (0, 200)], "#ce1126")
                + star(36, 80, 13, WHITE, n=7, inner=0.5) + star(36, 120, 13, WHITE, n=7, inner=0.5))
S("ARS")
FLAGS["ARS"] = (rect(0, 0, W, H, "#006c35") + rect(0, 0, 28, H, WHITE)
                + path("M70,70 q20,-14 40,0 t40,0 t40,0 t40,0", "none", WHITE, 7)
                + path("M80,96 q16,-10 32,0 t32,0 t32,0 t32,0", "none", WHITE, 6)
                + path("M80,140 L240,140 q14,0 22,-10", "none", WHITE, 7) + rect(232, 131, 6, 18, WHITE))
S("IEM")
iem = rect(0, 0, W, H, "#ce1126") + path("M70,118 L222,82", "none", WHITE, 9) + rect(78, 104, 12, 28, WHITE)
for x, y in [(110, 60), (190, 50), (240, 112), (120, 160), (205, 150)]:
    iem += star(x, y, 13, WHITE)
FLAGS["IEM"] = iem
FLAGS["OMA"] = rect(0, 0, W, H, "#c8102e")
S("NEP")
nep_out = [(60, 6), (230, 96), (122, 96), (230, 194), (60, 194)]
FLAGS["NEP"] = (poly(nep_out, "#dc143c", "#003893", 10)
                + path("M84,62 a18,18 0 0 0 36,0 a18,12 0 0 1 -36,0 z", WHITE) + star(102, 58, 9, WHITE, n=8, inner=0.6)
                + star(100, 152, 20, WHITE, n=12, inner=0.6) + circle(100, 152, 11, WHITE))
S("BUT")
FLAGS["BUT"] = (poly([(0, 0), (W, 0), (0, H)], "#ffd520") + poly([(W, 0), (W, H), (0, H)], "#ff4e12")
                + path("M70,150 q30,-40 70,-30 t70,-40 t40,-20", "none", WHITE, 16) + circle(232, 58, 9, WHITE))
FLAGS["TUR"] = (rect(0, 0, W, H, "#e30a17") + circle(112, 100, 50, WHITE) + circle(125, 100, 40, "#e30a17")
                + star(172, 100, 25, WHITE, rot=180))
S("IND")
FLAGS["IND"] = ensign("#c8102e", circle(225, 112, 32, "#e5b33a") + circle(225, 112, 26, "#c8102e") + star(225, 112, 20, WHITE))
FLAGS["EGI"] = (rect(0, 0, W, H, "#0c8f3c") + circle(150, 100, 60, WHITE) + circle(168, 100, 50, "#0c8f3c")
                + star(150, 66, 12, WHITE, rot=-90) + star(172, 100, 12, WHITE, rot=180) + star(150, 134, 12, WHITE, rot=90))
FLAGS["ETI"] = hstripes(["#078930", "#fcdd09", "#da121a"])

# ---------------------------------------------------------------- África, Américas britânicas, Oceania
lib = "".join(rect(0, i * H / 11, W, H / 11 + 0.3, "#bf0a30" if i % 2 == 0 else WHITE) for i in range(11))
lib += rect(0, 0, H * 5 / 11, H * 5 / 11, "#002868") + star(H * 5 / 22, H * 5 / 22, 32, WHITE)
FLAGS["LIB"] = lib
S("AFS")
FLAGS["AFS"] = (hstripes(["#ff7f00", WHITE, "#00247d"])
                + f'<g transform="translate(96,80)">{union_jack(40, 40, "a")}</g>'
                + rect(140, 80, 20, 40, "#ff7f00") + rect(140, 88, 20, 8, WHITE) + rect(140, 104, 20, 8, WHITE)
                + rect(164, 80, 40, 13.3, "#ae1c28") + rect(164, 93.3, 40, 13.3, WHITE) + rect(164, 106.6, 40, 13.4, "#21468b")
                + rect(164, 80, 10, 40, "#007a3d"))
S("CAN")
FLAGS["CAN"] = ensign("#d52b1e", shield(222, 112, 44, 58, WHITE) + rect(200, 83, 44, 14, "#d52b1e")
                      + poly([(222, 106), (230, 122), (222, 136), (214, 122)], "#2e7d32"))
aus = ensign("#012169", star(75, 150, 24, WHITE, n=7, inner=0.45))
for x, y, r in [(225, 40, 12), (195, 92, 12), (258, 84, 12), (225, 168, 12), (240, 118, 7)]:
    aus += star(x, y, r, WHITE, n=7 if r > 8 else 5, inner=0.45)
FLAGS["AUS"] = aus
nze = ensign("#012169", "")
for x, y, r in [(225, 42, 13), (195, 96, 12), (255, 86, 12), (225, 166, 14)]:
    nze += star(x, y, r + 3, WHITE) + star(x, y, r, "#c8102e")
FLAGS["NZE"] = nze

# ---------------------------------------------------------------- Europa
FLAGS["IRL"] = vstripes(["#169b62", WHITE, "#ff883e"])
FLAGS["ISL"] = nordic("#02529c", WHITE, "#dc1e35", cx=105, wbar=44, ibar=22)
FLAGS["ESP"] = hstripes(["#da121a", "#f1bf00", "#6c2c74"])
S("POR")
FLAGS["POR"] = (vstripes(["#006600", "#ff0000"], [2, 3]) + circle(120, 100, 40, "none", "#ffcc00", 8)
                + shield(120, 100, 36, 44, WHITE, "#ff0000", 6) + circle(120, 96, 6, "#003399"))
FLAGS["POL"] = hstripes([WHITE, "#dc143c"])
FLAGS["TCH"] = hstripes([WHITE, "#d7141a"]) + poly([(0, 0), (150, 100), (0, 200)], "#11457e")
FLAGS["AUT"] = hstripes(["#ed2939", WHITE, "#ed2939"])
S("HUN")
FLAGS["HUN"] = (hstripes(["#ce2939", WHITE, "#477050"]) + shield(150, 104, 30, 38, "#ce2939", "#e5b33a", 2)
                + rect(138, 84, 12, 30, WHITE) + poly([(138, 80), (162, 80), (158, 70), (150, 74), (142, 70)], "#e5b33a"))
FLAGS["ROM"] = vstripes(["#002b7f", "#fcd116", "#ce1126"])
FLAGS["IUG"] = hstripes(["#003893", WHITE, "#de0000"])
FLAGS["BUL"] = hstripes([WHITE, "#00966e", "#d62612"])
FLAGS["GRE"] = rect(0, 0, W, H, "#0d5eaf") + rect(130, 0, 40, H, WHITE) + rect(0, 80, W, 40, WHITE)
S("ALB")
FLAGS["ALB"] = (rect(0, 0, W, H, "#e41e20")
                + poly([(150, 70), (164, 56), (190, 46), (176, 66), (204, 62), (186, 82), (210, 86), (184, 100), (196, 116),
                        (170, 112), (166, 140), (150, 152), (134, 140), (130, 112), (104, 116), (116, 100), (90, 86),
                        (114, 82), (96, 62), (124, 66), (110, 46), (136, 56)], "#000000")
                + rect(140, 40, 20, 16, "#000000") + poly([(136, 40), (164, 40), (158, 30), (142, 30)], "#e5b33a"))
FLAGS["SUE"] = nordic("#006aa7", "#fecc02", cx=110, wbar=40)
FLAGS["NOR"] = nordic("#ba0c2f", WHITE, "#00205b", cx=110, wbar=46, ibar=23)
FLAGS["DIN"] = nordic("#c8102e", WHITE, cx=110, wbar=34)
FLAGS["FIN"] = nordic(WHITE, "#002f6c", cx=110, wbar=50)
FLAGS["EST"] = hstripes(["#0072ce", "#000000", WHITE])
FLAGS["LET"] = hstripes(["#9e3039", WHITE, "#9e3039"], [2, 1, 2])
FLAGS["LIT"] = hstripes(["#fdb913", "#006a44", "#c1272d"])
FLAGS["BEL"] = vstripes(["#000000", "#fdda24", "#ef3340"])
FLAGS["HOL"] = hstripes(["#ae1c28", WHITE, "#21468b"])
FLAGS["LUX"] = hstripes(["#ed2939", WHITE, "#00a1de"])
FLAGS["SUI"] = rect(0, 0, W, H, "#d52b1e") + rect(135, 45, 30, 110, WHITE) + rect(95, 85, 110, 30, WHITE)

# ---------------------------------------------------------------- América Latina
S("MEX")
FLAGS["MEX"] = (vstripes(["#006847", WHITE, "#ce1126"]) + wreath(150, 104, 30)
                + poly([(150, 74), (166, 84), (172, 104), (160, 118), (140, 118), (128, 104), (134, 84)], "#7a4a1e")
                + poly([(150, 74), (170, 60), (164, 82)], "#7a4a1e"))
S("GUA")
FLAGS["GUA"] = vstripes(["#4997d0", WHITE, "#4997d0"]) + wreath(150, 100, 30) + rect(136, 92, 28, 16, "#e5d8a6")
FLAGS["HON"] = hstripes(["#0073cf", WHITE, "#0073cf"]) + "".join(
    star(x, y, 9, "#0073cf") for x, y in [(122, 86), (178, 86), (150, 100), (122, 114), (178, 114)])
S("ELS")
FLAGS["ELS"] = hstripes(["#0047ab", WHITE, "#0047ab"]) + wreath(150, 100, 26) + poly([(134, 110), (166, 110), (150, 84)], "#0047ab")
S("NIC")
FLAGS["NIC"] = (hstripes(["#0067c6", WHITE, "#0067c6"]) + circle(150, 100, 26, "none", "#c9a227", 3)
                + poly([(132, 110), (168, 110), (150, 80)], "none", "#0067c6", 3))
S("CRI")
FLAGS["CRI"] = (hstripes(["#002b7f", WHITE, "#ce1126", WHITE, "#002b7f"], [1, 1, 2, 1, 1])
                + f'<ellipse cx="96" cy="100" rx="22" ry="24" fill="{WHITE}"/>' + circle(96, 100, 12, "#2e7d32"))
FLAGS["PAN"] = (rect(0, 0, 150, 100, WHITE) + rect(150, 0, 150, 100, "#d21034") + rect(0, 100, 150, 100, "#005293")
                + rect(150, 100, 150, 100, WHITE) + star(75, 50, 26, "#005293") + star(225, 150, 26, "#d21034"))
FLAGS["CUB"] = (hstripes(["#002a8f", WHITE, "#002a8f", WHITE, "#002a8f"]) + poly([(0, 0), (173, 100), (0, 200)], "#cf142b")
                + star(58, 100, 28, WHITE))
S("HAI")
FLAGS["HAI"] = hstripes(["#00209f", "#d21034"]) + rect(118, 76, 64, 48, WHITE) + wreath(150, 104, 14, "#2e7d32", 3) + rect(148, 82, 4, 30, "#5d4037")
S("DOM")
FLAGS["DOM"] = (rect(0, 0, W, H, WHITE) + rect(0, 0, 130, 80, "#002d62") + rect(170, 0, 130, 80, "#ce1126")
                + rect(0, 120, 130, 80, "#ce1126") + rect(170, 120, 130, 80, "#002d62") + shield(150, 100, 26, 30, "#2e7d32"))
FLAGS["COL"] = hstripes(["#fcd116", "#003893", "#ce1126"], [2, 1, 1])
ven = hstripes(["#ffcc00", "#00247d", "#cf142b"])
for i in range(7):
    a = math.radians(200 + i * 140 / 6)
    ven += star(150 + 46 * math.cos(a), 122 + 46 * math.sin(a), 8, WHITE)
FLAGS["VEN"] = ven
S("EQU")
FLAGS["EQU"] = (hstripes(["#ffdd00", "#034ea2", "#ed1c24"], [2, 1, 1]) + f'<ellipse cx="150" cy="100" rx="22" ry="28" fill="#6fb3e0"/>'
                + path("M118,72 q32,-26 64,0 q-32,-10 -64,0 z", "#3a2a1a"))
FLAGS["PER"] = vstripes(["#d91023", WHITE, "#d91023"])
FLAGS["BOL"] = hstripes(["#d52b1e", "#f9e300", "#007934"])
FLAGS["CHL"] = rect(0, 0, W, 100, WHITE) + rect(0, 100, W, 100, "#d52b1e") + rect(0, 0, 100, 100, "#0039a6") + star(50, 50, 22, WHITE)
FLAGS["ARG"] = hstripes(["#74acdf", WHITE, "#74acdf"]) + sun(150, 100, 26, "#f6b40e", rays=16, face_color="#85340a")
uru = "".join(rect(0, i * H / 9, W, H / 9 + 0.3, WHITE if i % 2 == 0 else "#0038a8") for i in range(9))
uru += rect(0, 0, 110, H * 5 / 9, WHITE) + sun(55, H * 5 / 18, 34, "#fcd116", rays=16, face_color="#7b3f00")
FLAGS["URU"] = uru
S("PAR")
FLAGS["PAR"] = hstripes(["#d52b1e", WHITE, "#0038a8"]) + circle(150, 100, 24, WHITE, "#2e7d32", 4) + star(150, 100, 11, "#fcd116")


def main():
    os.makedirs(OUT, exist_ok=True)
    for tag, body in FLAGS.items():
        svg = (f'<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}">'
               f'{body}</svg>\n')
        with open(os.path.join(OUT, tag + ".svg"), "w", encoding="utf-8") as f:
            f.write(svg)
    print(len(FLAGS), "bandeiras;", "simplificadas:", " ".join(sorted(SIMPLIFICADAS)))


if __name__ == "__main__":
    main()
