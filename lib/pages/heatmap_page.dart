import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers_stats.dart';
import '../widgets/heatmap.dart';

class ActivityHeatmapPage extends ConsumerWidget {
  final String activityId;
  final int n; // nb de jours (ex: 365)
  final Color? baseColor;

  const ActivityHeatmapPage({
    super.key,
    required this.activityId,
    this.n = 365,
    this.baseColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      lastNDaysProvider(
        LastNDaysArgs(activityId: activityId, n: n),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Heatmap')),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (stats) {
          // Map<DateTime, int> attendu par Heatmap
          final data = <DateTime, int>{
            for (final d in stats) DateUtils.dateOnly(d.date): d.minutes
          };

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Heatmap(
              data: data,
              baseColor: baseColor ?? Theme.of(context).colorScheme.primary,
              onTap: (day, minutes) {
                final d = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('$d : $minutes min')),
                );
              },
            ),
          );
        },
      ),
    );
  }
}
