import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/stats_service.dart';
import 'providers.dart';

final heatmapYearProvider =
FutureProvider.family<Map<DateTime, int>, String>((ref, activityId) async {
  final db = ref.read(dbProvider);
  final stats = StatsService(db);
  final now = DateTime.now();
  final from = DateTime(now.year, 1, 1);
  return stats.dailyMinutesRange(activityId: activityId, from: from, to: now);
});
