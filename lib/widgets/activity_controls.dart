import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers.dart'; // dbProvider

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
    await db.start(widget.activityId);          // ⬅ utilise start(...)
    if (mounted) setState(() {});               // petite secousse UI
  }

  Future<void> _togglePause() async {
    final db = ref.read(dbProvider);
    if (!db.isRunning(widget.activityId)) return;
    await db.togglePause(widget.activityId);    // ⬅ utilise togglePause(...)
    if (mounted) setState(() {});
  }

  Future<void> _stop() async {
    final db = ref.read(dbProvider);
    if (!db.isRunning(widget.activityId)) return;
    await db.stop(widget.activityId);           // ⬅ utilise stop(...)
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    // IMPORTANT : watch (et non read) pour reconstruire quand notifyListeners() est appelé.
    final db = ref.watch(dbProvider);

    final running = db.isRunning(widget.activityId);
    final paused  = db.isPaused(widget.activityId);

    final pad = widget.compact ? const EdgeInsets.symmetric(horizontal: 8, vertical: 6)
        : const EdgeInsets.symmetric(horizontal: 12, vertical: 10);

    // Boutons en fonction de l’état:
    // - non démarré : [Démarrer]
    // - démarré & en cours : [Pause] [Arrêter]
    // - démarré & en pause : [Reprendre] [Arrêter]
    List<Widget> buttons;
    if (!running) {
      buttons = [
        FilledButton.icon(
          onPressed: _start,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Démarrer'),
        ),
      ];
    } else if (paused) {
      buttons = [
        FilledButton.icon(
          onPressed: _togglePause,
          icon: const Icon(Icons.play_arrow),
          label: const Text('Reprendre'),
        ),
        OutlinedButton.icon(
          onPressed: _stop,
          icon: const Icon(Icons.stop),
          label: const Text('Arrêter'),
        ),
      ];
    } else {
      buttons = [
        FilledButton.icon(
          onPressed: _togglePause,
          icon: const Icon(Icons.pause),
          label: const Text('Pause'),
        ),
        OutlinedButton.icon(
          onPressed: _stop,
          icon: const Icon(Icons.stop),
          label: const Text('Arrêter'),
        ),
      ];
    }

    return Padding(
      padding: pad,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: buttons,
      ),
    );
  }
}
