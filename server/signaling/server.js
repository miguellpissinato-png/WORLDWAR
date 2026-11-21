// Servidor de sinalização do WorldWar.
// Só apresenta os jogadores: o host cria uma sala e recebe um código; quem entra com o código recebe
// um número (id). As mensagens de conexão do WebRTC (offer/answer/candidatos) passam por aqui até os
// computadores se conectarem direto. A partida em si não passa por este servidor.
//
// Mensagens (JSON):
//   jogador -> servidor: {type:"host"} | {type:"join", code} | {type:"signal", to, data} | {type:"lock"}
//   servidor -> jogador: {type:"hosted", code} | {type:"joined", id} | {type:"peer", id}
//                        {type:"signal", from, data} | {type:"peer_left", id} | {type:"closed"} | {type:"error", message}
const http = require("http");
const { WebSocketServer } = require("ws");

const PORT = process.env.PORT || 8080;
const ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"; // sem I, O, 0 e 1 (fáceis de confundir)
const MAX_PEERS = 16;
const rooms = new Map(); // código -> {host, peers: Map(id -> ws), next, locked}

const server = http.createServer((req, res) => {
  res.writeHead(200, { "content-type": "text/plain; charset=utf-8" });
  res.end("WorldWar: servidor de sinalização no ar. Salas abertas: " + rooms.size + "\n");
});
const wss = new WebSocketServer({ server });

function send(ws, msg) {
  if (ws && ws.readyState === 1) ws.send(JSON.stringify(msg));
}

function newCode() {
  if (process.env.TEST_CODE && !rooms.has(process.env.TEST_CODE)) return process.env.TEST_CODE; // só para testes
  for (;;) {
    let c = "";
    for (let i = 0; i < 4; i++) c += ALPHABET[Math.floor(Math.random() * ALPHABET.length)];
    if (!rooms.has(c)) return c;
  }
}

wss.on("connection", (ws) => {
  ws.room = null;
  ws.peerId = 0;
  ws.isAlive = true;
  ws.on("pong", () => (ws.isAlive = true));

  ws.on("message", (raw) => {
    let msg;
    try { msg = JSON.parse(raw); } catch { return; }
    if (msg.type === "host" && !ws.room) {
      const code = newCode();
      rooms.set(code, { host: ws, peers: new Map(), next: 2, locked: false });
      ws.room = code;
      ws.peerId = 1;
      send(ws, { type: "hosted", code });
    } else if (msg.type === "join" && !ws.room) {
      const code = String(msg.code || "").toUpperCase().trim();
      const room = rooms.get(code);
      if (!room) return send(ws, { type: "error", message: "Sala não encontrada. Confira o código." });
      if (room.locked) return send(ws, { type: "error", message: "A partida desta sala já começou." });
      if (room.peers.size + 1 >= MAX_PEERS) return send(ws, { type: "error", message: "A sala está cheia." });
      const id = room.next++;
      room.peers.set(id, ws);
      ws.room = code;
      ws.peerId = id;
      send(ws, { type: "joined", id });
      send(room.host, { type: "peer", id });
    } else if (msg.type === "signal" && ws.room) {
      const room = rooms.get(ws.room);
      if (!room) return;
      const target = msg.to === 1 ? room.host : room.peers.get(msg.to);
      send(target, { type: "signal", from: ws.peerId, data: msg.data });
    } else if (msg.type === "lock" && ws.room && ws.peerId === 1) {
      const room = rooms.get(ws.room);
      if (room) room.locked = true;
    }
  });

  ws.on("close", () => {
    const room = ws.room && rooms.get(ws.room);
    if (!room) return;
    if (ws.peerId === 1) {
      for (const p of room.peers.values()) send(p, { type: "closed" });
      rooms.delete(ws.room);
    } else {
      room.peers.delete(ws.peerId);
      send(room.host, { type: "peer_left", id: ws.peerId });
    }
  });
});

// Derruba conexões mortas (e mantém o serviço gratuito acordado enquanto houver gente).
setInterval(() => {
  for (const ws of wss.clients) {
    if (!ws.isAlive) { ws.terminate(); continue; }
    ws.isAlive = false;
    ws.ping();
  }
}, 30000);

server.listen(PORT, () => console.log("Sinalização do WorldWar na porta " + PORT));
