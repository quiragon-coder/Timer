import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers_stats.dart';
import '../widgets/hourly_bars_chart.dart';
import '../widgets/weekly_bars_chart.dart';
import '../widgets/mini_heatmap.dart';

class ActivityStatsPanel extends ConsumerWidget {
  final String activityId;
  const ActivityStatsPanel({super.key, required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today    = ref.watch(minutesTodayProvider(activityId));
    final week     = ref.watch(minutesThisWeekProvider(activityId));
    final month    = ref.watch(minutesThisMonthProvider(activityId));
    final year     = ref.watch(minutesThisYearProvider(activityId));
    final hourly   = ref.watch(hourlyTodayProvider(activityId));
    final last7    = ref.watch(lastNDaysProvider(LastNDaysArgs(activityId: activityId, n: 7)));

    final color = Theme.of(context).colorScheme.primary.withOpacity(.10);

    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _chip("Aujourd'hui", today),
                _chip("Semaine", week),
                _chip("Mois", month),
                _chip("Année", year),
              ],
            ),

            const SizedBox(height: 12),
            Text("Aujourd’hui par heure", style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
              child: hourly.when(
                loading: () => const SizedBox(height: 64),
                error: (e, _) => Text("Err: $e"),
                data: (buckets) => HourlyBarsChart(buckets: buckets),
              ),
            ),

            const SizedBox(height: 16),
            Row(
              children: [
                Text("7 derniers jours", style: Theme.of(context).textTheme.titleSmall),
                const Spacer(),
                // Rien à droite : la mini-heatmap est cliquable (double tap) pour ouvrir la page détaillée
              ],
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(8)),
              child: last7.when(
                loading: () => const SizedBox(height: 80),
                error: (e, _) => Text("Err: $e"),
                data: (stats) => Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    WeeklyBarsChart(stats: stats),
                    const SizedBox(height: 12),
                    // mini heatmap cliquable et double-tape
                    MiniHeatmap(activityId: activityId, days: 120),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, AsyncValue<int> av) {
    return av.when(
      loading: () => Chip(label: Text("$label: ...")),
      error: (e, _) => Chip(label: Text("$label: Err")),
      data: (m) => Chip(label: Text("$label: $m min")),
    );
  }
}
