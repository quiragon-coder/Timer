import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers_stats.dart';
import '../widgets/heatmap.dart';

class ActivityHeatmapPage extends ConsumerWidget {
  final String activityId;
  final int n;
  final Color baseColor;

  const ActivityHeatmapPage({
    super.key,
    required this.activityId,
    required this.n,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      lastNDaysProvider(LastNDaysArgs(activityId: activityId, n: n)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Heatmap')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
          data: (stats) {
            final map = <DateTime, int>{};
            for (final d in stats) {
              map[DateUtils.dateOnly(d.date)] = d.minutes;
            }
            return ListView(
              children: [
                Text(
                  "$n derniers jours",
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Heatmap(
                      data: map,
                      baseColor: baseColor,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
