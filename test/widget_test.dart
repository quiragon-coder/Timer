import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// Le nom du package est "habits_timer" (pubspec.yaml)
import 'package:habits_timer/main.dart';

void main() {
  testWidgets('App builds', (WidgetTester tester) async {
    // On wrappe dans ProviderScope car l'app utilise Riverpod
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    // Fumetest: la page d’accueil affiche "Activities"
    expect(find.text('Activities'), findsOneWidget);
  });
}
