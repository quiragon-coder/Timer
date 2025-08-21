import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';                 // dbProvider
import 'heatmap.dart' as hw;                // widget grille
import '../pages/heatmap_page.dart' as hp;  // page détaillée "Heatmap" (data + baseColor)

class MiniHeatmap extends ConsumerWidget {
  final String activityId;
  final int days; // ex: 28
  final Color baseColor;

  const MiniHeatmap({
    super.key,
    required this.activityId,
    required this.days,
    required this.baseColor,
  });

  Map<DateTime, int> _buildMap(WidgetRef ref) {
    final db = ref.read(dbProvider);
    final today = DateUtils.dateOnly(DateTime.now());
    final start = today.subtract(Duration(days: days - 1));
    final map = <DateTime, int>{};
    for (int i = 0; i < days; i++) {
      final day = DateUtils.dateOnly(start.add(Duration(days: i)));
      map[day] = db.effectiveMinutesOnDay(activityId, day);
    }
    return map;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final goal = db.activities
        .firstWhere((a) => a.id == activityId, orElse: () => db.activities.first)
        .dailyGoalMinutes ?? 0;

    final map = _buildMap(ref);

    void showPopover(DateTime day, int minutes) {
      final txt = goal > 0
          ? '${minutes} min • ${(minutes - goal >= 0 ? '▲' : '▼')}${(minutes - goal).abs()} vs obj'
          : '${minutes} min';
      final entry = OverlayEntry(
        builder: (_) => Positioned.fill(
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
        ),
      );
      Overlay.of(context).insert(entry);
      Future.delayed(const Duration(seconds: 2), entry.remove);
    }

    // Hauteur fixe pour stabilité, largeur forcée à 100%
    return SizedBox(
      width: double.infinity,
      height: 14 * 7 + 2 * 14 + 8,
      child: GestureDetector(
        onDoubleTap: () {
          Navigator.of(context).push(MaterialPageRoute(
            builder: (_) => hp.Heatmap(
              data: map,
              baseColor: baseColor,
            ),
          ));
        },
        child: hw.Heatmap(
          data: map,
          baseColor: baseColor,
          tileSize: 14,
          gutter: 2,
          showWeekdayLabels: true,
          onDayTap: (day, minutes) => showPopover(day, minutes),
        ),
      ),
    );
  }
}
