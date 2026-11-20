#!/usr/bin/env python3
"""Gera data/map/adjacency.json: para cada estado (pelo code), os estados vizinhos por terra.

Dois estados são vizinhos quando os contornos se tocam (com uma folga pequena, porque a simplificação
pode deixar frestas de frações de unidade). Também liga ilhas e costas muito próximas (estreitos
estreitos, ex. Dinamarca, Sicília) quando a distância é menor que STRAIT_GAP; essas ligações ficam
marcadas como "strait" para a simulação poder tratá-las diferente no futuro.

Uso: python3 tools/map/build_adjacency.py
"""
import json
import os

from shapely.geometry import Polygon
from shapely.ops import unary_union
from shapely.strtree import STRtree

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TOUCH_GAP = 0.6     # unidades do mapa (10 por grau): ~6 km
STRAIT_GAP = 3.0    # ~30 km


def main():
    shapes = json.load(open(os.path.join(ROOT, "data/map/shapes.json")))["shapes"]
    states = json.load(open(os.path.join(ROOT, "data/map/states.json")))
    code_of = {str(s["id"]): s["code"] for s in states}
    ids, geoms = [], []
    for sid, rings in shapes.items():
        polys = []
        for flat in rings:
            pts = list(zip(flat[0::2], flat[1::2]))
            if len(pts) >= 3:
                p = Polygon(pts)
                if not p.is_valid:
                    p = p.buffer(0)
                polys.append(p)
        if polys:
            ids.append(sid)
            geoms.append(unary_union(polys))
    tree = STRtree(geoms)
    land = {code_of[i]: set() for i in ids}
    strait = {code_of[i]: set() for i in ids}
    for i, g in enumerate(geoms):
        a = code_of[ids[i]]
        for j in tree.query(g.buffer(STRAIT_GAP)):
            if j == i:
                continue
            b = code_of[ids[j]]
            d = g.distance(geoms[j])
            if d <= TOUCH_GAP:
                land[a].add(b)
            elif d <= STRAIT_GAP:
                strait[a].add(b)
    out = {"_nota": "GERADO por tools/map/build_adjacency.py. land = fronteira por terra; strait = travessia curta de mar.",
           "land": {k: sorted(v) for k, v in land.items()},
           "strait": {k: sorted(v - land[k]) for k, v in strait.items() if v - land[k]}}
    with open(os.path.join(ROOT, "data/map/adjacency.json"), "w", encoding="utf-8") as f:
        json.dump(out, f, ensure_ascii=False, separators=(",", ":"))
    isolated = [k for k, v in land.items() if not v]
    print("%d estados, %d ligações por terra, %d estreitos, %d sem vizinho por terra" % (
        len(land), sum(len(v) for v in land.values()) // 2, sum(len(v) for v in out["strait"].values()) // 2, len(isolated)))


if __name__ == "__main__":
    main()
