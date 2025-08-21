import 'stats_service.dart';

extension StatsHeatmapExt on StatsService {
  Future<Map<DateTime, int>> lastNDaysMap(String activityId, int n) {
    final now = DateTime.now();
    final from = DateTime(now.year, now.month, now.day).subtract(Duration(days: n - 1));
    return dailyMinutesRange(activityId: activityId, from: from, to: now);
  }
}
