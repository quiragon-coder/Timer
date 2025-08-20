// lib/pages/heatmap_page.dart
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stats.dart';       // DailyStat
import '../providers_stats.dart';    // statsServiceProvider

class ActivityHeatmapPage extends ConsumerWidget {
  const ActivityHeatmapPage({
    super.key,
    required this.activityId,
    this.accent,
  });

  final String activityId;
  final Color? accent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.read(statsServiceProvider);
    final Color color = accent ?? Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: const Text('Heatmap annuelle')),
      body: FutureBuilder<List<DailyStat>>(
        // IMPORTANT: ta méthode lastNDays attend (activityId, n: ...).
        future: stats.lastNDays(activityId, n: 365),
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snap.data ?? const <DailyStat>[];
          if (data.isEmpty) {
            return const Center(child: Text("Aucune donnée pour l'instant"));
          }

          final byDay = <DateTime, int>{
            for (final d in data) DateUtils.dateOnly(d.day): d.minutes,
          };

          // On affiche jusqu'à 365 jours (ou la taille des données si plus courte)
          final totalDays = math.min(365, byDay.length.clamp(1, 365));
          final today = DateUtils.dateOnly(DateTime.now());
          final start = today.subtract(Duration(days: totalDays - 1));
          final allDays = List<DateTime>.generate(
            totalDays, (i) => start.add(Duration(days: i)),
          );

          // Colonnes par semaine (lun → dim)
          final List<List<DateTime>> weeks = [];
          var col = <DateTime>[];
          for (final d in allDays) {
            if (col.isEmpty) {
              col = [d];
            } else if (d.weekday == DateTime.monday) {
              weeks.add(col);
              col = [d];
            } else {
              col.add(d);
            }
          }
          if (col.isNotEmpty) weeks.add(col);

          final maxMin =
          byDay.values.isEmpty ? 0 : byDay.values.reduce(math.max);

          Color colorFor(int v) {
            if (v <= 0 || maxMin <= 0) {
              return Theme.of(context).colorScheme.onSurface.withOpacity(.10);
            }
            final t = v / maxMin;
            if (t < .20) return color.withOpacity(.25);
            if (t < .40) return color.withOpacity(.45);
            if (t < .70) return color.withOpacity(.65);
            return color.withOpacity(.85);
          }

          const double cell = 12;
          const double gap = 4;
          final colW = cell + gap;
          final rowH = cell + gap;

          final grid = Card(
            margin: const EdgeInsets.all(16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: SizedBox(
                  height: 7 * rowH - gap,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final colDays in weeks)
                        Padding(
                          padding: const EdgeInsets.only(right: gap),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(7, (row) {
                              DateTime? day;
                              try {
                                day = colDays.firstWhere((d) => d.weekday == row + 1);
                              } catch (_) {
                                day = null;
                              }
                              final v = (day == null) ? 0 : (byDay[day] ?? 0);
                              return Padding(
                                padding: const EdgeInsets.only(bottom: gap),
                                child: Tooltip(
                                  message: day == null
                                      ? '—'
                                      : "${_wd(day.weekday)} ${_two(day.day)}/${_two(day.month)}: $v min",
                                  child: Container(
                                    width: cell,
                                    height: cell,
                                    decoration: BoxDecoration(
                                      color: colorFor(v),
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  ),
                                ),
                              );
                            }),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 8),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text('Derniers jours', style: Theme.of(context).textTheme.titleMedium),
              ),
              grid,
            ],
          );
        },
      ),
    );
  }

  static String _two(int v) => v.toString().padLeft(2, '0');
  static String _wd(int w) {
    const fr = ['Lun', 'Mar', 'Mer', 'Jeu', 'Ven', 'Sam', 'Dim'];
    return fr[(w - 1).clamp(0, 6)];
  }
}
