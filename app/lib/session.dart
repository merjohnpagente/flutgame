import 'dart:async';
import 'dart:math' as math;

import 'model.dart';

/// What the game screen needs from a game, online or offline.
abstract class GameSession {
  Future<void> connect({
    required String name,
    required void Function(String id, int best) onWelcome,
    required void Function(Snapshot snapshot) onState,
    required void Function(String message) onError,
    required void Function() onClosed,
  });

  void sendInput(double x, double y);

  Future<void> close();
}

class LocalSession implements GameSession {
  LocalSession({LocalGame? game}) : _game = game ?? LocalGame();

  final LocalGame _game;
  Timer? _timer;
  void Function(Snapshot snapshot)? _onState;
  String _name = 'Hero';

  @override
  Future<void> connect({
    required String name,
    required void Function(String id, int best) onWelcome,
    required void Function(Snapshot snapshot) onState,
    required void Function(String message) onError,
    required void Function() onClosed,
  }) {
    final clean = name.trim();
    _name = clean.isEmpty
        ? 'Hero'
        : clean.substring(0, math.min(16, clean.length));
    _onState = onState;
    onWelcome('local', _game.best);
    _emit();

    _timer?.cancel();
    var tick = 0;
    _timer = Timer.periodic(const Duration(milliseconds: 50), (_) {
      _game.tick(0.05);
      tick += 1;
      if (tick.isEven) _emit();
    });
    return Future<void>.value();
  }

  void _emit() => _onState?.call(_game.snapshot(_name));

  @override
  void sendInput(double x, double y) => _game.sendInput(x, y);

  @override
  Future<void> close() {
    _timer?.cancel();
    _timer = null;
    _onState = null;
    return Future<void>.value();
  }
}

/// Offline version of the server room: one hero, same waves and damage.
class LocalGame {
  LocalGame({math.Random? random}) : _random = random ?? math.Random();

  // Keep these in step with server/game.js and arena_painter.dart.
  static const double _width = 1000;
  static const double _height = 700;
  static const double _playerRadius = 16;
  static const double _playerSpeed = 210;
  static const double _playerMaxHp = 100;
  static const double _attackRange = 230;
  static const double _attackCooldown = 0.45;
  static const double _attackDamage = 14;
  static const double _enemyRadius = 14;
  static const double _enemyDamage = 7;
  static const double _enemyCooldown = 0.8;
  static const double _waveBreak = 3;
  static const double _overDelay = 4;
  static const double _spawnInterval = 0.45;
  static const double _firstBreak = 1.5;

  final math.Random _random;
  final List<_LocalEnemy> _enemies = [];

  double _x = _width / 2;
  double _y = _height / 2;
  double _inputX = 0;
  double _inputY = 0;
  double _hp = _playerMaxHp;
  bool _dead = false;
  int _wave = 0;
  int _best = 0;
  int _nextId = 1;
  int _kills = 0;
  int _tick = 0;
  double _timer = _firstBreak;
  String _phase = 'intermission';
  int _spawnQueue = 0;
  double _spawnTimer = 0;
  double _attackTimer = 0;

  int get wave => _wave;
  String get phase => _phase;
  int get best => _best;

  void sendInput(double x, double y) {
    if (!x.isFinite || !y.isFinite) return;
    final length = math.sqrt(x * x + y * y);
    _inputX = length > 0 ? x / length : 0;
    _inputY = length > 0 ? y / length : 0;
  }

  void tick(double dt) {
    final step = dt.clamp(0.0, 0.1).toDouble();
    _tick += 1;

    if (_phase == 'over') {
      _timer -= step;
      if (_timer <= 0) _reset();
      return;
    }

    if (!_dead) {
      _x = (_x + _inputX * _playerSpeed * step)
          .clamp(_playerRadius, _width - _playerRadius)
          .toDouble();
      _y = (_y + _inputY * _playerSpeed * step)
          .clamp(_playerRadius, _height - _playerRadius)
          .toDouble();

      _attackTimer -= step;
      if (_attackTimer <= 0) _attackNearest();
    }

    for (final enemy in _enemies) {
      _moveEnemy(enemy, step);
    }

    // Checked before wave completion so a wipe is never mistaken for a clear.
    if (_dead) {
      _best = math.max(_best, _wave);
      _phase = 'over';
      _timer = _overDelay;
      _spawnQueue = 0;
      _enemies.clear();
      return;
    }

    if (_phase == 'intermission') {
      _timer -= step;
      if (_timer <= 0) _startWave();
    } else if (_phase == 'fighting') {
      if (_spawnQueue > 0) {
        _spawnTimer -= step;
        if (_spawnTimer <= 0) {
          _spawnEnemy();
          _spawnQueue -= 1;
          _spawnTimer = _spawnInterval;
        }
      }
      if (_spawnQueue == 0 && _enemies.isEmpty) {
        _best = math.max(_best, _wave);
        _phase = 'intermission';
        _timer = _waveBreak;
        _hp = math.min(_playerMaxHp, _hp + 25);
      }
    }
  }

  void _attackNearest() {
    _LocalEnemy? target;
    var nearest = double.infinity;
    for (final enemy in _enemies) {
      final gap = _distance(_x, _y, enemy.x, enemy.y);
      if (gap < nearest) {
        nearest = gap;
        target = enemy;
      }
    }
    if (target == null || nearest > _attackRange) return;

    target.hp -= _attackDamage;
    _attackTimer = _attackCooldown;
    if (target.hp <= 0) {
      _enemies.remove(target);
      _kills += 1;
    }
  }

  void _moveEnemy(_LocalEnemy enemy, double dt) {
    final gap = _distance(enemy.x, enemy.y, _x, _y);
    final reach = _playerRadius + _enemyRadius;
    if (gap > reach) {
      final step = math.min(enemy.speed * dt, gap - reach);
      enemy.x += (_x - enemy.x) / gap * step;
      enemy.y += (_y - enemy.y) / gap * step;
      return;
    }

    enemy.cooldown -= dt;
    if (enemy.cooldown > 0) return;
    _hp -= _enemyDamage;
    enemy.cooldown = _enemyCooldown;
    if (_hp <= 0) {
      _hp = 0;
      _dead = true;
    }
  }

  void _startWave() {
    _wave += 1;
    _phase = 'fighting';
    _spawnQueue = math.min(40, 3 + _wave * 2);
    _spawnTimer = 0;
    _best = math.max(_best, _wave);
  }

  void _spawnEnemy() {
    const margin = 30.0;
    var x = margin + _random.nextDouble() * (_width - margin * 2);
    var y = margin + _random.nextDouble() * (_height - margin * 2);
    final edge = _random.nextInt(4);
    if (edge == 0) y = margin;
    if (edge == 1) x = _width - margin;
    if (edge == 2) y = _height - margin;
    if (edge == 3) x = margin;

    final hp = 30.0 + (_wave - 1) * 8;
    _enemies.add(_LocalEnemy(
      id: 'e${_nextId++}',
      x: x,
      y: y,
      hp: hp,
      maxHp: hp,
      speed: math.min(115.0, 60 + (_wave - 1) * 4),
      cooldown: 0.2 + _random.nextDouble() * 0.6,
    ));
  }

  void _reset() {
    _enemies.clear();
    _spawnQueue = 0;
    _spawnTimer = 0;
    _wave = 0;
    _phase = 'intermission';
    _timer = _firstBreak;
    _x = _width / 2;
    _y = _height / 2;
    _hp = _playerMaxHp;
    _dead = false;
    _kills = 0;
    _attackTimer = 0;
    _inputX = 0;
    _inputY = 0;
  }

  Snapshot snapshot(String name) {
    return Snapshot(
      tick: _tick,
      wave: _wave,
      phase: _phase,
      timer: math.max(0.0, _timer),
      best: _best,
      players: [
        NetPlayer(
          id: 'local',
          name: name,
          x: _x,
          y: _y,
          hp: math.max(0.0, _hp),
          maxHp: _playerMaxHp,
          dead: _dead,
          kills: _kills,
        ),
      ],
      enemies: [
        for (final enemy in _enemies)
          NetEnemy(
            id: enemy.id,
            x: enemy.x,
            y: enemy.y,
            hp: math.max(0.0, enemy.hp),
            maxHp: enemy.maxHp,
          ),
      ],
    );
  }
}

class _LocalEnemy {
  _LocalEnemy({
    required this.id,
    required this.x,
    required this.y,
    required this.hp,
    required this.maxHp,
    required this.speed,
    required this.cooldown,
  });

  final String id;
  double x;
  double y;
  double hp;
  final double maxHp;
  final double speed;
  double cooldown;
}

double _distance(double x1, double y1, double x2, double y2) {
  final dx = x1 - x2;
  final dy = y1 - y2;
  return math.sqrt(dx * dx + dy * dy);
}
