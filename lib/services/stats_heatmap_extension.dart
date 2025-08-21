import 'package:flutter/material.dart' show DateUtils;

import './database_service.dart';
import './stats_service.dart';

/// Petites aides pour produire les données de heatmap depuis le DB
extension StatsHeatmapExtension on DatabaseService {
  /// Map<Date, minutes> pour les N derniers jours
  Future<Map<DateTime, int>> heatmapData(String activityId, {required int days}) async {
    final stats = await StatsService(this).lastNDays(activityId, n: days);
    return {
      for (final d in stats) DateUtils.dateOnly(d.date): d.minutes,
    };
  }
}
