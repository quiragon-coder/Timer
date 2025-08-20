import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/activity.dart';
import '../models/session.dart';
import '../models/pause.dart';

import '../providers.dart';
import '../providers_stats.dart';
import '../services/database_service.dart';

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
    final id = a.id;

    // Invalide les providers de stats à chaque changement DB
    ref.listen<DatabaseService>(dbProvider, (prev, next) {
      ref.invalidate(statsTodayProvider(id));
      ref.invalidate(hourlyTodayProvider(id));
      ref.invalidate(weekTotalProvider(id));
      ref.invalidate(monthTotalProvider(id));
      ref.invalidate(yearTotalProvider(id));
      if (mounted) setState(() {});
    });

    final running = db.isRunning(id);
    final paused = db.isPaused(id);
    _syncTicker(running);

    final elapsed = db.runningElapsed(id);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(a.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(child: Text(a.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          if (running)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: paused
                      ? Colors.orange.withOpacity(.15)
                      : Colors.green.withOpacity(.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
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
        padding: const EdgeInsets.all(16),
        children: [
          // En-tête + boutons
          Row(
            children: [
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: a.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('Objectif: ${a.dailyGoalMinutes ?? 0} min/j'),
            ],
          ),
          const SizedBox(height: 12),
          ActivityControls(activityId: id),

          // =====================  HISTORIQUE  =====================
          const SizedBox(height: 20),
          Text('Historique', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          _buildHistory(context, db, id),

          // ========================  STATS  =======================
          const SizedBox(height: 24),
          Text('Stats', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ActivityStatsPanel(activityId: id),
        ],
      ),
    );
  }

  // ---- Historique (sessions finies + session en cours) ----
  Widget _buildHistory(
      BuildContext context, DatabaseService db, String activityId) {
    final df = DateFormat('dd/MM HH:mm');
    final List<Session> sessions = db.sessionsByActivity(activityId);

    final running = db.isRunning(activityId);
    final List<Widget> tiles = [];

    // En cours
    if (running) {
      final start = db.currentSessionStart(activityId);
      tiles.add(
        ListTile(
          dense: true,
          leading: const Icon(Icons.play_arrow),
          title: const Text('En cours'),
          subtitle: Text(
              '${df.format(start)} • en cours'), // pas de durée pour en cours
        ),
      );
    }

    if (sessions.isEmpty && tiles.isEmpty) {
      return Text(
        "Aucun historique",
        style: Theme.of(context).textTheme.bodyMedium,
      );
    }

    // Sessions terminées
    for (final s in sessions) {
      final String range = '${df.format(s.startAt)} au ${df.format(s.endAt!)}';
      final Duration d = s.endAt!.difference(s.startAt);
      final int secs = d.inSeconds;
      final String dur =
      secs < 60 ? '${secs}s' : '${d.inMinutes}m ${secs.remainder(60)}s';
      tiles.add(
        Column(
          children: [
            ListTile(
              dense: true,
              leading: const Icon(Icons.check_circle_outline),
              title: Text(range),
              subtitle: Text('Durée: $dur'),
            ),
            const Divider(height: 1),
          ],
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: Column(children: tiles),
    );
  }
}
