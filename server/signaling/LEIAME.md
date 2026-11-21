# Servidor de sinalização do WorldWar

Serve só para os jogadores se acharem: o host cria uma sala e recebe um código de 4 letras; quem
entra com o código é apresentado ao host. Depois disso a partida vai direto entre os computadores
(P2P, WebRTC) e não passa mais por aqui. É leve e roda num plano gratuito.

## Colocar no ar (Render, gratuito, ~10 minutos)

1. Crie uma conta em https://render.com (pode entrar com o GitHub).
2. **New → Web Service** → escolha o repositório do jogo.
3. Preencha:
   - **Root Directory:** `server/signaling`
   - **Runtime:** Node
   - **Build Command:** `npm install`
   - **Start Command:** `node server.js`
   - **Instance Type:** Free
4. Clique em **Deploy**. Quando terminar, o Render mostra um endereço como
   `https://worldwar-sinalizacao.onrender.com`. Abra no navegador: deve aparecer
   "WorldWar: servidor de sinalização no ar".
5. Me passe esse endereço (ou coloque você mesmo em `data/common/network.json`, trocando `https://` por `wss://`):
   `"signaling_url": "wss://worldwar-sinalizacao.onrender.com"`

No plano gratuito o serviço "dorme" depois de 15 minutos sem uso: a primeira sala do dia pode levar
uns 30–60 segundos para ser criada.

## Rodar no próprio computador (para testar)

```
cd server/signaling
npm install
node server.js          # porta 8080; no jogo: "signaling_url": "ws://localhost:8080"
```

`TEST_CODE=TEST node server.js` faz a primeira sala ter o código TEST (só para testes automáticos).
