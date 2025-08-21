// lib/widgets/activity_stats_panel.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers_stats.dart';
import '../pages/heatmap_page.dart';
import 'hourly_bars_chart.dart';
import 'weekly_bars_chart.dart';
import 'mini_heatmap.dart';

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
    final last7Async  = ref.watch(
      lastNDaysProvider(LastNDaysArgs(activityId: activityId, n: 7)),
    );

    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre + bouton "Voir la heatmap"
            Row(
              children: [
                Text(
                  'Stats',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ActivityHeatmapPage(
                          activityId: activityId,
                          n: 365,
                          baseColor: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.grid_on_rounded, size: 18),
                  label: const Text('Heatmap'),
                ),
              ],
            ),

            // Ligne rapide "Aujourd'hui"
            todayAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.only(top: 4, bottom: 8),
                child: LinearProgressIndicator(minHeight: 2),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text('Aujourd’hui : erreur ($e)'),
              ),
              data: (m) => Padding(
                padding: const EdgeInsets.only(top: 2, bottom: 8),
                child: Text(
                  "Aujourd'hui : $m min",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ),

            // 4 mini stats (Aujourd’hui / Semaine / Mois / Année)
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _MiniStat(label: "Auj.", value: todayAsync),
                _MiniStat(label: "Sem.", value: weekAsync),
                _MiniStat(label: "Mois", value: monthAsync),
                _MiniStat(label: "Ann.", value: yearAsync),
              ],
            ),

            const SizedBox(height: 16),

            // Graphe "Aujourd'hui (par heure)"
            Text(
              "Aujourd'hui (par heures)",
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(.3),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: hourlyAsync.when(
                loading: () => const SizedBox(
                  height: 140,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (e, _) => SizedBox(
                  height: 60,
                  child: Center(child: Text('Erreur: $e')),
                ),
                data: (buckets) => SizedBox(
                  height: 160,
                  child: HourlyBarsChart(buckets: buckets),
                ),
              ),
            ),

            const SizedBox(height: 16),

            // Graphe "7 derniers jours"
            Row(
              children: [
                Text(
                  "7 derniers jours",
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Spacer(),
                // Hint: double-tap sur la mini heatmap pour la page détaillée
                const Icon(Icons.info_outline, size: 16),
                const SizedBox(width: 4),
                const Text("Double-tap la mini-heatmap"),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              decoration: BoxDecoration(
                border: Border.all(
                  color: Theme.of(context).colorScheme.outline.withOpacity(.3),
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.all(8),
              child: last7Async.when(
                loading: () => const SizedBox(
                  height: 150,
                  child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
                ),
                error: (e, _) => SizedBox(
                  height: 60,
                  child: Center(child: Text('Erreur: $e')),
                ),
                data: (stats) => Column(
                  children: [
                    SizedBox(
                      height: 150,
                      child: WeeklyBarsChart(stats: stats),
                    ),
                    const SizedBox(height: 12),

                    // Mini-heatmap directement cliquable (tap = overlay; double-tap = page détaillée)
                    MiniHeatmap(
                      activityId: activityId,
                      days: 30, // fenêtre courte sous le graphe 7j
                      baseColor: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label;
  final AsyncValue<int> value;

  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final Color border = Theme.of(context).colorScheme.outline.withOpacity(.3);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(999),
      ),
      child: value.when(
        loading: () => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 8),
            const SizedBox(
              width: 12, height: 12,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
          ],
        ),
        error: (e, _) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 6),
            const Icon(Icons.error_outline, size: 14),
          ],
        ),
        data: (m) => Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label),
            const SizedBox(width: 6),
            Text("$m min", style: const TextStyle(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
