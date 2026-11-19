#!/usr/bin/env python3
"""Gera data/common/equipment.json e data/common/research.json a partir de equipment_table.json.

Os números históricos (calibre, alcance, blindagem, velocidade...) vêm da tabela, com fontes.
Os valores de jogo (ataque, custo em dias-fábrica, recursos por unidade, dias de pesquisa) são
calculados aqui com fórmulas simples e documentadas abaixo. As fórmulas são escolhas de design
do WorldWar, não dados históricos, e podem ser reequilibradas sem mexer nos dados reais.

Uso: python3 tools/data/gen_equipment.py
"""
import json
import math
import os

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
TABLE = os.path.join(ROOT, "tools", "data", "equipment_table.json")
OUT_EQ = os.path.join(ROOT, "data", "common", "equipment.json")
OUT_RS = os.path.join(ROOT, "data", "common", "research.json")

AREAS = [
    {"id": "armas", "name": "Armas de infantaria"},
    {"id": "tropas", "name": "Tropas e especializações"},
    {"id": "blindados", "name": "Blindados"},
    {"id": "aviacao", "name": "Aviação"},
    {"id": "artilharia", "name": "Artilharia"},
]
AREA_OF = {"rifle": "armas", "sniper": "armas", "smg": "armas", "tank": "blindados",
           "fighter": "aviacao", "attack": "aviacao", "bomber": "aviacao", "artillery": "artilharia"}
CATEGORY_NAME = {"rifle": "Fuzil", "sniper": "Fuzil de precisão", "smg": "Submetralhadora", "tank": "Tanque",
                 "fighter": "Caça", "attack": "Ataque ao solo", "bomber": "Bombardeiro", "artillery": "Artilharia"}
UNIT_OF = {"rifle": "lote de 100 armas", "sniper": "lote de 100 armas", "smg": "lote de 100 armas",
           "tank": "veículo", "fighter": "avião", "attack": "avião", "bomber": "avião", "artillery": "peça"}


def r1(x):
    return round(x, 1)


def r2(x):
    return round(x, 2)


def small_arms(it):
    """Fuzis, fuzis de precisão e submetralhadoras.
    Cadência prática (tiros/min): ferrolho 10 + carregador/2; semiautomática 20 + carregador/2;
    automática = o menor entre 12% da cadência cíclica (rajadas e recargas) e 2,5 x carregador.
    Energia do cartucho: munição de pistola 0,35 (.45 ACP 0,45); munição de fuzil 1,0.
    Ataque = cadência x energia x fator de alcance (alcance/400 m, entre 0,4 e 2,5) / 5.
    Ataque de perto (cidades, trincheiras, assalto) = cadência x energia / 5."""
    action = it["action"]
    mag = it["magazine"]
    if action == "ferrolho":
        rpm = 10 + mag / 2
    elif action == "semiautomática":
        rpm = 20 + mag / 2
    else:
        rpm = min(it["cyclic_rpm"] * 0.12, mag * 2.5)
    cal = it["calibre"]
    energy = 0.45 if "45 ACP" in cal else 0.35 if ("9×19" in cal or "7,62×25" in cal) else 1.0
    range_f = min(2.5, max(0.4, it["range_m"] / 400))
    cost = {"ferrolho": 1.0, "semiautomática": 1.6, "automática": 1.4}[action]
    if it["category"] == "sniper":
        cost += 1.5   # luneta e seleção de canos
    stats = {
        "practical_rpm": r1(rpm),
        "soft_attack": r1(rpm * energy * range_f / 5),
        "close_attack": r1(rpm * energy / 5),
        "range_m": it["range_m"],
    }
    res = {"iron": r2(0.1 + 0.05 * cost)}
    if it["category"] == "sniper":
        res["rare_metals"] = 0.02
    return stats, r1(cost), res


def tank(it):
    """Perfuração estimada (mm) = calibre x comprimento do cano em calibres / 40.
    Blindagem efetiva = espessura frontal / cos(inclinação).
    Ataque contra blindados = perfuração / 10; contra infantaria = (calibre/10)^1,5 / 2.
    Custo = 2 + 0,4 dia-fábrica por tonelada (o preço histórico acompanha o peso:
    Tiger I 250.700 RM com 54 t; Tiger II 321.500 RM com 69,8 t).
    Recursos: ferro 0,03/t, borracha 0,005/t (lagartas e rodas), metais raros 0,0008 por mm de blindagem efetiva."""
    pen = it["gun_mm"] * it["gun_len"] / 40
    eff = it["armour_mm"] / math.cos(math.radians(it.get("slope_deg", 0)))
    w = it["weight_t"]
    stats = {
        "penetration_mm": round(pen),
        "effective_armour_mm": round(eff),
        "hard_attack": r1(pen / 10),
        "soft_attack": r1((it["gun_mm"] / 10) ** 1.5 / 2),
        "armour": r1(eff / 10),
        "speed_kmh": it["speed_kmh"],
    }
    res = {"iron": r2(w * 0.03), "rubber": r2(w * 0.005), "rare_metals": r2(eff * 0.0008)}
    return stats, r1(2 + 0.4 * w), res


def gun_power(guns):
    # Poder de fogo das armas fixas: soma de quantidade x (calibre / 7,92)^2 / 4.
    return sum(n * (mm / 7.92) ** 2 for n, mm in guns) / 4


def aircraft(it):
    """Caça: ataque aéreo = poder de fogo das armas; custo 6 + velocidade/100.
    Ataque ao solo e bombardeiro: ataque ao solo = bombas (kg) / 100; custo 4 + 6 por motor + bombas/500.
    Recursos por motor: bauxita 0,3 (alumínio), ferro 0,1, metais raros 0,03."""
    cat = it["category"]
    engines = it.get("engines", 1)
    stats = {"speed_kmh": it["speed_kmh"]}
    if cat == "fighter":
        stats["air_attack"] = r1(gun_power(it["guns"]))
        cost = 6 + it["speed_kmh"] / 100
    else:
        stats["ground_attack"] = r1(it["bomb_kg"] / 100)
        stats["bomb_kg"] = it["bomb_kg"]
        if it.get("guns"):
            stats["air_attack"] = r1(gun_power(it["guns"]))
        cost = 4 + 6 * engines + it["bomb_kg"] / 500
    if it.get("range_km"):
        stats["range_km"] = it["range_km"]
    res = {"bauxite": r2(0.3 * engines), "iron": r2(0.1 * engines), "rare_metals": r2(0.03 * engines)}
    return stats, r1(cost), res


def artillery(it):
    """Ataque contra infantaria = peso do projétil (kg) x raiz da cadência / 4.
    Raio de baixas (m) = 14 x raiz cúbica do peso do projétil (o efeito de explosão cresce
    com a raiz cúbica da carga). Custo = 1 + 1,5 dia-fábrica por tonelada da peça.
    Recursos: ferro 0,08 por tonelada, metais raros 0,01."""
    kg = it["shell_kg"]
    t = it["weight_kg"] / 1000
    stats = {
        "soft_attack": r1(kg * math.sqrt(it["rpm"]) / 4),
        "casualty_radius_m": round(14 * kg ** (1 / 3)),
        "range_km": r1(it["range_m"] / 1000),
        "shell_kg": kg,
    }
    return stats, r1(1 + 1.5 * t), {"iron": r2(0.08 * t), "rare_metals": 0.01}


def research_days(it):
    """Dias de pesquisa: fuzil 60, submetralhadora 70, fuzil de precisão 50, tanque 60 + 2 por tonelada,
    caça 120, ataque ao solo 110, bombardeiro 100 + 20 por motor, artilharia 60 + calibre/3."""
    c = it["category"]
    if c == "rifle":
        return 60
    if c == "smg":
        return 70
    if c == "sniper":
        return 50
    if c == "tank":
        return round(60 + 2 * it["weight_t"])
    if c == "fighter":
        return 120
    if c == "attack":
        return 110
    if c == "bomber":
        return 100 + 20 * it.get("engines", 2)
    return round(60 + it["calibre_mm"] / 3)


HISTORY_KEYS = ["calibre", "action", "feed", "magazine", "scope", "cyclic_rpm", "cyclic_note", "range_m", "range_note",
                "velocity_ms", "aimed_rpm_note", "gun", "ammo", "weight_t", "speed_kmh", "speed_note", "crew",
                "armour_mm", "armour_note", "slope_deg", "guns_text", "bomb_kg", "bomb_note", "range_km", "engines",
                "calibre_mm", "shell_kg", "filling_kg", "rpm", "rpm_note", "weight_kg", "built", "built_note", "unit_cost"]


def main():
    table = json.load(open(TABLE, encoding="utf-8"))
    requires = table.get("requires", {})
    equipment = {}
    techs = {}
    for it in table["items"]:
        cat = it["category"]
        if cat in ("rifle", "sniper", "smg"):
            stats, cost, res = small_arms(it)
        elif cat == "tank":
            stats, cost, res = tank(it)
        elif cat in ("fighter", "attack", "bomber"):
            stats, cost, res = aircraft(it)
        else:
            stats, cost, res = artillery(it)
        hist = {k: it[k] for k in HISTORY_KEYS if k in it}
        equipment[it["id"]] = {
            "name": it["name"], "category": cat, "category_name": CATEGORY_NAME[cat], "unit": UNIT_OF[cat],
            "origin": it["origin"], "year": it["year"],
            "stats": stats, "cost": cost, "resources": res,
            "history": hist, "estimated": it.get("estimado", []), "sources": it["sources"],
        }
        days = research_days(it)
        techs["tech_" + it["id"]] = {
            "name": it["name"], "area": AREA_OF[cat], "year": it["year"], "days": days, "money_cost": days * 2,
            "origin": [it["origin"]], "unlocks_equipment": [it["id"]],
            "requires": [("tech_" + r if not r.startswith("t_") else r) for r in requires.get(it["id"], [])]
                        + (["t_tanquistas"] if cat == "tank" else []),
            "estimated": ["year"] if "year" in it.get("estimado", []) else [],
        }
    for t in table["troops"]:
        techs[t["id"]] = {
            "name": t["name"], "area": "tropas", "year": t["year"], "days": t["days"], "money_cost": t["days"] * 2,
            "origin": [], "unlocks_unit": [t["id"].removeprefix("t_")], "requires": t.get("requires", []),
            "desc": t["desc"], "estimated": t.get("estimado", []),
        }
    with open(OUT_EQ, "w", encoding="utf-8") as f:
        json.dump({"_nota": "GERADO por tools/data/gen_equipment.py a partir de tools/data/equipment_table.json. "
                   "Não editar à mão. 'history' = dados reais com fontes; 'stats', 'cost' (dias-fábrica por unidade) "
                   "e 'resources' (por unidade) = valores de jogo calculados por fórmulas.",
                   "equipment": equipment}, f, ensure_ascii=False, indent=1)
        f.write("\n")
    with open(OUT_RS, "w", encoding="utf-8") as f:
        json.dump({"_nota": "GERADO por tools/data/gen_equipment.py. Regras de pesquisa em 'rules'.",
                   "rules": {"slots": 3, "max_years_ahead": 2, "ahead_penalty_per_year": 0.5,
                             "foreign_design_penalty": 0.75, "_foreign": "Projeto de outro país: +75% de tempo "
                             "(provisório, até existirem licenças na diplomacia)."},
                   "areas": AREAS, "techs": techs}, f, ensure_ascii=False, indent=1)
        f.write("\n")
    print("%d equipamentos, %d tecnologias" % (len(equipment), len(techs)))
    for k, e in equipment.items():
        print("%-18s %-10s custo %5.1f  %s" % (k, e["category"], e["cost"], e["stats"]))


if __name__ == "__main__":
    main()
