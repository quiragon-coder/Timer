import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stats.dart';                 // DailyStat (champ: day)
import '../providers_stats.dart';
import '../pages/heatmap_page.dart';

class MiniHeatmap extends ConsumerStatefulWidget {
  const MiniHeatmap({
    super.key,
    required this.activityId,
    this.days = 21,
    this.cellSize = 14,
    this.gap = 3,
  });

  final String activityId;
  final int days;
  final double cellSize;
  final double gap;

  @override
  ConsumerState<MiniHeatmap> createState() => _MiniHeatmapState();
}

class _MiniHeatmapState extends ConsumerState<MiniHeatmap> {
  OverlayEntry? _entry;
  Timer? _hideTimer;

  void _showOverlay(BuildContext context, Offset anchor, DailyStat s) {
    _hideOverlay();
    final overlay = Overlay.of(context);
    _entry = OverlayEntry(
      builder: (_) {
        return Positioned(
          left: anchor.dx + 8,
          top: anchor.dy - 40,
          child: Material(
            color: Colors.transparent,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.80),
                borderRadius: BorderRadius.circular(8),
              ),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(_fmtDate(s.day)),
                    const SizedBox(height: 2),
                    Text('${s.minutes} min'),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
    overlay.insert(_entry!);
    _hideTimer = Timer(const Duration(seconds: 2), _hideOverlay);
  }

  void _hideOverlay() {
    _hideTimer?.cancel();
    _hideTimer = null;
    _entry?.remove();
    _entry = null;
  }

  @override
  void dispose() {
    _hideOverlay();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(
      lastNDaysProvider({'activityId': widget.activityId, 'n': widget.days}),
    );

    return statsAsync.when(
      loading: () => const SizedBox(height: 24, child: LinearProgressIndicator()),
      error: (e, _) => Text('erreur: $e'),
      data: (list) {
        if (list.isEmpty) {
          return const Text('Pas de donn\u00E9es');
        }

        // On veut les jours du plus ancien au plus récent, groupés en colonnes (semaines)
        final data = list.reversed.toList(); // ancien -> récent
        final cols = <List<DailyStat>>[];
        for (var i = 0; i < data.length; i += 7) {
          cols.add(data.sublist(i, (i + 7).clamp(0, data.length)));
        }

        final max = (data.map((e) => e.minutes).fold<int>(0, (a, b) => a > b ? a : b)).clamp(1, 9999);

        return GestureDetector(
          onDoubleTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ActivityHeatmapPage(activityId: widget.activityId),
              ),
            );
          },
          child: SizedBox(
            height: widget.cellSize * 7 + widget.gap * 6,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final col in cols)
                  Padding(
                    padding: EdgeInsets.only(right: widget.gap),
                    child: Column(
                      children: [
                        for (var r = 0; r < 7; r++)
                          Builder(
                            builder: (ctx) {
                              final s = r < col.length ? col[r] : null;
                              final v = s?.minutes ?? 0;
                              final t = v / max;
                              final color = Color.lerp(
                                Theme.of(context).colorScheme.surfaceContainerHighest,
                                Theme.of(context).colorScheme.primary,
                                t.clamp(0, 1),
                              );
                              return GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTapDown: (details) {
                                  if (s == null) return;
                                  final box = ctx.findRenderObject() as RenderBox?;
                                  if (box == null) return;
                                  final topLeft = box.localToGlobal(Offset.zero);
                                  _showOverlay(context, topLeft, s);
                                },
                                onTapCancel: _hideOverlay,
                                onTapUp: (_) => _hideOverlay(),
                                child: Container(
                                  width: widget.cellSize,
                                  height: widget.cellSize,
                                  margin: EdgeInsets.only(bottom: widget.gap),
                                  decoration: BoxDecoration(
                                    color: color,
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                              );
                            },
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _fmtDate(DateTime d) {
    // format simple JJ/MM
    final dd = d.day.toString().padLeft(2, '0');
    final mm = d.month.toString().padLeft(2, '0');
    return '$dd/$mm';
  }
}
