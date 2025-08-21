import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../models/session.dart';
import '../models/pause.dart';
import '../providers.dart';
import '../widgets/activity_controls.dart';
import '../widgets/activity_stats_panel.dart';

class ActivityDetailPage extends ConsumerStatefulWidget {
  final Activity activity;
  const ActivityDetailPage({super.key, required this.activity});

  @override
  ConsumerState<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends ConsumerState<ActivityDetailPage> {
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    // Ticker global pour garder le badge et l’historique bien à jour
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final running = db.isRunning(widget.activity.id);
    final paused = db.isPaused(widget.activity.id);

    final elapsed = db.runningElapsed(widget.activity.id);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.activity.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.activity.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                color: widget.activity.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 12),
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
                  Text("$mm:$ss"),
                ]),
              ),
          ],
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Contrôles
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Contrôles",
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ActivityControls(activityId: widget.activity.id, compact: false),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Historique (entre contrôles et graphs)
            _buildHistory(context, db, widget.activity.id),

            const SizedBox(height: 12),

            // Graphs / stats (inclut la mini-heatmap)
            ActivityStatsPanel(activityId: widget.activity.id),
          ],
        ),
      ),
    );
  }

  // ---------- Historique ----------

  Widget _buildHistory(
      BuildContext context,
      dynamic db, // DatabaseService via provider
      String activityId,
      ) {
    final sessions = List<Session>.from(db.listSessionsByActivity(activityId));
    sessions.sort((a, b) => b.startAt.compareTo(a.startAt));

    if (sessions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.history, size: 18),
              const SizedBox(width: 8),
              Text(
                "Aucun historique pour le moment.",
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                "Historique",
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ),
            const SizedBox(height: 8),
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: sessions.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (_, i) {
                final s = sessions[i];
                final pauses = List<Pause>.from(db.listPausesBySession(s.id));
                final eff = _effectiveDuration(s, pauses);
                final effStr = _formatDuration(eff);

                final start = s.startAt;
                final end = s.endAt;
                final dateStr =
                    "${start.day.toString().padLeft(2, '0')}/${start.month.toString().padLeft(2, '0')} ${start.hour.toString().padLeft(2, '0')}:${start.minute.toString().padLeft(2, '0')}";
                final endStr = end == null
                    ? "en cours"
                    : "${end.hour.toString().padLeft(2, '0')}:${end.minute.toString().padLeft(2, '0')}";

                return ListTile(
                  dense: true,
                  leading: Icon(
                    end == null ? Icons.play_circle : Icons.check_circle,
                    color: end == null ? Colors.green : null,
                  ),
                  title: Text("$dateStr → $endStr"),
                  subtitle: pauses.isEmpty
                      ? Text("Durée effective : $effStr")
                      : Text(
                    "Durée effective : $effStr  •  ${pauses.length} pause${pauses.length > 1 ? 's' : ''}",
                  ),
                  trailing: Container(
                    padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withOpacity(.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(effStr),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Duration _effectiveDuration(Session s, List<Pause> pauses) {
    final now = DateTime.now();
    final start = s.startAt;
    final end = s.endAt ?? now;

    // durée brute
    int secs = end.difference(start).inSeconds;

    // soustraire chaque pause (intersection)
    for (final p in pauses) {
      final ps = p.startAt;
      final pe = p.endAt ?? now;
      final isec = _overlapSeconds(start, end, ps, pe);
      if (isec > 0) secs -= isec;
    }
    if (secs < 0) secs = 0;
    return Duration(seconds: secs);
  }

  int _overlapSeconds(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
    final s = aStart.isAfter(bStart) ? aStart : bStart;
    final e = aEnd.isBefore(bEnd) ? aEnd : bEnd;
    return e.isAfter(s) ? e.difference(s).inSeconds : 0;
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return "${h}h ${m.toString().padLeft(2, '0')}m";
    } else {
      return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
    }
  }
}
