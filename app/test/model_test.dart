import 'package:flutter_test/flutter_test.dart';

import 'package:dungeon_coop/model.dart';

void main() {
  test('parses a server snapshot', () {
    final snapshot = Snapshot.fromJson({
      't': 'state',
      'tick': 42,
      'wave': 3,
      'phase': 'fighting',
      'timer': 1.2,
      'best': 5,
      'players': [
        {
          'id': 'p1',
          'name': 'A',
          'x': 10.5,
          'y': 20,
          'hp': 80,
          'maxHp': 100,
          'dead': false,
          'kills': 2,
        },
      ],
      'enemies': [
        {'id': 'e1', 'x': 30, 'y': 40, 'hp': 12, 'maxHp': 30},
      ],
    });

    expect(snapshot.tick, 42);
    expect(snapshot.wave, 3);
    expect(snapshot.isFighting, isTrue);
    expect(snapshot.best, 5);
    expect(snapshot.players.single.name, 'A');
    expect(snapshot.players.single.x, 10.5);
    expect(snapshot.enemies.single.hp, 12);
  });

  test('tolerates a malformed or empty state', () {
    final snapshot = Snapshot.fromJson({});
    expect(snapshot.wave, 0);
    expect(snapshot.players, isEmpty);
    expect(snapshot.enemies, isEmpty);
  });

  test('smoothing eases toward the target without overshoot', () {
    var value = 0.0;
    for (var i = 0; i < 120; i += 1) {
      value = smoothToward(value, 100, 1 / 60);
    }
    expect(value, closeTo(100, 0.5));
  });
}
