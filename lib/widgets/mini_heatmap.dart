import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers_stats.dart';
import '../pages/heatmap_page.dart';
import 'heatmap.dart';

class MiniHeatmap extends ConsumerStatefulWidget {
  final String activityId;
  final int days; // ex: 30
  final Color baseColor;

  const MiniHeatmap({
    super.key,
    required this.activityId,
    required this.days,
    required this.baseColor,
  });

  @override
  ConsumerState<MiniHeatmap> createState() => _MiniHeatmapState();
}

class _MiniHeatmapState extends ConsumerState<MiniHeatmap> {
  OverlayEntry? _overlay;

  void _showOverlay(BuildContext context, Offset globalPos, String message) {
    _hideOverlay();
    final overlay = Overlay.of(context);
    final entry = OverlayEntry(
      builder: (_) {
        final renderBox = context.findRenderObject() as RenderBox?;
        final size = renderBox?.size ?? const Size(200, 100);
        final local = globalPos;
        final dx = local.dx.clamp(8.0, size.width - 8.0);
        final dy = (local.dy - 40).clamp(8.0, size.height - 8.0);

        return Positioned(
          left: dx,
          top: dy,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                message,
                style: const TextStyle(color: Colors.white, fontSize: 12),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(entry);
    _overlay = entry;

    Future.delayed(const Duration(seconds: 1), _hideOverlay);
  }

  void _hideOverlay() {
    _overlay?.remove();
    _overlay = null;
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(
      lastNDaysProvider(LastNDaysArgs(activityId: widget.activityId, n: widget.days)),
    );

    return async.when(
      loading: () => const SizedBox(
        height: 64,
        child: Center(child: SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))),
      ),
      error: (e, _) => SizedBox(
        height: 64,
        child: Center(child: Text('Erreur: $e')),
      ),
      data: (stats) {
        final map = <DateTime, int>{};
        for (final d in stats) {
          map[DateUtils.dateOnly(d.date)] = d.minutes;
        }

        return GestureDetector(
          onTapDown: (d) => _showOverlay(context, d.globalPosition, "Mini heatmap — tape 2× pour ouvrir"),
          onDoubleTap: () {
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => ActivityHeatmapPage(
                activityId: widget.activityId,
                n: 365,
                baseColor: widget.baseColor,
              ),
            ));
          },
          child: Heatmap(
            data: map,
            baseColor: widget.baseColor,
          ),
        );
      },
    );
  }
}
