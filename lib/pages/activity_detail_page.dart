// lib/pages/activity_detail_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../providers.dart';
import '../utils/color_compat.dart';

import '../widgets/mini_heatmap.dart';
import '../widgets/activity_stats_panel.dart';
import '../widgets/history_today_card.dart';
import '../widgets/elapsed_badge.dart';

import 'activity_history_page.dart';
import 'heatmap_page.dart' as hp; // alias de la page détaillée "Heatmap" (attend data + baseColor)

class ActivityDetailPage extends ConsumerWidget {
  final String activityId;
  const ActivityDetailPage({super.key, required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);

    final Activity? activity = db.activities.firstWhere(
          (a) => a.id == activityId,
      orElse: () => Activity(
        id: activityId,
        name: 'Activité',
        emoji: '⏱️',
        color: Theme.of(context).colorScheme.primary,
        dailyGoalMinutes: 0,
        weeklyGoalMinutes: 0,
        monthlyGoalMinutes: 0,
        yearlyGoalMinutes: 0,
      ),
    );

    final isRunning = db.isRunning(activityId);
    final isPaused  = db.isPaused(activityId);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Text(activity?.emoji ?? '⏱️', style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            Expanded(child: Text(activity?.name ?? 'Activité')),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Heatmap détaillée',
            icon: const Icon(Icons.grid_view_rounded),
            onPressed: () {
              // Construit la map des 90 derniers jours et ouvre la page Heatmap (hp.Heatmap)
              final today = DateUtils.dateOnly(DateTime.now());
              final start = today.subtract(const Duration(days: 90 - 1));
              final map = <DateTime, int>{};
              for (int i = 0; i < 90; i++) {
                final day = DateUtils.dateOnly(start.add(Duration(days: i)));
                map[day] = db.effectiveMinutesOnDay(activityId, day);
              }
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => hp.Heatmap(
                  data: map,
                  baseColor: activity?.color ?? Theme.of(context).colorScheme.primary,
                ),
              ));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {},
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HeaderInfo(activity: activity),

              const SizedBox(height: 12),

              _ControlsCard(activityId: activityId, isRunning: isRunning, isPaused: isPaused),

              const SizedBox(height: 12),

              HistoryTodayCard(
                activityId: activityId,
                activityName: activity?.name ?? 'Activité',
                maxRows: 5,
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ActivityHistoryPage(
                        activityId: activityId,
                        activityName: activity?.name ?? 'Activité',
                      ),
                    ));
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('Voir tout l’historique'),
                ),
              ),

              const SizedBox(height: 12),

              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Aperçu (28 jours)', style: Theme.of(context).textTheme.titleSmall),
                      const SizedBox(height: 8),
                      MiniHeatmap(
                        activityId: activityId,
                        days: 28,
                        baseColor: activity?.color ?? Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ActivityStatsPanel(activityId: activityId),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeaderInfo extends StatelessWidget {
  final Activity? activity;
  const _HeaderInfo({required this.activity});

  @override
  Widget build(BuildContext context) {
    final c = activity?.color ?? Theme.of(context).colorScheme.primary;
    final rows = <Widget>[];

    if ((activity?.dailyGoalMinutes ?? 0) > 0) {
      rows.add(_GoalChip(icon: Icons.today, label: "${activity!.dailyGoalMinutes} min/jour", color: c));
    }
    if ((activity?.weeklyGoalMinutes ?? 0) > 0) {
      rows.add(_GoalChip(icon: Icons.calendar_view_week, label: "${activity!.weeklyGoalMinutes} min/sem.", color: c));
    }
    if ((activity?.monthlyGoalMinutes ?? 0) > 0) {
      rows.add(_GoalChip(icon: Icons.calendar_view_month, label: "${activity!.monthlyGoalMinutes} min/mois", color: c));
    }
    if ((activity?.yearlyGoalMinutes ?? 0) > 0) {
      rows.add(_GoalChip(icon: Icons.event, label: "${activity!.yearlyGoalMinutes} min/an", color: c));
    }

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: c.withAlphaCompat(.8),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 10),
            if (rows.isNotEmpty)
              Wrap(spacing: 8, runSpacing: 8, children: rows)
            else
              Text("Aucun objectif défini pour cette activité", style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  const _GoalChip({required this.icon, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(icon, size: 16, color: color),
      label: Text(label),
      side: BorderSide(color: color.withAlphaCompat(.4)),
      backgroundColor: color.withAlphaCompat(.08),
    );
  }
}

class _ControlsCard extends ConsumerStatefulWidget {
  final String activityId;
  final bool isRunning;
  final bool isPaused;
  const _ControlsCard({required this.activityId, required this.isRunning, required this.isPaused});

  @override
  ConsumerState<_ControlsCard> createState() => _ControlsCardState();
}

class _ControlsCardState extends ConsumerState<_ControlsCard> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: ElapsedBadge(
                isRunning: widget.isRunning,
                isPaused: widget.isPaused,
                getElapsed: () => db.runningElapsed(widget.activityId),
              ),
            ),

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Démarrer'),
                  onPressed: _loading || widget.isRunning ? null : () async {
                    setState(() => _loading = true);
                    try { await db.start(widget.activityId); }
                    finally { if (mounted) setState(() => _loading = false); }
                  },
                ),
                OutlinedButton.icon(
                  icon: Icon(widget.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                  label: Text(widget.isPaused ? 'Reprendre' : 'Pause'),
                  onPressed: _loading || !widget.isRunning ? null : () async {
                    setState(() => _loading = true);
                    try { await db.togglePause(widget.activityId); }
                    finally { if (mounted) setState(() => _loading = false); }
                  },
                ),
                FilledButton.icon(
                  icon: const Icon(Icons.stop_rounded),
                  label: const Text('Stop'),
                  onPressed: _loading || !widget.isRunning ? null : () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Arrêter la session ?'),
                        content: const Text('La durée sera enregistrée.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
                          FilledButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Stop')),
                        ],
                      ),
                    );
                    if (confirm != true) return;
                    setState(() => _loading = true);
                    try { await db.stop(widget.activityId); }
                    finally { if (mounted) setState(() => _loading = false); }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
