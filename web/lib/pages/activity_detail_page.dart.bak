import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/activity.dart';
import '../models/session.dart';
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
  final _df = DateFormat('dd MMM HH:mm');
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
    final sessions = db.listSessionsByActivity(widget.activity.id);

    final running = db.isRunning(widget.activity.id);
    final paused = db.isPaused(widget.activity.id);
    _syncTicker(running);

    final elapsed = db.runningElapsed(widget.activity.id);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.activity.emoji} ${widget.activity.name}',
            overflow: TextOverflow.ellipsis),
        actions: [
          if (running)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (paused ? Colors.orange : Colors.green).withOpacity(.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(paused ? Icons.pause : Icons.timer_outlined, size: 16),
                      const SizedBox(width: 4),
                      Text('$mm:$ss'),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Header + boutons
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(widget.activity.emoji, style: const TextStyle(fontSize: 28)),
                        Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(color: widget.activity.color, shape: BoxShape.circle),
                        ),
                        Text(
                          'Objectif: ${widget.activity.dailyGoalMinutes ?? 0} min/j',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OverflowBar(
                      alignment: MainAxisAlignment.start,
                      spacing: 8,
                      overflowSpacing: 8,
                      children: [
                        ActivityControls(activityId: widget.activity.id, compact: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            Text('Historique', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Aucune session pour le moment.'),
              )
            else
              Column(
                children: [
                  for (final s in sessions) _SessionTile(df: _df, s: s),
                ],
              ),

            // Panneau Stats
            ActivityStatsPanel(
              activityId: widget.activity.id,
              dailyGoal: widget.activity.dailyGoalMinutes,
            ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final DateFormat df;
  final Session s;
  const _SessionTile({required this.df, required this.s});

  @override
  Widget build(BuildContext context) {
    final end = s.endAt;
    final dur = s.duration;
    final hh = dur.inHours.toString().padLeft(2, '0');
    final mm = dur.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = dur.inSeconds.remainder(60).toString().padLeft(2, '0');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(
        end == null ? Icons.play_circle_fill : Icons.check_circle,
        color: end == null ? Colors.orange : Colors.green,
      ),
      title: Text(
        end == null ? 'En cours' : 'Fini ($hh:$mm:$ss)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        // Flèche ASCII pour éviter l’UTF-8 exotique
        '${df.format(s.startAt)} -> ${end == null ? 'en cours' : df.format(end)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
