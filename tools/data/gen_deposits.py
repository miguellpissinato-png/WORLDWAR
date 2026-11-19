"""Gera data/common/state_resources.json a partir da produção real de 1936 por país.

Cada recurso: total do país (toneladas/ano, fonte nas notas) -> unidades/dia do jogo
(divisão por UNIT[recurso]) -> distribuído entre regiões do país pelos pesos.
"""
import json
from pathlib import Path

R = Path(__file__).resolve().parents[2]
states = json.load(open(R / 'data/map/states.json'))

# toneladas por ano equivalentes a 1 unidade/dia no jogo
UNIT = {"oil": 900_000, "coal": 3_500_000, "iron": 1_000_000, "bauxite": 50_000, "rubber": 12_000, "rare_metals": None}
MIN_RAW = 0.15   # abaixo disso o país não recebe jazida

# (país, total t/ano, [(ISO, trecho do nome do estado, peso), ...], nota)
OIL = [
 ("EUA", 148_606_400, [("USA","Texas",39),("USA","Califórnia",20),("USA","Oklahoma",19),("USA","Luisiana",8),("USA","Kansas",5),
   ("USA","Novo México",3),("USA","Pensilvânia",2),("USA","Wyoming",1),("USA","Michigan",1),("USA","Illinois",1)], "SS"),
 ("URSS", 27_163_000, [("AZE","Absheron",70),("RUS","Chechénia",17),("RUS","Bascortostão",4),("RUS","Sacalina",3),("KAZ","Atyrau",3),("TKM","Balkan",3)], "SS (inclui Sacalina)"),
 ("Venezuela", 22_582_910, [("VEN","Zulia",85),("VEN","Anzoátegui",8),("VEN","Monagas",7)], "SS"),
 ("Romênia", 8_566_037, [("ROU","Prahova",80),("ROU","Dâmbovița",12),("ROU","Bacău",8)], "SS"),
 ("Irã", 8_198_119, [("IRN","Khuzistão",100)], "SS"),
 ("Índias Orientais Holandesas", 6_336_122, [("IDN","Sumatra do Sul",45),("IDN","Kalimantan Oriental",35),("IDN","Achém",10),("IDN","Java Oriental",10)], "SS"),
 ("México", 6_107_424, [("MEX","Veracruz",70),("MEX","Tamaulipas",30)], "SS"),
 ("Iraque", 3_947_535, [("IRQ","Kirkuk",100)], "SS"),
 ("Colômbia", 2_640_700, [("COL","Santander",100)], "SS"),
 ("Peru", 2_286_977, [("PER","Piura",85),("PER","Tumbes",15)], "SS"),
 ("Argentina", 2_173_207, [("ARG","Chubut",70),("ARG","Mendoza",20),("ARG","Salta",10)], "SS"),
 ("Trinidad", 1_813_292, [("TTO","Rio Claro",100)], "SS"),
 ("Birmânia", 1_025_367, [("MMR","Magway",100)], "SS"),
 ("Bahrein", 663_600, [("BHR","Sul",100)], "SS"),
 ("Polônia", 502_500, [("UKR","Ivano",60),("POL","Subcarpácia",25),("UKR","Lviv",15)], "SS"),
 ("Brunei", 451_621, [("BRN","Belait",100)], "SS"),
 ("Alemanha", 437_631, [("DEU","Baixa Saxônia",100)], "SS"),
 ("Equador", 334_431, [("ECU","Santa Elena",100)], "SS"),
 ("Japão", 333_600, [("JPN","Niigata",70),("JPN","Akita",30)], "SS"),
 ("Índia", 267_342, [("IND","Assam",100)], "SS"),
 ("Sarawak", 222_452, [("MYS","Sarawak",100)], "SS"),
 ("Canadá", 189_921, [("CAN","Alberta",100)], "SS"),
 ("Egito", 179_638, [("EGY","Mar Vermelho",100)], "SS"),
]
# carvão: hulha + 0,33 x linhito/carvão marrom (menor poder calorífico)
COAL = [
 ("EUA", 48_731_728 + 392_042_770, [("USA","Pensilvânia",33),("USA","Virgínia Ocidental",24),("USA","Illinois",10),("USA","Kentucky",9),
   ("USA","Ohio",5),("USA","Indiana",4),("USA","Alabama",3),("USA","Virgínia",3),("USA","Colorado",2),("USA","Utah",1),("USA","Wyoming",1)], "SS"),
 ("Reino Unido", 6_525_225 + 221_923_131, [("GBR","North East",19),("GBR","Yorkshire",18),("GBR","West Wales",13),("GBR","East Wales",3),
   ("GBR","East Midlands",14),("GBR","South Western",8),("GBR","Eastern",5),("GBR","North West",7),("GBR","West Midlands",7)], "SS"),
 ("Alemanha", 155_782_899 + 0.33 * 158_847_655, [("DEU","Renânia do Norte",62),("POL","Opole",10),("DEU","Sarre",7),("POL","Baixa Silésia",3),
   ("DEU","Saxónia",8),("DEU","Saxônia-Anhalt",6),("DEU","Brandemburgo",4)], "SS"),
 ("URSS", 126_000_000, [("UKR","Donetsk",45),("UKR","Lugansk",20),("RUS","Kemerovo",14),("RUS","Tula",6),("KAZ","Qaraghandy",6),
   ("RUS","Perm",4),("RUS","Sverdlovsk",3),("RUS","Irkutsk",2)], "estimativa de referência"),
 ("França", 44_513_214 + 0.33 * 928_333, [("FRA","Norte",35),("FRA","Pas-de-Calais",35),("FRA","Mosela",14),("FRA","Loire",8),("FRA","Saône-et-Loire",4),("FRA","Gard",4)], "SS"),
 ("Japão", 41_800_000, [("JPN","Fukuoka",55),("JPN","Hokkaido",30),("JPN","Fukushima",8),("JPN","Ibaraki",7)], "estimativa de referência"),
 ("Polônia", 29_278_040, [("POL","Silésia",90),("POL","Pequena Polónia",10)], "SS"),
 ("Bélgica", 5_981_898 + 21_445_070, [("BEL","Hainaut",65),("BEL","Liège",20),("BEL","Limburgo",15)], "SS"),
 ("China", 27_116_000, [("CHN","Hebei",30),("CHN","Shanxi",20),("CHN","Shandong",15),("CHN","Henan",15),("CHN","Jiangxi",10),("CHN","Hunan",10)], "Minerals Yearbook"),
 ("Índia", 22_212_457 + 398_364 + 565_000, [("IND","Jharkhand",55),("IND","Bengala Ocidental",35),("IND","Madhya Pradesh",10)], "SS"),
 ("Tchecoslováquia", 12_039_975 + 0.33 * 15_696_878, [("CZE","Morávia-Silésia",60),("CZE","Ústí",30),("CZE","Karlovy",10)], "SS"),
 ("África do Sul", 14_607_313, [("ZAF","Mpumalanga",65),("ZAF","KwaZulu",35)], "SS"),
 ("Manchukuo", 13_600_000, [("CHN","Liaoning",100)], "estimativa de referência"),
 ("Austrália", 11_370_409 + 0.33 * 3_044_897, [("AUS","Nova Gales do Sul",75),("AUS","Vitória",15),("AUS","Queensland",10)], "SS"),
 ("Países Baixos", 12_600_340, [("NLD","Limburgo",100)], "SS"),
 ("Canadá", 9_639_406 + 505_567 + 0.33 * 3_452_511, [("CAN","Nova Escócia",50),("CAN","Alberta",40),("CAN","Colúmbia Britânica",10)], "SS"),
 ("Espanha", 7_000_000, [("ESP","Astúrias",80),("ESP","Leão",20)], "estimativa de referência (guerra civil)"),
 ("Hungria", 813_783 + 0.33 * (6_501_139 + 491_652), [("HUN","Baranya",50),("HUN","Komárom",50)], "SS"),
 ("Coreia", 2_282_000, [("PRK","Pyongan Sul",100)], "Minerals Yearbook"),
 ("Turquia", 2_300_000, [("TUR","Zonguldak",100)], "estimativa de referência"),
 ("Indochina Francesa", 2_116_108, [("VNM","Quang Ninh",100)], "SS"),
 ("Chile", 1_655_761 + 0.33 * 189_433, [("CHL","Bío",100)], "SS"),
 ("Iugoslávia", 434_384 + 0.33 * (3_017_941 + 952_916), [("SRB","Zaje",50),("BIH","Tuzla",50)], "SS"),
 ("Formosa", 1_716_236, [("TWN","Taipé",100)], "SS"),
 ("Nova Zelândia", 858_857 + 0.33 * (1_150_071 + 131_289), [("NZL","Costa Oeste",100)], "SS"),
 ("México", 1_276_000, [("MEX","Coahuila",100)], "SS"),
 ("Áustria", 240_480 + 0.33 * 2_851_446, [("AUT","Estíria",100)], "SS"),
 ("Itália", 78_709 + 714_696 + 0.33 * 756_425, [("ITA","Carbonia-Iglesias",100)], "SS"),
 ("Romênia", 3_649 + 284_299 + 0.33 * (1_482_615 + 162_805), [("ROU","Hunedoara",100)], "SS"),
 ("Noruega (Svalbard)", 771_442, [("NOR","Svalbard",100)], "SS"),
 ("Rodésia do Sul", 693_947, [("ZWE","Matabelelândia Norte",100)], "SS"),
 ("Brasil", 651_738, [("BRA","Santa Catarina",60),("BRA","Rio Grande do Sul",40)], "SS"),
 ("Bulgária", 2_286 + 98_379 + 0.33 * 1_551_206, [("BGR","Pernik",100)], "SS"),
]
IRON = [
 ("EUA", 49_729_264, [("USA","Minnesota",80),("USA","Michigan",10),("USA","Alabama",10)], "SS"),
 ("França", 32_775_667, [("FRA","Meurthe-et-Moselle",65),("FRA","Mosela",30),("FRA","Calvados",5)], "SS"),
 ("URSS", 27_477_000, [("UKR","Dnipropetrovsk",65),("RUS","Cheliabinsk",20),("RUS","Crimeia",5),("RUS","Sverdlovsk",5),("RUS","Kursk",5)], "SS"),
 ("Reino Unido", 12_701_386, [("GBR","East Midlands",70),("GBR","North West",15),("GBR","North East",15)], "SS"),
 ("Suécia", 11_065_890, [("SWE","Norrbotten",75),("SWE","Dalarna",10),("SWE","Örebro",10),("SWE","Västmanland",5)], "SS"),
 ("Alemanha", 7_450_638, [("DEU","Baixa Saxônia",45),("DEU","Renânia do Norte",25),("DEU","Hesse",15),("DEU","Baviera",15)], "SS"),
 ("Luxemburgo", 4_818_667, [("LUX","Luxemburgo",100)], "SS"),
 ("Manchukuo", 2_583_000, [("CHN","Liaoning",100)], "SS"),
 ("Índia", 2_526_931, [("IND","Orissa",60),("IND","Jharkhand",40)], "SS"),
 ("Argélia", 2_136_248, [("DZA","Tébessa",100)], "SS"),
 ("Espanha", 2_013_578, [("ESP","Biscaia",70),("ESP","Almeria",15),("ESP","Granada",15)], "SS"),
 ("Austrália", 1_889_599, [("AUS","Austrália Meridional",100)], "SS"),
 ("Malásia", 1_654_547 + 449, [("MYS","Terengganu",60),("MYS","Johor",40)], "SS"),
 ("Chile", 1_332_325, [("CHL","Coquimbo",100)], "SS"),
 ("Tchecoslováquia", 1_072_414, [("CZE","Boémia Central",100)], "SS"),
 ("Marrocos Espanhol", 1_030_501, [("MAR","Oriental",100)], "SS"),
 ("Áustria", 1_008_110, [("AUT","Estíria",100)], "SS"),
 ("Terra Nova", 893_308, [("CAN","Terra Nova",100)], "SS"),
 ("Itália", 843_921, [("ITA","Livorno",100)], "SS"),
 ("Noruega", 833_435, [("NOR","Finnmark",60),("NOR","Nordland",40)], "SS"),
 ("Japão", 742_500, [("JPN","Iwate",100)], "SS"),
 ("Tunísia", 715_000, [("TUN","Jendouba",100)], "SS"),
 ("Serra Leoa", 566_595, [("SLE","Northern",100)], "SS"),
 ("Filipinas", 529_041, [("PHL","Bicol",100)], "SS"),
 ("Polônia", 461_253, [("POL","Santa Cruz",100)], "SS"),
 ("Cuba", 449_612, [("CUB","Santiago de Cuba",100)], "SS"),
 ("Iugoslávia", 443_738, [("BIH","Zenica",100)], "SS"),
 ("África do Sul", 359_219, [("ZAF","Cabo Setentrional",100)], "SS"),
 ("Grécia", 275_845, [("GRC","Grécia Central",100)], "SS"),
 ("Hungria", 275_256, [("HUN","Borsod",100)], "SS"),
 ("Coreia", 230_700, [("PRK","Hamgyong Norte",100)], "SS"),
 ("Bélgica", 187_649, [("BEL","Luxemburgo",100)], "SS"),
]
BAUXITE = [
 ("França", 639_250, [("FRA","Var",80),("FRA","Hérault",20)], "SS"),
 ("EUA", 372_005, [("USA","Arkansas",100)], "SS"),
 ("Hungria", 323_893, [("HUN","Fejér",50),("HUN","Veszprém",50)], "SS"),
 ("Iugoslávia", 287_560, [("HRV","Split",60),("BIH","Herzegov",40)], "SS"),
 ("Itália", 258_104, [("HRV","Ístria",60),("ITA","Áquila",40)], "SS"),
 ("Guiana Holandesa", 231_136, [("SUR","Para",60),("SUR","Marowijne",40)], "SS"),
 ("Guiana Britânica", 157_945 + 11_525 + 39_851, [("GUY","Alto Demerara",100)], "SS"),
 ("URSS", 200_000, [("RUS","Leningrado",70),("RUS","Sverdlovsk",30)], "SS (estimativa)"),
 ("Índias Orientais Holandesas", 131_619, [("IDN","Ilhas Riau",100)], "SS"),
 ("Grécia", 127_846, [("GRC","Grécia Central",100)], "SS"),
 ("Alemanha", 12_229, [("DEU","Hesse",100)], "SS"),
 ("Romênia", 10_658, [("ROU","Bihor",100)], "SS"),
]
# borracha: 1934 (milhares de t), Anuário Estatístico Alemão 1935, tabela 115
RUBBER = [
 ("Malásia", 475_000, [("MYS","Perak",22),("MYS","Selangor",18),("MYS","Johor",25),("MYS","Negeri Sembilan",12),("MYS","Quedá",10),("MYS","Pahang",8),("MYS","Malaca",5)], "Stat. Jb. 1935"),
 ("Índias Orientais Holandesas", 384_000, [("IDN","Sumatra do Norte",35),("IDN","Java Ocidental",15),("IDN","Kalimantan Ocidental",12),("IDN","Sumatra do Sul",12),
   ("IDN","Jambi",10),("IDN","Kalimantan do Sul",8),("IDN","Riau",8)], "Stat. Jb. 1935"),
 ("Ceilão", 80_000, [("LKA","Ratnapura",35),("LKA","Kegalle",35),("LKA","Kŏḷamba",15),("LKA","Kulatra",15)], "Stat. Jb. 1935"),
 ("Bornéu Britânico", 29_000, [("MYS","Sarawak",55),("MYS","Sabá",45)], "Stat. Jb. 1935"),
 ("Indochina Francesa", 20_000, [("VNM","Binh Duong",40),("VNM","Binh Phuoc",30),("KHM","Kampong Cham",30)], "Stat. Jb. 1935"),
 ("Sião", 18_000, [("THA","Songkhla",60),("THA","Surat Thani",40)], "Stat. Jb. 1935"),
 ("Índia e Birmânia", 12_000, [("IND","Kerala",70),("MMR","Mon",30)], "Stat. Jb. 1935"),
 ("América do Sul", 9_000, [("BRA","Amazonas",60),("BRA","Pará",40)], "Stat. Jb. 1935"),
 ("África", 3_000, [("LBR","Margibi",100)], "Stat. Jb. 1935"),
]
# metais raros: índice de valor = estanho (t metal) x1 + níquel (t metal) x1 + tungstênio (t conc. 60%) x0,8
#               + cromita (t Cr2O3) x0,04 + manganês (t minério) x0,012
def rare(tin=0, nickel=0, tungsten=0, chromite=0, manganese=0):
    return tin + nickel + 0.8 * tungsten + 0.04 * chromite + 0.012 * manganese
RARE = [
 ("Malásia", rare(tin=66_717, tungsten=1_650, manganese=36_776), [("MYS","Perak",55),("MYS","Selangor",25),("MYS","Pahang",10),("MYS","Kelantan",10)], "SS"),
 ("Canadá", rare(nickel=75_777, chromite=824), [("CAN","Ontário",100)], "SS"),
 ("Índias Orientais Holandesas", rare(tin=30_728, manganese=8_483), [("IDN","Bangka",100)], "SS"),
 ("Bolívia", rare(tin=24_091), [("BOL","Potosí",50),("BOL","Oruro",50)], "SS"),
 ("URSS", rare(nickel=9_000, chromite=216_000, manganese=2_955_000), [("GEO","Imereti",45),("UKR","Dnipropetrovsk",25),("RUS","Sverdlovsk",15),("KAZ","Aqtöbe",15)], "SS"),
 ("China", rare(tin=10_400, tungsten=7_638), [("CHN","Jiangxi",55),("CHN","Yunnan",30),("CHN","Hunan",15)], "SS + Minerals Yearbook 1937"),
 ("Birmânia", rare(tin=4_546, nickel=1_292, tungsten=7_000), [("MMR","Shan",50),("MMR","Tanintharyi",50)], "SS + estimativa"),
 ("Sião", rare(tin=12_633), [("THA","Phuket",60),("THA","Phangnga",40)], "SS"),
 ("Nigéria", rare(tin=9_648), [("NGA","Plateau",100)], "SS"),
 ("Congo Belga", rare(tin=7_303), [("COD","Katanga",100)], "SS"),
 ("Rodésia do Sul", rare(chromite=180_499), [("ZWE","Midlands",100)], "SS"),
 ("África do Sul", rare(tin=634, chromite=172_896, manganese=254_167), [("ZAF","Limpopo",60),("ZAF","Cabo Setentrional",40)], "SS"),
 ("Índia", rare(chromite=49_486, manganese=813_442), [("IND","Orissa",50),("IND","Madhya Pradesh",30),("IND","Maharashtra",20)], "SS"),
 ("Turquia", rare(chromite=161_292, manganese=5_100), [("TUR","Elazığ",50),("TUR","Muğla",50)], "SS"),
 ("EUA", rare(tin=101, tungsten=2_370, manganese=32_119), [("USA","Nevada",50),("USA","Colorado",50)], "SS + Minerals Yearbook 1937"),
 ("Nova Caledônia", rare(nickel=5_000, chromite=47_084), [("NCL","Sud",70),("NCL","Norte",30)], "SS (níquel estimado)"),
 ("Austrália", rare(tin=3_027, tungsten=344), [("AUS","Tasmânia",60),("AUS","Nova Gales do Sul",40)], "SS"),
 ("Japão", rare(tin=2_300, chromite=37_868, manganese=66_683), [("JPN","Hokkaido",50),("JPN","Akita",50)], "SS"),
 ("Costa do Ouro", rare(manganese=411_024), [("GHA","Ocidental",100)], "SS"),
 ("Cuba", rare(chromite=69_257, manganese=151_981), [("CUB","Camagüey",50),("CUB","Santiago de Cuba",50)], "SS"),
 ("Reino Unido", rare(tin=2_099), [("GBR","South West",100)], "SS"),
 ("Iugoslávia", rare(chromite=53_190, manganese=2_696), [("MKD","Skopje",100)], "SS"),
 ("Grécia", rare(chromite=46_599, manganese=1_653), [("GRC","Tessália",100)], "SS"),
 ("Brasil", rare(chromite=3_829, manganese=153_734), [("BRA","Minas Gerais",100)], "SS"),
 ("Egito", rare(manganese=132_840), [("EGY","Sinai do Sul",100)], "SS"),
 ("Indochina Francesa", rare(tin=1_381, manganese=3_375), [("LAO","Khammouan",100)], "SS"),
 ("Tchecoslováquia", rare(manganese=91_567), [("SVK","Košice",100)], "SS"),
 ("Portugal", rare(tin=823, manganese=285), [("PRT","Castelo Branco",100)], "SS"),
 ("Argentina", rare(tin=940, tungsten=350), [("ARG","Jujuy",100)], "SS + Minerals Yearbook 1937"),
]

rare_total = sum(t for _, t, _, _ in RARE)
UNIT["rare_metals"] = rare_total / 90.0   # ~90 unidades/dia no mundo

out = {"_nota": "Produção de recursos por estado (código do mapa), em unidades/dia. Calculada a partir da produção real "
                "de 1936 por país (ver docs/fontes-recursos.md) e distribuída pelas regiões produtoras."}
missing, totals, table = [], {}, []
for res, rows in [("oil", OIL), ("coal", COAL), ("iron", IRON), ("bauxite", BAUXITE), ("rubber", RUBBER), ("rare_metals", RARE)]:
    for country, total, regions, note in rows:
        raw = total / UNIT[res]
        if raw < MIN_RAW:
            continue
        units = max(1, round(raw))
        wsum = sum(w for _, _, w in regions)
        # distribui em unidades inteiras pelo maior resto
        shares = []
        for iso, frag, w in regions:
            cands = [s for s in states if s['country'] == iso and frag.lower() in s['name'].lower()]
            if len(cands) > 1:
                exact = [s for s in cands if s['name'].lower() == frag.lower()]
                cands = exact or [min(cands, key=lambda s: len(s['name']))]
            if not cands:
                missing.append((res, country, iso, frag)); continue
            shares.append([cands[0]['code'], units * w / wsum])
        if not shares:
            continue
        ints = [[c, int(v)] for c, v in shares]
        rest = units - sum(v for _, v in ints)
        order = sorted(range(len(shares)), key=lambda i: shares[i][1] - int(shares[i][1]), reverse=True)
        for i in order[:rest]:
            ints[i][1] += 1
        for code, v in ints:
            if v > 0:
                out.setdefault(code, {})
                out[code][res] = out[code].get(res, 0) + v
        totals[res] = totals.get(res, 0) + units
        table.append((res, country, total, units, note))

print("não encontrados:", missing)
print("totais:", totals, "| estados:", len(out) - 1)
txt = "{\n" + ",\n".join(f'  {json.dumps(k, ensure_ascii=False)}: {json.dumps(v, ensure_ascii=False)}' for k, v in out.items()) + "\n}\n"
(R / 'data/common/state_resources.json').write_text(txt, encoding='utf-8')
json.dump({"unit": UNIT, "table": table}, open(R / 'tools/data/deposit_table.json', 'w'), ensure_ascii=False, indent=1)
