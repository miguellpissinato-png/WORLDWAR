# WorldWar

Jogo de grande estratégia em tempo real com pausa, ambientado na Segunda Guerra Mundial (1936–1945).
Feito no Godot 4.5 com GDScript.

## Como abrir

1. Instale o [Godot 4.5](https://godotengine.org/download) (versão padrão, não a .NET).
2. No Godot, clique em **Importar** e escolha o arquivo `project.godot` desta pasta.
3. Aperte **F5** para rodar.

## Estado atual (Fase 1)

- Mapa mundial com 3.681 estados (divisões regionais do Natural Earth, domínio público), projeção de Miller
- Fronteiras de 1º/01/1936 com 74 países, colônias e as principais diferenças das fronteiras atuais
  (Prússia Oriental, leste da Polônia, Manchukuo, Coreia e Taiwan japonesas, Fiume e Ístria etc.)
- Visual: terreno com textura, cores dos países translúcidas, fronteiras grossas com faixa clara,
  linhas finas entre estados, oceano escuro, nomes curvos sobre os países e capitais com estrela
- Mar com profundidade real (batimetria do Natural Earth): plataforma continental mais clara perto da
  costa, mar aberto mais escuro, linhas de profundidade e 950 zonas marítimas demarcadas e com nome
  (ex.: "Mar do Norte 3"); os detalhes aparecem conforme o zoom
- Clique num estado para ver os dados e construir (só nos seus estados)
- Relógio do jogo com pausa e 5 velocidades; fila de construção; tudo via comandos
- 20 testes automáticos

Controles: roda do mouse = zoom, botão direito = arrastar, WASD = mover, espaço = pausar, 1–5 = velocidade.

Os números de fábricas e os líderes de países menores ainda são provisórios (`data/`).

## Mapa

Os arquivos `data/map/` são gerados a partir do Natural Earth: `tools/map/build_map.py` (estados) e
`tools/map/build_sea.py` (profundidade e zonas marítimas).
Os donos de cada estado em 1936 ficam em `data/scenarios/1936/owners.json` (regras por país moderno
e exceções por estado), e podem ser editados sem programar.

## Testes

```
tests/run.sh                      # usa o comando "godot" do sistema
GODOT=/caminho/do/godot tests/run.sh
```

No Windows, sem bash: `godot --headless -s tests/run_tests.gd`

Regras de arquitetura e convenções: veja `CLAUDE.md`. Design completo: `docs/design.md`.
