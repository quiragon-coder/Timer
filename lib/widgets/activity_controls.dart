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
    // IMPORTANT: watch (et pas read) pour que l'UI reflète l'état courant
    final db = ref.watch(dbProvider);

    final bool running = db.isRunning(activityId);
    final bool paused  = db.isPaused(activityId);

    final pad = const EdgeInsets.symmetric(horizontal: 16, vertical: 10);

    return Wrap(
      spacing: compact ? 8 : 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        // Démarrer: uniquement quand pas en cours
        FilledButton.icon(
          onPressed: running ? null : () async {
            await db.start(activityId);
          },
          icon: const Icon(Icons.play_arrow),
          label: const Text('Démarrer'),
          style: ButtonStyle(padding: MaterialStatePropertyAll(pad)),
        ),

        // Pause / Reprendre: visible quand en cours
        FilledButton.icon(
          onPressed: running ? () async {
            await db.togglePause(activityId);
          } : null,
          icon: Icon(paused ? Icons.play_arrow : Icons.pause),
          label: Text(paused ? 'Reprendre' : 'Mettre en pause'),
          style: ButtonStyle(padding: MaterialStatePropertyAll(pad)),
        ),

        // Stop: actif si en cours (même en pause)
        FilledButton.icon(
          onPressed: running || paused ? () async {
            await db.stop(activityId);
          } : null,
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
          style: ButtonStyle(
            padding: MaterialStatePropertyAll(pad),
            foregroundColor: MaterialStatePropertyAll(
              Theme.of(context).colorScheme.error,
            ),
            backgroundColor: MaterialStatePropertyAll(
              Theme.of(context).colorScheme.error.withOpacity(.10),
            ),
          ),
        ),
      ],
    );
  }
}
