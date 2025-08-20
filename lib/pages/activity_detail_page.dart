import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../providers.dart';
import '../services/database_service.dart';
import '../widgets/activity_controls.dart';
import '../widgets/activity_stats_panel.dart';

class ActivityDetailPage extends ConsumerWidget {
  const ActivityDetailPage({
    super.key,
    required this.activity,
  });

  final Activity activity;

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  String _fmtDT(DateTime d) {
    String two(int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
  }

  String _fmtDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Rebuild auto quand DatabaseService notifie
    final db = ref.watch(dbProvider);

    // Utilise la version la plus a jour de l'activite
    final current = db.activityById(activity.id) ?? activity;

    final running = db.isRunning(current.id);
    final paused = db.isPaused(current.id);
    final elapsed = db.runningElapsed(current.id);

    return Scaffold(
      appBar: AppBar(
        title: Text('${current.emoji} ${current.name}'),
        actions: [
          if (running)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceVariant,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  '${paused ? '⏸' : '⏱'} ${_formatElapsed(elapsed)}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              CircleAvatar(
                backgroundColor: current.color.withOpacity(0.15),
                child: Text(current.emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Objectif: ${current.dailyGoalMinutes ?? 0} min/j',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ActivityControls(activityId: current.id, compact: true),
            ],
          ),
          const SizedBox(height: 24),

          Text('Historique', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          _buildHistory(context, db, current.id),

          const SizedBox(height: 24),

          Text('Stats', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              // IMPORTANT: ActivityStatsPanel prend activityId:
              child: ActivityStatsPanel(activityId: current.id),
            ),
          ),
        ],
      ),
    );
  }

  // <-- ICI on a bien le type DatabaseService, avec l'import en haut
  Widget _buildHistory(
      BuildContext context, DatabaseService db, String activityId) {
    final sessions = db.listSessionsByActivity(activityId);
    if (sessions.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24),
        child: Text(
          "Aucune session pour l'instant.",
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final s in sessions)
          ListTile(
            leading: Icon(
              s.endAt == null ? Icons.play_arrow : Icons.check_circle,
              color: s.endAt == null
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.tertiary,
            ),
            title: Text(
              s.endAt == null
                  ? 'En cours'
                  : 'Du ${_fmtDT(s.startAt)} au ${_fmtDT(s.endAt!)}',
            ),
            subtitle: Text(
              s.endAt == null
                  ? '${_fmtDT(s.startAt)} • en cours'
                  : 'Durée: ${_fmtDur(s.endAt!.difference(s.startAt))}',
            ),
          ),
      ],
    );
  }
}
