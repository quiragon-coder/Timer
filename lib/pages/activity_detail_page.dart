import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../providers.dart';              // dbProvider
import '../providers_stats.dart';       // minutesTodayProvider, minutesThisWeekProvider, hourlyTodayProvider, lastNDaysProvider
import '../widgets/activity_controls.dart';
import '../widgets/activity_stats_panel.dart';
import '../widgets/mini_heatmap.dart';
import '../widgets/heatmap.dart';

class ActivityDetailPage extends ConsumerStatefulWidget {
  final Activity activity;
  const ActivityDetailPage({super.key, required this.activity});

  @override
  ConsumerState<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends ConsumerState<ActivityDetailPage> {
  Timer? _ticker;
  ProviderSubscription? _cancelDbListen;

  @override
  void initState() {
    super.initState();
    // Badge mm:ss en temps réel quand ça tourne
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      final db = ref.read(dbProvider);
      if (db.isRunning(widget.activity.id) && mounted) setState(() {});
    });

    // Invalidation des providers de stats quand le DB bouge
    _cancelDbListen = ref.listenManual(
      dbProvider,
          (prev, next) {
        final id = widget.activity.id;
        ref.invalidate(minutesTodayProvider(id));
        ref.invalidate(minutesThisWeekProvider(id));
        ref.invalidate(minutesThisMonthProvider(id));
        ref.invalidate(minutesThisYearProvider(id));
        ref.invalidate(hourlyTodayProvider(id));
        ref.invalidate(lastNDaysProvider(LastNDaysArgs(activityId: id, n: 7)));
        if (mounted) setState(() {});
      },
      fireImmediately: false,
    );
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _cancelDbListen?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final a  = widget.activity;
    final db = ref.watch(dbProvider);

    final running = db.isRunning(a.id);
    final paused  = db.isPaused(a.id);
    final elapsed = db.runningElapsed(a.id);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    final todayAsync = ref.watch(minutesTodayProvider(a.id));

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(a.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (running)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: (paused ? Colors.orange : Colors.green).withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: paused ? Colors.orange : Colors.green),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(paused ? Icons.pause : Icons.timer_outlined, size: 14),
                  const SizedBox(width: 6),
                  Text("$mm:$ss"),
                ]),
              ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(12),
        children: [
          // Objectif du jour
          todayAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
            data: (today) {
              final goal = a.dailyGoalMinutes ?? 0;
              if (goal <= 0) return const SizedBox.shrink();
              if (today >= goal) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(children: const [
                    Icon(Icons.check_circle, size: 18, color: Colors.green),
                    SizedBox(width: 8),
                    Text("Objectif du jour atteint"),
                  ]),
                );
              }
              final remain = goal - today;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text("Reste $remain min aujourd'hui"),
              );
            },
          ),

          // Contrôles
          Card(child: ActivityControls(activityId: a.id)),
          const SizedBox(height: 12),

          // Historique entre contrôles et graphs
          _buildHistory(context, db, a.id),
          const SizedBox(height: 12),

          // Stats + mini heatmap
          Card(
            clipBehavior: Clip.antiAlias,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Text(
                        "7 derniers jours",
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const Spacer(),
                      MiniHeatmap(
                        activityId: a.id,
                        days: 28,
                        baseColor: a.color,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        tooltip: "Heatmap détaillée",
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => HeatmapPage(activity: a)),
                          );
                        },
                        icon: const Icon(Icons.grid_view),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  ActivityStatsPanel(activityId: a.id),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// =======================
  /// Historique des sessions
  /// =======================
  Widget _buildHistory(BuildContext context, dynamic db, String activityId) {
    // On ne suppose plus le type exact (Session vs DbSession)
    final raw = (db.listSessionsByActivity(activityId) as List);
    final sessions = raw.map((e) => _Sess.from(e)).toList();

    if (sessions.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            "Aucune session pour l’instant.",
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    sessions.sort((a, b) => (b.startAt ?? DateTime(1970))
        .compareTo(a.startAt ?? DateTime(1970)));

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text("Historique", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            ...sessions.map((s) {
              final start = s.startAt;
              final end   = s.endAt;

              final title = start != null
                  ? "${start.year}-${start.month.toString().padLeft(2,'0')}-${start.day.toString().padLeft(2,'0')}  "
                  "${start.hour.toString().padLeft(2,'0')}:${start.minute.toString().padLeft(2,'0')}"
                  : "(début inconnu)";

              final pauses = db.listPausesBySession(activityId, s.id) as List;
              final totalPaused = pauses.fold<Duration>(
                Duration.zero,
                    (acc, p) {
                  try {
                    final ps = p.startAt as DateTime?;
                    final pe = (p.endAt as DateTime?) ?? DateTime.now();
                    if (ps == null) return acc;
                    return acc + pe.difference(ps);
                  } catch (_) {
                    return acc;
                  }
                },
              );

              Duration effective;
              if (start == null) {
                effective = Duration.zero;
              } else {
                final stop = end ?? DateTime.now();
                final full = stop.difference(start);
                effective = full - totalPaused;
                if (effective.isNegative) effective = Duration.zero;
              }

              final mins = effective.inMinutes;
              return ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: pauses.isEmpty
                    ? const Text("Aucune pause")
                    : Text("${pauses.length} pause(s) • ${_fmtDuration(totalPaused)}"),
                trailing: Text("$mins min", style: const TextStyle(fontWeight: FontWeight.w600)),
              );
            }),
          ],
        ),
      ),
    );
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return "${h}h${m.toString().padLeft(2, '0')}";
    return "${m}m";
  }
}

/// Petit adaptateur local pour uniformiser Session/DbSession
class _Sess {
  final String id;
  final DateTime? startAt;
  final DateTime? endAt;

  _Sess({required this.id, this.startAt, this.endAt});

  factory _Sess.from(dynamic s) {
    try {
      // Classes avec champs .id, .startAt, .endAt
      return _Sess(
        id: s.id as String,
        startAt: s.startAt as DateTime?,
        endAt: s.endAt as DateTime?,
      );
    } catch (_) {
      if (s is Map) {
        return _Sess(
          id: (s['id'] ?? '').toString(),
          startAt: s['startAt'] as DateTime?,
          endAt: s['endAt'] as DateTime?,
        );
      }
      // Fallback très permissif
      return _Sess(id: (s?.id ?? '').toString(), startAt: null, endAt: null);
    }
  }
}

/// Heatmap détaillée
class HeatmapPage extends ConsumerWidget {
  final Activity activity;
  const HeatmapPage({super.key, required this.activity});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final base  = activity.color;
    final stats = ref.watch(
      lastNDaysProvider(LastNDaysArgs(activityId: activity.id, n: 90)),
    );

    return Scaffold(
      appBar: AppBar(title: Text("${activity.emoji} ${activity.name} — Heatmap")),
      body: stats.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Erreur: $e")),
        data: (days) {
          final map = <DateTime, int>{for (final d in days) d.date: d.minutes};
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                clipBehavior: Clip.antiAlias,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Heatmap(
                    data: map,
                    baseColor: base,
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
