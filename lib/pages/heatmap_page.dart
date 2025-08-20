import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stats.dart';
import '../providers_stats.dart';

class ActivityHeatmapPage extends ConsumerWidget {
  const ActivityHeatmapPage({super.key, required this.activityId});

  final String activityId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync =
    ref.watch(lastNDaysProvider({'activityId': activityId, 'n': 365}));

    return Scaffold(
      appBar: AppBar(title: const Text('Heatmap annuelle')),
      body: Padding(
        padding: const EdgeInsets.all(12.0),
        child: statsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
          data: (days) {
            if (days.isEmpty) {
              return const Center(child: Text('Pas de donn\u00E9es'));
            }
            // Simple grille annuelle (ex. 52 colonnes x 7 lignes)
            final data = days.reversed.toList(); // ancien -> récent
            final cols = <List<DailyStat>>[];
            for (var i = 0; i < data.length; i += 7) {
              cols.add(data.sublist(i, (i + 7).clamp(0, data.length)));
            }
            final max = (data.map((e) => e.minutes).fold<int>(0, (a, b) => a > b ? a : b)).clamp(1, 9999);

            return SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final col in cols)
                    Padding(
                      padding: const EdgeInsets.only(right: 3),
                      child: Column(
                        children: [
                          for (var r = 0; r < 7; r++)
                            Container(
                              width: 14,
                              height: 14,
                              margin: const EdgeInsets.only(bottom: 3),
                              decoration: BoxDecoration(
                                color: Color.lerp(
                                  Theme.of(context).colorScheme.surfaceContainerHighest,
                                  Theme.of(context).colorScheme.primary,
                                  ((r < col.length ? col[r].minutes : 0) / max).clamp(0, 1),
                                ),
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
