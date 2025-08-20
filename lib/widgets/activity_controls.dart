import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

class ActivityControls extends ConsumerStatefulWidget {
  final String activityId;
  const ActivityControls({super.key, required this.activityId});

  @override
  ConsumerState<ActivityControls> createState() => _ActivityControlsState();
}

class _ActivityControlsState extends ConsumerState<ActivityControls> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final running = ref.watch(dbProvider).isRunning(widget.activityId);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: running ? 'Déjà en cours' : 'Start',
          onPressed: _busy || running ? null : () => _run(() => ref.read(dbProvider).quickStart(widget.activityId)),
          icon: const Icon(Icons.play_arrow),
        ),
        IconButton(
          tooltip: 'Pause / Reprendre',
          onPressed: _busy || !running ? null : () => _run(() => ref.read(dbProvider).quickTogglePause(widget.activityId)),
          icon: const Icon(Icons.pause),
        ),
        IconButton(
          tooltip: 'Stop',
          onPressed: _busy || !running ? null : () => _run(() => ref.read(dbProvider).quickStop(widget.activityId)),
          icon: const Icon(Icons.stop),
        ),
      ],
    );
  }

  Future<void> _run(Future Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
