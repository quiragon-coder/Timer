import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stats.dart';
import '../providers_stats.dart';
import '../widgets/heatmap.dart';

class ActivityHeatmapPage extends ConsumerWidget {
  final String activityId;
  final int n; // nombre de jours à afficher (par ex. 365)

  const ActivityHeatmapPage({
    super.key,
    required this.activityId,
    this.n = 365,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats = ref.watch(
      lastNDaysProvider(LastNDaysArgs(activityId: activityId, n: n)),
    );

    return Scaffold(
      appBar: AppBar(title: const Text('Historique (heatmap)')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: asyncStats.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Erreur: $e')),
          data: (List<DailyStat> stats) {
            // On laisse le widget réutilisable Heatmap consommer les DailyStat
            return SingleChildScrollView(
              child: Heatmap(
                stats: stats,
                // Optionnel: callback quand on tape une case
                onDayTap: (date, minutes) {
                  final m = minutes ?? 0;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("$date • $m min")),
                  );
                },
              ),
            );
          },
        ),
      ),
    );
  }
}
