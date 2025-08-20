import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class ActivityControls extends ConsumerWidget {
  final String activityId;
  final bool compact;

  const ActivityControls({
    super.key,
    required this.activityId,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final running = db.isRunning(activityId);
    final paused = db.isPaused(activityId);

    final style = compact
        ? const ButtonStyle(
      minimumSize: MaterialStatePropertyAll(Size(36, 36)),
      padding:
      MaterialStatePropertyAll(EdgeInsets.symmetric(horizontal: 10)),
    )
        : const ButtonStyle();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // START
        ElevatedButton.icon(
          style: style,
          onPressed: running ? null : () => ref.read(dbProvider).quickStart(activityId),
          icon: const Icon(Icons.play_arrow),
          label: Text(compact ? 'Start' : 'Démarrer'),
        ),

        // PAUSE / RESUME
        ElevatedButton.icon(
          style: style,
          onPressed: running ? () => ref.read(dbProvider).quickTogglePause(activityId) : null,
          icon: Icon(paused ? Icons.play_circle_outline : Icons.pause),
          label: Text(paused ? (compact ? 'Reprendre' : 'Reprendre')
              : (compact ? 'Pause' : 'Mettre en pause')),
        ),

        // STOP
        ElevatedButton.icon(
          style: style,
          onPressed: running ? () => ref.read(dbProvider).quickStop(activityId) : null,
          icon: const Icon(Icons.stop),
          label: Text(compact ? 'Stop' : 'Arrêter'),
        ),
      ],
    );
  }
}
