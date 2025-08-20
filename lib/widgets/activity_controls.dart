import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';

/// Boutons Start / Pause↔Reprendre / Stop.
/// - compact:true  -> icônes seules (liste)
/// - compact:false -> boutons avec libellés (page détail)
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
    await db.start(widget.activityId);      // ← noms standard
    if (!mounted) return;
    setState(() {});                        // petite MAJ locale
  }

  Future<void> _togglePause() async {
    final db = ref.read(dbProvider);
    if (!db.isRunning(widget.activityId)) return;
    await db.togglePause(widget.activityId); // ← noms standard
    if (!mounted) return;
    setState(() {});
  }

  Future<void> _stop() async {
    final db = ref.read(dbProvider);
    if (!db.isRunning(widget.activityId)) return;
    await db.stop(widget.activityId);       // ← noms standard
    if (!mounted) return;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final running = db.isRunning(widget.activityId);
    final paused  = running && db.isPaused(widget.activityId);

    if (!widget.compact) {
      // Version “riche” (page détail) — Wrap = responsive
      return Wrap(
        spacing: 12,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            onPressed: running ? null : _start,
            icon: const Icon(Icons.play_arrow),
            label: const Text('Démarrer'),
          ),
          FilledButton.tonalIcon(
            onPressed: running ? _togglePause : null,
            icon: Icon(paused ? Icons.play_arrow : Icons.pause),
            label: Text(paused ? 'Reprendre' : 'Mettre en pause'),
          ),
          OutlinedButton.icon(
            onPressed: running ? _stop : null,
            icon: const Icon(Icons.stop),
            label: const Text('Arrêter'),
          ),
        ],
      );
    }

    // Version compacte (liste) — icônes seules
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        IconButton.filled(
          tooltip: 'Démarrer',
          onPressed: running ? null : _start,
          icon: const Icon(Icons.play_arrow),
        ),
        IconButton.filledTonal(
          tooltip: paused ? 'Reprendre' : 'Mettre en pause',
          onPressed: running ? _togglePause : null,
          icon: Icon(paused ? Icons.play_arrow : Icons.pause),
        ),
        IconButton.outlined(
          tooltip: 'Arrêter',
          onPressed: running ? _stop : null,
          icon: const Icon(Icons.stop),
        ),
      ],
    );
  }
}
