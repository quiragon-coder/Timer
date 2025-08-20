// lib/widgets/activity_controls.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart'; // dbProvider

/// Boutons Démarrer / Pause-Reprendre / Arrêter pour une activité.
class ActivityControls extends ConsumerWidget {
  const ActivityControls({
    super.key,
    required this.activityId,
    this.compact = false,
  });

  final String activityId;
  final bool compact;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);

    final bool running = db.isRunning(activityId);
    final bool paused  = db.isPaused(activityId);

    final EdgeInsets pad = compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 10);

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        ElevatedButton.icon(
          onPressed: running ? null : () async {
            await ref.read(dbProvider).start(activityId);
          },
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Démarrer'),
          style: ElevatedButton.styleFrom(padding: pad),
        ),
        OutlinedButton.icon(
          onPressed: running ? () async {
            await ref.read(dbProvider).togglePause(activityId);
          } : null,
          icon: Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
          label: Text(paused ? 'Reprendre' : 'Mettre en pause'),
          style: OutlinedButton.styleFrom(padding: pad),
        ),
        OutlinedButton.icon(
          onPressed: running ? () async {
            await ref.read(dbProvider).stop(activityId);
          } : null,
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Arrêter'),
          style: OutlinedButton.styleFrom(padding: pad),
        ),
      ],
    );
  }
}
