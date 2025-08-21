import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/stats.dart';
import '../providers_stats.dart';

class MiniHeatmap extends ConsumerWidget {
  final String activityId;
  final int days;              // ex: 7, 30, 365
  final void Function()? onOpenDetails; // double tap

  const MiniHeatmap({
    super.key,
    required this.activityId,
    this.days = 7,
    this.onOpenDetails,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(lastNDaysProvider(LastNDaysArgs(activityId, days)));

    return async.when(
      loading: () => const SizedBox(height: 56, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (_, __) => const SizedBox(height: 56, child: Center(child: Text('Erreur'))),
      data: (stats) {
        if (stats.isEmpty) {
          return const SizedBox(height: 56, child: Center(child: Text('Aucune donnée')));
        }

        // Normalise en semaines x 7 (petite grille compacte)
        final cols = (days / 7).ceil();
        final items = stats; // List<DailyStat>, chaque DailyStat a .day (DateTime) et .minutes (int)

        final maxMinutes = (items.map((e) => e.minutes).fold<int>(0, (a, b) => a > b ? a : b)).clamp(1, 999999);

        return _MiniHeatmapSurface(
          items: items,
          cols: cols,
          maxMinutes: maxMinutes,
          onOpenDetails: onOpenDetails,
        );
      },
    );
  }
}

class _MiniHeatmapSurface extends StatefulWidget {
  final List<DailyStat> items;
  final int cols;
  final int maxMinutes;
  final void Function()? onOpenDetails;

  const _MiniHeatmapSurface({
    required this.items,
    required this.cols,
    required this.maxMinutes,
    this.onOpenDetails,
  });

  @override
  State<_MiniHeatmapSurface> createState() => _MiniHeatmapSurfaceState();
}

class _MiniHeatmapSurfaceState extends State<_MiniHeatmapSurface> {
  DailyStat? _hover; // pour l’overlay sur un tap simple

  @override
  Widget build(BuildContext context) {
    // 7 lignes (lun..dim), N colonnes (semaines)
    final rows = 7;
    final cell = 14.0;
    final gap = 3.0;

    // on construit une table (cols * rows) en commençant par la fin (aujourd'hui)
    final now = DateTime.now();
    Map<DateTime, int> minutesByDay = {
      for (final s in widget.items)
        DateTime(s.day.year, s.day.month, s.day.day): s.minutes,
    };

    List<DateTime> days = [];
    for (int i = widget.cols * 7 - 1; i >= 0; i--) {
      final d = DateTime(now.year, now.month, now.day).subtract(Duration(days: i));
      days.add(d);
    }

    return GestureDetector(
      onDoubleTap: widget.onOpenDetails,
      onTapDown: (details) {
        // détecte la cellule tapée pour afficher un petit overlay (tooltip)
        final box = context.findRenderObject() as RenderBox?;
        if (box == null) return;
        final local = box.globalToLocal(details.globalPosition);

        final totalWidth = widget.cols * cell + (widget.cols - 1) * gap;
        final totalHeight = rows * cell + (rows - 1) * gap;

        if (local.dx < 0 || local.dy < 0 || local.dx > totalWidth || local.dy > totalHeight) {
          setState(() => _hover = null);
          return;
        }

        final col = (local.dx / (cell + gap)).floor();
        final row = (local.dy / (cell + gap)).floor();

        final index = row + col * 7; // jour dans la liste "days"
        if (index >= 0 && index < days.length) {
          final d = days[index];
          final key = DateTime(d.year, d.month, d.day);
          final m = minutesByDay[key] ?? 0;

          setState(() {
            _hover = DailyStat(day: key, minutes: m);
          });
        }
      },
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          SizedBox(
            width: widget.cols * cell + (widget.cols - 1) * gap,
            height: rows * cell + (rows - 1) * gap,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(rows, (r) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: List.generate(widget.cols, (c) {
                    final dayIndex = r + c * 7;
                    if (dayIndex < 0 || dayIndex >= days.length) {
                      return SizedBox(width: cell, height: cell);
                    }
                    final d = days[dayIndex];
                    final key = DateTime(d.year, d.month, d.day);
                    final m = minutesByDay[key] ?? 0;

                    final t = m / (widget.maxMinutes == 0 ? 1 : widget.maxMinutes);
                    final color = Color.lerp(Colors.grey.shade200, Colors.green, t.clamp(0, 1).toDouble())!;

                    return Container(
                      width: cell,
                      height: cell,
                      margin: EdgeInsets.only(
                        right: c == widget.cols - 1 ? 0 : gap,
                        bottom: r == rows - 1 ? 0 : gap,
                      ),
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                        border: Border.all(color: Colors.black12, width: 0.5),
                      ),
                    );
                  }),
                );
              }),
            ),
          ),

          // Petit overlay (tooltip) quand on tape une case
          if (_hover != null)
            Positioned(
              right: 0,
              top: -36,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(8),
                  boxShadow: const [BoxShadow(blurRadius: 8, color: Colors.black26)],
                  border: Border.all(color: Colors.black12),
                ),
                child: Text(
                  "${_hover!.day.day}/${_hover!.day.month} : ${_hover!.minutes} min",
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
