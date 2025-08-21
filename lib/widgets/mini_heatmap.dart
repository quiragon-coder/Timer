import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers_stats.dart';          // lastNDaysProvider, LastNDaysArgs
import '../widgets/heatmap.dart';          // votre composant Heatmap(Map<DateTime,int> data, Color baseColor, {onDayTap})
import '../pages/heatmap_page.dart';       // ActivityHeatmapPage(activityId:, n:)

/// Mini heatmap pour 7 jours (ou n jours) :
/// - Tape simple sur un carré  -> petit overlay d’infos (date + minutes)
/// - Double-tape n'importe où  -> ouvre la heatmap détaillée (365 jours par défaut)
class MiniHeatmap extends ConsumerWidget {
  final String activityId;
  final int n;
  final Color? baseColor;

  const MiniHeatmap({
    super.key,
    required this.activityId,
    this.n = 7,
    this.baseColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(
      lastNDaysProvider(LastNDaysArgs(activityId: activityId, n: n)),
    );

    return statsAsync.when(
      loading: () => const SizedBox(
        height: 60,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => SizedBox(
        height: 60,
        child: Center(child: Text('Erreur: $e')),
      ),
      data: (stats) {
        // Convertit List<DailyStat> -> Map<DateTime, int> attendu par Heatmap
        final data = <DateTime, int>{
          for (final s in stats) s.day: s.minutes,
        };

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ActivityHeatmapPage(
                  activityId: activityId,
                  n: 365,
                ),
              ),
            );
          },
          child: Heatmap(
            data: data,
            baseColor: baseColor ?? Theme.of(context).colorScheme.primary,
            onDayTap: (day, minutes) {
              // Petit overlay (dialog) avec la date + minutes
              final locale = Localizations.localeOf(context).toString();
              final df = DateFormat.yMMMMEEEEd(locale);
              showDialog(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('Détail'),
                  content: Text('${df.format(day)}\n$minutes min'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('OK'),
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
