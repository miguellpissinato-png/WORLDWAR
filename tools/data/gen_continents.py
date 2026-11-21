"""Gera data/map/continents.json: o continente de cada estado (pelo campo `code`), usado pelos objetivos.

Fonte: Natural Earth 50m admin-0 (campo CONTINENT, domínio público). Ajustes:
  - Rússia: estados a leste dos Urais (longitude do centro > 60°) contam como Ásia.
  - América do Norte inclui a América Central e o Caribe.
  - Ilhas de "mar aberto" do Natural Earth e a Antártida ficam fora dos continentes ("outros").
Uso: python3 tools/data/gen_continents.py <ne_50m_admin_0_countries.geojson>
"""
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
NAMES = {"Europe": "europa", "Asia": "asia", "Africa": "africa", "North America": "america_norte",
         "South America": "america_sul", "Oceania": "oceania"}
EXTRA = {"CLP": "america_norte", "USG": "america_norte", "GIB": "europa", "CSI": "oceania", "UMI": "oceania",
         "ESB": "asia", "WSB": "asia", "KAB": "asia", "PGA": "asia"}


def main(path):
    ne = json.load(open(path))
    cont = {f["properties"]["ADM0_A3"]: f["properties"]["CONTINENT"] for f in ne["features"]}
    states = json.load(open(ROOT / "data/map/states.json"))
    out = {}
    for s in states:
        c = EXTRA.get(s["country"]) or NAMES.get(cont.get(s["country"], ""), "outros")
        lon = s["center"][0] / 10.0 - 180.0
        if s["country"] == "RUS" and lon > 60.0:
            c = "asia"
        out[s["code"]] = c
    (ROOT / "data/map/continents.json").write_text(json.dumps(out, ensure_ascii=False, separators=(",", ":")))
    from collections import Counter
    print(Counter(out.values()))


if __name__ == "__main__":
    main(sys.argv[1])
