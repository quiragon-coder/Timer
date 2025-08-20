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
    final paused = db.isPaused(widget.activityId);

    // Style “compact” pour mobile / petit espace
    final pad = widget.compact ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6) : null;
    final visual = widget.compact ? VisualDensity.compact : VisualDensity.standard;

    final startBtn = ElevatedButton.icon(
      onPressed: running ? null : _start,
      icon: const Icon(Icons.play_arrow),
      label: const Text('Démarrer'),
      style: ElevatedButton.styleFrom(padding: pad, visualDensity: visual),
    );

    final pauseBtn = OutlinedButton.icon(
      onPressed: running ? _togglePause : null,
      icon: Icon(paused ? Icons.play_arrow : Icons.pause),
      label: Text(paused ? 'Reprendre' : 'Pause'),
      style: OutlinedButton.styleFrom(padding: pad, visualDensity: visual),
    );

    final stopBtn = TextButton.icon(
      onPressed: running ? _stop : null,
      icon: const Icon(Icons.stop),
      label: const Text('Stop'),
      style: TextButton.styleFrom(padding: pad, visualDensity: visual),
    );

    // Wrap = casse automatiquement la ligne si pas assez de place
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        if (!running) startBtn,
        if (running) pauseBtn,
        if (running) stopBtn,
      ],
    );
  }
}
