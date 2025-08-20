import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../providers.dart'; // dbProvider
import '../providers_stats.dart'; // providers des stats (today / hourly / week / month / year)
import '../widgets/activity_controls.dart';
import '../widgets/activity_stats_panel.dart';

/// Page détail d’une activité.
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

  // Force un petit ticker local pour faire défiler les secondes sur le badge ⏱
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

  // Invalide tous les providers de stats liés à cette activité
  void _invalidateAllStats(String id) {
    ref.invalidate(statsTodayProvider(id));
    ref.invalidate(hourlyTodayProvider(id));
    ref.invalidate(weekTotalProvider(id));
    ref.invalidate(monthTotalProvider(id));
    ref.invalidate(yearTotalProvider(id));
    // Si tu as un provider “7 derniers jours” distinct, décommente :
    // ref.invalidate(last7DaysProvider(id));
  }

  @override
  Widget build(BuildContext context) {
    // ⚠️ On WATCH le service DB : toute évolution (start/pause/stop)
    // reconstruit cette page automatiquement.
    final db = ref.watch(dbProvider);
    final id = widget.activity.id;

    final running = db.isRunning(id);
    final paused = db.isPaused(id);
    _syncTicker(running);

    // Formate le temps écoulé courant (mm:ss) si en cours
    final elapsed = db.runningElapsed(id);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            Text(widget.activity.emoji, style: const TextStyle(fontSize: 22)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                widget.activity.name,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        actions: [
          // Badge ⏱ en haut à droite quand une session est en cours
          if (running)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: (paused
                      ? Colors.orange.withOpacity(.14)
                      : Colors.green.withOpacity(.14)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  children: [
                    Icon(
                      paused ? Icons.pause_circle_filled : Icons.timer_outlined,
                      size: 18,
                      color: paused ? Colors.orange : Colors.green,
                    ),
                    const SizedBox(width: 6),
                    Text('$mm:$ss'),
                  ],
                ),
              ),
            ),
          IconButton(
            tooltip: 'Rafraîchir les statistiques',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _invalidateAllStats(id);
              if (mounted) setState(() {});
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // En-tête "objectif" + points + contrôles
          _Header(activity: widget.activity),

          const SizedBox(height: 12),

          // Boutons Start/Pause-Resume/Stop (responsives)
          ActivityControls(activityId: id),

          const SizedBox(height: 16),

          // Panneau Stats (aujourd’hui + semaine/mois/année + graphiques)
          ActivityStatsPanel(activityId: id),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.activity});

  final Activity activity;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        // Petit point de couleur + emoji + nom
        CircleAvatar(
          radius: 14,
          backgroundColor: activity.color,
          child: Text(activity.emoji, style: const TextStyle(fontSize: 16)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            "Objectif: ${activity.dailyGoalMinutes ?? 0} min/j",
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ],
    );
  }
}
