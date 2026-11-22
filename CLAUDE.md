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
- Terreno real (`data/map/terrain.webp`, de `tools/map/build_terrain.py`; fontes em `docs/fontes-terreno-e-sons.md`):
  relevo, solo, neve e lagos no RGB, rios no alfa (255 - rio). O shader mistura pelo `terrain_detail`
  (`MapView.TERRAIN_ZOOM_FROM`/`FULL`): de longe vista política, de perto o terreno com a cor do país fraca.
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
  construção) e militares (encomenda de tropas): `GameState.civil_factories()` / `military_factories()`.
  `SetCivilShareCommand` muda o alvo; `IndustrySystem` converte `industry.conversion_per_day` por dia.
  Nunca usar `total_building(tag, "factory")` para economia ou produção: usar as funções civil/militar.
- Equipamento: dados históricos com fontes em `tools/data/equipment_table.json`; `tools/data/gen_equipment.py`
  gera `data/common/equipment.json` e `data/common/research.json` (não editar à mão). Campos sem fonte
  vão em `estimado` e aparecem "a conferir" na interface. Fontes listadas em `docs/fontes-equipamento.md`.
- Pesquisa (`ResearchSystem`): 5 áreas, vagas por país, penalidade por ano adiantado (limite
  `max_years_ahead`) e por projeto estrangeiro (`origin`). Começo do cenário: `data/scenarios/<ano>/research.json`.
- Produção militar = encomenda de tropas (`RecruitSystem`, não há mais linhas de equipamento): a aba Exército
  tem um botão + por tipo (`troops` em `data/common/army.json`: soldados, artilharia, tanques, aviões; lote,
  dias mínimos, dias-fábrica e recursos por unidade, escalas de combate). `RecruitTroopsCommand` põe o lote em
  `Country.recruit_queue`; por dia as fábricas militares trabalham em ordem (cada lote pega só o que precisa
  para o prazo), gastam recursos (falta reduz até `shortage_floor`) e o lote pronto nasce no estado favorito
  (`Country.rally_state`, `SetRallyStateCommand`, estrela na ficha do estado) ou no vizinho nosso mais perto
  com espaço (`recruit.state_capacity`, `spill_depth`). O modelo é o melhor pesquisado (`ArmySystem.best_model`).
- Eventos para o jogador: `GameState.add_event(tags, texto, tipo)`; o tipo vira o prefixo no registro.

## Exército

- `data/common/army.json`: tipos de tropa (`troops`), regras de encomenda (`recruit`), limites de generais e
  combate. Nomes dos generais (fictícios, decisão do Miguel: nada de generais reais) em
  `data/common/general_names.json`, sorteados com `GameState.rng`.
- Tropas em pilhas: `ArmyGroup.troops` = [{type, model, count, org}]; pilhas paradas do mesmo país no mesmo
  estado viram uma só a cada hora (`ArmySystem.merge_stacks`). `MoveGroupCommand` com `counts` manda só uma
  parte (vira pilha nova; a ficha da pilha tem barras "Enviar na próxima ordem"). `General` (ataque, defesa,
  velocidade 1–5) dá bônus à pilha. Caminho por terra (Dijkstra em km) respeitando `can_enter`.
- `MovementSystem.hourly_update` anda a pilha hora a hora no passo do tipo mais lento; `MapGeo.km()` dá a distância real.
  Vizinhança por terra: `data/map/adjacency.json`, gerado por `tools/map/build_adjacency.py`.
- Exército inicial: `data/scenarios/<ano>/armies.json` (tropas por tipo na capital; valores de exemplo, marcados).

## Diplomacia e guerra

- `data/common/diplomacy.json` (dias e custo da justificativa). `GameState.wars` (pares em guerra),
  `justifications`, `alliances` (reservado; ainda sem sistema de alianças). `can_enter(tag, dono)`:
  tropas só entram em território próprio, aliado ou inimigo em guerra (`ArmySystem.find_path` respeita isso;
  `route_blocker()` diz qual país fecha o caminho).
- `DiplomacySystem`: `JustifyWarCommand` (custa dinheiro, leva dias; o alvo é avisado) e, quando termina,
  `DeclareWarCommand` (a guerra só começa ao declarar). Eventos do tipo "Diplomacia" e "Guerra".
- Combate (`CombatSystem`, regras em `combat` de `data/common/army.json`, valores de jogo): grupo em marcha
  para na divisa de um estado com tropas inimigas e ataca; cada hora os lados perdem organização (0–100 por
  entrada de tropa, `r.org`) na proporção da força do outro (estatísticas do modelo x unidades x `stat_scale`,
  leve/blindado, organização, general, bônus de defesa) e um pouco das unidades (baixas). Aviões lutam onde
  estão e apoiam as batalhas vizinhas (`air_support_neighbor`). Lado com todos abaixo de `break_org` perde: defensor
  recua para vizinho amigo (sem saída = destruído); atacante desiste. Fora de batalha a organização volta.
  `GameState.battles` (estado -> atacantes/defensores) é refeito a cada hora.
- Efeitos de batalha (`ui/units/battle_fx.gd`, filho do `UnitLayer`): clarões, traçantes, explosões com fumaça
  e sons (`Audio.play_sfx`, barramento "Efeitos", volume nas configurações). Sorteio próprio, fora da simulação;
  sons em `audio/sfx/`, sintetizados por `tools/audio/gen_sfx.py`.
- Ocupação: `MapState.controller` ("" = o dono); `control()` / `occupied()`; `GameState.set_control()`.
  Entrar em estado de inimigo em guerra ocupa; entrar num estado próprio ocupado liberta. `states_of()` usa
  quem controla (o ocupante usa fábricas e recursos). Mapa pinta pelo controle (`control_version`).
- Objetivos de vitória (estilo War): `data/common/objectives.json` (dominar % do mundo ou de continentes;
  continentes por estado em `data/map/continents.json`, de `tools/data/gen_continents.py`, Rússia a leste dos
  Urais = Ásia). `ObjectiveSystem` mede a área controlada; `SetObjectivesCommand` define (tag -> objetivo);
  o primeiro a cumprir vira `GameState.winner`. Sorteio só entre objetivos ainda distantes
  (`max_start_progress`). Solo: sorteado ao começar, com "Sortear outro" no briefing. Multiplayer: o host
  escolhe na sala o modo individual (um sorteado e secreto por jogador) ou comum (votação; empate = sorteio).
  Briefing do começo e tela de vitória/derrota em `ui/panels/briefing_screen.gd`; barra do topo tem "Objetivo".
  Enquanto não houver marinha, as porcentagens deixam de fora as ilhas grandes.
- Paz (`PeaceSystem`, regras em `peace` de `data/common/diplomacy.json`): `ProposePeaceCommand` pede dinheiro,
  estados e recursos do inimigo (ou nada = paz branca); paz separada entre os dois países. A IA decide na hora
  (`ai_accepts`: andamento da guerra + cansaço >= custo dos termos) e também propõe (pede o que ocupa ou paz
  branca); jogador responde com `RespondPeaceCommand` (janela `ui/panels/peace_dialog.gd`, abre sozinha; a ficha
  do inimigo tem "Propor paz" com previsão). Aceita: termos pagos até o que há, guerra encerrada, ocupações
  desfeitas, tropas voltam para dentro. Planos de guerra da IA não se repetem (`GameState.declared`).
- Leitura da batalha (pedido do Miguel: saber a "vida" e quantos soldados levar): na interface a organização
  se chama **Moral (vida da tropa)**, com barra sob o número de cada pilha no mapa. `GameState.battles[sid]` guarda
  `p_att/p_def` (força), `loss_att/loss_def` (moral perdida na última hora) e `dead_att/dead_def` (baixas por tipo);
  ao acabar, `battle_results[sid]` guarda o resultado e o aviso traz as baixas. `CombatSystem.forecast()` prevê um
  ataque (vantagem, horas até um lado ceder, `soldiers_needed` para chegar a `safe_share`). Interface: quadro em
  cada batalha e previsão ao passar o mouse com uma pilha selecionada (`ui/units/battle_overlay.gd`, por cima dos
  bonecos), ficha da batalha (`ui/panels/battle_panel.gd`, abre clicando na marca ou em "Ver a batalha").
  Força na tela = valor x10 (`BattlePanel.power_text`). Batalha parelha dura ~3,5 dias (`org_loss_per_hour` 1).
- Ainda falta: capitulação.
- Alianças = facções: `GameState.factions` (id -> {name, leader, members}); `allied()` = mesma facção.
  `FactionSystem` (entrar/sair, `JoinFactionCommand`/`LeaveFactionCommand`); quem entra assume as guerras da
  facção; declarar guerra chama as duas facções inteiras (`DiplomacySystem.side_of`/`start_war`). Libertar estado
  de aliado devolve ao dono. Passagem militar: `GameState.access` ([quem, por onde], de
  `data/scenarios/<ano>/access.json`; ex.: Japão em Manchukuo). Estreitos (`strait` do adjacency.json) e as
  travessias de `data/common/sea_crossings.json` (Dover, Coreia, Otranto) contam como vizinhança.

## IA dos países e jornal

- `data/common/ai.json` (valores de jogo): cada país da IA pensa a cada `think_every_days` (escalonado) em
  `AiSystem`: economia (civil/militar, construir), pesquisa, exército (encomenda tropas pela proporção `mix`, generais),
  comércio (vende excesso a quem tem falta), diplomacia, operações (manda `attack_share` de cada pilha grande ao
  estado inimigo mais perto da frente) e paz.
  `war_plans` e `factions` seguem fatos históricos com datas aproximadas; plano com justificativa pronta declara.
  Os comandos da IA são aplicados dentro de `Simulation._daily_update` (determinísticos, fora do diário).
  Sem `defs.ai` (mundo de teste), a IA não joga. Hoje: 17–30 s por ano simulado sem tela em paz, ~45 s com
  guerra mundial (1940). Caminhos: A* com heap (`ArmySystem._dijkstra`); combate usa índice estado -> pilhas.
- Notícias: `GameState.add_news(manchete, linha fina, texto, estado, tags, tipo)`; `news_count` conta todas
  (a lista guarda só as últimas `MAX_NEWS`). Artigos e contrações em `NewsText` ("à França", "aos Aliados";
  gênero pela primeira palavra). Nomes de aliança no plural ficam em `NewsText.PLURAL`.
- Jornal (`ui/panels/newspaper.gd`, "O Correio do Mundo", nome fictício) substituiu o sino: papel, título em
  UnifrakturMaguntia, texto em Old Standard (OFL, `ui/fonts/`), foto em retícula feita do relevo do mapa no
  estado da notícia (shader com níveis automáticos). Uma foto em `ui/news/<TAG>.jpg|png|webp` substitui o
  recorte (só imagens com direito de uso; nada de fotos de líderes reais geradas ou baixadas por nós).
  Coluna "Despachos ao governo" = avisos do jogador + falta de recursos. Notícia de guerra/aliança do dia
  mostra o "EXTRA!" com "Ler a notícia" (`main._check_extra`).

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
  pesquisa, exército); a ficha de equipamento é `ResearchPanel.equipment_sheet()`.
- Visual "quartel-general" (aprovado pelo Miguel, proposta A do Design): tudo passa por `ui/ui_style.gd`.
  Painéis `#17191c` com fio dourado `#c9b37a` e sombra; títulos em Oswald maiúsculo espaçado
  (`title_label`, `section`, `header`); números em Oswald (`number_label`); texto em Inter.
  Fontes em `ui/fonts/` (OFL, recortadas para latim); ícones de traço brancos em `ui/icons/*.svg`,
  coloridos com `UiStyle.icon(nome, cor)`. Não criar estilos soltos nos painéis: usar as funções do UiStyle.
- Barra superior: país (abre ficha), Tesouro (abre detalhe), Fábricas civis|militares (abre Exército), Pesquisa,
  Soldados, Recursos (abre tabela com estoque, variação de ontem e preço)
  e Jornal (notícias do mundo + avisos do jogador e falta de recurso), data, pausa e 5 barras de velocidade.
  As caixas abertas são uma só (`_drop` em `main.gd`); Esc ou clique fora fecham.
- Menu inicial (`ui/panels/main_menu.gd`, modelo "cartaz central" escolhido pelo Miguel): imagem de
  cartazes `ui/menu/menu_bg.jpg`, título na fonte de estêncil Big Shoulders (OFL), Single player (vai para a
  escolha de país), Multiplayer, Configurações e Sair (some na versão web).
- Multiplayer (`ui/panels/multiplayer_screen.gd` + autoload `Net` em `ui/net/net_session.gd`): 1) perfil
  (apelido e insígnia, guardados em `user://settings.cfg` [perfil]); 2) criar servidor (nome, porta, máx. de
  jogadores; padrão 7036) ou entrar por IP:porta (recentes guardados); 3) sala com a lista de jogadores.
  Rede por WebSocket (`WebSocketMultiplayerPeer`): o host recebe `_register` e manda `_sync` para todos.
  No navegador não dá para criar servidor (e uma página https não conecta em ws://): multiplayer é no jogo
  instalado. Insígnias genéricas em `ui/avatars/*.svg` (desenhos próprios).
  Na sala cada um escolhe um país (`Net.pick_country`, o host impede repetidos) e o host inicia (`_begin`).
  Partida em rede (`main.mp`): o cliente manda o comando ao host (`send_command`); o host confere se o país
  é do remetente, aplica e repassa a todos (`broadcast_command`); o tempo só anda no host, que manda
  `broadcast_advance(horas)` e `broadcast_time(pausa, velocidade)`. Como a simulação é determinística,
  todos ficam iguais. Jogador que sai: a IA assume (`ClaimCountryCommand` com release = o próprio país).
  Host saiu: os clientes voltam ao menu com aviso (`Net.last_message`).
- Online P2P (sala com código): `Net.host_online()` / `join_online(código)`. O servidor de sinalização
  (`server/signaling/`, Node + ws, instruções no LEIAME de lá; endereço em `data/common/network.json`)
  só troca as mensagens do WebRTC (offer/answer/candidatos); a partida vai direto entre os computadores por
  `WebRTCMultiplayerPeer` (host = par 1, clientes ligados só ao host), com as mesmas RPCs da rede local.
  No navegador o WebRTC é nativo; no jogo instalado precisa do plugin oficial "WebRTC" (Godot AssetLib,
  pasta `addons/webrtc`), que não guardamos no repositório. Campo "Entrar": 4 letras = código; com ponto
  ou dois-pontos = IP. Teste local: Chrome com `--disable-features=WebRtcHideLocalIpsWithMdns`.
- Menu do Esc (`ui/panels/pause_menu.gd`): Esc fecha primeiro o que estiver aberto (aviso, caixa, janela,
  seleção); sem nada aberto, abre o menu (Continuar jogo, Salvar jogo, Configurações, Sair para o menu inicial)
  e pausa o single player. "Carregar jogo" aparece no menu inicial quando existe `user://save.json`.
- Salvar/carregar (`src/sim/save_game.gd`): o arquivo guarda cenário + diário de comandos (`Simulation.journal`);
  carregar refaz a partida hora a hora (determinismo). Ao carregar, `SaveGame.pending` + `reload_current_scene()`.
  Cerca de 11 s por ano de jogo; se ficar lento demais, trocar por uma foto do estado.
- Configurações (`ui/panels/settings_panel.gd`), abas (por enquanto só Áudio: volume geral, música e efeitos, 0–100).
  Áudio no autoload `Audio` (`ui/audio/audio_manager.gd`): barramento "Musica", volumes em `user://settings.cfg`,
  músicas de `data/common/music.json` (`audio/music/`) tocando em sequência; música começa em 50%.
- Desempenho: `GameState.states_of()` usa um índice por dono (refeito a cada hora e depois de cada comando);
  não voltar a varrer todos os estados em consultas por país.
- Escolha de país (`ui/panels/start_screen.gd`): lista com bandeiras (grandes potências primeiro, nomes
  ordenados sem acento), ficha com placas de números e recursos com % da produção mundial, e
  "Ver no mapa" (destaca o país, voa a câmera; clicar em outro país troca).
- Bandeiras de 1936: `ui/flags/<TAG>.svg`, geradas por `tools/data/gen_flags.py` (não editar à mão);
  decisões e fontes em `docs/fontes-bandeiras.md` (Alemanha sem suástica, Lei 7.716/89).
  Na interface: `UiStyle.flag_box()` + `UiStyle.set_flag(caixa, tag, cor)`.
- As fontes não têm símbolos como ● ▶ ❚: usar ícones (`ui/icons`) ou `UiStyle.dot()`.
- Ordens de marcha: clicar no boneco seleciona; clicar num estado manda marchar (botão direito também).
  Passar o mouse mostra a prévia do caminho. Setas grossas e curvas com ponta (verde = marcha,
  vermelha = destino inimigo) em `UnitLayer._draw_route`. Fronteira fechada abre o aviso
  (`main._show_war_dialog`: cancelar, justificar ou declarar guerra); a ficha de estado estrangeiro
  tem a seção Diplomacia.
- Pesquisa em organograma (`ResearchPanel` + `ResearchTreeCanvas`): colunas por ano, linhas ligando
  requisitos, cartões com ilustração. Ilustrações em `ui/research/<tech>.svg`, geradas por
  `tools/data/gen_research_art.py`; um PNG com o mesmo nome substitui o desenho automaticamente.
  PNGs reais (660x300, fundo transparente, variante exata conferida) com fontes em `docs/fontes-imagens-pesquisa.md`;
  suástica da deriva dos aviões alemães coberta. Itens sem PNG seguem com o SVG e são trocados aos poucos.
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
