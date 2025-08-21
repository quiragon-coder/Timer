import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart'; // dbProvider
import '../models/stats.dart';
import 'weekly_bars_chart.dart';

class WeeklyBarsCard extends ConsumerWidget {
  final String activityId;
  const WeeklyBarsCard({super.key, required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);

    // Construit la liste des 7 derniers jours (du plus ancien au plus récent)
    final today = DateUtils.dateOnly(DateTime.now());
    final start = today.subtract(const Duration(days: 7 - 1));
    final stats = <DailyStat>[];
    for (int i = 0; i < 7; i++) {
      final day = DateUtils.dateOnly(start.add(Duration(days: i)));
      final minutes = db.effectiveMinutesOnDay(activityId, day);
      stats.add(DailyStat(date: day, minutes: minutes));
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("7 derniers jours", style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        SizedBox(height: 160, child: WeeklyBarsChart(stats: stats)),
      ],
    );
  }
}
