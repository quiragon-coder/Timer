import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

class ActivityControls extends ConsumerStatefulWidget {
  final String activityId;
  final bool compact;
  const ActivityControls({super.key, required this.activityId, this.compact = false});

  @override
  ConsumerState<ActivityControls> createState() => _ActivityControlsState();
}

class _ActivityControlsState extends ConsumerState<ActivityControls> {
  Future<void> _start() async {
    final db = ref.read(dbProvider);
    await db.start(widget.activityId);     // <- wrappers normalisés
    if (mounted) setState(() {});
  }

  Future<void> _togglePause() async {
    final db = ref.read(dbProvider);
    if (!db.isRunning(widget.activityId)) return;
    await db.togglePause(widget.activityId);
    if (mounted) setState(() {});
  }

  Future<void> _stop() async {
    final db = ref.read(dbProvider);
    if (!db.isRunning(widget.activityId)) return;
    await db.stop(widget.activityId);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final running = db.isRunning(widget.activityId);
    final paused  = db.isPaused(widget.activityId);

    final children = <Widget>[
      // START
      FilledButton.icon(
        onPressed: running ? null : _start,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Démarrer'),
      ),

      // PAUSE / REPRENDRE (visible seulement si en cours)
      if (running)
        FilledButton.tonalIcon(
          onPressed: _togglePause,
          icon: Icon(paused ? Icons.play_arrow : Icons.pause),
          label: Text(paused ? 'Reprendre' : 'Mettre en pause'),
        ),

      // STOP (visible seulement si en cours)
      if (running)
        FilledButton.icon(
          onPressed: _stop,
          icon: const Icon(Icons.stop),
          label: const Text('Stop'),
          style: ButtonStyle(
            backgroundColor: MaterialStateProperty.resolveWith((states) {
              return Theme.of(context).colorScheme.errorContainer;
            }),
            foregroundColor: MaterialStateProperty.resolveWith((states) {
              return Theme.of(context).colorScheme.onErrorContainer;
            }),
          ),
        ),
    ];

    if (widget.compact) {
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: children,
      );
    }

    return OverflowBar(
      alignment: MainAxisAlignment.start,
      spacing: 12,
      overflowSpacing: 8,
      children: children,
    );
  }
}
