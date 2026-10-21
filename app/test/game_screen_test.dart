import 'package:dungeon_coop/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('offline run starts without a server', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: GameScreen(name: 'Hero')),
    );
    await tester.pump();

    expect(find.text('WAVE 0'), findsOneWidget);

    await tester.pump(const Duration(seconds: 2));
    await tester.pump();

    expect(find.text('WAVE 1'), findsOneWidget);

    // Dispose the screen so its local timer is cancelled.
    await tester.pumpWidget(const SizedBox());
  });
}
