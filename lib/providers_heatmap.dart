import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/stats.dart';
import 'providers_stats.dart';

/// Alias pratique si ton UI importe ce fichier
final miniHeatmapProvider = last28DaysProvider;

/// Valeur max (utile pour normaliser les teintes)
final heatmapMaxProvider = Provider.family<int, List<DayStat>>((ref, days) {
  var max = 0;
  for (final d in days) {
    if (d.minutes > max) max = d.minutes;
  }
  return max == 0 ? 1 : max;
});
