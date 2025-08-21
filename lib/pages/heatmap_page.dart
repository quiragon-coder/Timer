import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers_stats.dart';
import '../models/stats.dart';

class ActivityHeatmapPage extends ConsumerWidget {
  final String activityId;
  const ActivityHeatmapPage({super.key, required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lastNDaysProvider(LastNDaysArgs(activityId, 365)));

    return Scaffold(
      appBar: AppBar(title: const Text('Historique annuel')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
          data: (stats) => _HeatmapLarge(stats: stats),
        ),
      ),
    );
  }
}

class _HeatmapLarge extends StatelessWidget {
  final List<DailyStat> stats;
  const _HeatmapLarge({required this.stats});

  @override
  Widget build(BuildContext context) {
    // Même logique que la mini-heatmap, mais plus grand, avec une légende
    final now = DateTime.now();
    Map<DateTime, int> minutesByDay = {
      for (final s in stats)
        DateTime(s.day.year, s.day.month, s.day.day): s.minutes,
    };

    final days = <DateTime>[];
    for (int i = 365 - 1; i >= 0; i--) {
      days.add(DateTime(now.year, now.month, now.day).subtract(Duration(days: i)));
    }

    final maxMinutes = (stats.map((e) => e.minutes).fold<int>(0, (a, b) => a > b ? a : b)).clamp(1, 999999);
    final rows = 7;
    final cols = (days.length / 7).ceil();
    const cell = 16.0;
    const gap = 3.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: cols * (cell + gap),
            child: Column(
              children: List.generate(rows, (r) {
                return Row(
                  children: List.generate(cols, (c) {
                    final idx = r + c * 7;
                    if (idx < 0 || idx >= days.length) return const SizedBox(width: cell, height: cell);
                    final d = days[idx];
                    final key = DateTime(d.year, d.month, d.day);
                    final m = minutesByDay[key] ?? 0;
                    final t = m / (maxMinutes == 0 ? 1 : maxMinutes);
                    final color = Color.lerp(Colors.grey.shade200, Colors.green, t.clamp(0, 1).toDouble())!;
                    return Container(
                      width: cell,
                      height: cell,
                      margin: const EdgeInsets.only(right: gap, bottom: gap),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.black12, width: 0.5),
                      ),
                    );
                  }),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              const Text('Faible'),
              const SizedBox(width: 6),
              for (final t in [0.0, 0.25, 0.5, 0.75, 1.0])
                Container(
                  width: 16, height: 16, margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    color: Color.lerp(Colors.grey.shade200, Colors.green, t)!,
                    border: Border.all(color: Colors.black12, width: 0.5),
                  ),
                ),
              const SizedBox(width: 6),
              const Text('Élevé'),
            ],
          )
        ],
      ),
    );
  }
}
