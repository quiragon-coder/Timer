import 'dart:async';
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
  Timer? _ticker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _startTickerIfNeeded();
  }

  @override
  void didUpdateWidget(covariant ActivityControls oldWidget) {
    super.didUpdateWidget(oldWidget);
    _startTickerIfNeeded();
  }

  void _startTickerIfNeeded() {
    _ticker?.cancel();
    if (ref.read(dbProvider).isRunning(widget.activityId)) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final running = db.isRunning(widget.activityId);
    final paused = db.isPaused(widget.activityId);
    final elapsed = db.runningElapsed(widget.activityId);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (running) Padding(
          padding: const EdgeInsets.only(right: 6),
          child: Text(paused ? '⏸ $mm:$ss' : '⏱ $mm:$ss',
              style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()])),
        ),
        IconButton(
          tooltip: running ? 'Déjà en cours' : 'Start',
          onPressed: _busy || running ? null : () => _run(() => ref.read(dbProvider).quickStart(widget.activityId)),
          icon: const Icon(Icons.play_arrow),
        ),
        IconButton(
          tooltip: paused ? 'Reprendre' : 'Pause',
          onPressed: _busy || !running ? null : () => _run(() => ref.read(dbProvider).quickTogglePause(widget.activityId)),
          icon: Icon(paused ? Icons.play_circle : Icons.pause),
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
      _startTickerIfNeeded();
    }
  }
}
