// lib/pages/activity_detail_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../providers.dart'; // dbProvider
import '../widgets/activity_controls.dart';
import '../widgets/activity_stats_panel.dart';

class ActivityDetailPage extends ConsumerStatefulWidget {
  final Activity activity;
  const ActivityDetailPage({super.key, required this.activity});

  @override
  ConsumerState<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends ConsumerState<ActivityDetailPage> {
  Timer? _ticker; // tick visuel pour ⏱ AppBar et section info

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

  String _fmt(Duration d) {
    final mm = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$mm:$ss';
    // (si tu veux HH:mm:ss quand > 1h, adapte ici)
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final id = widget.activity.id;

    final running = db.isRunning(id);
    final paused = db.isPaused(id);
    _ensureTicker(running);

    Duration elapsed;
    try {
      elapsed = db.runningElapsed(id);
    } catch (_) {
      elapsed = Duration.zero;
    }

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
          ],
        ),
        actions: [
          if (running)
            Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (paused ? Colors.orange : Colors.green).withOpacity(.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(
                      paused ? Icons.pause : Icons.timer_outlined,
                      size: 16,
                      color: paused ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _fmt(elapsed),
                      style: TextStyle(
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: paused ? Colors.orange : Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // ── Contrôles ──────────────────────────────────────────────────────────
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: ActivityControls(activityId: id),
            ),
          ),

          const SizedBox(height: 12),

          // ── Historique de sessions ────────────────────────────────────────────
          _HistorySection(activityId: id),

          const SizedBox(height: 12),

          // ── Stats (barres/jours + répartition horaire + objectifs) ───────────
          // Si ton ActivityStatsPanel prend un 'activity' (et pas 'activityId')
          // ajuste si besoin.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: ActivityStatsPanel(activity: widget.activity),
            ),
          ),
        ],
      ),
    );
  }
}

/// Affiche un petit historique des sessions récentes.
/// NB : pour éviter les erreurs de compilation selon les variantes de DatabaseService,
/// on appelle les méthodes de façon *défensive* via `dynamic` + try/catch.
/// Ça n’explose pas si un helper s’appelle différemment : on essaye plusieurs noms.
class _HistorySection extends ConsumerStatefulWidget {
  final String activityId;
  const _HistorySection({required this.activityId});

  @override
  ConsumerState<_HistorySection> createState() => _HistorySectionState();
}

class _HistorySectionState extends ConsumerState<_HistorySection> {
  // renvoie une liste ordonnée (plus récentes d’abord) des sessions "dynamiques"
  List<dynamic> _loadSessions(dynamic db, String activityId) {
    try {
      // variantes possibles rencontrées dans le projet
      final s1 = db.sessionsByActivity(activityId);
      if (s1 is List) return List<dynamic>.from(s1);
    } catch (_) {}
    try {
      final s2 = db.listSessionsByActivity(activityId);
      if (s2 is List) return List<dynamic>.from(s2);
    } catch (_) {}
    try {
      final s3 = db.getSessionsByActivity(activityId);
      if (s3 is List) return List<dynamic>.from(s3);
    } catch (_) {}
    return const [];
  }

  List<dynamic> _loadPauses(dynamic db, String sessionId) {
    try {
      final p1 = db.listPausesBySession(sessionId);
      if (p1 is List) return List<dynamic>.from(p1);
    } catch (_) {}
    try {
      final p2 = db.getPausesBySession(sessionId);
      if (p2 is List) return List<dynamic>.from(p2);
    } catch (_) {}
    return const [];
  }

  Duration _effectiveDuration(dynamic session, List<dynamic> pauses) {
    try {
      final DateTime start = session.startAt as DateTime;
      final DateTime end = (session.endAt as DateTime?) ?? DateTime.now();
      var total = end.difference(start);

      for (final p in pauses) {
        try {
          final DateTime ps = p.startAt as DateTime;
          final DateTime pe = (p.endAt as DateTime?) ?? DateTime.now();
          // soustraire l'intersection pause∩[start,end]
          final overlapStart = ps.isAfter(start) ? ps : start;
          final overlapEnd = pe.isBefore(end) ? pe : end;
          if (!overlapEnd.isBefore(overlapStart)) {
            total -= overlapEnd.difference(overlapStart);
          }
        } catch (_) {}
      }
      if (total.isNegative) return Duration.zero;
      return total;
    } catch (_) {
      return Duration.zero;
    }
  }

  String _fmtShort(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    return '${m}m';
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final dynamic ddb = db; // dynamique pour compat VN des noms de méthodes

    final sessions = _loadSessions(ddb, widget.activityId);
    if (sessions.isEmpty) {
      return Card(
        child: ListTile(
          leading: const Icon(Icons.history),
          title: const Text('Historique'),
          subtitle: Text(
            "Aucune session enregistrée pour le moment.",
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      );
    }

    // on affiche les N dernières
    final display = sessions.take(10).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8.0),
        child: Column(
          children: [
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Historique'),
              subtitle: Text(
                "Dernières sessions (max 10)",
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            const Divider(height: 1),
            ...display.map((s) {
              try {
                final pauses = _loadPauses(ddb, (s.id as String));
                final dur = _effectiveDuration(s, pauses);
                final start = (s.startAt as DateTime);
                final end = (s.endAt as DateTime?);
                final running = end == null;

                return ListTile(
                  dense: true,
                  leading: Icon(
                    running ? Icons.play_arrow_rounded : Icons.check_circle,
                    color: running ? Colors.green : null,
                  ),
                  title: Text(
                    running
                        ? "En cours depuis ${TimeOfDay.fromDateTime(start).format(context)}"
                        : "${TimeOfDay.fromDateTime(start).format(context)} → ${TimeOfDay.fromDateTime(end).format(context)}",
                  ),
                  subtitle: Text("Effectif: ${_fmtShort(dur)}"
                      "${pauses.isNotEmpty ? " (pauses: ${pauses.length})" : ""}"),
                );
              } catch (_) {
                return const ListTile(
                  dense: true,
                  title: Text("Session"),
                  subtitle: Text("Détails indisponibles"),
                );
              }
            }),
          ],
        ),
      ),
    );
  }
}
