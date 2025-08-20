import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/activity.dart';
import '../models/session.dart';
import '../providers.dart'; // dbProvider
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

  void _ensureTicker(bool running) {
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
    final id = widget.activity.id;

    final running = db.isRunning(id);
    final paused = db.isPaused(id);
    _ensureTicker(running);

    final elapsed = db.runningElapsed(id);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.activity.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(widget.activity.name,
                  overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          // badge timer (non-null, rafraîchi par _ticker)
          if (running)
            Container(
              margin: const EdgeInsets.only(right: 12),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                (paused ? Colors.orange : Colors.green).withOpacity(0.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Row(children: [
                Icon(paused ? Icons.pause : Icons.timer_outlined, size: 16),
                const SizedBox(width: 6),
                Text('$mm:$ss'),
              ]),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        children: [
          // Ligne sous le titre : couleur + objectif + contrôles
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: widget.activity.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Objectif: ${widget.activity.dailyGoalMinutes ?? 0} min/j',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              OverflowBar(
                alignment: MainAxisAlignment.end,
                spacing: 8,
                overflowSpacing: 8,
                children: [
                  ActivityControls(activityId: id, compact: false),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Historique
          Text('Historique',
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          _buildHistory(context, db, id),
          const SizedBox(height: 16),

          // Stats (panneau + graphs)
          Text('Stats', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          ActivityStatsPanel(activityId: id),
        ],
      ),
    );
  }

  /// Liste l’historique (session en cours + sessions terminées)
  Widget _buildHistory(
      BuildContext context, DatabaseService db, String activityId) {
    final fmt = DateFormat('dd/MM HH:mm');

    final sessions = List<Session>.from(db.getSessionsByActivity(activityId))
      ..sort((a, b) {
        // Les plus récentes en premier
        final aEnd = a.endAt ?? DateTime.now();
        final bEnd = b.endAt ?? DateTime.now();
        return bEnd.compareTo(aEnd);
      });

    final running = db.isRunning(activityId);
    if (!running && sessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text('Aucune session pour le moment',
            style: Theme.of(context).textTheme.bodyMedium),
      );
    }

    final tiles = <Widget>[];

    // Session en cours (si présente)
    if (running) {
      final start = db.currentSessionStart(activityId) ?? DateTime.now();
      tiles.add(
        ListTile(
          leading: const Icon(Icons.play_arrow_rounded, color: Colors.indigo),
          title: const Text('En cours'),
          subtitle: Text('${fmt.format(start)} • en cours'),
        ),
      );
      tiles.add(const Divider(height: 1));
    }

    // Sessions terminées
    for (final s in sessions.where((s) => s.endAt != null)) {
      final DateTime end = s.endAt ?? DateTime.now(); // <-- non-null ici
      final dur = db.effectiveMinutes(s);
      tiles.add(
        ListTile(
          leading:
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          title: Text('Du ${fmt.format(s.startAt)} au ${fmt.format(end)}'),
          subtitle: Text('Durée: ${dur}m'),
        ),
      );
      tiles.add(const Divider(height: 1));
    }

    return Material(
      color: Colors.transparent,
      child: Column(children: tiles),
    );
  }
}
