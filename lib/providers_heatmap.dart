import 'package:flutter/material.dart' show DateUtils;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import './providers_stats.dart';
import './models/stats.dart' show DailyStat;

/// Petit type utilitaire (min/max)
class IntRange {
  final int min;
  final int max;
  const IntRange(this.min, this.max);
}

/// Calcule min/max des minutes sur N jours
final heatmapRangeProvider =
FutureProvider.family<IntRange, LastNDaysArgs>((ref, args) async {
  final days = await ref.watch(lastNDaysProvider(args).future);
  if (days.isEmpty) return const IntRange(0, 0);
  var minVal = days.first.minutes;
  var maxVal = days.first.minutes;
  for (final d in days) {
    if (d.minutes < minVal) minVal = d.minutes;
    if (d.minutes > maxVal) maxVal = d.minutes;
  }
  return IntRange(minVal, maxVal);
});

/// Transforme la liste DailyStat -> Map<DateTime, minutes> (clé = dateOnly)
final heatmapDataProvider =
FutureProvider.family<Map<DateTime, int>, LastNDaysArgs>((ref, args) async {
  final days = await ref.watch(lastNDaysProvider(args).future);
  final map = <DateTime, int>{};
  for (final d in days) {
    map[DateUtils.dateOnly(d.date)] = d.minutes;
  }
  return map;
});
