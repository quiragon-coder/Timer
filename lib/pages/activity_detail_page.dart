import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/activity.dart';
import '../models/session.dart';
import '../providers.dart';
import '../widgets/activity_controls.dart';

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
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ensureTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _ensureTicker() {
    _ticker?.cancel();
    final db = ref.read(dbProvider);
    if (db.isRunning(widget.activity.id)) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {}); // rafraîchit l’elapsed affiché
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final sessions = db.listSessionsByActivity(widget.activity.id);
    final running = db.isRunning(widget.activity.id);
    final paused = db.isPaused(widget.activity.id);
    final elapsed = db.runningElapsed(widget.activity.id);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.activity.emoji} ${widget.activity.name}'),
        actions: [
          if (running)
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 12, bottom: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: paused ? Colors.orange.withOpacity(.15) : Colors.green.withOpacity(.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(paused ? '⏸ $mm:$ss' : '⏱ $mm:$ss'),
                ),
              ),
            ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            Row(
              children: [
                Container(width: 16, height: 16, decoration: BoxDecoration(color: widget.activity.color, shape: BoxShape.circle)),
                const SizedBox(width: 8),
                Text('Objectif jour: ${widget.activity.dailyGoalMinutes ?? 0} min'),
                const Spacer(),
                ActivityControls(activityId: widget.activity.id),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
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
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        end == null ? Icons.play_circle_fill : Icons.check_circle,
        color: end == null ? Colors.orange : Colors.green,
      ),
      title: Text(end == null ? 'En cours' : 'Fini ($hh:$mm:$ss)'),
      subtitle: Text('${df.format(s.startAt)} → ${end == null ? 'en cours' : df.format(end)}'),
    );
  }
}
