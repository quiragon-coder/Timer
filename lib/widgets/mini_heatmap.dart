import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stats.dart';
import '../providers_stats.dart';
import '../pages/heatmap_page.dart';

/// Mini-heatmap cliquable:
/// - 1 tap: SnackBar (overlay) avec la valeur du jour
/// - Double tap: ouvre la page Heatmap détaillée
class MiniHeatmap extends ConsumerWidget {
  final String activityId;
  final int n; // ex. 90 jours

  const MiniHeatmap({
    super.key,
    required this.activityId,
    this.n = 90,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStats =
    ref.watch(lastNDaysProvider(LastNDaysArgs(activityId: activityId, n: n)));

    return asyncStats.when(
      loading: () => const SizedBox(
        height: 84,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => SizedBox(height: 84, child: Center(child: Text('Err: $e'))),
      data: (List<DailyStat> stats) {
        if (stats.isEmpty) {
          return const SizedBox(height: 84, child: Center(child: Text('Aucune donnée')));
        }

        // max minutes pour l’intensité
        final maxMinutes = stats.fold<int>(0, (max, s) {
          final m = s.minutes ?? 0;
          return m > max ? m : max;
        }).clamp(1, 999999);

        final columns = (n / 7).ceil();
        const rows = 7;

        // grille récente alignée à droite
        final grid = List<DailyStat?>.filled(rows * columns, null);
        for (int i = 0; i < stats.length; i++) {
          final indexFromEnd = stats.length - 1 - i; // 0 = dernier jour
          final col = columns - 1 - (indexFromEnd ~/ rows);
          final row = indexFromEnd % rows;
          final gridIndex = row * columns + col;
          if (gridIndex >= 0 && gridIndex < grid.length) {
            grid[gridIndex] = stats[i];
          }
        }

        return GestureDetector(
          onDoubleTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ActivityHeatmapPage(activityId: activityId, n: 365),
              ),
            );
          },
          child: SizedBox(
            height: 84,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text('7 derniers jours',
                      style: Theme.of(context).textTheme.bodySmall),
                ),
                Expanded(
                  child: Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 2,
                    runSpacing: 2,
                    children: List.generate(grid.length, (i) {
                      final s = grid[i];
                      final minutes = s?.minutes ?? 0;
                      final t = minutes / maxMinutes; // 0..1
                      final bg = Color.lerp(
                        Colors.green.withOpacity(0.08),
                        Colors.green,
                        t,
                      ) ??
                          Colors.green;

                      return GestureDetector(
                        onTap: () {
                          if (s == null) return;
                          final d = s.day; // <- DailyStat.day (pas .date)
                          final m = s.minutes ?? 0;
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                "${d.toLocal().toString().split(' ').first} • $m min",
                              ),
                            ),
                          );
                        },
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: s == null
                                ? Colors.grey.withOpacity(0.1)
                                : bg.withOpacity(0.9),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
