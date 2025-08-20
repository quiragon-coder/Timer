import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../providers.dart';
import '../providers_stats.dart';
import '../widgets/activity_controls.dart';
import '../widgets/activity_stats_panel.dart';

class ActivityDetailPage extends ConsumerStatefulWidget {
  final Activity activity;
  const ActivityDetailPage({super.key, required this.activity});

  @override
  ConsumerState<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends ConsumerState<ActivityDetailPage> {
  Timer? _ticker; // pour faire “tiquer” le badge ⏱ en temps réel

  @override
  void initState() {
    super.initState();
    // petit ticker pour forcer un repaint toutes les secondes si nécessaire
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _invalidateStats(String id) {
    // Invalide en douceur les providers de stats
    try { ref.invalidate(statsTodayProvider(id)); } catch (_) {}
    try { ref.invalidate(hourlyTodayProvider(id)); } catch (_) {}
    try { ref.invalidate(weekTotalProvider(id)); } catch (_) {}
    try { ref.invalidate(monthTotalProvider(id)); } catch (_) {}
    try { ref.invalidate(yearTotalProvider(id)); } catch (_) {}
    try { ref.invalidate(last7DaysProvider(id)); } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final a = widget.activity;

    final running = db.isRunning(a.id);
    final paused = db.isPaused(a.id);
    final elapsed = db.runningElapsed(a.id);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Text(a.name, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: 'Rafraîchir les stats',
            icon: const Icon(Icons.refresh),
            onPressed: () => _invalidateStats(a.id),
          ),
        ],
      ),
      body: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 520;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header : emoji + nom + pastille + badge temps
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(a.emoji, style: TextStyle(fontSize: compact ? 28 : 34)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        a.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(color: a.color, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 10),
                    if (running)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: (paused ? Colors.orange : Colors.green).withOpacity(.15),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(paused ? Icons.pause : Icons.timer_outlined, size: 16),
                          const SizedBox(width: 6),
                          Text(
                            '$mm:$ss',
                            style: TextStyle(fontFeatures: const [ui.FontFeature.tabularFigures()]),
                          ),
                        ]),
                      ),
                  ],
                ),

                const SizedBox(height: 16),

                // Contrôles
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ActivityControls(activityId: a.id, compact: compact),
                    OutlinedButton.icon(
                      onPressed: () => _invalidateStats(a.id),
                      icon: const Icon(Icons.cached),
                      label: const Text('Rafraîchir'),
                    ),
                  ],
                ),

                const SizedBox(height: 20),

                // Panneau Stats
                Card(
                  elevation: 0,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    // ⬇️ ICI la correction : on passe activityId: a.id
                    child: ActivityStatsPanel(activityId: a.id),
                  ),
                ),

                const SizedBox(height: 24),

                // Résumé du jour simple (facultatif)
                _TodaySummaryLine(activityId: a.id),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _TodaySummaryLine extends ConsumerWidget {
  final String activityId;
  const _TodaySummaryLine({required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(statsTodayProvider(activityId));
    return todayAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => const SizedBox.shrink(),
      data: (m) => Row(
        children: [
          const Icon(Icons.today, size: 18),
          const SizedBox(width: 8),
          Text('Aujourd’hui : $m min'),
        ],
      ),
    );
  }
}
