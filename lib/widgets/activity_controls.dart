import 'package:flutter/material.dart';
import '../providers.dart';

class ActivityControls extends StatefulWidget {
  final String activityId;
  const ActivityControls({super.key, required this.activityId});

  @override
  State<ActivityControls> createState() => _ActivityControlsState();
}

class _ActivityControlsState extends State<ActivityControls> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        IconButton(
          tooltip: 'Start',
          onPressed: _busy ? null : () => _run(() => dbProvider.read(context).quickStart(widget.activityId)),
          icon: const Icon(Icons.play_arrow),
        ),
        IconButton(
          tooltip: 'Pause/Unpause',
          onPressed: _busy ? null : () => _run(() => dbProvider.read(context).quickTogglePause(widget.activityId)),
          icon: const Icon(Icons.pause),
        ),
        IconButton(
          tooltip: 'Stop',
          onPressed: _busy ? null : () => _run(() => dbProvider.read(context).quickStop(widget.activityId)),
          icon: const Icon(Icons.stop),
        ),
      ],
    );
  }

  Future<void> _run(Future Function() action) async {
    setState(() => _busy = true);
    try { await action(); } finally { if (mounted) setState(() => _busy = false); }
  }
}

extension on ProviderBase {
  T read<T>(BuildContext context) => ProviderScope.containerOf(context, listen: false).read(this as dynamic);
}
