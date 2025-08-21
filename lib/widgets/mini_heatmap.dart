import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stats.dart';
import '../providers_stats.dart';
import '../pages/heatmap_page.dart';
import 'heatmap.dart';

/// Mini heatmap (tap = overlay, double-tap = page détaillée)
class MiniHeatmap extends ConsumerWidget {
  final String activityId;
  final int days; // ex: 120 ou 180

  const MiniHeatmap({
    super.key,
    required this.activityId,
    this.days = 120,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lastNDaysProvider(LastNDaysArgs(activityId: activityId, n: days)));

    return async.when(
      loading: () => const SizedBox(height: 80),
      error: (e, _) => Text("Err heatmap: $e"),
      data: (List<DailyStat> list) {
        // Convertir en Map<DateTime,int>
        final map = <DateTime, int>{};
        for (final d in list) {
          map[d.date] = d.minutes;
        }

        return GestureDetector(
          onDoubleTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ActivityHeatmapPage(activityId: activityId),
            ));
          },
          child: Heatmap(
            data: map,
            baseColor: Theme.of(context).colorScheme.primary,
            onDayTap: (day, minutes) {
              // Overlay d’info
              final dateStr = "${day.day.toString().padLeft(2, '0')}/${day.month.toString().padLeft(2, '0')}";
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text("Détails"),
                  content: Text("$dateStr • $minutes min"),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text("OK"),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}
