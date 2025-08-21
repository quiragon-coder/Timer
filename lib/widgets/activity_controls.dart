import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

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
  Future<void> _start() async {
    final db = ref.read(dbProvider);
    await db.start(widget.activityId);
    if (mounted) setState(() {});
  }

  Future<void> _pauseOrResume() async {
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
    final paused = db.isPaused(widget.activityId);

    final EdgeInsets pad = widget.compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 8)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 12);

    final buttons = <Widget>[
      // START
      if (!running)
        FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Démarrer'),
          style: FilledButton.styleFrom(padding: pad),
        ),

      // PAUSE / REPRENDRE
      if (running)
        FilledButton.tonal(
          onPressed: _pauseOrResume,
          style: FilledButton.styleFrom(padding: pad),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(paused ? Icons.play_arrow_rounded : Icons.pause_rounded),
              const SizedBox(width: 6),
              Text(paused ? 'Reprendre' : 'Mettre en pause'),
            ],
          ),
        ),

      // STOP
      if (running)
        OutlinedButton.icon(
          onPressed: _stop,
          icon: const Icon(Icons.stop_rounded),
          label: const Text('Stop'),
          style: OutlinedButton.styleFrom(padding: pad),
        ),
    ];

    return Align(
      alignment: Alignment.centerLeft,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: buttons
            .map(
              (b) => ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 120),
            child: b,
          ),
        )
            .toList(),
      ),
    );
  }
}
