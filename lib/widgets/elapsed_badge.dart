import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';

class ElapsedBadge extends StatefulWidget {
  final bool isRunning;
  final bool isPaused;
  final Duration Function() getElapsed; // appelé à l’affichage

  const ElapsedBadge({
    super.key,
    required this.isRunning,
    required this.isPaused,
    required this.getElapsed,
  });

  @override
  State<ElapsedBadge> createState() => _ElapsedBadgeState();
}

class _ElapsedBadgeState extends State<ElapsedBadge> {
  Timer? _t;

  @override
  void didUpdateWidget(covariant ElapsedBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    _ensureTicker();
  }

  @override
  void initState() {
    super.initState();
    _ensureTicker();
  }

  void _ensureTicker() {
    final shouldTick = widget.isRunning && !widget.isPaused;
    if (shouldTick) {
      if (_t == null || !_t!.isActive) {
        _t?.cancel();
        _t = Timer.periodic(const Duration(seconds: 1), (_) {
          if (mounted) setState(() {});
        });
      }
    } else {
      _t?.cancel();
      _t = null;
    }
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String _fmtElapsed(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    final s = d.inSeconds.remainder(60);
    if (h > 0) {
      return "${h}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
    }
    return "${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}";
  }

  @override
  Widget build(BuildContext context) {
    final d = widget.getElapsed();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            widget.isRunning
                ? (widget.isPaused ? Icons.pause_circle_filled_rounded : Icons.play_circle_fill_rounded)
                : Icons.stop_circle_rounded,
            size: 18,
          ),
          const SizedBox(width: 6),
          Text(
            _fmtElapsed(d),
            style: const TextStyle(fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ],
      ),
    );
  }
}
