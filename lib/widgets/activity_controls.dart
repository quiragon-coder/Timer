import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart';

class ActivityControls extends ConsumerStatefulWidget {
  final String activityId;
  final bool compact; // boutons plus petits
  const ActivityControls({super.key, required this.activityId, this.compact = false});

  @override
  ConsumerState<ActivityControls> createState() => _ActivityControlsState();
}

class _ActivityControlsState extends ConsumerState<ActivityControls> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final running = db.isRunning(widget.activityId);
    final paused = db.isPaused(widget.activityId);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _btn(
          tooltip: running ? 'Déjà en cours' : 'Start',
          icon: Icons.play_arrow,
          onPressed: _busy || running ? null : () => _run(() => ref.read(dbProvider).quickStart(widget.activityId)),
        ),
        _btn(
          tooltip: paused ? 'Reprendre' : 'Pause',
          icon: paused ? Icons.play_circle : Icons.pause,
          onPressed: _busy || !running ? null : () => _run(() => ref.read(dbProvider).quickTogglePause(widget.activityId)),
        ),
        _btn(
          tooltip: 'Stop',
          icon: Icons.stop,
          onPressed: _busy || !running ? null : () => _run(() => ref.read(dbProvider).quickStop(widget.activityId)),
        ),
      ],
    );
  }

  Widget _btn({required String tooltip, required IconData icon, required VoidCallback? onPressed}) {
    if (widget.compact) {
      return IconButton(
        tooltip: tooltip,
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        padding: const EdgeInsets.all(4),
        constraints: const BoxConstraints.tightFor(width: 36, height: 36),
        visualDensity: VisualDensity.compact,
      );
    }
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon),
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
