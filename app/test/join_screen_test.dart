import 'package:dungeon_coop/join_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('join screen defaults to offline play', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: JoinScreen()));

    expect(find.text('DUNGEON CO-OP'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Play offline'), findsOneWidget);
  });

  testWidgets('online mode asks for a server', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: JoinScreen()));

    await tester.tap(find.text('Online'));
    await tester.pump();

    expect(find.byType(TextField), findsNWidgets(2));
    expect(find.text('Enter the dungeon'), findsOneWidget);
  });
}
