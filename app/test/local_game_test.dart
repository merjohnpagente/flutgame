import 'dart:math' as math;

import 'package:dungeon_coop/session.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('local run starts the first wave after the break', () {
    final game = LocalGame(random: math.Random(1));
    expect(game.wave, 0);
    expect(game.phase, 'intermission');

    for (var i = 0; i < 32; i += 1) {
      game.tick(0.05);
    }

    expect(game.phase, 'fighting');
    expect(game.wave, 1);
    expect(game.snapshot('Hero').enemies, isNotEmpty);
  });

  test('input moves the hero and stays inside the arena', () {
    final game = LocalGame(random: math.Random(1));
    game.sendInput(1, 0);

    for (var i = 0; i < 30; i += 1) {
      game.tick(0.1);
    }

    final me = game.snapshot('Hero').players.single;
    expect(me.x, closeTo(984, 0.01));
    expect(me.y, closeTo(350, 0.01));
  });
}
