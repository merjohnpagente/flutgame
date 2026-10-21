import 'dart:math' as math;

class NetPlayer {
  const NetPlayer({
    required this.id,
    required this.name,
    required this.x,
    required this.y,
    required this.hp,
    required this.maxHp,
    required this.dead,
    required this.kills,
  });

  final String id;
  final String name;
  final double x;
  final double y;
  final double hp;
  final double maxHp;
  final bool dead;
  final int kills;

  factory NetPlayer.fromJson(Map<String, dynamic> json) => NetPlayer(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Hero',
        x: _number(json['x']),
        y: _number(json['y']),
        hp: _number(json['hp']),
        maxHp: _number(json['maxHp'], 100),
        dead: json['dead'] as bool? ?? false,
        kills: (json['kills'] as num?)?.toInt() ?? 0,
      );
}

class NetEnemy {
  const NetEnemy({
    required this.id,
    required this.x,
    required this.y,
    required this.hp,
    required this.maxHp,
  });

  final String id;
  final double x;
  final double y;
  final double hp;
  final double maxHp;

  factory NetEnemy.fromJson(Map<String, dynamic> json) => NetEnemy(
        id: json['id'] as String? ?? '',
        x: _number(json['x']),
        y: _number(json['y']),
        hp: _number(json['hp']),
        maxHp: _number(json['maxHp'], 30),
      );
}

class Snapshot {
  const Snapshot({
    required this.tick,
    required this.wave,
    required this.phase,
    required this.timer,
    required this.best,
    required this.players,
    required this.enemies,
  });

  final int tick;
  final int wave;
  final String phase;
  final double timer;
  final int best;
  final List<NetPlayer> players;
  final List<NetEnemy> enemies;

  bool get isOver => phase == 'over';
  bool get isFighting => phase == 'fighting';

  factory Snapshot.fromJson(Map<String, dynamic> json) {
    final players = json['players'];
    final enemies = json['enemies'];
    return Snapshot(
      tick: (json['tick'] as num?)?.toInt() ?? 0,
      wave: (json['wave'] as num?)?.toInt() ?? 0,
      phase: json['phase'] as String? ?? 'intermission',
      timer: _number(json['timer']),
      best: (json['best'] as num?)?.toInt() ?? 0,
      players: [
        if (players is List)
          for (final player in players)
            if (player is Map<String, dynamic>) NetPlayer.fromJson(player),
      ],
      enemies: [
        if (enemies is List)
          for (final enemy in enemies)
            if (enemy is Map<String, dynamic>) NetEnemy.fromJson(enemy),
      ],
    );
  }
}

double _number(Object? value, [double fallback = 0]) =>
    value is num ? value.toDouble() : fallback;

/// Frame-rate independent easing used to smooth 10 Hz server snapshots.
double smoothToward(double current, double target, double dt) =>
    current + (target - current) * (1 - math.exp(-16 * dt));
