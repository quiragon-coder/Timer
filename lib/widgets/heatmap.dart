import 'package:flutter/material.dart';
import '../utils/color_compat.dart';

/// Heatmap façon "GitHub contributions".
/// - [data] : Map<jour, minutes>
/// - [baseColor] : couleur de base (l’intensité est gérée via alpha)
/// - [onDayTap] : callback (jour, minutes)
class Heatmap extends StatelessWidget {
  final Map<DateTime, int> data;
  final Color baseColor;
  final void Function(DateTime day, int minutes)? onDayTap;

  const Heatmap({
    super.key,
    required this.data,
    required this.baseColor,
    this.onDayTap,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const SizedBox(height: 80);
    }

    // Normalise (dates "dateOnly")
    final norm = <DateTime, int>{};
    for (final e in data.entries) {
      final d = DateUtils.dateOnly(e.key);
      norm[d] = (norm[d] ?? 0) + e.value;
    }

    final dates = norm.keys.toList()..sort();
    final minDate = dates.first;
    final maxDate = dates.last;

    // Aligne sur semaines (lundi..dimanche)
    DateTime start = minDate.subtract(Duration(days: (minDate.weekday - 1)));
    DateTime end = maxDate.add(Duration(days: (7 - maxDate.weekday)));

    final weeks = <List<DateTime>>[];
    var cursor = start;
    while (!cursor.isAfter(end)) {
      final week = <DateTime>[];
      for (int i = 0; i < 7; i++) {
        week.add(cursor.add(Duration(days: i)));
      }
      weeks.add(week);
      cursor = cursor.add(const Duration(days: 7));
    }

    final maxVal = (norm.values.isEmpty ? 0 : norm.values.reduce((a, b) => a > b ? a : b)).clamp(0, 999999);
    double levelFor(int minutes) {
      if (minutes <= 0 || maxVal == 0) return 0.0;
      final ratio = minutes / maxVal;
      // paliers 0, .2, .4, .6, .8
      if (ratio < 0.2) return 0.2;
      if (ratio < 0.4) return 0.4;
      if (ratio < 0.6) return 0.6;
      if (ratio < 0.8) return 0.8;
      return 1.0;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: weeks.map((week) {
          return Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Column(
              children: week.map((day) {
                final minutes = norm[day] ?? 0;
                final alpha = levelFor(minutes);
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: GestureDetector(
                    onTap: onDayTap == null ? null : () => onDayTap!(day, minutes),
                    child: Container(
                      width: 12,
                      height: 12,
                      decoration: BoxDecoration(
                        color: alpha == 0 ? baseColor.withAlphaCompat(0) : baseColor.withAlphaCompat(alpha),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          );
        }).toList(),
      ),
    );
  }
}
