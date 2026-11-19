"""Gera o mar do mapa: profundidade (batimetria real) e zonas marítimas.

Uso:
    python tools/map/build_sea.py PASTA_COM_GEOJSON

A pasta deve conter estes arquivos do Natural Earth (domínio público), baixados de
https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/<nome>.geojson
    ne_10m_land, ne_10m_geography_marine_polys,
    ne_10m_bathymetry_K_200, _J_1000, _I_2000, _H_3000, _G_4000, _F_5000

Saída:
    data/map/sea_depth.png    profundidade (0 = raso/costa, 255 = 5.000 m ou mais), 1 pixel = 1 unidade do mapa
    data/map/sea_zones.json   zonas marítimas: id, código, nome, centro
    data/map/sea_shapes.json  contornos das zonas (só a interface usa)

Requer: pip install shapely numpy scipy pillow
"""
import json
import random
import sys
from collections import Counter
from pathlib import Path

import numpy as np
import shapely
from PIL import Image, ImageDraw
from scipy import ndimage
from shapely.geometry import MultiPoint, Point, box, shape
from shapely.ops import unary_union, voronoi_diagram
from shapely.validation import make_valid

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_map import LAT_BOTTOM, LAT_TOP, OUT_DIR, SCALE, Y_BOTTOM, Y_TOP, polygons_of  # noqa: E402

WIDTH = int(round(360 * SCALE))
HEIGHT = int(round((Y_TOP - Y_BOTTOM) * SCALE))

# Faixas de profundidade (m) e o tom de cada uma (0 = raso, 1 = fundo).
# A curva dá mais destaque à plataforma continental, perto da costa.
DEPTH_LEVELS = [("K_200", 200, 0.30), ("J_1000", 1000, 0.48), ("I_2000", 2000, 0.62),
                ("H_3000", 3000, 0.75), ("G_4000", 4000, 0.88), ("F_5000", 5000, 1.0)]
DEPTH_BLUR = 2.5            # suavização entre faixas, em pixels

# Zonas marítimas: sementes mais densas perto da costa, mais espaçadas em alto-mar.
COAST_STEP = 58.0           # distância entre sementes perto da costa (unidades do mapa)
COAST_BAND = 90.0           # até que distância da terra conta como "costa"
OPEN_SEA_EVERY = 3          # em alto-mar, mantém 1 a cada N sementes em cada eixo
SEED = 1936


def project_array(coords):
    lon = np.clip(coords[:, 0], -180.0, 180.0)
    lat = np.clip(coords[:, 1], LAT_BOTTOM, LAT_TOP)
    y = np.degrees(1.25 * np.log(np.tan(np.pi / 4 + 0.4 * np.radians(lat))))
    return np.column_stack(((lon + 180.0) * SCALE, (Y_TOP - y) * SCALE))


def projected(geom):
    return shapely.transform(geom, project_array)


def load(folder, name):
    path = Path(folder) / f"{name}.geojson"
    return json.loads(path.read_text(encoding="utf-8"))["features"]


def draw_polygon(draw, poly, fill, hole_fill):
    draw.polygon([tuple(c) for c in poly.exterior.coords], fill=fill)
    for ring in poly.interiors:
        draw.polygon([tuple(c) for c in ring.coords], fill=hole_fill)


def build_depth(folder):
    img = Image.new("F", (WIDTH, HEIGHT), 0.0)
    draw = ImageDraw.Draw(img)
    previous = 0.0
    for suffix, _meters, tone in DEPTH_LEVELS:
        for f in load(folder, f"ne_10m_bathymetry_{suffix}"):
            for poly in polygons_of(projected(make_valid(shape(f["geometry"])))):
                draw_polygon(draw, poly, tone, previous)
        previous = tone
    arr = ndimage.gaussian_filter(np.asarray(img, dtype=np.float32), DEPTH_BLUR)
    out = Image.fromarray(np.clip(arr * 255.0, 0, 255).astype(np.uint8), mode="L")
    out.save(OUT_DIR / "sea_depth.png", optimize=True)
    print(f"profundidade: {WIDTH}x{HEIGHT}")


def build_zones(folder):
    land = unary_union([projected(make_valid(shape(f["geometry"]))) for f in load(folder, "ne_10m_land")])
    land = land.simplify(0.5)
    world = box(0, 0, WIDTH, HEIGHT)
    ocean = world.difference(land)
    shapely.prepare(ocean)

    # Distância até a terra, para decidir a densidade das sementes.
    mask = Image.new("L", (WIDTH, HEIGHT), 0)
    d = ImageDraw.Draw(mask)
    for poly in polygons_of(land):
        draw_polygon(d, poly, 255, 0)
    dist = ndimage.distance_transform_edt(np.asarray(mask) == 0)

    rng = random.Random(SEED)
    seeds = []
    nx = int(WIDTH / COAST_STEP) + 1
    ny = int(HEIGHT / COAST_STEP) + 1
    for gx in range(nx):
        for gy in range(ny):
            x = (gx + 0.5 + rng.uniform(-0.35, 0.35)) * COAST_STEP
            y = (gy + 0.5 + rng.uniform(-0.35, 0.35)) * COAST_STEP
            if not (0 <= x < WIDTH and 0 <= y < HEIGHT):
                continue
            if not ocean.contains(Point(x, y)):
                continue
            near_coast = dist[int(y), int(x)] < COAST_BAND
            if near_coast or (gx % OPEN_SEA_EVERY == 0 and gy % OPEN_SEA_EVERY == 0):
                seeds.append((x, y))

    cells = voronoi_diagram(MultiPoint(seeds), envelope=world).geoms
    marine = []
    for f in load(folder, "ne_10m_geography_marine_polys"):
        g = projected(make_valid(shape(f["geometry"])))
        p = f["properties"]
        marine.append((g, g.area, p.get("name_pt") or p.get("name_en") or p.get("name")))

    zones = []
    zone_shapes = {}
    for cell in cells:
        cell = cell.intersection(world)
        water = cell.intersection(ocean)
        parts = [g for g in polygons_of(water) if g.area > 1.0]
        if not parts:
            continue
        main = max(parts, key=lambda g: g.area)
        c = main.representative_point()
        best = None
        for g, area, name in marine:
            if name and (best is None or area < best[0]) and g.contains(c):
                best = (area, name)
        zones.append({"name": best[1] if best else "Oceano", "center": [round(c.x, 1), round(c.y, 1)],
                      "_cell": cell})

    # Ordem estável (oeste -> leste, norte -> sul em faixas) e nomes repetidos numerados.
    zones.sort(key=lambda z: (round(z["center"][0] / 100), z["center"][1]))
    count = Counter(z["name"] for z in zones)
    seen = Counter()
    out = []
    for i, z in enumerate(zones, start=1):
        name = z["name"]
        if count[name] > 1:
            seen[name] += 1
            name = f"{name} {seen[name]}"
        out.append({"id": i, "code": f"MAR-{i:04d}", "name": name, "center": z["center"]})
        ring = [round(v, 1) for xy in z["_cell"].exterior.coords[:-1] for v in xy]
        zone_shapes[str(i)] = [ring]

    (OUT_DIR / "sea_zones.json").write_text(
        json.dumps(out, ensure_ascii=False, indent=0, separators=(",", ":")), encoding="utf-8")
    (OUT_DIR / "sea_shapes.json").write_text(
        json.dumps({"shapes": zone_shapes}, separators=(",", ":")), encoding="utf-8")
    print(f"{len(out)} zonas marítimas")


def main(folder):
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    build_depth(folder)
    build_zones(folder)


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1])
