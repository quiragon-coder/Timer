import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../providers.dart';                      // dbProvider
import '../providers_stats.dart';               // chips/minutes*
import '../widgets/activity_controls.dart';
import '../widgets/activity_stats_panel.dart';
import '../widgets/mini_heatmap.dart';
import 'heatmap_page.dart';

class ActivityDetailPage extends ConsumerStatefulWidget {
  const ActivityDetailPage({super.key, required this.activity});

  final Activity activity;

  @override
  ConsumerState<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends ConsumerState<ActivityDetailPage> {
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker(bool running) {
    final active = _ticker?.isActive ?? false;
    if (running && !active) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running && active) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final a = widget.activity;
    final running = db.isRunning(a.id);
    final paused = db.isPaused(a.id);
    _syncTicker(running);

    // minutes pour puces
    final todayAsync  = ref.watch(minutesTodayProvider(a.id));
    final weekAsync   = ref.watch(minutesThisWeekProvider(a.id));
    final monthAsync  = ref.watch(minutesThisMonthProvider(a.id));
    final yearAsync   = ref.watch(minutesThisYearProvider(a.id));

    // badge en haut à droite
    final elapsed = db.runningElapsed(a.id);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(a.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(a.name,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium),
            ),
          ],
        ),
        actions: [
          if (running)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (paused
                      ? Colors.orange
                      : Theme.of(context).colorScheme.primary)
                      .withOpacity(.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(paused ? Icons.pause : Icons.timer_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text('$mm:$ss'),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // En-tête + contrôles
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(a.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                            color: a.color, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text("Objectif: ${a.dailyGoalMinutes ?? 0} min/j"),
                    ]),
                    const SizedBox(height: 12),
                    ActivityControls(activityId: a.id),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Stats (puces + barres horaires + 7 jours)
          Card(
            clipBehavior: Clip.antiAlias,
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _StatChip(icon: Icons.today_outlined, label: "Aujourd'hui",
                          minutesAsync: todayAsync),
                      _StatChip(icon: Icons.view_week_outlined, label: "Semaine",
                          minutesAsync: weekAsync),
                      _StatChip(icon: Icons.calendar_view_month, label: "Mois",
                          minutesAsync: monthAsync),
                      _StatChip(icon: Icons.event_available_outlined, label: "Ann\u00E9e",
                          minutesAsync: yearAsync),
                    ],
                  ),

                  const SizedBox(height: 16),
                  Divider(color: Theme.of(context).dividerColor),

                  // Graphiques existants (si tu utilises ActivityStatsPanel)
                  const SizedBox(height: 12),
                  ActivityStatsPanel(activityId: a.id),

                  const SizedBox(height: 20),

                  // ==== Mini heatmap + "Voir plus" ====
                  Row(
                    children: [
                      Text('7 derniers jours',
                          style: Theme.of(context).textTheme.titleMedium),
                      const Spacer(),
                      TextButton.icon(
                        onPressed: () {
                          Navigator.of(context).push(MaterialPageRoute(
                            builder: (_) =>
                                ActivityHeatmapPage(activityId: a.id),
                          ));
                        },
                        icon: const Icon(Icons.grid_view_outlined, size: 18),
                        label: const Text('Voir plus'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  MiniHeatmap(activityId: a.id, days: 21),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.minutesAsync,
  });

  final IconData icon;
  final String label;
  final AsyncValue<int> minutesAsync;

  @override
  Widget build(BuildContext context) {
    return minutesAsync.when(
      loading: () => Chip(
        avatar: Icon(icon, size: 16),
        label: const Text('...'),
      ),
      error: (e, _) => Chip(
        avatar: Icon(icon, size: 16),
        label: const Text('Err'),
      ),
      data: (m) => Chip(
        avatar: Icon(icon, size: 16),
        label: Text('$label: $m min'),
      ),
    );
  }
}
