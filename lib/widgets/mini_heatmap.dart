import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers_stats.dart';
import '../pages/heatmap_page.dart';
import 'heatmap.dart';

class MiniHeatmap extends ConsumerWidget {
  final String activityId;
  final int days; // fenêtre affichée (ex: 30)
  final Color? baseColor;

  const MiniHeatmap({
    super.key,
    required this.activityId,
    required this.days,
    this.baseColor,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(
      lastNDaysProvider(
        LastNDaysArgs(activityId: activityId, n: days),
      ),
    );

    return async.when(
      loading: () => const SizedBox(
        height: 84,
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      error: (e, _) => SizedBox(
        height: 84,
        child: Center(child: Text('Erreur: $e')),
      ),
      data: (list) {
        final data = <DateTime, int>{
          for (final d in list) DateUtils.dateOnly(d.date): d.minutes
        };

        // Gestion tap + double-tap
        return _TapWrapper(
          onSingleTap: (offset) {
            // Affiche un tooltip simple au point tapé
            // Trouve la journée la plus proche : approximation (le widget Heatmap gère le rendu).
            // Ici on affiche juste une info générique pour rester léger.
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Jour sélectionné')),
            );
          },
          onDoubleTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ActivityHeatmapPage(
                  activityId: activityId,
                  n: 365,
                  baseColor: baseColor,
                ),
              ),
            );
          },
          child: Heatmap(
            data: data,
            baseColor: baseColor ?? Theme.of(context).colorScheme.primary,
            cellSize: 12,
            cellSpacing: 3,
            padding: const EdgeInsets.all(8),
            // Pas d’onTap ici : on passe par notre wrapper pour gérer single/double tap
          ),
        );
      },
    );
  }
}

/// Détecte single tap vs double tap et expose la position du single tap.
class _TapWrapper extends StatefulWidget {
  final Widget child;
  final void Function(Offset localPos) onSingleTap;
  final VoidCallback onDoubleTap;

  const _TapWrapper({
    required this.child,
    required this.onSingleTap,
    required this.onDoubleTap,
  });

  @override
  State<_TapWrapper> createState() => _TapWrapperState();
}

class _TapWrapperState extends State<_TapWrapper> {
  Offset _lastTapPosition = Offset.zero;
  final Duration _doubleTapDelay = const Duration(milliseconds: 260);
  DateTime? _lastTapTime;

  void _handleTapDown(TapDownDetails d) {
    _lastTapPosition = d.localPosition;
  }

  void _handleTap() {
    final now = DateTime.now();
    if (_lastTapTime != null &&
        now.difference(_lastTapTime!) <= _doubleTapDelay) {
      // Double tap
      _lastTapTime = null;
      widget.onDoubleTap();
    } else {
      // Single tap
      _lastTapTime = now;
      Future.delayed(_doubleTapDelay, () {
        if (!mounted) return;
        // Si pas eu de second tap dans la fenêtre, considère comme single tap
        if (_lastTapTime != null &&
            DateTime.now().difference(_lastTapTime!) > _doubleTapDelay) {
          widget.onSingleTap(_lastTapPosition);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _handleTapDown,
      onTap: _handleTap,
      child: widget.child,
    );
  }
}
