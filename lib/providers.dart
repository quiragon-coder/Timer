import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/activity.dart';
import 'services/database_service.dart';
import 'services/stats_service.dart';

final dbProvider = Provider<DatabaseService>((ref) {
  return DatabaseService();
});

final statsServiceProvider = Provider<StatsService>((ref) {
  final db = ref.read(dbProvider);
  return StatsService(db);
});

final activitiesProvider = FutureProvider<List<Activity>>((ref) async {
  final db = ref.read(dbProvider);
  return db.getActivities();
});
