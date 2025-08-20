// lib/widgets/activity_controls.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart'; // exposes dbProvider

/// Start / Pause / Stop controls for one activity.
class ActivityControls extends ConsumerStatefulWidget {
  const ActivityControls({
    super.key,
    required this.activityId,
    this.compact = false,
  });

  final String activityId;
  final bool compact;

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
    // Watch to rebuild when DB notifies changes
    final db = ref.watch(dbProvider);

    final bool running = db.isRunning(widget.activityId);
    final bool paused  = db.isPaused(widget.activityId);

    // Pause button appears only when a session is running.
    final bool canPauseOrResume = running;
    final bool showResume = running && paused; // true -> label "Reprendre"

    final EdgeInsets pad = widget.compact
        ? const EdgeInsets.symmetric(horizontal: 10, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 14, vertical: 10);

    final TextStyle? txt = widget.compact
        ? Theme.of(context).textTheme.labelLarge
        : Theme.of(context).textTheme.labelLarge;

    // Use Wrap for responsiveness (no RenderOverflow issues)
    return Wrap(
      alignment: WrapAlignment.start,
      spacing: 12,
      runSpacing: 12,
      children: [
        _btn(
          enabled: !running,
          onPressed: _start,
          icon: Icons.play_arrow_rounded,
          label: 'Démarrer',
          pad: pad,
          textStyle: txt,
          primary: true,
        ),
        _btn(
          enabled: canPauseOrResume,
          onPressed: _togglePause,
          icon: showResume ? Icons.play_arrow_rounded : Icons.pause_rounded,
          label: showResume ? 'Reprendre' : 'Mettre en pause',
          pad: pad,
          textStyle: txt,
        ),
        _btn(
          enabled: running,
          onPressed: _stop,
          icon: Icons.stop_rounded,
          label: 'Arrêter',
          pad: pad,
          textStyle: txt,
        ),
      ],
    );
  }

  Widget _btn({
    required bool enabled,
    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required EdgeInsets pad,
    TextStyle? textStyle,
    bool primary = false,
  }) {
    final ButtonStyle style = (primary
        ? ElevatedButton.styleFrom(padding: pad)
        : OutlinedButton.styleFrom(padding: pad))
        .merge(ButtonStyle(
      textStyle: WidgetStatePropertyAll(textStyle),
    ));

    final Widget child = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon),
        const SizedBox(width: 6),
        Text(label),
      ],
    );

    if (primary) {
      return ElevatedButton(
        onPressed: enabled ? onPressed : null,
        style: style,
        child: child,
      );
    } else {
      return OutlinedButton(
        onPressed: enabled ? onPressed : null,
        style: style,
        child: child,
      );
    }
  }
}
