import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../providers.dart';
import '../widgets/activity_controls.dart';
import '../widgets/activity_stats_panel.dart';

class ActivityDetailPage extends ConsumerStatefulWidget {
  const ActivityDetailPage({
    super.key,
    required this.activity,
  });

  final Activity activity;

  @override
  ConsumerState<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends ConsumerState<ActivityDetailPage> {
  late Activity _current; // toujours initialisé dans initState

  @override
  void initState() {
    super.initState();
    _current = widget.activity;

    // Écoute les mises à jour de la liste et garde l’activité à jour
    ref.onAddListener(activitiesProvider, _onActivitiesChanged);
  }

  void _onActivitiesChanged(AsyncValue<List<Activity>>? prev,
      AsyncValue<List<Activity>> next) {
    if (!mounted) return;
    next.whenData((list) {
      final found =
          list.where((a) => a.id == _current.id).cast<Activity?>().firstOrNull;
      if (found != null && mounted) {
        setState(() => _current = found);
      }
    });
  }

  @override
  void dispose() {
    ref.removeListener(activitiesProvider, _onActivitiesChanged);
    super.dispose();
  }

  String _formatElapsed(Duration d) {
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final running = db.isRunning(_current.id);
    final paused = db.isPaused(_current.id);
    final elapsed = db.runningElapsed(_current.id);

    return Scaffold(
      appBar: AppBar(
        title: Text('${_current.emoji} ${_current.name}'),
        actions: [
          // badge temps en cours
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
          // Ligne de contrôle
          Row(
            mainAxisAlignment: MainAxisAlignment.start,
            children: [
              CircleAvatar(
                backgroundColor: _current.color.withOpacity(0.15),
                child: Text(_current.emoji, style: const TextStyle(fontSize: 18)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Objectif: ${_current.dailyGoalMinutes ?? 0} min/j',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              ActivityControls(activityId: _current.id, compact: true),
            ],
          ),
          const SizedBox(height: 24),

          // Historique (simple)
          Text('Historique', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          _buildHistory(context),

          const SizedBox(height: 24),

          // Stats Panel
          Text('Stats', style: Theme.of(context).textTheme.headlineSmall),
          const SizedBox(height: 8),
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(12.0),
              child: ActivityStatsPanel(activity: _current),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(BuildContext context) {
    final asyncActivities = ref.watch(activitiesProvider);
    final db = ref.read(dbProvider);

    // On affiche la session en cours + les 5 dernières (si tu veux)
    final sessions = db.listSessionsByActivity(_current.id);
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

  String _fmtDT(DateTime d) {
    final two = (int v) => v.toString().padLeft(2, '0');
    return '${two(d.day)}/${two(d.month)} ${two(d.hour)}:${two(d.minute)}';
    // (si tu veux la locale FR complète, on activera intl + initializeDateFormatting)
  }

  String _fmtDur(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) return '${h}h ${m}m';
    if (m > 0) return '${m}m ${s}s';
    return '${s}s';
  }
}

extension<T> on Iterable<T> {
  T? get firstOrNull {
    final it = iterator;
    return it.moveNext() ? it.current : null;
  }
}
