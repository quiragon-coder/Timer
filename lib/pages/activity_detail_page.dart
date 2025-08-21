import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../models/session.dart';                 // <-- Session
import '../providers.dart';                      // dbProvider
import '../services/database_service.dart';      // <-- DatabaseService
import '../widgets/activity_controls.dart';
import '../widgets/activity_stats_panel.dart';
import '../widgets/mini_heatmap.dart';

class ActivityDetailPage extends ConsumerStatefulWidget {
  final Activity activity;

  const ActivityDetailPage({super.key, required this.activity});

  @override
  ConsumerState<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends ConsumerState<ActivityDetailPage> {
  String get _aId => widget.activity.id;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final db = ref.watch(dbProvider);

    final running = db.isRunning(_aId);
    final paused = db.isPaused(_aId);
    final elapsed = db.runningElapsed(_aId);
    final String badge = _fmtMmSs(elapsed);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(widget.activity.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                widget.activity.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          if (running)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Chip(
                label: Text(badge),
                avatar: Icon(
                  paused ? Icons.pause : Icons.timer_outlined,
                  size: 16,
                  color: paused ? Colors.orange : theme.colorScheme.primary,
                ),
                backgroundColor: (paused ? Colors.orange : theme.colorScheme.primary).withOpacity(.10),
                side: BorderSide(
                  color: (paused ? Colors.orange : theme.colorScheme.primary).withOpacity(.35),
                ),
              ),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
        children: [
          // 1) CONTRÔLES
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Contrôles', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                ActivityControls(activityId: _aId),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 2) HISTORIQUE
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Historique', style: theme.textTheme.titleMedium),
                const SizedBox(height: 10),
                _buildCurrentHistoryLine(context, db),
                const SizedBox(height: 6),
                const Divider(height: 22),
                ..._buildPastSessions(context, db),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 3) STATS (chips + graphes)
          ActivityStatsPanel(activityId: _aId),
          const SizedBox(height: 12),

          // 4) MINI HEATMAP SOUS LES STATS
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Mini heatmap', style: theme.textTheme.titleMedium),
                const SizedBox(height: 8),
                MiniHeatmap(
                  activityId: _aId,
                  days: 7, // <-- param correct
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Ligne "en cours" si une session tourne
  Widget _buildCurrentHistoryLine(BuildContext context, DatabaseService db) {
    final theme = Theme.of(context);
    final running = db.isRunning(_aId);
    if (!running) {
      return Row(
        children: [
          Icon(Icons.history, color: theme.colorScheme.outline),
          const SizedBox(width: 8),
          Text(
            'Aucune session en cours',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      );
    }

    final DateTime? start = db.currentSessionStart(_aId);
    final now = DateTime.now();
    final dur = now.difference(start ?? now);
    final durStr = _fmtHms(dur);

    return Row(
      children: [
        const Icon(Icons.play_arrow_rounded, color: Colors.green),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            '${_fmtDateTime(start)}  →  en cours',
            style: theme.textTheme.bodyMedium,
          ),
        ),
        Chip(
          label: Text(durStr),
          backgroundColor: Colors.green.withOpacity(.10),
          side: const BorderSide(color: Colors.green),
        ),
      ],
    );
  }

  // Sessions passées (10 dernières)
  List<Widget> _buildPastSessions(BuildContext context, DatabaseService db) {
    final theme = Theme.of(context);

    // On filtre toute valeur nulle au cas où l’API renverrait List<Session?>
    final List<Session> sessions =
    db.listSessionsByActivity(_aId).whereType<Session>().toList();

    // Tri: plus récentes d'abord (par endAt si disponible sinon startAt)
    sessions.sort((a, b) {
      final DateTime da = (a.endAt ?? a.startAt);
      final DateTime dbt = (b.endAt ?? b.startAt);
      return dbt.compareTo(da);
    });

    if (sessions.isEmpty) {
      return [
        Row(
          children: [
            Icon(Icons.info_outline, color: theme.colorScheme.outline),
            const SizedBox(width: 8),
            Text(
              'Aucune session terminée',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        )
      ];
    }

    return sessions.take(10).map((s) {
      final DateTime start = s.startAt;
      final DateTime end = s.endAt ?? s.startAt;
      final Duration dur = end.difference(start);
      final String textDur = _fmtHms(dur);

      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.check_circle, color: theme.colorScheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_fmtDateTime(start)}  au  ${_fmtDateTime(end)}',
                    style: theme.textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Durée: $textDur',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }).toList();
  }

  // Helpers format
  static String _two(int n) => n.toString().padLeft(2, '0');

  String _fmtMmSs(Duration d) =>
      '${_two(d.inMinutes.remainder(60))}:${_two(d.inSeconds.remainder(60))}';

  String _fmtHms(Duration d) {
    if (d.inHours >= 1) {
      final h = d.inHours;
      final m = d.inMinutes.remainder(60);
      final s = d.inSeconds.remainder(60);
      return '${h}h ${_two(m)}m ${_two(s)}s';
    }
    final m = d.inMinutes;
    final s = d.inSeconds.remainder(60);
    return '${m}m ${_two(s)}s';
  }

  String _fmtDateTime(DateTime? dt) {
    if (dt == null) return '—';
    final dd = _two(dt.day);
    final mm = _two(dt.month);
    final hh = _two(dt.hour);
    final min = _two(dt.minute);
    return '$dd/$mm ${hh}h$min';
  }
}

// Petite carte réutilisable
class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      color: theme.colorScheme.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: theme.colorScheme.outlineVariant.withOpacity(.35),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: child,
      ),
    );
  }
}
