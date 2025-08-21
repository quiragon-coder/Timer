import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../providers.dart';                 // dbProvider
import '../services/database_service.dart'; // DatabaseService
import '../services/stats_service.dart';    // StatsService (lastNDays)
import '../widgets/heatmap.dart';           // Heatmap(data:, baseColor:)

/// Page heatmap détaillée (environ 12 mois).
class ActivityHeatmapPage extends ConsumerWidget {
  final String activityId;

  const ActivityHeatmapPage({
    super.key,
    required this.activityId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final db = ref.watch(dbProvider);

    // Récupère l'activité pour l’entête/couleur (si dispo)
    Activity? activity;
    try {
      activity = db.activities.firstWhere((a) => a.id == activityId);
    } catch (_) {
      activity = null;
    }
    final base = activity?.color ?? theme.colorScheme.primary;

    final stats = StatsService(db);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            if (activity != null)
              Text(activity!.emoji, style: const TextStyle(fontSize: 20)),
            if (activity != null) const SizedBox(width: 8),
            Flexible(
              child: Text(
                activity?.name ?? 'Heatmap',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
      body: FutureBuilder(
        // ⬇️ n: 365 (et non days:)
        future: stats.lastNDays(activityId, n: 365),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('Erreur: ${snapshot.error}'));
          }

          final list = (snapshot.data as List?) ?? const [];
          // Convertit List<DailyStat> -> Map<DateTime,int>
          final Map<DateTime, int> data = <DateTime, int>{};
          for (final d in list) {
            try {
              final dynamic item = d;
              final DateTime date = DateUtils.dateOnly(item.date as DateTime);
              final dynamic m = item.minutes;
              final int minutes = m is int ? m : (m is double ? m.round() : 0);
              data[date] = minutes;
            } catch (_) {
              // ignore élément mal formé
            }
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
            children: [
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: theme.colorScheme.outlineVariant.withOpacity(.35),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Heatmap (12 mois)', style: theme.textTheme.titleMedium),
                      const SizedBox(height: 12),
                      Heatmap(
                        data: data,
                        baseColor: base,
                        // Si ta version du widget supporte un callback :
                        // onTap: (day, value) {
                        //   final v = value ?? 0;
                        //   final dd = '${day.day.toString().padLeft(2, '0')}/'
                        //             '${day.month.toString().padLeft(2, '0')}/'
                        //             '${day.year}';
                        //   ScaffoldMessenger.of(context).showSnackBar(
                        //     SnackBar(content: Text('$dd • $v min')),
                        //   );
                        // },
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          _LegendSwatch(base.withOpacity(.20)),
                          _LegendSwatch(base.withOpacity(.40)),
                          _LegendSwatch(base.withOpacity(.60)),
                          _LegendSwatch(base.withOpacity(.80)),
                          _LegendSwatch(base),
                          const SizedBox(width: 8),
                          Text('Intensité (minutes/jour)',
                              style: theme.textTheme.bodySmall),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _LegendSwatch extends StatelessWidget {
  final Color color;
  const _LegendSwatch(this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 16,
      height: 12,
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(
          color: Theme.of(context).colorScheme.outline.withOpacity(.35),
        ),
      ),
    );
  }
}
