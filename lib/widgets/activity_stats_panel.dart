// lib/widgets/activity_stats_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/color_compat.dart';
import '../providers_stats.dart';
import 'hourly_bars_chart.dart';
import 'weekly_bars_chart.dart';

class ActivityStatsPanel extends ConsumerWidget {
  final String activityId;
  const ActivityStatsPanel({super.key, required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync  = ref.watch(minutesTodayProvider(activityId));
    final weekAsync   = ref.watch(minutesThisWeekProvider(activityId));
    final monthAsync  = ref.watch(minutesThisMonthProvider(activityId));
    final yearAsync   = ref.watch(minutesThisYearProvider(activityId));
    final hourlyAsync = ref.watch(hourlyTodayProvider(activityId));
    final last7Async  = ref.watch(lastNDaysProvider(LastNDaysArgs(activityId: activityId, n: 7)));

    Widget chip(String label, AsyncValue<int> val) {
      return val.when(
        loading: () => Chip(label: Text('$label…')),
        error: (e, _) => Chip(label: Text('$label: err')),
        data: (m) => Chip(label: Text('$label: ${m}m')),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            chip("Aujourd'hui", todayAsync),
            chip("Semaine", weekAsync),
            chip("Mois", monthAsync),
            chip("Année", yearAsync),
          ],
        ),
        const SizedBox(height: 16),

        // Graphe horaire (aujourd'hui)
        Text("Aujourd'hui (par heures)", style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.outline.withAlphaCompat(.3),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(8),
          child: hourlyAsync.when(
            loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
            error: (e, _) => SizedBox(height: 60, child: Center(child: Text('Erreur: $e'))),
            data: (buckets) => SizedBox(height: 160, child: HourlyBarsChart(buckets: buckets)),
          ),
        ),

        const SizedBox(height: 16),

        // 7 derniers jours
        Text("7 derniers jours", style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: 8),
        last7Async.when(
          loading: () => const SizedBox(height: 140, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
          error: (e, _) => SizedBox(height: 60, child: Center(child: Text('Erreur: $e'))),
          data: (days) => SizedBox(height: 160, child: WeeklyBarsChart(stats: days)),
        ),
      ],
    );
  }
}
