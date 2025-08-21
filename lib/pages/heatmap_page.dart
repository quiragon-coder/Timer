// lib/pages/heatmap_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stats.dart';              // DailyStat (day, minutes)
import '../providers_stats.dart';           // lastNDaysProvider / LastNDaysArgs
import '../widgets/heatmap.dart';           // Heatmap widget custom

class ActivityHeatmapPage extends ConsumerWidget {
  final String activityId;
  final int n; // nb de jours (ex: 365)

  const ActivityHeatmapPage({
    super.key,
    required this.activityId,
    required this.n,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(lastNDaysProvider(LastNDaysArgs(
      activityId: activityId,
      n: n,
    )));

    return Scaffold(
      appBar: AppBar(title: const Text('Heatmap')),
      body: statsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (List<DailyStat> stats) {
          // conversion -> Map<DateTime,int>
          final map = <DateTime, int>{
            for (final s in stats) s.day: s.minutes,
          };

          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Heatmap(
              data: map,
              baseColor: Theme.of(context).colorScheme.primary,
              onDayTap: (day, minutes) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${day.toString().substring(0, 10)} : ${minutes} min',
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
