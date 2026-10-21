import { WebSocketServer, WebSocket } from 'ws';
import {
  addPlayer,
  createRoom,
  removePlayer,
  setInput,
  snapshot,
  tick,
} from './game.js';

const TICK_MS = 50;
const SNAPSHOT_EVERY = 2;

export function startServer(port = 8080, host = '0.0.0.0') {
  const room = createRoom();
  const clients = new Map();
  const wss = new WebSocketServer({ port, host, maxPayload: 1024 });

  const broadcast = () => {
    const payload = JSON.stringify(snapshot(room));
    for (const ws of clients.keys()) {
      if (ws.readyState === WebSocket.OPEN) ws.send(payload);
    }
  };

  wss.on('connection', (ws) => {
    ws.on('message', (raw) => {
      let message;
      try {
        message = JSON.parse(raw);
      } catch {
        return;
      }

      if (message.t === 'join') {
        if (clients.has(ws)) return;
        const player = addPlayer(room, message.name);
        if (!player) {
          ws.send(JSON.stringify({ t: 'error', message: 'Room is full (4 players)' }));
          return;
        }
        clients.set(ws, player.id);
        ws.send(
          JSON.stringify({ t: 'welcome', id: player.id, best: room.best, maxPlayers: 4 }),
        );
        broadcast();
      } else if (message.t === 'input') {
        const id = clients.get(ws);
        if (id) setInput(room, id, Number(message.x), Number(message.y));
      }
    });

    ws.on('close', () => {
      const id = clients.get(ws);
      if (!id) return;
      clients.delete(ws);
      removePlayer(room, id);
      broadcast();
    });
  });

  const timer = setInterval(() => {
    tick(room, TICK_MS / 1000);
    if (room.tick % SNAPSHOT_EVERY === 0) broadcast();
  }, TICK_MS);

  return {
    wss,
    room,
    close() {
      clearInterval(timer);
      for (const ws of clients.keys()) ws.close();
      wss.close();
    },
  };
}
