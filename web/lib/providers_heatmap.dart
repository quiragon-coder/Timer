import "package:flutter_riverpod/flutter_riverpod.dart";

import "providers.dart";
import "services/stats_service.dart";
import "services/stats_heatmap_extension.dart";

final heatmapYearProvider = FutureProvider.family<Map<DateTime, int>, String>((ref, activityId) async {
  final db = ref.read(dbProvider);
  final stats = StatsService(db);
  final now = DateTime.now();
  final from = DateTime(now.year - 1, now.month, now.day);
  return stats.dailyMinutesRange(activityId: activityId, from: from, to: now);
});
