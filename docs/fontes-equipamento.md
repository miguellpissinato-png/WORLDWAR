# Fontes do equipamento militar

Dados históricos usados em `tools/data/equipment_table.json` (que gera `data/common/equipment.json` e
`data/common/research.json` com `python3 tools/data/gen_equipment.py`). Pesquisa feita em 19/11/2026.

- Os números históricos (calibre, alcance, cadência, blindagem, peso, velocidade, bombas, unidades fabricadas)
  vêm das fontes abaixo. Onde as fontes dão uma faixa (ex.: 500–550 tiros/min), o jogo usa um valor do meio
  e mostra a faixa na ficha.
- Campos marcados como **a conferir** não foram achados numa fonte durante a pesquisa e aparecem assim no jogo.
- Não usamos números de outros jogos (wikis de jogos de tanque/avião ficaram de fora como fonte). Exceção
  provisória: o Yak-1 só tem a página de museu do simulador IL-2 Sturmovik, por isso velocidade, ano e armas
  dele estão todos marcados a conferir.
- Valores de jogo (ataque, custo em dias-fábrica, recursos por unidade, dias de pesquisa) são fórmulas de
  design explicadas em `tools/data/gen_equipment.py`, não dados históricos.
- "Tiger H1": o Tiger I se chamava Ausf. H1 e depois foi renomeado Ausf. E. É o mesmo tanque; o outro
  Tiger do jogo é o Tiger II (Königstiger).

## Fuzis

- **Karabiner 98k** (ALE, 1935)
  - https://en.wikipedia.org/wiki/Karabiner_98k
- **Mosin-Nagant M91/30** (URS, 1930) — a conferir: range_m
  - https://en.wikipedia.org/wiki/Mosin%E2%80%93Nagant
- **M1 Garand** (EUA, 1936)
  - https://en.wikipedia.org/wiki/M1_Garand
- **Lee-Enfield No. 4 Mk I** (RUN, 1941)
  - https://en.wikipedia.org/wiki/Lee%E2%80%93Enfield

## Fuzis de precisão

- **Kar 98k com luneta ZF39** (ALE, 1939)
  - https://en.wikipedia.org/wiki/Karabiner_98k
  - https://www.lonesentry.com/ordnance/?p=2681
- **Mosin M91/30 com luneta PU** (URS, 1942) — a conferir: year, range_m
  - https://en.wikipedia.org/wiki/Mosin%E2%80%93Nagant
- **Springfield M1903A4** (EUA, 1943) — a conferir: magazine
  - https://www.gunsandammo.com/editorial/best-world-war-ii-sniper-rifle-4-springfield-m1903a4/527413
  - https://www.forgottenweapons.com/m1903a4-americas-ww2-sniper-rifle/

## Submetralhadoras

- **MP 40** (ALE, 1940)
  - https://en.wikipedia.org/wiki/MP_40
- **PPSh-41** (URS, 1941)
  - https://en.wikipedia.org/wiki/PPSh-41
- **Thompson M1928A1** (EUA, 1938) — a conferir: year
  - https://en.wikipedia.org/wiki/Thompson_submachine_gun
  - https://www.dday-overlord.com/en/material/weapons/thompson
- **Thompson M1A1** (EUA, 1942) — a conferir: year
  - https://en.wikipedia.org/wiki/Thompson_submachine_gun

## Tanques

- **Panzer II (Ausf. a–C)** (ALE, 1936)
  - https://en.wikipedia.org/wiki/Panzer_II
  - https://lonesentry.com/ordnance/tag/tank/page/2
- **Panzer III Ausf. J** (ALE, 1941) — a conferir: speed_kmh
  - https://en.wikipedia.org/wiki/Panzer_III
  - https://lonesentry.com/ordnance/tag/sdkfz-141
- **Panzer IV Ausf. F2** (ALE, 1942)
  - https://www.historyofwar.org/articles/weapons_panzer_IV_ausf_F2.html
  - https://www.quartermastersection.com/german/afvs/451/PzIVAsufF
- **Panzer IV Ausf. H** (ALE, 1943)
  - https://en.wikipedia.org/wiki/Panzer_IV
  - https://www.ecured.cu/Tiger-I
- **Panzer V Panther** (ALE, 1943)
  - https://en.wikipedia.org/wiki/Panther_tank
  - https://www.tankmuseum.org/article/panther
  - https://tanks-encyclopedia.com/ww2/germany/Panzer-V_Panther.php
- **Tiger I (Ausf. H1, depois Ausf. E)** (ALE, 1942)
  - https://en.wikipedia.org/wiki/Tiger_I
  - https://military-history.fandom.com/wiki/Tiger_I_tank
- **Tiger II (Königstiger)** (ALE, 1944)
  - https://en.wikipedia.org/wiki/Tiger_II
  - https://www.dday-overlord.com/?p=134267
- **T-26 (mod. 1933)** (URS, 1933) — a conferir: speed_kmh, gun_len
  - https://en.wikipedia.org/wiki/T-26
- **BT-7 (mod. 1937)** (URS, 1935) — a conferir: speed_kmh, armour_mm, gun_len
  - https://en.wikipedia.org/wiki/BT-7
- **T-34/76 (mod. 1941)** (URS, 1941)
  - https://en.wikipedia.org/wiki/T-34
  - https://www.tankmuseum.org/tank-nuts/tank-collection/t-34
- **M4 Sherman (75 mm)** (EUA, 1942)
  - https://en.wikipedia.org/wiki/M4_Sherman
  - https://en.namu.wiki/w/M4%20%EC%85%94%EB%A8%BC

## Caças

- **Messerschmitt Bf 109 E-3** (ALE, 1939)
  - https://chuckhawks.com/best_fighter_planes.htm
  - https://battleofbritain1940.com/messerschmitt-bf-109/
  - https://www.historyofwar.org/articles/weapons_bf_109E.html
- **Focke-Wulf Fw 190 A-8** (ALE, 1944) — a conferir: year, guns
  - https://militarymachine.com/ww2-aircraft/compare/p-51d-mustang-vs-fw-190a
  - https://aerocorner.com/blog/best-ww2-fighter-planes/
- **Hawker Hurricane Mk I** (RUN, 1937)
  - https://weaponsandwarfare.com/?p=12603
  - https://historyrise.com/article/comparing-the-spitfire-to-its-contemporaries-hawker-hurricane-and-messerschmitt-bf-109/
- **Supermarine Spitfire Mk I** (RUN, 1938)
  - https://historyrise.com/article/comparing-the-spitfire-to-its-contemporaries-hawker-hurricane-and-messerschmitt-bf-109/
  - https://www.iwm.org.uk/history/second-world-war/battle-of-britain/iconic-aircraft
- **North American P-51D Mustang** (EUA, 1944) — a conferir: year
  - https://militarymachine.com/ww2-aircraft/p-51d-mustang
  - https://en.wikipedia.org/wiki/North_American_P-51_Mustang
- **Mitsubishi A6M2 Zero** (JAP, 1940) — a conferir: guns
  - https://aerocorner.com/blog/best-ww2-fighter-planes/
- **Yakovlev Yak-1** (URS, 1941) — a conferir: year, speed_kmh, guns
  - https://il2sturmovik.com/museum/fighters/yak-1-ser69

## Ataque ao solo

- **Junkers Ju 87 Stuka** (ALE, 1937) — a conferir: year
  - https://lonesentry.com/manuals/tme30/ch10sec5table2.html
  - https://aerocorner.com/blog/german-bombers-ww2/
- **Ilyushin Il-2 Sturmovik** (URS, 1941)
  - https://en.wikipedia.org/wiki/Ilyushin_Il-2
  - https://www.airandspaceforces.com/PDF/MagazineArchive/Magazine%20Documents/2008/January%202008/0108classics.pdf

## Bombardeiros

- **Heinkel He 111 H** (ALE, 1937) — a conferir: year
  - https://militarymachine.com/ww2-aircraft/he-111h
  - https://battleofbritain1940.com/german-aircraft-of-the-battle-of-britain/heinkel-he-111/
  - https://migflug.com/aircraft/he-111/
- **Junkers Ju 88 A-4** (ALE, 1940) — a conferir: year
  - https://aerocorner.com/blog/german-bombers-ww2/
- **Boeing B-17 Flying Fortress** (EUA, 1938)
  - https://www.worldhistory.org/B-17_Flying_Fortress/
  - https://b17flyingfortress.de/en/der-bomber/technische-daten/
  - https://445bg.org/b-17.html
- **Avro Lancaster** (RUN, 1942) — a conferir: year, speed_kmh
  - https://www.worldhistory.org/audioplayer/en/1-22863/6007dfa311d1d3fadb16cc7838b1d4a6/

## Artilharia

- **10,5 cm leFH 18** (ALE, 1935)
  - https://en.wikipedia.org/wiki/10.5_cm_leFH_18
- **15 cm sFH 18** (ALE, 1934)
  - https://en.wikipedia.org/wiki/15_cm_sFH_18
  - https://en.rcamuseum.com/?p=586
- **Obuseiro M2A1 de 105 mm** (EUA, 1941)
  - https://americangimuseum.org/collections/restored-vehicles/m2a1-105mm-howitzer-1941-1953/
  - https://www.dday-overlord.com/?p=134376
  - https://www.quartermastersection.com/american/artillery/270/105mmM2A1
- **QF 25-pounder** (RUN, 1940) — a conferir: range_m, rpm, weight_kg
  - https://en.wikipedia.org/wiki/Ordnance_QF_25-pounder
- **Canhão divisional ZiS-3 de 76 mm** (URS, 1942) — a conferir: shell_kg, rpm
  - https://en.wikipedia.org/wiki/76_mm_divisional_gun_M1942_(ZiS-3)
- **Obuseiro M-30 de 122 mm** (URS, 1939) — a conferir: shell_kg
  - https://en.wikipedia.org/wiki/122_mm_howitzer_M1938_(M-30)

## Tropas e especializações

Anos de jogo para paraquedistas (1938) e tropas de desembarque (1937) ainda estão a conferir; as demais
especializações começam em 1936. Unidades só passam a existir na parte 2 (exército).
