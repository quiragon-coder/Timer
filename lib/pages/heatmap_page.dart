import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers_stats.dart';
import '../models/stats.dart';
import '../widgets/heatmap.dart';

class ActivityHeatmapPage extends ConsumerWidget {
  final String activityId;
  const ActivityHeatmapPage({super.key, required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 365 jours
    final async = ref.watch(
      lastNDaysProvider(LastNDaysArgs(activityId: activityId, n: 365)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text("Heatmap annuelle")),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: async.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text("Erreur: $e")),
          data: (List<DailyStat> data) {
            final map = <DateTime, int>{};
            for (final d in data) {
              map[d.date] = d.minutes;
            }
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Heatmap(
                    data: map,
                    baseColor: Theme.of(context).colorScheme.primary,
                    onDayTap: (day, minutes) {
                      final dateStr = "${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}/${day.year}";
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text("$dateStr • $minutes min")),
                      );
                    },
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "Astuce: double-tape sur la mini-heatmap dans la page activité pour ouvrir cette vue.",
                    style: Theme.of(context).textTheme.bodySmall,
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
