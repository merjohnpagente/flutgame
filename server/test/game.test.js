import test from 'node:test';
import assert from 'node:assert/strict';
import {
  MAX_PLAYERS,
  WORLD,
  addPlayer,
  createRoom,
  removePlayer,
  resetRoom,
  setInput,
  snapshot,
  tick,
} from '../game.js';

const steps = (room, seconds) => {
  for (let i = 0; i < Math.ceil(seconds / 0.1); i += 1) tick(room, 0.1);
};

test('room starts an intermission and then wave 1', () => {
  const room = createRoom();
  addPlayer(room, 'A');
  assert.equal(room.phase, 'intermission');
  steps(room, 1.6);
  assert.equal(room.phase, 'fighting');
  assert.equal(room.wave, 1);
  assert.equal(room.spawnQueue + room.enemies.size, 5);
});

test('moves players and clamps them to the arena', () => {
  const room = createRoom();
  const player = addPlayer(room, 'A');
  player.x = WORLD.width - 20;
  player.y = 300;
  setInput(room, player.id, 1, 0);
  steps(room, 1);
  assert.equal(player.x, WORLD.width - 16);
  assert.equal(player.y, 300);
});

test('ignores diagonal speed boosts and bad input', () => {
  const room = createRoom();
  const player = addPlayer(room, 'A');
  setInput(room, player.id, 1, 1);
  assert.ok(Math.abs(Math.hypot(player.inputX, player.inputY) - 1) < 1e-9);
  setInput(room, player.id, Number.NaN, 0);
  assert.equal(player.inputX, 1 / Math.SQRT2);
});

test('enemies chase and hurt the nearest player', () => {
  const room = createRoom();
  const player = addPlayer(room, 'A');
  room.phase = 'fighting';
  room.enemies.set('e1', {
    id: 'e1',
    x: player.x + 100,
    y: player.y,
    hp: 9999,
    maxHp: 9999,
    speed: 60,
    cooldown: 0,
  });
  steps(room, 2);
  assert.ok(player.hp < player.maxHp);
});

test('players auto-attack and kill enemies in range', () => {
  const room = createRoom();
  const player = addPlayer(room, 'A');
  room.phase = 'intermission';
  room.timer = 100; // keep the wave from clearing while we test attacks
  room.enemies.set('e1', {
    id: 'e1',
    x: player.x + 100,
    y: player.y,
    hp: 30,
    maxHp: 30,
    speed: 0,
    cooldown: 100,
  });
  steps(room, 1.6);
  assert.equal(room.enemies.size, 0);
  assert.equal(player.kills, 1);
});

test('clearing a wave sets the best and heals players', () => {
  const room = createRoom();
  const player = addPlayer(room, 'A');
  player.hp = 50;
  room.phase = 'fighting';
  room.wave = 3;
  tick(room, 0.05);
  assert.equal(room.phase, 'intermission');
  assert.equal(room.best, 3);
  assert.equal(player.hp, 75);
});

test('a full wipe ends the run, then restarts it', () => {
  const room = createRoom();
  const player = addPlayer(room, 'A');
  player.dead = true;
  player.hp = 0;
  room.phase = 'fighting';
  room.wave = 4;
  tick(room, 0.05);
  assert.equal(room.phase, 'over');
  assert.equal(room.best, 4);
  steps(room, 4.2);
  assert.equal(room.phase, 'intermission');
  assert.equal(room.wave, 0);
  assert.equal(player.dead, false);
  assert.equal(player.hp, 100);
});

test('room capacity is enforced and leaving frees a slot', () => {
  const room = createRoom();
  const players = [];
  for (let i = 0; i < MAX_PLAYERS; i += 1) players.push(addPlayer(room, `P${i}`));
  assert.equal(players.every(Boolean), true);
  assert.equal(addPlayer(room, 'overflow'), null);
  removePlayer(room, players[0].id);
  assert.ok(addPlayer(room, 'late'));
});

test('player names are trimmed and control characters are removed', () => {
  const room = createRoom();
  const player = addPlayer(room, '  A\nB\tC  ');
  assert.equal(player.name, 'A B C');
});

test('empty room reset keeps the best wave', () => {
  const room = createRoom();
  room.best = 7;
  resetRoom(room);
  assert.equal(room.best, 7);
});

test('snapshot only exposes the public state', () => {
  const room = createRoom();
  const player = addPlayer(room, 'A');
  const state = snapshot(room);
  assert.equal(state.t, 'state');
  assert.equal(state.players[0].id, player.id);
  assert.equal('inputX' in state.players[0], false);
  assert.ok(Array.isArray(state.enemies));
});
