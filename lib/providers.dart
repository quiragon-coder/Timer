import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/activity.dart';
import 'services/database_service.dart';
import 'services/stats_service.dart';

/// Service principal (in-memory) qui notifie l’UI.
final dbProvider = ChangeNotifierProvider<DatabaseService>((ref) {
  return DatabaseService();
});

/// Liste des activités (se met à jour quand dbProvider notifie).
final activitiesProvider = FutureProvider<List<Activity>>((ref) async {
  final db = ref.watch(dbProvider);
  return db.getActivities();
});

/// Service de stats construit au-dessus du DB.
final statsServiceProvider = Provider<StatsService>((ref) {
  final db = ref.watch(dbProvider);
  return StatsService(db);
});
