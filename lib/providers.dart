import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/activity.dart';
import 'services/database_service.dart';

/// Service principal
final dbProvider = ChangeNotifierProvider<DatabaseService>((ref) {
  return DatabaseService();
});

/// Liste d’activités (recalculée à chaque notifyListeners du service)
final activitiesProvider = FutureProvider<List<Activity>>((ref) async {
  final db = ref.watch(dbProvider);
  // on renvoie un Future pour rester compatible avec le code qui fait .when(...)
  return db.activities;
});
