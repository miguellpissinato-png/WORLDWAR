# WorldWar — instruções para o Claude Code

Jogo de grande estratégia em tempo real com pausa, Segunda Guerra Mundial (1936–1945).
Godot 4.5, GDScript. Desenvolvedor: Miguel (fala português; responda em português).
Documento de design completo: `docs/design.md`.

## Regras de arquitetura (não quebrar)

1. **A simulação não conhece a interface.** Nada em `src/` pode usar nós de cena, `get_node`,
   input ou UI. A simulação é feita de classes `RefCounted` e roda igual com ou sem tela.
2. **Só comandos mudam a simulação.** Toda ação de jogador ou da IA é um `Command`
   (`src/commands/`). Ele é enviado com `Simulation.submit()` e aplicado no início da próxima
   hora do jogo, ou na hora com `Simulation.apply_pending()` (a interface do jogo solo faz isso em
   `main.submit()`; no multiplayer só o host aplica). A interface nunca altera `GameState`
   diretamente. Isso é o que permite multiplayer, salvar/carregar e replays.
3. **Todo comando é serializável** (`to_dict()` / `CommandRegistry.from_dict()`), porque vai
   passar pela rede no multiplayer.
4. **Conteúdo em dados, não em código.** Países, estados, construções, tecnologias e cenários
   ficam em JSON dentro de `data/`. Adicionar conteúdo não deve exigir programar.
5. **Determinismo.** Nada de `randi()` solto ou do relógio do sistema na simulação. Sorteios
   usam o gerador de `GameState` (com semente salva).
6. **Tempo em horas inteiras** desde 1º/01/1936 00:00 (`GameDate`).

## Pastas

- `src/sim/` — estado do jogo e a simulação; `src/sim/systems/` um arquivo por sistema
- `src/commands/` — um arquivo por tipo de comando + `command_registry.gd`
- `src/data/` — carregamento dos JSON
- `ui/` — cenas e scripts de interface
- `data/common/` — definições gerais (construções etc.); `data/scenarios/<ano>/` — cenários
- `ui/map/` — desenho do mapa: `map_view.gd` (imagem de IDs + shader), `map.gdshader`,
  `map_labels.gd` (nomes curvos e capitais), `map_camera.gd`
- `tools/map/` — scripts Python que geram `data/map/` a partir do Natural Earth
- `tests/` — testes automáticos da simulação

## Mapa

- `data/map/states.json` (dados) e `data/map/shapes.json` (contornos, só a interface usa) são gerados;
  `sea_zones.json`, `sea_shapes.json` e `sea_depth.png` vêm de `tools/map/build_sea.py`;
  não editar à mão. O id de cada estado depende da ordem dos códigos: use sempre o `code` nos dados.
- Donos por cenário: `data/scenarios/<ano>/owners.json`. Capitais e construções iniciais usam o `code`.
- Na imagem de IDs, azul = 255 marca zona marítima e azul = 0 marca estado de terra.
- O mapa é pintado por um shader que lê uma imagem de IDs; mudar o dono de um estado = chamar
  `MapView.color_by_owner()` de novo (não precisa redesenhar polígonos).

## Economia e recursos

- Recursos, extração, economia e mercado: `data/common/resources.json`. Produção de 1936 por estado:
  `data/common/state_resources.json`, gerada por `tools/data/gen_deposits.py` a partir de dados reais
  (fontes em `docs/fontes-recursos.md`). Nunca inventar números: novos dados vêm com fonte.
- Extração = produção de 1936 + níveis da construção `extraction_<recurso>` (10% cada), até a jazida
  (2x a produção de 1936). Construções de extração são geradas em `ConstructionSystem.definition()`.
- Por dia (`EconomySystem`): a extração de cada recurso se divide por `Country.goods_share` entre bens de
  consumo (viram dinheiro, limitados por fábricas civis x `goods_per_factory`) e estoque (`stockpile`).
- Preço mundial (`MarketSystem`): demanda (fábricas civis do mundo) / oferta (extração mundial).
- Comércio = propostas de lote único (`ProposeTradeCommand`), preço por unidade com teto de
  mercado + `max_markup`. A IA responde na hora (`TradeSystem.ai_accepts`); jogadores humanos
  (`GameState.human_tags`) respondem com `RespondTradeCommand`. Doação: `DonateResourcesCommand`.
- Construções custam dinheiro (`money_cost`) além do trabalho das fábricas civis.

## Indústria, pesquisa e produção militar

- Fábricas são uma construção só (`factory`). `Country.civil_share` divide entre civis (bens de consumo e
  construção) e militares (linhas de produção): `GameState.civil_factories()` / `military_factories()`.
  `SetCivilShareCommand` muda o alvo; `IndustrySystem` converte `industry.conversion_per_day` por dia.
  Nunca usar `total_building(tag, "factory")` para economia ou produção: usar as funções civil/militar.
- Equipamento: dados históricos com fontes em `tools/data/equipment_table.json`; `tools/data/gen_equipment.py`
  gera `data/common/equipment.json` e `data/common/research.json` (não editar à mão). Campos sem fonte
  vão em `estimado` e aparecem "a conferir" na interface. Fontes listadas em `docs/fontes-equipamento.md`.
- Pesquisa (`ResearchSystem`): 5 áreas, vagas por país, penalidade por ano adiantado (limite
  `max_years_ahead`) e por projeto estrangeiro (`origin`). Começo do cenário: `data/scenarios/<ano>/research.json`.
- Produção (`ProductionSystem`): linhas pegam fábricas militares em ordem; eficiência sobe por dia;
  recursos saem do estoque e a falta reduz a velocidade até `shortage_floor` (estoque nunca negativo).
  Regras em `military_production` de `data/common/buildings.json`.
- Eventos para o jogador: `GameState.add_event(tags, texto, tipo)`; o tipo vira o prefixo no registro.

## Exército

- `data/common/army.json`: tipos de regimento (equipamento necessário por categoria, marcha em km/dia),
  limites (regimentos por grupo, grupos por general) e generais. Nomes dos generais (fictícios, decisão
  do Miguel: nada de generais reais) em `data/common/general_names.json`, sorteados com `GameState.rng`.
- `ArmyGroup` (regimentos, estado atual, caminho, km andados no trecho) e `General` (ataque, defesa,
  velocidade 1–5). `ArmySystem`: formar regimento na hora com o melhor equipamento do depósito,
  dissolver, caminho por terra (Dijkstra em km, só no próprio país por enquanto).
- `MovementSystem.hourly_update` anda o grupo hora a hora; `MapGeo.km()` dá a distância real.
  Vizinhança por terra: `data/map/adjacency.json`, gerado por `tools/map/build_adjacency.py`.
- Exército inicial: `data/scenarios/<ano>/armies.json` (valores de exemplo, marcados).

## Inteligência

- `data/common/intelligence.json`. Cada país tem espionagem (`intel_offense`) e contraespionagem
  (`intel_defense`), níveis 1–5, comprados com dinheiro.
- `StartInvestigationCommand`: custa dinheiro, pode ser barrada na infiltração; depois, a cada dia,
  os agentes podem ser presos (`IntelligenceSystem`). Ao terminar, gera um relatório **congelado**
  (com erro que cai com o nível) em `Country.intel_reports[alvo]`. Avisos vão para `GameState.events`.
- **Regra de interface:** produção, estoques, jazidas e dinheiro de outros países só aparecem na tela
  de escolha de país (`ui/panels/start_screen.gd`) ou via relatório de inteligência. O mercado mostra
  apenas lotes à venda e preços.

## Interface

- `ui/main.gd` orquestra; painéis em `ui/panels/` (escolha de país, economia, mercado, inteligência,
  pesquisa, produção, exército); a ficha de equipamento é `ResearchPanel.equipment_sheet()`.
- Visual "quartel-general" (aprovado pelo Miguel, proposta A do Design): tudo passa por `ui/ui_style.gd`.
  Painéis `#17191c` com fio dourado `#c9b37a` e sombra; títulos em Oswald maiúsculo espaçado
  (`title_label`, `section`, `header`); números em Oswald (`number_label`); texto em Inter.
  Fontes em `ui/fonts/` (OFL, recortadas para latim); ícones de traço brancos em `ui/icons/*.svg`,
  coloridos com `UiStyle.icon(nome, cor)`. Não criar estilos soltos nos painéis: usar as funções do UiStyle.
- Barra superior: país (abre ficha), Tesouro (abre detalhe), Fábricas civis|militares, Pesquisa,
  Grupos, Recursos (abre tabela com estoque, variação de ontem e preço), sino de Avisos
  (`GameState.events` do jogador + falta de recurso na produção), data, pausa e 5 barras de velocidade.
  As caixas abertas são uma só (`_drop` em `main.gd`); Esc ou clique fora fecham.
- Menu inicial (`ui/panels/main_menu.gd`, modelo "cartaz central" escolhido pelo Miguel): imagem de
  cartazes `ui/menu/menu_bg.jpg`, título na fonte de estêncil Big Shoulders (OFL), Single player (vai para a
  escolha de país), Multiplayer (aviso de "em breve" até existir a rede), Configurações (opções a definir)
  e Sair (some na versão web). A escolha de país tem "Voltar ao menu".
- As fontes não têm símbolos como ● ▶ ❚: usar ícones (`ui/icons`) ou `UiStyle.dot()`.
- Tropas no mapa (`ui/units/`): bonecos 3D numa camada 3D por cima do mapa 2D (`UnitLayer`). Modelos:
  `SoldierModel` (articulado, uniforme de `data/common/uniforms.json`), `TankModel`, `PlaneModel`,
  montados com `MeshKit`. Soldado com tamanho fixo no mapa (cabe nos países); veículos em escala de
  miniatura (`VEHICLE_SCALE`). O Miguel quer bonecos realistas: os modelos finais virão do Blender.
- O mundo dá a volta em x: `MapView` desenha cópias do mapa em ±largura, `MapView.wrap_point()` leva
  pontos para o mapa original e `MapCamera.near()` leva um ponto para a cópia mais perto da câmera.
  Zoom mínimo calculado (`MapCamera.min_zoom()`) para nunca aparecer faixa cinza fora do mapa.

## Testes

Rodar sempre depois de mudar algo em `src/`:

```
godot --headless --import            # só na primeira vez ou depois de criar classes novas
godot --headless -s tests/run_tests.gd
```

Cada arquivo `tests/test_*.gd` estende `TestCase`; cada método `test_*` é um teste.
Todo sistema novo da simulação vem com testes.

## Conteúdo e legalidade

Mecânicas do gênero e fatos históricos podem ser usados. Não copiar nada de Hearts of Iron
ou de outros jogos: nomes, textos, arte, ícones, valores de arquivos de dados.
Os números em `data/` hoje são valores de exemplo, não dados históricos conferidos.
A imagem do menu (`ui/menu/menu_bg.jpg`) foi enviada pelo Miguel: o cartaz da direita (Nações Unidas,
governo dos EUA, 1943) é domínio público; o soviético da esquerda precisa ser conferido; o do meio
("D-Day") parece ilustração moderna com autor. Antes de distribuir o jogo, obter permissão ou trocar.
