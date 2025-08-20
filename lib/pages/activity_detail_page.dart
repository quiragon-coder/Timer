import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../providers.dart';            // dbProvider
import '../providers_stats.dart';      // statsTodayProvider, hourlyTodayProvider, week/month/year
import '../services/database_service.dart';
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
  void initState() {
    super.initState();

    // À chaque changement DB on invalide les stats clés (aujourd’hui + totaux).
    // NB: j’enlève ici l’invalidation du provider "last7DaysProvider" qui
    // n’a pas le même nom partout (évite ton erreur de symbole introuvable).
    ref.listen<DatabaseService>(dbProvider, (_, __) {
      final id = widget.activity.id;
      ref.invalidate(statsTodayProvider(id));
      ref.invalidate(hourlyTodayProvider(id));
      ref.invalidate(weekTotalProvider(id));
      ref.invalidate(monthTotalProvider(id));
      ref.invalidate(yearTotalProvider(id));
      if (mounted) setState(() {});
    });
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

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final a  = widget.activity;

    final running = db.isRunning(a.id);
    final paused  = db.isPaused(a.id);
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
            Expanded(child: Text(a.name, overflow: TextOverflow.ellipsis)),
          ],
        ),
        actions: [
          if (running)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: paused
                      ? Colors.orange.withOpacity(.15)
                      : Colors.green.withOpacity(.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(paused ? Icons.pause : Icons.timer_outlined, size: 16),
                    const SizedBox(width: 6),
                    Text('$mm:$ss'),
                  ],
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
              Container(
                width: 10, height: 10,
                decoration: BoxDecoration(color: a.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text('Objectif: ${a.dailyGoalMinutes ?? 0} min/j'),
            ],
          ),
          const SizedBox(height: 12),

          Wrap(
            spacing: 12, runSpacing: 12,
            children: [
              ActivityControls(activityId: a.id),
            ],
          ),

          const SizedBox(height: 24),
          Divider(color: Theme.of(context).dividerColor.withOpacity(.4)),
          const SizedBox(height: 12),

          ActivityStatsPanel(activityId: a.id),
        ],
      ),
    );
  }
}
