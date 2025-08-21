// lib/pages/activity_detail_page.dart
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../providers.dart';                // dbProvider, activitiesProvider (si présent)
import '../services/database_models_adapters.dart'; // extensions typées sur DatabaseService
import '../utils/color_compat.dart';

import '../widgets/mini_heatmap.dart';
import '../widgets/activity_stats_panel.dart';
import '../widgets/history_today_card.dart';

import 'activity_history_page.dart';
import 'heatmap_page.dart';

class ActivityDetailPage extends ConsumerStatefulWidget {
  final String activityId;

  const ActivityDetailPage({
    super.key,
    required this.activityId,
  });

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

  /// Démarre/arrête le tick d’1s selon l’état en cours.
  void _updateTicker({required bool shouldTick}) {
    if (shouldTick) {
      if (_ticker == null || !_ticker!.isActive) {
        _ticker?.cancel();
        _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      }
    } else {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);

    // Récupère l’activité (depuis la source de vérité du service)
    final Activity? activity = db.activities.firstWhere(
          (a) => a.id == widget.activityId,
      orElse: () => Activity(
        id: widget.activityId,
        name: 'Activité',
        emoji: '⏱️',
        color: Theme.of(context).colorScheme.primary,
        dailyGoalMinutes: 0,
        weeklyGoalMinutes: 0,
        monthlyGoalMinutes: 0,
        yearlyGoalMinutes: 0,
      ),
    );

    final bool isRunning = db.isRunning(widget.activityId);
    final bool isPaused  = db.isPaused(widget.activityId);
    final Duration elapsed = db.runningElapsed(widget.activityId); // supposé inclure le temps actuel

    // Active le tick seulement quand ça tourne et n’est pas en pause
    _updateTicker(shouldTick: isRunning && !isPaused);

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
          // Accès direct à la Heatmap détaillée (90 jours)
          IconButton(
            tooltip: 'Heatmap détaillée',
            icon: const Icon(Icons.grid_view_rounded),
            onPressed: () {
              Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => ActivityHeatmapPage(
                  activityId: widget.activityId,
                  n: 90,
                  baseColor: activity?.color ?? Theme.of(context).colorScheme.primary,
                ),
              ));
            },
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          // Si tu as un mécanisme de reload, déclenche-le ici.
          setState(() {});
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // En-tête : couleur + objectifs rapides (si renseignés)
              _HeaderInfo(activity: activity),

              const SizedBox(height: 12),

              // Contrôles + badge live mm:ss
              _ControlsRow(
                activityId: widget.activityId,
                isRunning: isRunning,
                isPaused: isPaused,
                elapsed: elapsed,
                onChanged: () => setState(() {}),
              ),

              const SizedBox(height: 12),

              // Historique du jour (typé)
              HistoryTodayCard(
                activityId: widget.activityId,
                activityName: activity?.name ?? 'Activité',
                maxRows: 5,
              ),

              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(MaterialPageRoute(
                      builder: (_) => ActivityHistoryPage(
                        activityId: widget.activityId,
                        activityName: activity?.name ?? 'Activité',
                      ),
                    ));
                  },
                  icon: const Icon(Icons.history),
                  label: const Text('Voir tout l’historique'),
                ),
              ),

              const SizedBox(height: 12),

              // Mini-heatmap riche (28 jours)
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
                        activityId: widget.activityId,
                        days: 28,
                        baseColor: activity?.color ?? Theme.of(context).colorScheme.primary,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Stats (aujourd’hui/semaine/mois/année + graphes)
              Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: ActivityStatsPanel(activityId: widget.activityId),
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

    // Objectifs s’ils existent
    if ((activity?.dailyGoalMinutes ?? 0) > 0) {
      rows.add(_GoalChip(icon: Icons.today,   label: "${activity!.dailyGoalMinutes} min/jour",   color: c));
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
            // Bandeau couleur activité
            Container(
              height: 6,
              decoration: BoxDecoration(
                color: c.withAlphaCompat(.8),
                borderRadius: BorderRadius.circular(6),
              ),
            ),
            const SizedBox(height: 10),
            if (rows.isNotEmpty)
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: rows,
              )
            else
              Text(
                "Aucun objectif défini pour cette activité",
                style: Theme.of(context).textTheme.bodySmall,
              ),
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

class _ControlsRow extends ConsumerStatefulWidget {
  final String activityId;
  final bool isRunning;
  final bool isPaused;
  final Duration elapsed;
  final VoidCallback onChanged;

  const _ControlsRow({
    required this.activityId,
    required this.isRunning,
    required this.isPaused,
    required this.elapsed,
    required this.onChanged,
  });

  @override
  ConsumerState<_ControlsRow> createState() => _ControlsRowState();
}

class _ControlsRowState extends ConsumerState<_ControlsRow> {
  bool _loading = false;

  String _fmtElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return "${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
    }
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);

    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        child: Column(
          children: [
            // Badge live mm:ss
            Align(
              alignment: Alignment.centerRight,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      widget.isRunning
                          ? (widget.isPaused ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded)
                          : Icons.stop_circle_rounded,
                      size: 18,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      _fmtElapsed(widget.elapsed),
                      style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Boutons Start / Pause / Stop
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
                    try {
                      await db.start(widget.activityId);
                    } finally {
                      if (mounted) setState(() => _loading = false);
                      widget.onChanged();
                    }
                  },
                ),
                OutlinedButton.icon(
                  icon: Icon(widget.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                  label: Text(widget.isPaused ? 'Reprendre' : 'Pause'),
                  onPressed: _loading || !widget.isRunning ? null : () async {
                    setState(() => _loading = true);
                    try {
                      await db.togglePause(widget.activityId);
                    } finally {
                      if (mounted) setState(() => _loading = false);
                      widget.onChanged();
                    }
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
                    try {
                      await db.stop(widget.activityId);
                    } finally {
                      if (mounted) setState(() => _loading = false);
                      widget.onChanged();
                    }
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
