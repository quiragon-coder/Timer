import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/database_service.dart';
import 'models/activity.dart';

/// Service principal en mémoire
final dbProvider = ChangeNotifierProvider<DatabaseService>((ref) {
  return DatabaseService();
});

/// Liste d’activités (Future pour rester compatible avec .when)
final activitiesProvider = FutureProvider<List<Activity>>((ref) async {
  final db = ref.watch(dbProvider);
  return db.activities;
});
