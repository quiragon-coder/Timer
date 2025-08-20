// lib/pages/activity_detail_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../models/session.dart';
import '../models/pause.dart';
import '../services/database_service.dart';
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
  Timer? _ticker;

  // Démarre/arrête le ticker du badge
  void _syncTicker(bool running) {
    final active = _ticker?.isActive ?? false;
    if (running && !active) {
      _ticker = Timer.periodic(
        const Duration(seconds: 1),
            (_) {
          if (mounted) setState(() {});
        },
      );
    } else if (!running && active) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  // Invalide les providers de stats pour forcer l'UI à se rafraîchir
  void _refreshStats() {
    final id = widget.activity.id;
    // chips
    ref.invalidate(statsTodayProvider(id));
    ref.invalidate(weekTotalProvider(id));
    ref.invalidate(monthTotalProvider(id));
    ref.invalidate(yearTotalProvider(id));
    // graphes
    ref.invalidate(hourlyTodayProvider(id));
    ref.invalidate(statsLast7DaysProvider(id));
    // liste / badges éventuels
    ref.invalidate(activitiesProvider);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final a = widget.activity;
    final id = a.id;

    final running = db.isRunning(id);
    final paused  = db.isPaused(id);
    _syncTicker(running);

    final elapsed = db.runningElapsed(id);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(a.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(a.name, overflow: TextOverflow.ellipsis),
            ),
          ],
        ),
        actions: [
          if (running)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color:
                  (paused ? Colors.orange : Colors.green).withOpacity(.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(
                      paused ? Icons.pause : Icons.timer_outlined,
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text("$mm:$ss"),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // En-tête
          Row(
            children: [
              Text(a.emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 10),
              Text("Objectif: ${a.dailyGoalMinutes ?? 0} min/j"),
            ],
          ),
          const SizedBox(height: 12),

          // Commandes
          Row(
            children: [
              FilledButton.icon(
                onPressed: running
                    ? null
                    : () async {
                  await db.quickStart(id);
                  if (mounted) setState(() {});
                  _refreshStats();
                },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Démarrer'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: running
                    ? () async {
                  await db.quickTogglePause(id);
                  if (mounted) setState(() {});
                  _refreshStats();
                }
                    : null,
                icon: Icon(paused ? Icons.play_arrow : Icons.pause),
                label: Text(paused ? 'Reprendre' : 'Mettre en pause'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: running
                    ? () async {
                  await db.quickStop(id);
                  if (mounted) setState(() {});
                  _refreshStats();
                }
                    : null,
                icon: const Icon(Icons.stop),
                label: const Text('Arrêter'),
              ),
            ],
          ),

          const SizedBox(height: 24),
          Text('Historique', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          _buildHistory(context, db, id),

          const SizedBox(height: 24),
          // Panneau Stats (chips + graphes)
          ActivityStatsPanel(activityId: id),
        ],
      ),
    );
  }

  // ---------- Historique ----------

  Widget _buildHistory(
      BuildContext context, DatabaseService db, String activityId) {
    // Récupère toutes les sessions de cette activité
    final List<Session> sessions = db.sessions
        .where((s) => s.activityId == activityId)
        .toList()
      ..sort((a, b) => b.startAt.compareTo(a.startAt)); // récentes d'abord

    // Cherche une session en cours (endAt == null)
    Session? current;
    for (final s in sessions) {
      if (s.endAt == null) {
        current = s;
        break;
      }
    }

    if (sessions.isEmpty && current == null) {
      return Text("Aucune session",
          style: Theme.of(context).textTheme.bodyMedium);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (current != null)
          ListTile(
            leading: const Icon(Icons.play_arrow),
            title: const Text('En cours'),
            subtitle:
            Text("${_fmt(current.startAt)} • en cours"),
          ),
        for (final s in sessions.where((e) => e.endAt != null))
          _SessionTile(session: s, pauses: db.pauses),
      ],
    );
  }

  String _fmt(DateTime dt) {
    // petit format maison pour éviter les soucis d'intl sur le web
    final d2 =
        "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
    final h2 =
        "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
    return "$d2 $h2";
  }
}

class _SessionTile extends StatelessWidget {
  final Session session;
  final List<Pause> pauses;

  const _SessionTile({required this.session, required this.pauses});

  Duration _effectiveDuration() {
    final end = session.endAt ?? DateTime.now();
    var dur = end.difference(session.startAt);

    final pz = pauses.where((p) => p.sessionId == session.id);
    for (final p in pz) {
      final pend = p.endAt ?? DateTime.now();
      dur -= pend.difference(p.startAt);
    }
    return dur;
  }

  @override
  Widget build(BuildContext context) {
    final d = _effectiveDuration();
    final mins = d.inMinutes;
    final secs = d.inSeconds.remainder(60).toString().padLeft(2, '0');

    String fmt(DateTime dt) {
      final d2 =
          "${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}";
      final h2 =
          "${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}";
      return "$d2 $h2";
    }

    return ListTile(
      leading: const Icon(Icons.check_circle),
      title: Text("Du ${fmt(session.startAt)} au ${fmt(session.endAt!)}"),
      subtitle: Text("Durée: ${mins}m ${secs}s"),
    );
  }
}
