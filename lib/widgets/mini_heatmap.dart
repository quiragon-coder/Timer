import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';           // dbProvider (pour objectif du jour)
import '../providers_stats.dart';     // lastNDaysProvider
import '../pages/heatmap_page.dart';  // ActivityHeatmapPage
import 'heatmap.dart';

class MiniHeatmap extends ConsumerStatefulWidget {
  final String activityId;
  final int days; // ex: 28
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
  DateTime? _lastTapDay;
  OverlayEntry? _overlay;

  @override
  void dispose() {
    _overlay?.remove();
    super.dispose();
  }

  void _showPopover(BuildContext context, DateTime day, int minutes, int goal) {
    _overlay?.remove();

    final txt = goal > 0
        ? '${minutes} min • ${(minutes - goal >= 0 ? '▲' : '▼')}${(minutes - goal).abs()} vs obj'
        : '${minutes} min';

    _overlay = OverlayEntry(
      builder: (_) {
        return Positioned.fill(
          child: IgnorePointer(
            child: Center(
              child: Material(
                elevation: 12,
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  child: Text(
                    '${day.toLocal().toString().split(' ').first}\n$txt',
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlay!);
    Future.delayed(const Duration(seconds: 2), () {
      _overlay?.remove();
      _overlay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final statsAsync = ref.watch(
      lastNDaysProvider(LastNDaysArgs(activityId: widget.activityId, n: widget.days)),
    );

    return statsAsync.when(
      loading: () => const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (e, _) => SizedBox(height: 60, child: Center(child: Text('Erreur: $e'))),
      data: (list) {
        // DailyStat -> Map<DateOnly, minutes>
        final map = <DateTime, int>{};
        for (final d in list) {
          final k = DateUtils.dateOnly(d.date);
          map[k] = (map[k] ?? 0) + d.minutes;
        }

        // Objectif du jour
        final db = ref.read(dbProvider);
        final act = db.activities.firstWhere((a) => a.id == widget.activityId, orElse: () => db.activities.first);
        final goal = act.dailyGoalMinutes ?? 0;

        return GestureDetector(
          onTapDown: (_) {
            // Consomme l'événement pour rendre le double-tap plus fiable
          },
          onTap: () {
            // Tap = popover sur le dernier jour tapé ou le plus récent
            final day = _lastTapDay ?? (map.isEmpty
                ? DateUtils.dateOnly(DateTime.now())
                : (map.keys.toList()..sort()).last);
            final minutes = map[day] ?? 0;
            _showPopover(context, day, minutes, goal);
          },
          onDoubleTap: () {
            // Double-tap = ouvre la Heatmap détaillée (365 jours)
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
            onDayTap: (day, minutes) {
              _lastTapDay = day;
              _showPopover(context, day, minutes, goal);
            },
          ),
        );
      },
    );
  }
}
