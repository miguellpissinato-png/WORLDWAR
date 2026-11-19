# WorldWar — resumo do design

Documento completo (fonte oficial, editável): https://claude.ai/artifact/WGmRaKDzr4b8V9GGaVNctW
Este arquivo é um resumo para consulta rápida dentro do projeto.

## Conceito

Grande estratégia em tempo real com pausa, Segunda Guerra Mundial. Qualquer país do mundo é jogável.
Modos: um jogador contra a IA e multiplayer 1x1 (host + 1 jogador). PC, Godot 4.5, GDScript.

## Cenários

| Cenário | Início | Fim |
| --- | --- | --- |
| Rearmamento | 1º/01/1936 | 31/12/1945 ou capitulação |
| Guerra na Europa | 1º/09/1939 | 31/12/1945 ou capitulação |

Vitória: capitulação dos inimigos, vitória da facção, ou mais pontos em 31/12/1945.

## Mapa

Mundo inteiro desde a Fase 1. Províncias (movimento/combate, meta ~3.000 terrestres + ~500 marítimas)
→ estados (indústria, população, recursos, construções) → regiões estratégicas (ar, clima, mar).
Base geográfica do Natural Earth; fronteiras de 1936/1939 a partir de base histórica aberta (licença a conferir).
Províncias definidas por uma imagem com uma cor única por província + JSON com dados.

## Sistemas e fases

| Sistema | Fase |
| --- | --- |
| Tempo (horas, 5 velocidades, pausa) | 1 |
| Economia e construção (fábricas civis, recursos) | 1 |
| Produção militar (linhas de produção) | 1 |
| Exército (divisões, modelos, generais) | 2 |
| Combate terrestre | 2 |
| Multiplayer 1x1 | 2 |
| Pesquisa, política, foco nacional, diplomacia | 3 |
| Suprimentos, frentes de batalha, IA ativa | 4 |
| Ar, mar, eventos, acabamento, toque pessoal | 5 |

Critérios de "pronto" por fase:
1. Escolher qualquer país, construir fábricas e produzir equipamento.
2. Dois jogadores guerreiam em rede até um capitular.
3. Uma partida de 1936 segue um rumo histórico plausível.
4. Duas IAs travam uma guerra sozinhas.
5. Partida completa 1936–1945 jogável do início ao fim.

## Multiplayer

Host autoritativo: a simulação roda no host; o outro jogador envia comandos e recebe o estado.
Rede do Godot (ENet); à distância via Tailscale/ZeroTier. Host controla a velocidade; qualquer um pausa.

## Cuidados

Não usar nada de Hearts of Iron ou de outros jogos (nome, arte, textos, valores de dados).
Fatos históricos são livres. Bandeira alternativa para a Alemanha se o jogo for distribuído.

## Pendências

- Toque pessoal do jogo
- Base de fronteiras históricas (licença)
- Confirmar líderes de cada cenário com fontes
- Estilo visual
