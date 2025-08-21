import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers_stats.dart';
import 'hourly_bars_chart.dart';
import 'weekly_bars_chart.dart';

class ActivityStatsPanel extends ConsumerWidget {
  final String activityId;
  const ActivityStatsPanel({super.key, required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(statsTodayProvider(activityId));
    final week  = ref.watch(weekTotalProvider(activityId));
    final month = ref.watch(monthTotalProvider(activityId));
    final year  = ref.watch(yearTotalProvider(activityId));

    final hourly = ref.watch(hourlyTodayProvider(activityId));
    final last7  = ref.watch(last7DaysProvider(activityId));

    return Column(
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

        const SizedBox(height: 16),
        Text("Répartition horaire (aujourd'hui)", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 200,
          child: hourly.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur: $e')),
            data: (buckets) => HourlyBarsChart(buckets: buckets),
          ),
        ),

        const SizedBox(height: 16),
        Text("7 derniers jours", style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        SizedBox(
          height: 220,
          child: last7.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Erreur: $e')),
            data: (stats) => WeeklyBarsChart(stats: stats),
          ),
        ),
      ],
    );
  }

  Widget _chip(String label, AsyncValue<int> v) {
    return v.when(
      loading: () => Chip(label: Text('$label: ...')),
      error: (e, _) => Chip(label: Text('$label: err')),
      data: (m) => Chip(label: Text('$label: ${m}m')),
    );
  }
}
