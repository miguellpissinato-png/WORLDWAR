# Fontes do terreno do mapa e dos sons de batalha

## Terreno (`data/map/terrain.webp`, gerado por `tools/map/build_terrain.py`)

- Relevo sombreado: Natural Earth, "Shaded Relief" (domínio público). Arquivo `shadedrelief.jpg`
  (10800x5400) tirado do pacote `basemap-data` do PyPI.
- Cobertura do solo e neve: NASA Blue Marble Next Generation (domínio público). Arquivo `bmng.jpg`
  (5400x2700), mesmo pacote.
- Rios e lagos: Natural Earth 10m (`rivers_lake_centerlines`, `rivers_europe`, `rivers_north_america`,
  `lakes`), domínio público, de `github.com/nvkelso/natural-earth-vector`.

Como gerar de novo: `pip download basemap-data --no-deps`, extrair `mpl_toolkits/basemap_data/`, baixar os
geojson e rodar `python3 tools/map/build_terrain.py <pasta das imagens> <pasta dos geojson>`.

Observação: a neve é a de um mosaico de satélite (cobertura de uma época do ano), não muda com as estações.

## Sons de batalha (`audio/sfx/*.ogg`, gerados por `tools/audio/gen_sfx.py`)

Sintetizados pelo próprio script (ruído filtrado, envelopes e reverberação): tiros, rajadas de metralhadora
e explosões. Não há sons de terceiros.

## Música (`audio/music/`)

Enviada pelo Miguel; nomes originais `cscprod-*` (ao que parece do Pixabay). Conferir a licença antes de
distribuir o jogo.
