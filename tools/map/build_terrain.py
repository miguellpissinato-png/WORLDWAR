"""Gera data/map/terrain.webp: o terreno do mapa (relevo, cobertura do solo, neve, rios e lagos),
na mesma projeção do mapa (Miller, lat 83 a -58). O shader do mapa mostra este terreno quando
a câmera chega perto; de longe continua a vista política.

Fontes (domínio público):
  - Relevo sombreado: Natural Earth "Shaded Relief" (shadedrelief.jpg, 10800x5400, do pacote
    basemap-data do PyPI).
  - Cobertura do solo e neve: NASA Blue Marble Next Generation (bmng.jpg, 5400x2700, mesmo pacote).
  - Rios e lagos: Natural Earth 10m (rivers_lake_centerlines, rivers_europe, rivers_north_america, lakes).

Canais: RGB = cor do terreno; A = 255 - rio (o shader pinta os rios e os esconde de longe).

Uso: python3 tools/map/build_terrain.py <pasta com shadedrelief.jpg e bmng.jpg> <pasta com os geojson>
"""
import json
import math
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from scipy import ndimage

SCALE = 10.0
LAT_TOP = 83.0
LAT_BOTTOM = -58.0
MAP_W = 3600.0
OUT_W = 6144
OUT = Path(__file__).resolve().parents[2] / "data" / "map" / "terrain.webp"


def miller_deg(lat):
    phi = math.radians(lat)
    return math.degrees(1.25 * math.log(math.tan(math.pi / 4 + 0.4 * phi)))


Y_TOP = miller_deg(LAT_TOP)
Y_BOTTOM = miller_deg(LAT_BOTTOM)
MAP_H = (Y_TOP - Y_BOTTOM) * SCALE
OUT_H = round(OUT_W * MAP_H / MAP_W)
PX = OUT_W / MAP_W   # pixels da saída por unidade do mapa


def inv_miller(ym_deg):
    y = np.radians(ym_deg)
    return np.degrees((np.arctan(np.exp(y / 1.25)) - math.pi / 4) / 0.4)


def sample_equirect(img: np.ndarray, lon, lat):
    """Amostra uma imagem equirretangular (-180..180, 90..-90) com interpolação bilinear."""
    h, w = img.shape[:2]
    x = (lon + 180.0) / 360.0 * w - 0.5
    y = (90.0 - lat) / 180.0 * h - 0.5
    out = np.empty(lon.shape + (img.shape[2],), np.float32)
    for c in range(img.shape[2]):
        out[..., c] = ndimage.map_coordinates(img[..., c], [y, x], order=1, mode="wrap")
    return out


def project(lon, lat):
    lat = max(min(lat, LAT_TOP), LAT_BOTTOM)
    return ((lon + 180.0) * SCALE * PX, (Y_TOP - miller_deg(lat)) * SCALE * PX)


def lines_of(geom):
    if geom is None:
        return []
    if geom["type"] == "LineString":
        return [geom["coordinates"]]
    if geom["type"] == "MultiLineString":
        return geom["coordinates"]
    return []


def rings_of(geom):
    if geom is None:
        return []
    if geom["type"] == "Polygon":
        return [geom["coordinates"][0]]
    if geom["type"] == "MultiPolygon":
        return [p[0] for p in geom["coordinates"]]
    return []


def main(raster_dir: Path, ne_dir: Path):
    print("terreno %dx%d" % (OUT_W, OUT_H))
    xs = (np.arange(OUT_W) + 0.5) / PX / SCALE - 180.0
    ys = Y_TOP - (np.arange(OUT_H) + 0.5) / PX / SCALE
    lon, ym = np.meshgrid(xs, ys)
    lat = inv_miller(ym)

    relief = np.asarray(Image.open(raster_dir / "shadedrelief.jpg").convert("L"), np.float32)[..., None] / 255.0
    rel = sample_equirect(relief, lon, lat)[..., 0]
    # relevo local: luminância dividida pela média da vizinhança (realça serras e vales)
    local = ndimage.gaussian_filter(rel, 18)
    shade = np.clip(rel / np.maximum(local, 0.05), 0.55, 1.45)

    bm = np.asarray(Image.open(raster_dir / "bmng.jpg").convert("RGB"), np.float32) / 255.0
    cover = sample_equirect(bm, lon, lat)
    cover = np.power(np.clip(cover, 0, 1), 0.7)                     # clareia (o original é escuro)
    gray = cover.mean(axis=2, keepdims=True)
    cover = gray + (cover - gray) * 0.7                             # tira um pouco da saturação
    snow = np.clip((gray[..., 0] - 0.62) / 0.2, 0, 1)               # neve e gelo ficam brancos
    col = cover * np.power(shade, 1.25)[..., None]
    col = col * (1 - snow[..., None]) + (0.93 * shade[..., None] ** 0.6) * snow[..., None]

    # lagos
    img = Image.fromarray((np.clip(col, 0, 1) * 255).astype(np.uint8), "RGB")
    d = ImageDraw.Draw(img)
    lakes = json.load(open(ne_dir / "ne_10m_lakes.geojson"))
    for f in lakes["features"]:
        for ring in rings_of(f["geometry"]):
            pts = [project(x, y) for x, y in ring]
            if len(pts) > 2:
                d.polygon(pts, fill=(64, 104, 132))

    # rios: máscara desenhada em 2x e reduzida (bordas suaves)
    ss = 2
    mask = Image.new("L", (OUT_W * ss, OUT_H * ss), 0)
    dm = ImageDraw.Draw(mask)
    files = [("ne_10m_rivers_lake_centerlines.geojson", 0.0), ("ne_10m_rivers_europe.geojson", -0.4),
             ("ne_10m_rivers_north_america.geojson", -0.4)]
    for name, extra in files:
        data = json.load(open(ne_dir / name))
        for f in data["features"]:
            rank = float(f["properties"].get("scalerank") or 9)
            width = max(0.7, (2.6 - 0.2 * rank + extra)) * ss
            for line in lines_of(f["geometry"]):
                pts = [project(x, y) for x, y in line]
                pts = [(x * ss, y * ss) for x, y in pts]
                for a, b in zip(pts, pts[1:]):
                    if abs(a[0] - b[0]) < OUT_W * ss / 2:   # não cruza o mapa inteiro na volta do mundo
                        dm.line([a, b], fill=255, width=max(1, round(width)))
    mask = mask.resize((OUT_W, OUT_H), Image.LANCZOS)
    alpha = Image.fromarray(255 - np.asarray(mask), "L")
    img.putalpha(alpha)
    img.save(OUT, "WEBP", quality=88, method=6)
    print("salvo", OUT, OUT.stat().st_size // 1024, "KB")


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
