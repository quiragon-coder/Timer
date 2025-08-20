import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';
import '../providers_settings.dart';

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
    final settings = ref.read(settingsProvider);
    await db.start(widget.activityId);
    if (settings.hapticsOnControls) {
      HapticFeedback.mediumImpact();
    }
    if (mounted) setState(() {});
  }

  Future<void> _togglePause() async {
    final db = ref.read(dbProvider);
    final settings = ref.read(settingsProvider);
    if (!db.isRunning(widget.activityId)) return;
    await db.togglePause(widget.activityId);
    if (settings.hapticsOnControls) {
      HapticFeedback.selectionClick();
    }
    if (mounted) setState(() {});
  }

  Future<void> _stop() async {
    final db = ref.read(dbProvider);
    final settings = ref.read(settingsProvider);
    if (!db.isRunning(widget.activityId)) return;

    if (settings.confirmStop) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Arrêter la session ?'),
          content: const Text('La session en cours sera arrêtée.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuler')),
            FilledButton.tonal(onPressed: () => Navigator.pop(context, true), child: const Text('Arrêter')),
          ],
        ),
      );
      if (ok != true) return;
    }

    await db.stop(widget.activityId);
    if (settings.hapticsOnControls) {
      HapticFeedback.heavyImpact();
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final running = db.isRunning(widget.activityId);
    final paused = db.isPaused(widget.activityId);

    final ButtonStyle filled = FilledButton.styleFrom();
    final ButtonStyle tonal = FilledButton.tonalStyleFrom();
    final ButtonStyle outlined = OutlinedButton.styleFrom();

    final pad = widget.compact ? const EdgeInsets.symmetric(horizontal: 8) : null;

    if (!running) {
      // DÉMARRER
      return FilledButton(
        style: filled,
        onPressed: _start,
        child: const Text('Démarrer'),
      );
    }

    // EN COURS
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!paused)
          FilledButton.tonal(
            style: tonal,
            onPressed: _togglePause,
            child: const Text('Mettre en pause'),
          )
        else
          FilledButton(
            style: filled,
            onPressed: _togglePause,
            child: const Text('Reprendre'),
          ),
        OutlinedButton(
          style: outlined.copyWith(padding: pad),
          onPressed: _stop,
          child: const Text('Arrêter'),
        ),
      ],
    );
  }
}
