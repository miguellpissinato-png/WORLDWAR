# WorldWar

Jogo de grande estratégia em tempo real com pausa, ambientado na Segunda Guerra Mundial (1936–1945).
Feito no Godot 4.5 com GDScript.

## Como abrir

1. Instale o [Godot 4.5](https://godotengine.org/download) (versão padrão, não a .NET).
2. No Godot, clique em **Importar** e escolha o arquivo `project.godot` desta pasta.
3. Aperte **F5** para rodar.

## Estado atual (Fase 1, início)

- Relógio do jogo com pausa e 5 velocidades (espaço e teclas 1–5)
- Cenário de 1936 com 8 países de exemplo, cada um com um estado (a capital)
- Fila de construção: fábricas civis, militares e infraestrutura
- Todas as ações passam por comandos (base para o multiplayer)
- 15 testes automáticos

Ainda não tem mapa: a tela atual é provisória. Os números em `data/` são valores de exemplo.

## Testes

```
tests/run.sh                      # usa o comando "godot" do sistema
GODOT=/caminho/do/godot tests/run.sh
```

No Windows, sem bash: `godot --headless -s tests/run_tests.gd`

Regras de arquitetura e convenções: veja `CLAUDE.md`. Design completo: `docs/design.md`.
