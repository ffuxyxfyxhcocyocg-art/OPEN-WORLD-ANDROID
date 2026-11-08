const http = require("node:http");
const { WebSocketServer, WebSocket } = require("ws");

const PORT = Number(process.env.PORT || 10000);
const MAX_PLAYERS = 40;
const WAIT_SECONDS = 12;
const COUNTDOWN_SECONDS = 5;
const ZONE_WAIT_SECONDS = 15;
const ZONE_SHRINK_SECONDS = 90;
const ZONE_START = 150;
const ZONE_END = 24;

const players = new Map();
let phase = "waiting";
let phaseStartedAt = Date.now();
let matchStartedAt = 0;

const httpServer = http.createServer((req, res) => {
  if (req.url === "/health" || req.url === "/") {
    res.writeHead(200, { "content-type": "application/json; charset=utf-8", "cache-control": "no-store" });
    res.end(JSON.stringify({ ok: true, service: "Open World BR realtime", players: players.size, maxPlayers: MAX_PLAYERS, phase }));
    return;
  }
  res.writeHead(404, { "content-type": "application/json" });
  res.end(JSON.stringify({ error: "not_found" }));
});

const wss = new WebSocketServer({ server: httpServer, path: "/ws", maxPayload: 4096 });

function resetMatch() {
  phase = "waiting";
  phaseStartedAt = Date.now();
  matchStartedAt = 0;
}
function updatePhase(now) {
  if (players.size === 0) { if (phase !== "waiting") resetMatch(); return; }
  const elapsed = (now - phaseStartedAt) / 1000;
  if (phase === "waiting" && elapsed >= WAIT_SECONDS) {
    phase = "countdown";
    phaseStartedAt = now;
  } else if (phase === "countdown" && elapsed >= COUNTDOWN_SECONDS) {
    phase = "started";
    phaseStartedAt = now;
    matchStartedAt = now;
  }
}
function currentState(now) {
  updatePhase(now);
  const matchElapsed = phase === "started" ? Math.max(0, (now - matchStartedAt) / 1000) : 0;
  const zoneElapsed = Math.max(0, matchElapsed - ZONE_WAIT_SECONDS);
  const progress = Math.min(1, zoneElapsed / ZONE_SHRINK_SECONDS);
  const zoneRadius = ZONE_START + (ZONE_END - ZONE_START) * progress;
  const phaseDuration = phase === "waiting" ? WAIT_SECONDS : phase === "countdown" ? COUNTDOWN_SECONDS : 0;
  const phaseRemaining = phaseDuration ? Math.max(0, phaseDuration - (now - phaseStartedAt) / 1000) : 0;
  return {
    type: "snapshot",
    phase,
    phaseRemaining,
    playerCount: players.size,
    maxPlayers: MAX_PLAYERS,
    matchElapsed,
    zoneElapsed: matchElapsed,
    zoneRadius,
    players: Array.from(players.values()).map(p => ({
      id: p.id, name: p.name, x: p.x, y: p.y, z: p.z, yaw: p.yaw, vehicle: p.vehicle
    }))
  };
}
function send(ws, data) {
  if (ws.readyState === WebSocket.OPEN) ws.send(JSON.stringify(data));
}
wss.on("connection", (ws) => {
  if (players.size >= MAX_PLAYERS) {
    send(ws, { type: "full", message: "Sala cheia. Tente novamente." });
    ws.close(1008, "room_full");
    return;
  }
  if (players.size === 0) resetMatch();
  const id = require("node:crypto").randomUUID();
  const player = { id, name: "Jogador", x: 0, y: 0, z: 3, yaw: 0, vehicle: false, ws, lastUpdate: 0 };
  players.set(id, player);
  send(ws, { type: "welcome", id, maxPlayers: MAX_PLAYERS });
  ws.on("message", raw => {
    if (raw.length > 2048) return;
    let msg;
    try { msg = JSON.parse(raw.toString()); } catch { return; }
    if (!msg || typeof msg !== "object") return;
    if (msg.type === "join") {
      const name = String(msg.name || "Jogador").replace(/[^\p{L}\p{N} _-]/gu, "").trim().slice(0, 16);
      if (name) player.name = name;
      return;
    }
    if (msg.type === "state") {
      const now = Date.now();
      if (now - player.lastUpdate < 70) return;
      player.lastUpdate = now;
      const x = Number(msg.x), z = Number(msg.z), yaw = Number(msg.yaw);
      if (Number.isFinite(x) && Number.isFinite(z) && Math.abs(x) <= 220 && Math.abs(z) <= 220) {
        player.x = x; player.z = z;
      }
      if (Number.isFinite(yaw)) player.yaw = Math.max(-Math.PI * 4, Math.min(Math.PI * 4, yaw));
      player.vehicle = msg.vehicle === true;
    }
  });
  ws.on("close", () => {
    players.delete(id);
    if (players.size === 0) resetMatch();
  });
  ws.on("error", () => players.delete(id));
});

setInterval(() => {
  const snapshot = JSON.stringify(currentState(Date.now()));
  for (const p of players.values()) if (p.ws.readyState === WebSocket.OPEN) p.ws.send(snapshot);
}, 100);
httpServer.listen(PORT, "0.0.0.0", () => {
  console.log("Open World BR realtime server listening on " + PORT);
});
