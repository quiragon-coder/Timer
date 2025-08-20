// lib/pages/activity_detail_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../models/session.dart';
import '../providers.dart';
import '../widgets/activity_controls.dart';
import '../widgets/activity_stats_panel.dart';
import 'heatmap_page.dart';

class ActivityDetailPage extends ConsumerStatefulWidget {
  final Activity activity;
  const ActivityDetailPage({super.key, required this.activity});

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
            Flexible(child: Text(a.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Carte statut + contrôles
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 10,
                        height: 10,
                        decoration: BoxDecoration(
                          color: a.color,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          a.name,
                          style: Theme.of(context).textTheme.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (running)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: (paused ? Colors.orange : Colors.green)
                                .withValues(alpha: .12),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                paused
                                    ? Icons.pause_circle_outline
                                    : Icons.timer_outlined,
                                size: 16,
                              ),
                              const SizedBox(width: 6),
                              Text('$mm:$ss'),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ActivityControls(activityId: a.id, compact: false),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // ====== Historique ======
          _HistoryCard(activityId: a.id),

          const SizedBox(height: 16),

          // ====== Stats ======
          ActivityStatsPanel(activityId: a.id),

          const SizedBox(height: 16),

          // ====== Mini Heatmap (28 jours) — tap = overlay, double-tap = page détaillée
          HeatmapPreviewCard(activityId: a.id, title: a.name),
        ],
      ),
    );
  }
}

/// --------------------
/// HISTORIQUE
/// --------------------
class _HistoryCard extends ConsumerWidget {
  final String activityId;
  const _HistoryCard({required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);

    final isRunning = db.isRunning(activityId);
    final start = isRunning ? db.currentSessionStart(activityId) : null;

    final List<Session> sessions =
    (db.listSessionsByActivity(activityId) ?? const <Session>[])
        .where((s) => s.endAt != null)
        .toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt));

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Historique', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (isRunning && start != null) ...[
              Row(
                children: [
                  const Icon(Icons.play_arrow, size: 18),
                  const SizedBox(width: 8),
                  Text(
                    "En cours  •  ${_fmtDateTime(start)}  •  en cours",
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
              const Divider(height: 24),
            ],
            if (sessions.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  "Aucune session terminée.",
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              )
            else
              ...sessions.take(10).map((s) {
                final dur = s.duration.inMinutes;
                final startStr = _fmtDateTime(s.startAt);
                final endStr = _fmtDateTime(s.endAt!);
                return Column(
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            "Du $startStr au $endStr",
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.only(left: 26, top: 2, bottom: 8),
                      child: Text("Durée: ${dur}m"),
                    ),
                    const Divider(height: 8),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }

  static String _fmtDateTime(DateTime dt) {
    final dd = dt.day.toString().padLeft(2, '0');
    final mm = dt.month.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mi = dt.minute.toString().padLeft(2, '0');
    return "$dd/$mm $hh:$mi";
  }
}

/// --------------------
/// MINI HEATMAP (28 jours)
/// --------------------
class HeatmapPreviewCard extends ConsumerWidget {
  final String activityId;
  final String title;
  const HeatmapPreviewCard({
    super.key,
    required this.activityId,
    required this.title,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final sessions = db.listSessionsByActivity(activityId) ?? <Session>[];

    void _openLegend() {
      showDialog(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Légende'),
          content: const Text(
            "Tap sur un carré : détail du jour\n"
                "Double-tap : heatmap détaillée\n\n"
                "Intensité = minutes enregistrées ce jour.\n"
                "Plus c’est foncé, plus il y a de temps.",
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK')),
          ],
        ),
      );
    }

    void _openFull() {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) =>
              ActivityHeatmapPage(activityId: activityId, title: title),
        ),
      );
    }

    void _openDayDetails(DateTime day, int minutes, List<Session> daySessions) {
      showModalBottomSheet(
        context: context,
        isScrollControlled: false,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        builder: (_) {
          final ds = "${day.day.toString().padLeft(2, '0')}/"
              "${day.month.toString().padLeft(2, '0')}/"
              "${(day.year % 100).toString().padLeft(2, '0')}";
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Détails du $ds",
                    style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 8),
                Text("Total: ${minutes} min"),
                const SizedBox(height: 12),
                if (daySessions.isEmpty)
                  const Text("Aucune session ce jour.")
                else
                  ...daySessions.map((s) {
                    final from =
                        "${s.startAt.hour.toString().padLeft(2, '0')}:${s.startAt.minute.toString().padLeft(2, '0')}";
                    final to = (s.endAt ?? DateTime.now());
                    final toStr =
                        "${to.hour.toString().padLeft(2, '0')}:${to.minute.toString().padLeft(2, '0')}";
                    final mins = s.duration.inMinutes;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.schedule, size: 16),
                          const SizedBox(width: 8),
                          Expanded(child: Text("$from → $toStr")),
                          Text("${mins}m"),
                        ],
                      ),
                    );
                  }),
                const SizedBox(height: 12),
              ],
            ),
          );
        },
      );
    }

    return Card(
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Titre (appui long = légende)
            GestureDetector(
              onLongPress: _openLegend,
              child: Row(
                children: [
                  const Icon(Icons.local_fire_department_outlined, size: 20),
                  const SizedBox(width: 8),
                  Text('Heatmap (28 jours)',
                      style: Theme.of(context).textTheme.titleMedium),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Grille : tap carré -> overlay | double-tap carré -> page détaillée
            _MiniHeatmapGrid(
              sessions: sessions,
              onDayTap: _openDayDetails,
              onDoubleTapGrid: _openFull,
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniHeatmapGrid extends StatelessWidget {
  final List<Session> sessions;
  final void Function(DateTime day, int minutes, List<Session> daySessions)
  onDayTap;
  final VoidCallback onDoubleTapGrid;

  const _MiniHeatmapGrid({
    required this.sessions,
    required this.onDayTap,
    required this.onDoubleTapGrid,
  });

  @override
  Widget build(BuildContext context) {
    // Fenêtre: 28 jours jusqu’à aujourd’hui inclus
    final now = DateTime.now();
    final today0 = DateTime(now.year, now.month, now.day);
    final days = List<DateTime>.generate(
      28,
          (i) => today0.subtract(Duration(days: 27 - i)),
    );

    // Minutes + sessions par jour
    int minutesForDay(DateTime day) {
      final start = day;
      final end = day.add(const Duration(days: 1));
      int secs = 0;
      for (final s in sessions) {
        final sStart = s.startAt;
        final sEnd = s.endAt ?? now;
        final overlapStart = sStart.isAfter(start) ? sStart : start;
        final overlapEnd = sEnd.isBefore(end) ? sEnd : end;
        final d = overlapEnd.difference(overlapStart).inSeconds;
        if (d > 0) secs += d;
      }
      return (secs / 60).round();
    }

    List<Session> daySessions(DateTime day) {
      final start = day;
      final end = day.add(const Duration(days: 1));
      bool overlaps(Session s) {
        final sStart = s.startAt;
        final sEnd = s.endAt ?? now;
        return !(sEnd.isBefore(start) || sStart.isAfter(end));
      }
      return sessions.where(overlaps).toList();
    }

    final values = days.map(minutesForDay).toList();
    final maxVal = (values.isEmpty ? 0 : values.reduce((a, b) => a > b ? a : b));

    return LayoutBuilder(
      builder: (context, constraints) {
        // 7 colonnes x 4 lignes
        const cols = 7;
        const spacing = 4.0;
        final cell =
        ((constraints.maxWidth - spacing * (cols - 1)) / cols).clamp(10.0, 18.0);

        final base = Theme.of(context).colorScheme.primary;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: List.generate(values.length, (i) {
            final v = values[i];
            final day = days[i];
            final dayList = daySessions(day);

            // Intensité 0..1
            final t = maxVal == 0 ? 0.0 : (v / maxVal).clamp(0.0, 1.0);
            final alpha = 0.12 + 0.63 * t;
            final color = base.withValues(alpha: alpha);
            final tooltip = "${_ddMMyy(day)} • ${v} min";

            return Tooltip(
              message: tooltip,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => onDayTap(day, v, dayList),
                onDoubleTap: onDoubleTapGrid,
                child: Container(
                  width: cell,
                  height: cell,
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(3),
                    border: Border.all(
                      color: Theme.of(context).dividerColor.withValues(alpha: .4),
                      width: 0.5,
                    ),
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }

  String _ddMMyy(DateTime d) {
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    final yy = (d.year % 100).toString().padLeft(2, '0');
    return "$dd/$mm/$yy";
  }
}
