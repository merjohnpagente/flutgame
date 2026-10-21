import test from 'node:test';
import assert from 'node:assert/strict';
import { once } from 'node:events';
import WebSocket from 'ws';
import { startServer } from '../server.js';

async function open(port) {
  const ws = new WebSocket(`ws://127.0.0.1:${port}`);
  await once(ws, 'open');
  return ws;
}

function nextMessage(ws, predicate, timeoutMs = 3000) {
  return new Promise((resolve, reject) => {
    const timeout = setTimeout(() => {
      ws.off('message', onMessage);
      reject(new Error('timed out waiting for message'));
    }, timeoutMs);
    function onMessage(raw) {
      const message = JSON.parse(raw);
      if (!predicate(message)) return;
      clearTimeout(timeout);
      ws.off('message', onMessage);
      resolve(message);
    }
    ws.on('message', onMessage);
  });
}

test('two clients join, see each other, and can move', async () => {
  const server = startServer(0, '127.0.0.1');
  if (!server.wss.address()) await once(server.wss, 'listening');
  const port = server.wss.address().port;
  const clients = [];

  try {
    const a = await open(port);
    const b = await open(port);
    clients.push(a, b);

    a.send(JSON.stringify({ t: 'join', name: 'A' }));
    const welcomeA = await nextMessage(a, (m) => m.t === 'welcome');
    assert.equal(typeof welcomeA.id, 'string');

    b.send(JSON.stringify({ t: 'join', name: 'B' }));
    await nextMessage(b, (m) => m.t === 'welcome');

    const twoPlayers = await nextMessage(
      a,
      (m) => m.t === 'state' && m.players.length === 2,
    );
    const playerA = twoPlayers.players.find((p) => p.id === welcomeA.id);
    assert.ok(playerA);
    assert.equal(twoPlayers.players.some((p) => p.name === 'B'), true);

    a.send(JSON.stringify({ t: 'input', x: 1, y: 0 }));
    const moved = await nextMessage(
      a,
      (m) =>
        m.t === 'state' &&
        m.players.some((p) => p.id === welcomeA.id && p.x > playerA.x),
    );
    assert.ok(moved.players.find((p) => p.id === welcomeA.id).x > playerA.x);
  } finally {
    for (const ws of clients) ws.close();
    server.close();
  }
});

test('a fifth player is rejected', async () => {
  const server = startServer(0, '127.0.0.1');
  if (!server.wss.address()) await once(server.wss, 'listening');
  const port = server.wss.address().port;
  const clients = [];

  try {
    for (let i = 0; i < 4; i += 1) {
      const ws = await open(port);
      clients.push(ws);
      ws.send(JSON.stringify({ t: 'join', name: `P${i}` }));
      await nextMessage(ws, (m) => m.t === 'welcome');
    }
    const extra = await open(port);
    clients.push(extra);
    extra.send(JSON.stringify({ t: 'join', name: 'E' }));
    const error = await nextMessage(extra, (m) => m.t === 'error');
    assert.match(error.message, /full/i);
  } finally {
    for (const ws of clients) ws.close();
    server.close();
  }
});
