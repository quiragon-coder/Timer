
## Activer Isar

- Ajouté: `lib/isar/*.dart` (modèles Isar) — exécutez `flutter pub get` puis `dart run build_runner build --delete-conflicting-outputs` pour générer les `*.g.dart`.
- Ajouté: `lib/services/database_service_isar.dart` — implémente la même API que `DatabaseService` mais avec persistance.

Pour l'utiliser, changez le provider dans `lib/providers.dart` :

```dart
import 'services/database_service_isar.dart';

final dbProvider = ChangeNotifierProvider<DatabaseServiceIsar>((ref) {
  // IMPORTANT: init() est async — vous devez l'attendre AVANT runApp.
  throw UnimplementedError('Voir main.dart pour un exemple d'initialisation.');
});
```

Ou plus simple : dans `main.dart`, initialisez le service, puis passez-le via `ProviderScope(overrides: [...])`.
