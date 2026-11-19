"""Gera os estados do mapa a partir das divisões admin-1 do Natural Earth (domínio público).

Uso:
    python tools/map/build_map.py caminho/ne_10m_admin_1_states_provinces.geojson

Baixe o arquivo em:
https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_10m_admin_1_states_provinces.geojson

Saída:
    data/map/states.json  dados de cada estado (id, código, nome, país moderno, centro, área)
    data/map/shapes.json  contornos de cada estado, já projetados (usados só pela interface)

Requer: pip install shapely
"""
import json
import math
import sys
from collections import defaultdict
from pathlib import Path

import shapely
from shapely.geometry import shape, Polygon, MultiPolygon
from shapely.ops import unary_union
from shapely.validation import make_valid

ROOT = Path(__file__).resolve().parents[2]
OUT_DIR = ROOT / "data" / "map"

# Projeção de Miller (parecida com Mercator, mas sem exagerar os polos).
# x: 1 grau de longitude = SCALE unidades. y cresce para o sul.
SCALE = 10.0
LAT_TOP = 83.0
LAT_BOTTOM = -58.0

# Tolerância de simplificação (graus) e área mínima de uma ilha (graus²).
SIMPLIFY_TOLERANCE = 0.04
MIN_PART_AREA = 0.005

# Países muito fragmentados no Natural Earth: os estados são agrupados pelo campo "region".
MERGE_BY_REGION = {"GBR", "SVN", "LVA", "PHL", "UGA", "MKD", "AZE", "MLT"}

# Fora do jogo.
EXCLUDE_COUNTRIES = {"ATA"}


def miller_deg(lat):
    """Coordenada y de Miller, em 'graus equivalentes'."""
    phi = math.radians(lat)
    return math.degrees(1.25 * math.log(math.tan(math.pi / 4 + 0.4 * phi)))


Y_TOP = miller_deg(LAT_TOP)
Y_BOTTOM = miller_deg(LAT_BOTTOM)


def project(lon, lat):
    lat = max(min(lat, LAT_TOP), LAT_BOTTOM)
    return (round((lon + 180.0) * SCALE, 1), round((Y_TOP - miller_deg(lat)) * SCALE, 1))


def polygons_of(geom):
    if isinstance(geom, Polygon):
        return [geom]
    if isinstance(geom, MultiPolygon):
        return list(geom.geoms)
    if hasattr(geom, "geoms"):  # GeometryCollection
        out = []
        for g in geom.geoms:
            out.extend(polygons_of(g))
        return out
    return []


def _polygonal(geom):
    parts = polygons_of(geom)
    return MultiPolygon(parts) if len(parts) != 1 else parts[0]


def main(src):
    features = json.loads(Path(src).read_text(encoding="utf-8"))["features"]
    groups = defaultdict(list)
    info = {}
    for f in features:
        p = f["properties"]
        adm0 = p["adm0_a3"]
        if adm0 in EXCLUDE_COUNTRIES or f["geometry"] is None:
            continue
        if adm0 in MERGE_BY_REGION and p.get("region"):
            key = f"{adm0}-R-{p['region']}"
            name = p["region"]
        else:
            key = p["adm1_code"]
            name = p.get("name_pt") or p.get("name") or p.get("name_en") or key
        groups[key].append(make_valid(shape(f["geometry"])))
        info.setdefault(key, {"code": key, "name": name, "country": adm0, "country_name": p["admin"]})

    keys = sorted(groups)
    merged = [_polygonal(make_valid(unary_union(groups[k]))) for k in keys]
    # Simplificação de cobertura: bordas compartilhadas são simplificadas do mesmo jeito
    # nos dois estados vizinhos, então não sobram frestas entre eles.
    simplified = shapely.coverage_simplify(merged, SIMPLIFY_TOLERANCE)

    states = []
    shapes = {}
    for key, geom in zip(keys, simplified):
        parts = [g for g in polygons_of(geom) if g.area >= MIN_PART_AREA]
        if not parts:
            # Estado minúsculo: mantém só a maior parte.
            parts = sorted(polygons_of(geom), key=lambda g: g.area, reverse=True)[:1]
        if not parts:
            continue
        rings = []
        for part in parts:
            ring = [c for xy in part.exterior.coords[:-1] for c in project(*xy)]
            if len(ring) >= 6:
                rings.append(ring)
        if not rings:
            continue
        sid = len(states) + 1
        main_part = max(parts, key=lambda g: g.area)
        center = main_part.representative_point()
        lat_c = center.y
        # Área aproximada em km² (graus² corrigidos pela latitude).
        area_km2 = sum(g.area for g in parts) * (111.32 ** 2) * math.cos(math.radians(lat_c))
        st = dict(info[key])
        st.update({"id": sid, "center": list(project(center.x, center.y)), "area_km2": int(area_km2)})
        states.append(st)
        shapes[str(sid)] = rings

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    (OUT_DIR / "states.json").write_text(
        json.dumps(states, ensure_ascii=False, indent=0, separators=(",", ":")), encoding="utf-8")
    (OUT_DIR / "shapes.json").write_text(
        json.dumps({"scale": SCALE, "lat_top": LAT_TOP, "width": 360 * SCALE,
                    "height": round((Y_TOP - Y_BOTTOM) * SCALE, 1), "projection": "miller", "shapes": shapes},
                   separators=(",", ":")), encoding="utf-8")
    points = sum(len(r) // 2 for rs in shapes.values() for r in rs)
    print(f"{len(states)} estados, {points} pontos")


if __name__ == "__main__":
    if len(sys.argv) != 2:
        print(__doc__)
        sys.exit(1)
    main(sys.argv[1])
