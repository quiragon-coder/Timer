import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:habits_timer/main.dart';

void main() {
  testWidgets('HabitsApp démarre et affiche la page d\'activités',
          (WidgetTester tester) async {
        // Monte l'app avec Riverpod
        await tester.pumpWidget(
          const ProviderScope(child: HabitsApp()),
        );

        // Vérifie que l'app a un MaterialApp
        expect(find.byType(MaterialApp), findsOneWidget);

        // Vérifie que la page d'activités est affichée (titre ou widget spécifique)
        expect(find.text('Activities'), findsOneWidget);
      });
}
