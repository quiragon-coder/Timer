// lib/pages/activity_detail_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/activity.dart';
import '../models/session.dart';
import '../services/database_service.dart'; // <-- IMPORT AJOUTÉ
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
  late Activity _current;
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _current = widget.activity;
  }

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

  void _refreshStats() {
    final id = widget.activity.id;
    ref.invalidate(statsTodayProvider(id));
    ref.invalidate(weekTotalProvider(id));
    ref.invalidate(monthTotalProvider(id));
    ref.invalidate(yearTotalProvider(id));
    ref.invalidate(hourlyTodayProvider(id));
    ref.invalidate(statsLast7DaysProvider(id));
    ref.invalidate(activitiesProvider);
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);

    final all = ref.watch(activitiesProvider).maybeWhen(
      data: (list) => list,
      orElse: () => <Activity>[],
    );
    final updated = all.firstWhere(
          (a) => a.id == _current.id,
      orElse: () => _current,
    );
    _current = updated;

    final running = db.isRunning(_current.id);
    final paused  = db.isPaused(_current.id);
    _syncTicker(running);

    final elapsed = db.runningElapsed(_current.id);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(_current.emoji, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(_current.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
            if (running)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (paused ? Colors.orange : Colors.green).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(paused ? Icons.pause_circle_filled : Icons.timer_outlined, size: 16),
                  const SizedBox(width: 6),
                  Text('$mm:$ss'),
                ]),
              ),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Text(_current.emoji, style: const TextStyle(fontSize: 28)),
              const SizedBox(width: 12),
              Container(width: 10, height: 10,
                decoration: BoxDecoration(color: _current.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Objectif: ${_current.dailyGoalMinutes ?? 0} min/j",
                  maxLines: 1, overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          OverflowBar(
            alignment: MainAxisAlignment.start,
            spacing: 8, overflowSpacing: 8,
            children: [ ActivityControls(activityId: _current.id, compact: false) ],
          ),
          const SizedBox(height: 24),

          Text("Historique", style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          _buildHistory(context, db, _current.id),
          const SizedBox(height: 24),

          ActivityStatsPanel(activityId: _current.id),
        ],
      ),
    );
  }

  Widget _buildHistory(BuildContext context, DatabaseService db, String activityId) {
    final List<Session> sessions = db.listSessionsByActivity(activityId);
    sessions.sort((a, b) {
      final da = a.endAt ?? DateTime.now();
      final dbb = b.endAt ?? DateTime.now();
      return dbb.compareTo(da);
    });

    if (sessions.isEmpty) {
      return ListTile(
        leading: const Icon(Icons.play_circle_outline),
        title: const Text("Aucune session"),
        subtitle: Text("Commence une session avec le bouton Démarrer.",
            style: Theme.of(context).textTheme.bodySmall),
      );
    }

    final fmt = DateFormat("dd/MM HH:mm");

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
    if (h > 0) return "${h}h ${m.toString().padLeft(2, '0')}m";
    return "${m}m ${s.toString().padLeft(2, '0')}s";
  }
}
