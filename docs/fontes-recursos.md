# Fontes dos recursos (produção de 1936)

Os depósitos de cada estado em `data/common/state_resources.json` saem da produção real de cada país,
convertida para a escala do jogo e distribuída entre as regiões onde a produção acontecia.
Script gerador: `tools/data/gen_deposits.py`.

## Fontes

- **SS** — *Statistical Summary of the Mineral Industry of the British Empire and Foreign Countries, 1936–1938*,
  Imperial Institute, Londres (HMSO). Cópia digital: https://nora.nerc.ac.uk/535290/1/SS_1936_1938.pdf
  (valores em toneladas longas; tratadas como toneladas no jogo, diferença de 1,6%).
- **Minerals Yearbook** — U.S. Bureau of Mines, *Minerals Yearbook 1937* (tungstênio: exportações da China em 1936)
  e *Review of 1940* (carvão da China e da Coreia em 1936).
- **Stat. Jb. 1935** — *Statistisches Jahrbuch für das Deutsche Reich 1935*, tabela 115 (borracha bruta por país,
  dados de 1934, os mais próximos de 1936 encontrados): https://digi.bib.uni-mannheim.de/fileadmin/statjahrb/514401303_1935/pdf/514401303_0673.pdf
- **estimativa de referência** — valores aproximados da literatura histórica, usados onde a fonte principal não traz
  o país (carvão: URSS, Japão, Manchukuo, Espanha, Turquia; tungstênio da Birmânia; níquel da Nova Caledônia).
  A conferir.

## Conversão para o jogo

| Recurso | 1 unidade/dia no jogo equivale a |
| --- | --- |
| Petróleo | 900.000 t de petróleo bruto por ano |
| Carvão | 3.500.000 t de carvão (linhito conta 1/3) por ano |
| Ferro (minério) | 1.000.000 t de minério de ferro por ano |
| Bauxita | 50.000 t de bauxita por ano |
| Borracha | 12.000 t de borracha natural por ano |
| Metais raros | 4.299 pontos do índice de valor por ano |

Países abaixo de 0,15 unidade não recebem jazida. Metais raros usam um índice de valor:
estanho (t de metal) × 1 + níquel (t de metal) × 1 + tungstênio (t de concentrado 60%) × 0,8
+ cromita (t de Cr₂O₃) × 0,04 + manganês (t de minério) × 0,012.

## Petróleo

| País (1936) | Produção (t de petróleo bruto/ano) | Unidades/dia | Fonte |
| --- | ---: | ---: | --- |
| EUA | 148.606.400 | 165 | SS |
| URSS | 27.163.000 | 30 | SS (inclui Sacalina) |
| Venezuela | 22.582.910 | 25 | SS |
| Romênia | 8.566.037 | 10 | SS |
| Irã | 8.198.119 | 9 | SS |
| Índias Orientais Holandesas | 6.336.122 | 7 | SS |
| México | 6.107.424 | 7 | SS |
| Iraque | 3.947.535 | 4 | SS |
| Colômbia | 2.640.700 | 3 | SS |
| Peru | 2.286.977 | 3 | SS |
| Argentina | 2.173.207 | 2 | SS |
| Trinidad | 1.813.292 | 2 | SS |
| Birmânia | 1.025.367 | 1 | SS |
| Bahrein | 663.600 | 1 | SS |
| Polônia | 502.500 | 1 | SS |
| Brunei | 451.621 | 1 | SS |
| Alemanha | 437.631 | 1 | SS |
| Equador | 334.431 | 1 | SS |
| Japão | 333.600 | 1 | SS |
| Índia | 267.342 | 1 | SS |
| Sarawak | 222.452 | 1 | SS |
| Canadá | 189.921 | 1 | SS |
| Egito | 179.638 | 1 | SS |

## Carvão

| País (1936) | Produção (t de carvão (linhito conta 1/3)/ano) | Unidades/dia | Fonte |
| --- | ---: | ---: | --- |
| EUA | 440.774.498 | 126 | SS |
| Reino Unido | 228.448.356 | 65 | SS |
| Alemanha | 208.202.625 | 59 | SS |
| URSS | 126.000.000 | 36 | estimativa de referência |
| França | 44.819.564 | 13 | SS |
| Japão | 41.800.000 | 12 | estimativa de referência |
| Polônia | 29.278.040 | 8 | SS |
| Bélgica | 27.426.968 | 8 | SS |
| China | 27.116.000 | 8 | Minerals Yearbook |
| Índia | 23.175.821 | 7 | SS |
| Tchecoslováquia | 17.219.945 | 5 | SS |
| África do Sul | 14.607.313 | 4 | SS |
| Manchukuo | 13.600.000 | 4 | estimativa de referência |
| Países Baixos | 12.600.340 | 4 | SS |
| Austrália | 12.375.225 | 4 | SS |
| Canadá | 11.284.302 | 3 | SS |
| Espanha | 7.000.000 | 2 | estimativa de referência (guerra civil) |
| Hungria | 3.121.404 | 1 | SS |
| Turquia | 2.300.000 | 1 | estimativa de referência |
| Coreia | 2.282.000 | 1 | Minerals Yearbook |
| Indochina Francesa | 2.116.108 | 1 | SS |
| Iugoslávia | 1.744.767 | 1 | SS |
| Chile | 1.718.274 | 1 | SS |
| Formosa | 1.716.236 | 1 | SS |
| Nova Zelândia | 1.281.706 | 1 | SS |
| México | 1.276.000 | 1 | SS |
| Áustria | 1.181.457 | 1 | SS |
| Itália | 1.043.025 | 1 | SS |
| Romênia | 830.937 | 1 | SS |
| Noruega (Svalbard) | 771.442 | 1 | SS |
| Rodésia do Sul | 693.947 | 1 | SS |
| Brasil | 651.738 | 1 | SS |
| Bulgária | 612.563 | 1 | SS |

## Ferro (minério)

| País (1936) | Produção (t de minério de ferro/ano) | Unidades/dia | Fonte |
| --- | ---: | ---: | --- |
| EUA | 49.729.264 | 50 | SS |
| França | 32.775.667 | 33 | SS |
| URSS | 27.477.000 | 27 | SS |
| Reino Unido | 12.701.386 | 13 | SS |
| Suécia | 11.065.890 | 11 | SS |
| Alemanha | 7.450.638 | 7 | SS |
| Luxemburgo | 4.818.667 | 5 | SS |
| Manchukuo | 2.583.000 | 3 | SS |
| Índia | 2.526.931 | 3 | SS |
| Argélia | 2.136.248 | 2 | SS |
| Espanha | 2.013.578 | 2 | SS |
| Austrália | 1.889.599 | 2 | SS |
| Malásia | 1.654.996 | 2 | SS |
| Chile | 1.332.325 | 1 | SS |
| Tchecoslováquia | 1.072.414 | 1 | SS |
| Marrocos Espanhol | 1.030.501 | 1 | SS |
| Áustria | 1.008.110 | 1 | SS |
| Terra Nova | 893.308 | 1 | SS |
| Itália | 843.921 | 1 | SS |
| Noruega | 833.435 | 1 | SS |
| Japão | 742.500 | 1 | SS |
| Tunísia | 715.000 | 1 | SS |
| Serra Leoa | 566.595 | 1 | SS |
| Filipinas | 529.041 | 1 | SS |
| Polônia | 461.253 | 1 | SS |
| Cuba | 449.612 | 1 | SS |
| Iugoslávia | 443.738 | 1 | SS |
| África do Sul | 359.219 | 1 | SS |
| Grécia | 275.845 | 1 | SS |
| Hungria | 275.256 | 1 | SS |
| Coreia | 230.700 | 1 | SS |
| Bélgica | 187.649 | 1 | SS |

## Bauxita

| País (1936) | Produção (t de bauxita/ano) | Unidades/dia | Fonte |
| --- | ---: | ---: | --- |
| França | 639.250 | 13 | SS |
| EUA | 372.005 | 7 | SS |
| Hungria | 323.893 | 6 | SS |
| Iugoslávia | 287.560 | 6 | SS |
| Itália | 258.104 | 5 | SS |
| Guiana Holandesa | 231.136 | 5 | SS |
| Guiana Britânica | 209.321 | 4 | SS |
| URSS | 200.000 | 4 | SS (estimativa) |
| Índias Orientais Holandesas | 131.619 | 3 | SS |
| Grécia | 127.846 | 3 | SS |
| Alemanha | 12.229 | 1 | SS |
| Romênia | 10.658 | 1 | SS |

## Borracha

| País (1936) | Produção (t de borracha natural/ano) | Unidades/dia | Fonte |
| --- | ---: | ---: | --- |
| Malásia | 475.000 | 40 | Stat. Jb. 1935 |
| Índias Orientais Holandesas | 384.000 | 32 | Stat. Jb. 1935 |
| Ceilão | 80.000 | 7 | Stat. Jb. 1935 |
| Bornéu Britânico | 29.000 | 2 | Stat. Jb. 1935 |
| Indochina Francesa | 20.000 | 2 | Stat. Jb. 1935 |
| Sião | 18.000 | 2 | Stat. Jb. 1935 |
| Índia e Birmânia | 12.000 | 1 | Stat. Jb. 1935 |
| América do Sul | 9.000 | 1 | Stat. Jb. 1935 |
| África | 3.000 | 1 | Stat. Jb. 1935 |

## Metais raros

| País (1936) | Produção (pontos do índice de valor/ano) | Unidades/dia | Fonte |
| --- | ---: | ---: | --- |
| Canadá | 75.810 | 18 | SS |
| Malásia | 68.478 | 16 | SS |
| URSS | 53.100 | 12 | SS |
| Índias Orientais Holandesas | 30.830 | 7 | SS |
| Bolívia | 24.091 | 6 | SS |
| China | 16.510 | 4 | SS + Minerals Yearbook 1937 |
| Sião | 12.633 | 3 | SS |
| Índia | 11.741 | 3 | SS |
| Birmânia | 11.438 | 3 | SS + estimativa |
| África do Sul | 10.600 | 2 | SS |
| Nigéria | 9.648 | 2 | SS |
| Congo Belga | 7.303 | 2 | SS |
| Rodésia do Sul | 7.220 | 2 | SS |
| Nova Caledônia | 6.883 | 2 | SS (níquel estimado) |
| Turquia | 6.513 | 2 | SS |
| Costa do Ouro | 4.932 | 1 | SS |
| Japão | 4.615 | 1 | SS |
| Cuba | 4.594 | 1 | SS |
| Austrália | 3.302 | 1 | SS |
| EUA | 2.382 | 1 | SS + Minerals Yearbook 1937 |
| Iugoslávia | 2.160 | 1 | SS |
| Reino Unido | 2.099 | 1 | SS |
| Brasil | 1.998 | 1 | SS |
| Grécia | 1.884 | 1 | SS |
| Egito | 1.594 | 1 | SS |
| Indochina Francesa | 1.422 | 1 | SS |
| Argentina | 1.220 | 1 | SS + Minerals Yearbook 1937 |
| Tchecoslováquia | 1.099 | 1 | SS |
| Portugal | 826 | 1 | SS |
