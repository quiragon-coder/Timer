import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../providers_stats.dart';

/// Invalide les providers de stats liés à une activité.
/// (Je n’invalide pas de "last7Provider" ici pour rester compatible
///  avec ton fichier providers_stats.dart actuel.)
void _invalidateStats(WidgetRef ref, String id) {
  ref.invalidate(statsTodayProvider(id));
  ref.invalidate(hourlyTodayProvider(id));
  ref.invalidate(weekTotalProvider(id));
  ref.invalidate(monthTotalProvider(id));
  ref.invalidate(yearTotalProvider(id));
}

/// Boutons Start / Pause-Reprendre / Stop, responsives.
class ActivityControls extends ConsumerStatefulWidget {
  final String activityId;
  final bool compact;

  const ActivityControls({
    super.key,
    required this.activityId,
    this.compact = false,
  });

  @override
  ConsumerState<ActivityControls> createState() => _ActivityControlsState();
}

class _ActivityControlsState extends ConsumerState<ActivityControls> {
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  Future<void> _start() async {
    final db = ref.read(dbProvider);
    await db.start(widget.activityId);
    _invalidateStats(ref, widget.activityId);
    if (mounted) setState(() {});
  }

  Future<void> _togglePause() async {
    final db = ref.read(dbProvider);
    if (!db.isRunning(widget.activityId)) return;
    await db.togglePause(widget.activityId);
    _invalidateStats(ref, widget.activityId);
    if (mounted) setState(() {});
  }

  Future<void> _stop() async {
    final db = ref.read(dbProvider);
    if (!db.isRunning(widget.activityId)) return;
    await db.stop(widget.activityId);
    _invalidateStats(ref, widget.activityId);
    if (mounted) setState(() {});
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
    // On WATCH le db pour reconstruire l’UI quand l’état change
    final db = ref.watch(dbProvider);

    final running = db.isRunning(widget.activityId);
    final paused  = db.isPaused(widget.activityId);

    _syncTicker(running);

    final isSmall = widget.compact;
    final ButtonStyle smallStyle = FilledButton.styleFrom(
      padding: const EdgeInsets.symmetric(horizontal: 12),
    );

    final pauseResumeLabel = paused ? "Reprendre" : "Mettre en pause";
    final pauseResumeIcon  = paused ? Icons.play_arrow : Icons.pause;

    // Wrap pour éviter les overflows -> responsive
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        FilledButton.icon(
          style: isSmall ? smallStyle : const ButtonStyle(),
          onPressed: running ? null : _start,
          icon: const Icon(Icons.play_arrow),
          label: const Text("Démarrer"),
        ),
        FilledButton.tonalIcon(
          style: isSmall ? smallStyle : const ButtonStyle(),
          onPressed: running ? _togglePause : null,
          icon: Icon(pauseResumeIcon),
          label: Text(pauseResumeLabel),
        ),
        FilledButton.tonalIcon(
          style: isSmall ? smallStyle : const ButtonStyle(),
          onPressed: running ? _stop : null,
          icon: const Icon(Icons.stop),
          label: const Text("Arrêter"),
        ),
      ],
    );
  }
}
