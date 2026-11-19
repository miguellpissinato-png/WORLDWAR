# WorldWar — instruções para o Claude Code

Jogo de grande estratégia em tempo real com pausa, Segunda Guerra Mundial (1936–1945).
Godot 4.5, GDScript. Desenvolvedor: Miguel (fala português; responda em português).
Documento de design completo: `docs/design.md`.

## Regras de arquitetura (não quebrar)

1. **A simulação não conhece a interface.** Nada em `src/` pode usar nós de cena, `get_node`,
   input ou UI. A simulação é feita de classes `RefCounted` e roda igual com ou sem tela.
2. **Só comandos mudam a simulação.** Toda ação de jogador ou da IA é um `Command`
   (`src/commands/`). Ele é enviado com `Simulation.submit()` e aplicado no início da próxima
   hora do jogo. A interface nunca altera `GameState` diretamente. Isso é o que permite multiplayer,
   salvar/carregar e replays.
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
