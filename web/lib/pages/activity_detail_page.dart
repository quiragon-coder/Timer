import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/activity.dart';
import '../providers.dart';                // dbProvider
import '../providers_stats.dart';         // lastNDaysProvider, LastNDaysArgs
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

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider); // reconstruit quand start/pause/stop notifie
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final id = widget.activity.id;
    final running = db.isRunning(id);
    final paused = db.isPaused(id);
    _ensureTicker(running);

    final elapsed = db.runningElapsed(id);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    // Historique (totaux par jour) sur 7 jours
    final last7Async = ref.watch(lastNDaysProvider(LastNDaysArgs(activityId: id, n: 7)));
    final dayFmt = DateFormat.EEEE('fr_FR'); // ex. lundi
    final dateFmt = DateFormat('d MMM', 'fr_FR');

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
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // En-tête + badge temps réel
            Card(
              elevation: 0,
              color: cs.surface,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    // pastille couleur + emoji + nom
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: widget.activity.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(widget.activity.emoji, style: const TextStyle(fontSize: 22)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        widget.activity.name,
                        style: tt.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),

                    // Badge ⏱ temps réel si en cours
                    if (running)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: (paused ? Colors.orange : Colors.green).withOpacity(.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: paused ? Colors.orange : Colors.green,
                            width: 0.75,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              paused ? Icons.pause_circle_outline : Icons.timer_outlined,
                              size: 16,
                              color: paused ? Colors.orange : Colors.green,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              '$mm:$ss',
                              style: tt.bodyMedium?.copyWith(
                                color: paused ? Colors.orange : Colors.green,
                                fontFeatures: const [FontFeature.tabularFigures()],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Contrôles
            ActivityControls(activityId: id),

            const SizedBox(height: 12),

            // Historique de session (simple: totaux par jour sur 7 jours)
            Card(
              elevation: 0,
              color: cs.surface,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Historique (7 derniers jours)', style: tt.titleSmall),
                    const SizedBox(height: 8),
                    last7Async.when(
                      loading: () => const Center(child: Padding(
                        padding: EdgeInsets.all(12),
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )),
                      error: (e, _) => Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text('Erreur: $e'),
                      ),
                      data: (stats) {
                        // On affiche même les jours à 0 min pour visibilité
                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: stats.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final s = stats[i]; // has: s.date (DateTime), s.minutes (int)
                            final title = '${toBeginningOfSentenceCase(dayFmt.format(s.date))} ${dateFmt.format(s.date)}';
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(title),
                              trailing: Text('${s.minutes} min'),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            // Panel Stats (mini heatmap + charts)
            ActivityStatsPanel(activityId: id),
          ],
        ),
      ),
    );
  }
}
