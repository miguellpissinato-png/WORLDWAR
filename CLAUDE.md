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
- `tests/` — testes automáticos da simulação

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
