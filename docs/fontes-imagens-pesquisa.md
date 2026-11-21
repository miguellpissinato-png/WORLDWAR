# Fontes das imagens da pesquisa

Imagens em `ui/research/<tech>.png` (660x300, fundo transparente). Quando existe o PNG, o jogo usa ele no lugar do desenho SVG gerado por `tools/data/gen_research_art.py`.
Processamento: recorte do fundo branco e centralização. Nos perfis alemães de avião, a suástica da deriva foi coberta com a cor da cauda (mesma regra da bandeira, Lei 7.716/89).
Itens sem PNG continuam com o desenho SVG; serão trocados em sessões futuras, sempre conferindo a variante exata.

## Tanques — Tank Encyclopedia (ilustrações de David Bocquelet e equipe)
Uso a conferir antes de distribuir o jogo (o site não declara licença livre).

| Tecnologia | Variante na imagem | Arquivo original |
|---|---|---|
| `tech_panzer_ii` | Panzer II Ausf.C | https://tanks-encyclopedia.com/wp-content/uploads/imported/ww2_germany_panzer_ii_php/KVouBAm.jpeg |
| `tech_panzer_iii_j` | Panzer III Ausf.J (5 cm L/42) | https://tanks-encyclopedia.com/wp-content/uploads/imported/ww2_nazi_germany_panzer_iii_ausf_g/2ZPmoo1.jpeg |
| `tech_panzer_iv_f2` | Panzer IV Ausf.F2, Líbia 1942 | https://tanks-encyclopedia.com/wp-content/uploads/2021/12/panzer_IV_AusfF2_libya.png |
| `tech_panzer_iv_h` | Panzer IV Ausf.H, 2ª Panzerdivision, França 1944 | https://tanks-encyclopedia.com/wp-content/uploads/imported/ww2_nazi_germany_panzer_iv_ausf_h/RZkH3z8.jpeg |
| `tech_panther` | Panther Ausf.D2, Pz.Abt. 51 | https://tanks-encyclopedia.com/ww2/germany/Medium_Tanks/Panzer-V_Panther/Panther_Ausf-D2_PzAbt51.png |
| `tech_tiger_i` | Tiger I Ausf.H1 de início de produção, s.Pz.Abt. 502, Leningrado | https://tanks-encyclopedia.com/wp-content/uploads/2019/07/PanzerVI_Tiger-I_AusfH1-Earlyprod-PzAbt502Lening.png |
| `tech_tiger_ii` | Tiger II com torre Henschel, s.Pz.Abt. 501, Ardenas 1944 | https://tanks-encyclopedia.com/wp-content/uploads/2019/09/Tiger-II_222-2sPzAbt501_Ardennes-44.png |
| `tech_m4_sherman` | M4 Sherman (75 mm), Tunísia, março 1943 | https://tanks-encyclopedia.com/wp-content/uploads/2017/07/M4_Sherman_tunisia_march43-1.png |

## Aviões e armas — Wikimedia Commons

| Tecnologia | Descrição | Licença | Autor | Página |
|---|---|---|---|---|
| `tech_bf109e` | Bf 109 E-3 | CC BY-SA 2.0 de | The original uploader was B. Huber at German Wikipedia.

(Or | https://commons.wikimedia.org/wiki/File:Bf109_E3_neu2_eingezogen.jpg |
| `tech_fw190a8` | Fw 190 A-8/R2 flown by Major Walter Dahl, CO of IV.(Sturm)/JG 300 | CC BY-SA 3.0 | B. Huber | https://commons.wikimedia.org/wiki/File:Fw_190_A8_Dahl_Wiki.jpg |
| `tech_hurricane_i` | Hawker Hurricane Mk I of the 46th Squadron RAF during the Norwegian campaign, Ma | CC BY-SA 4.0 | Martin Čížek | https://commons.wikimedia.org/wiki/File:Hurricane_I_46_Squadron.jpg |
| `tech_spitfire_i` | Spitfire Mk I , No. 66 Squadron RAF , PO Crelin Bodie. | CC BY-SA 3.0 | B. Huber | https://commons.wikimedia.org/wiki/File:Spitfire_MKI_Wiki.jpg |
| `tech_p51d` | ©John " Wily " Mollison P-51D flown by Capt. Ray Littge | CC BY-SA 3.0 | Wily at English Wikipedia | https://commons.wikimedia.org/wiki/File:North_American_P-51D_Mustang_Ray_Littge_profile_drawing.jpg |
| `tech_kar98k` | Darstellung eines Karabiner 98k | CC BY-SA 4.0 | Armémuseum (The Swedish Army Museum) through the Digital Mus | https://commons.wikimedia.org/wiki/File:Kar_98K_noBG.jpg |
| `tech_mp40` | MP40 — Erma, 1943 manufacturing, extended stock. | CC BY-SA 3.0 | Quickload at English Wikipedia | https://commons.wikimedia.org/wiki/File:MP_40_AYF_2.JPG |
| `tech_ppsh41` | Soviet army ppsh 41 | CC BY-SA 3.0 | Lposka | https://commons.wikimedia.org/wiki/File:PPSh-41_from_soviet_noBG.png |
| `tech_m1_garand` | M1 Garand rifle, USA. Caliber .30-06. From the collections of Armémuseum (Swedis | CC BY-SA 4.0 | Armémuseum (The Swedish Army Museum) | https://commons.wikimedia.org/wiki/File:M1_Garand_rifle_USA_noBg_cropped.jpg |
| `tech_lee_enfield_no4` | Lee-Enfield No 4 Mk I rifle, made in 1943. Caliber .303" British. From the colle | CC BY-SA 4.0 | Armémuseum (The Swedish Army Museum) | https://commons.wikimedia.org/wiki/File:Lee-Enfield_No_4_Mk_I_(1943)_-_AM.032027_noBG.jpg |
| `tech_mosin_pu` | Soviet Mosin-Nagant m/91-30 sniper rifle, captured by Finland. Photographed in M | CC BY-SA 3.0 | https://commons.wikimedia.org/wiki/User:MKFI | https://commons.wikimedia.org/wiki/File:Mosin-Nagant_m91-30_sniper_noBG.png |

## Descartadas na conferência

- Thompson: a foto livre achada é de uma "Model 1928" com nº de série 5768 (Colt 1921 remarcada), não M1928A1.
- T-34: o perfil encontrado do modelo 1941 tem marca-d'água; a página soviética do Tank Encyclopedia estava com erro.
- Panzer III: o perfil em dunkelgelb tem o canhão longo L/60 (Ausf.J tardio); o jogo usa o L/42.
