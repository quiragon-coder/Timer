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
          children: [
            Text(a.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                a.name,
                overflow: TextOverflow.ellipsis,
              ),
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
                  color: (paused
                      ? Colors.orange
                      : Theme.of(context).colorScheme.primary)
                      .withOpacity(.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                      color: paused
                          ? Colors.orange
                          : Theme.of(context).colorScheme.primary),
                ),
                child: Row(
                  children: [
                    Icon(
                      paused ? Icons.pause : Icons.timer_outlined,
                      size: 16,
                      color: paused
                          ? Colors.orange
                          : Theme.of(context).colorScheme.primary,
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
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          // En-tête activité
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(a.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Container(
                width: 10,
                height: 10,
                decoration:
                BoxDecoration(color: a.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Objectif: ${a.dailyGoalMinutes ?? 0} min/j",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Boutons start/pause/stop
          OverflowBar(
            alignment: MainAxisAlignment.start,
            spacing: 8,
            overflowSpacing: 8,
            children: [
              ActivityControls(activityId: a.id),
            ],
          ),

          const SizedBox(height: 24),

          // Historique
          Text("Historique",
              style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          _buildHistory(context, db, a.id),

          const SizedBox(height: 24),

          // Stats
          Text("Stats", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          ActivityStatsPanel(activityId: a.id),
        ],
      ),
    );
  }

  Widget _buildHistory(
      BuildContext context, DatabaseService db, String activityId) {
    // Copie MUTABLE pour éviter l'erreur "Cannot modify an unmodifiable list"
    final List<Session> sessions =
    List<Session>.from(db.listSessionsByActivity(activityId));

    // Tri du plus récent au plus ancien
    sessions.sort((a, b) {
      final da = a.endAt ?? DateTime.now();
      final dbb = b.endAt ?? DateTime.now();
      return dbb.compareTo(da);
    });

    if (sessions.isEmpty) {
      return ListTile(
        leading: const Icon(Icons.play_circle_outline),
        title: const Text("Aucune session"),
        subtitle: Text(
          "Commence une session avec le bouton Démarrer.",
          style: Theme.of(context).textTheme.bodySmall,
        ),
      );
    }

    final fmt = DateFormat("dd/MM HH:mm");

    return Column(
      children: [
        for (final s in sessions) ...[
          ListTile(
            leading: Icon(
              s.endAt == null ? Icons.play_arrow : Icons.check_circle,
              color: s.endAt == null ? Colors.amber : Colors.green,
            ),
            title: s.endAt == null
                ? const Text("En cours")
                : Text("Du ${fmt.format(s.startAt)} au ${fmt.format(s.endAt!)}"),
            subtitle: Text(
              s.endAt == null
                  ? "${fmt.format(s.startAt)} • en cours"
                  : "Durée: ${_formatDuration(s.endAt!.difference(s.startAt))}",
            ),
          ),
          const Divider(height: 1),
        ]
      ],
    );
  }

  String _formatDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return "${h}h ${m}m ${s}s";
    } else if (m > 0) {
      return "${m}m ${s}s";
    }
    return "${s}s";
    // (pour un affichage 00:00:SS tu pourrais faire:
    // final mm = d.inMinutes.remainder(60).toString().padLeft(2,'0');
    // final ss = d.inSeconds.remainder(60).toString().padLeft(2,'0');
    // return "$mm:$ss";
  }
}
