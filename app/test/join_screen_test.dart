import 'package:dungeon_coop/join_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('join screen shows name, server and join controls', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: JoinScreen()));

    expect(find.text('DUNGEON CO-OP'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Enter the dungeon'), findsOneWidget);
  });
}
