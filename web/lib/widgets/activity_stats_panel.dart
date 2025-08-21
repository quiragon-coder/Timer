import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers_stats.dart';              // minutesTodayProvider, weekTotalProvider, monthTotalProvider, yearTotalProvider, hourlyTodayProvider, lastNDaysProvider, LastNDaysArgs
import 'hourly_bars_chart.dart';              // HourlyBarsChart(buckets: ...)
import 'weekly_bars_chart.dart';              // WeeklyBarsChart(stats: ...)
import 'mini_heatmap.dart';                   // MiniHeatmap(activityId: ..., n: ...)

class ActivityStatsPanel extends ConsumerWidget {
  final String activityId;

  const ActivityStatsPanel({super.key, required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // Providers (tous en AsyncValue)
    final todayAsync  = ref.watch(minutesTodayProvider(activityId));
    final weekAsync   = ref.watch(weekTotalProvider(activityId));
    final monthAsync  = ref.watch(monthTotalProvider(activityId));
    final yearAsync   = ref.watch(yearTotalProvider(activityId));
    final hourlyAsync = ref.watch(hourlyTodayProvider(activityId));
    final last7Async  = ref.watch(lastNDaysProvider(LastNDaysArgs(activityId: activityId, n: 7)));

    return Card(
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      color: cs.surface,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Titre
            Text('Stats', style: textTheme.titleMedium),

            const SizedBox(height: 8),

            // Ligne des totaux Aujourd’hui / Semaine / Mois / Année (chips responsives)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _TotalChip(
                  label: "Aujourd'hui",
                  valueAsync: todayAsync,
                  baseColor: cs.primary,
                ),
                _TotalChip(
                  label: 'Semaine',
                  valueAsync: weekAsync,
                  baseColor: cs.tertiary,
                ),
                _TotalChip(
                  label: 'Mois',
                  valueAsync: monthAsync,
                  baseColor: cs.secondary,
                ),
                _TotalChip(
                  label: 'Année',
                  valueAsync: yearAsync,
                  baseColor: cs.outline,
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Mini heatmap (tap = overlay info, double-tap = page détaillée)
            MiniHeatmap(
              activityId: activityId,
              n: 7,
              baseColor: cs.primary,
            ),

            const SizedBox(height: 12),

            // Histogramme journalier (par heure) — aujourd’hui
            Text('Aujourd’hui (répartition horaire)', style: textTheme.titleSmall),
            const SizedBox(height: 6),
            SizedBox(
              height: 140,
              child: hourlyAsync.when(
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Center(child: Text('Erreur: $e')),
                data: (buckets) => HourlyBarsChart(buckets: buckets),
              ),
            ),

            const SizedBox(height: 12),

            // Barres 7 derniers jours
            Row(
              children: [
                Text('7 derniers jours', style: textTheme.titleSmall),
              ],
            ),
            const SizedBox(height: 6),
            SizedBox(
              height: 160,
              child: last7Async.when(
                loading: () => const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                error: (e, _) => Center(child: Text('Erreur: $e')),
                data: (stats) => WeeklyBarsChart(stats: stats),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TotalChip extends StatelessWidget {
  final String label;
  final AsyncValue<int> valueAsync;
  final Color baseColor;

  const _TotalChip({
    required this.label,
    required this.valueAsync,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    final bg = baseColor.withOpacity(0.10);
    final border = baseColor.withOpacity(0.35);

    return valueAsync.when(
      loading: () => Chip(
        label: Text('$label: …'),
        side: BorderSide(color: border),
        backgroundColor: bg,
      ),
      error: (e, _) => Chip(
        label: Text('$label: err'),
        side: BorderSide(color: border),
        backgroundColor: bg,
      ),
      data: (m) => Chip(
        avatar: const Icon(Icons.timer_outlined, size: 16),
        label: Text('$label: $m min'),
        side: BorderSide(color: border),
        backgroundColor: bg,
      ),
    );
  }
}
