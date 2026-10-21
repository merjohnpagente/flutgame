// Server-authoritative dungeon room. Clients only send movement direction.
export const WORLD = { width: 1000, height: 700 };
export const MAX_PLAYERS = 4;

const PLAYER = {
  radius: 16,
  speed: 210,
  maxHp: 100,
  range: 230,
  cooldown: 0.45,
  damage: 14,
};
const ENEMY = {
  radius: 14,
  hp: 30,
  speed: 60,
  damage: 7,
  cooldown: 0.8,
};
const WAVE_BREAK = 3;
const OVER_DELAY = 4;
const SPAWN_INTERVAL = 0.45;
const FIRST_BREAK = 1.5;

const rand = (min, max) => min + Math.random() * (max - min);
const clamp = (v, min, max) => Math.min(max, Math.max(min, v));
const round = (v) => Math.round(v * 10) / 10;
const distance = (a, b) => Math.hypot(a.x - b.x, a.y - b.y);

export function createRoom() {
  return {
    players: new Map(),
    enemies: new Map(),
    wave: 0,
    phase: 'intermission',
    timer: FIRST_BREAK,
    spawnQueue: 0,
    spawnTimer: 0,
    best: 0,
    nextId: 1,
    tick: 0,
  };
}

export function addPlayer(room, name) {
  if (room.players.size >= MAX_PLAYERS) return null;
  const cleanName = String(name ?? '')
    .replace(/[\u0000-\u001f\u007f]/g, ' ')
    .trim()
    .slice(0, 16);
  const player = {
    id: `p${room.nextId++}`,
    name: cleanName || 'Hero',
    x: WORLD.width / 2 + rand(-80, 80),
    y: WORLD.height / 2 + rand(-80, 80),
    hp: PLAYER.maxHp,
    maxHp: PLAYER.maxHp,
    dead: false,
    inputX: 0,
    inputY: 0,
    attackTimer: 0,
    kills: 0,
  };
  room.players.set(player.id, player);
  return player;
}

export function removePlayer(room, id) {
  room.players.delete(id);
  if (room.players.size === 0) resetRoom(room);
}

export function setInput(room, id, x, y) {
  const player = room.players.get(id);
  if (!player) return;
  if (!Number.isFinite(x) || !Number.isFinite(y)) return;
  const length = Math.hypot(x, y);
  player.inputX = length > 0 ? x / length : 0;
  player.inputY = length > 0 ? y / length : 0;
}

export function resetRoom(room) {
  room.enemies.clear();
  room.spawnQueue = 0;
  room.spawnTimer = 0;
  room.wave = 0;
  room.phase = 'intermission';
  room.timer = FIRST_BREAK;
  for (const player of room.players.values()) {
    player.x = WORLD.width / 2 + rand(-80, 80);
    player.y = WORLD.height / 2 + rand(-80, 80);
    player.hp = PLAYER.maxHp;
    player.dead = false;
    player.kills = 0;
    player.attackTimer = 0;
    player.inputX = 0;
    player.inputY = 0;
  }
}

export function tick(room, dt) {
  dt = clamp(dt, 0, 0.1);
  if (room.players.size === 0) {
    resetRoom(room);
    return;
  }
  room.tick += 1;

  if (room.phase === 'over') {
    room.timer -= dt;
    if (room.timer <= 0) resetRoom(room);
    return;
  }

  for (const player of room.players.values()) {
    if (player.dead) continue;
    player.x = clamp(
      player.x + player.inputX * PLAYER.speed * dt,
      PLAYER.radius,
      WORLD.width - PLAYER.radius,
    );
    player.y = clamp(
      player.y + player.inputY * PLAYER.speed * dt,
      PLAYER.radius,
      WORLD.height - PLAYER.radius,
    );

    player.attackTimer -= dt;
    if (player.attackTimer > 0) continue;
    let target = null;
    for (const enemy of room.enemies.values()) {
      if (!target || distance(player, enemy) < distance(player, target)) target = enemy;
    }
    if (target && distance(player, target) <= PLAYER.range) {
      target.hp -= PLAYER.damage;
      player.attackTimer = PLAYER.cooldown;
      if (target.hp <= 0) {
        room.enemies.delete(target.id);
        player.kills += 1;
      }
    }
  }

  for (const enemy of room.enemies.values()) {
    let target = null;
    for (const player of room.players.values()) {
      if (player.dead) continue;
      if (!target || distance(enemy, player) < distance(enemy, target)) target = player;
    }
    if (!target) continue;

    const reach = PLAYER.radius + ENEMY.radius;
    const gap = distance(enemy, target);
    if (gap > reach) {
      const step = Math.min(enemy.speed * dt, gap - reach);
      enemy.x += ((target.x - enemy.x) / gap) * step;
      enemy.y += ((target.y - enemy.y) / gap) * step;
    } else {
      enemy.cooldown -= dt;
      if (enemy.cooldown <= 0) {
        target.hp -= ENEMY.damage;
        enemy.cooldown = ENEMY.cooldown;
        if (target.hp <= 0) {
          target.hp = 0;
          target.dead = true;
        }
      }
    }
  }

  // Checked before wave completion so a wipe is never mistaken for a clear + revive.
  const alive = [...room.players.values()].some((player) => !player.dead);
  if (!alive) {
    room.best = Math.max(room.best, room.wave);
    room.phase = 'over';
    room.timer = OVER_DELAY;
    room.spawnQueue = 0;
    room.enemies.clear();
    return;
  }

  if (room.phase === 'intermission') {
    room.timer -= dt;
    if (room.timer <= 0) startWave(room);
  } else if (room.phase === 'fighting') {
    if (room.spawnQueue > 0) {
      room.spawnTimer -= dt;
      if (room.spawnTimer <= 0) {
        spawnEnemy(room);
        room.spawnQueue -= 1;
        room.spawnTimer = SPAWN_INTERVAL;
      }
    }
    if (room.spawnQueue === 0 && room.enemies.size === 0) {
      room.best = Math.max(room.best, room.wave);
      room.phase = 'intermission';
      room.timer = WAVE_BREAK;
      for (const player of room.players.values()) {
        if (player.dead) {
          player.dead = false;
          player.hp = 40;
        } else {
          player.hp = Math.min(player.maxHp, player.hp + 25);
        }
      }
    }
  }

}

function startWave(room) {
  room.wave += 1;
  room.phase = 'fighting';
  room.spawnQueue = Math.min(40, 3 + room.wave * 2);
  room.spawnTimer = 0;
  room.best = Math.max(room.best, room.wave);
}

function spawnEnemy(room) {
  const margin = 30;
  const edge = Math.floor(Math.random() * 4);
  let x = rand(margin, WORLD.width - margin);
  let y = rand(margin, WORLD.height - margin);
  if (edge === 0) y = margin;
  if (edge === 1) x = WORLD.width - margin;
  if (edge === 2) y = WORLD.height - margin;
  if (edge === 3) x = margin;

  const hp = ENEMY.hp + (room.wave - 1) * 8;
  const enemy = {
    id: `e${room.nextId++}`,
    x,
    y,
    hp,
    maxHp: hp,
    speed: Math.min(115, ENEMY.speed + (room.wave - 1) * 4),
    cooldown: rand(0.2, 0.8),
  };
  room.enemies.set(enemy.id, enemy);
}

export function snapshot(room) {
  return {
    t: 'state',
    tick: room.tick,
    wave: room.wave,
    phase: room.phase,
    timer: Math.max(0, round(room.timer)),
    best: room.best,
    players: [...room.players.values()].map((player) => ({
      id: player.id,
      name: player.name,
      x: round(player.x),
      y: round(player.y),
      hp: Math.max(0, Math.round(player.hp)),
      maxHp: player.maxHp,
      dead: player.dead,
      kills: player.kills,
    })),
    enemies: [...room.enemies.values()].map((enemy) => ({
      id: enemy.id,
      x: round(enemy.x),
      y: round(enemy.y),
      hp: Math.max(0, Math.round(enemy.hp)),
      maxHp: enemy.maxHp,
    })),
  };
}
