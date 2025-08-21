import 'package:flutter/material.dart';
import '../utils/color_compat.dart';

class Heatmap extends StatelessWidget {
  final Map<DateTime, int> data;
  final Color baseColor;
  final void Function(DateTime day, int minutes)? onDayTap;

  /// Taille d’une tuile (par défaut 12).
  final double tileSize;

  /// Espacement vertical entre tuiles (par défaut 2).
  final double gutter;

  /// Afficher des labels “Lun / Mer / Ven” sur la gauche.
  final bool showWeekdayLabels;

  const Heatmap({
    super.key,
    required this.data,
    required this.baseColor,
    this.onDayTap,
    this.tileSize = 12,
    this.gutter = 2,
    this.showWeekdayLabels = false,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return _emptyBox(context);
    }

    // Normalisation dateOnly
    final norm = <DateTime, int>{};
    for (final e in data.entries) {
      final d = DateUtils.dateOnly(e.key);
      norm[d] = (norm[d] ?? 0) + e.value;
    }

    final dates = norm.keys.toList()..sort();
    if (dates.isEmpty) return _emptyBox(context);

    final minDate = dates.first;
    final maxDate = dates.last;

    // Aligner sur semaines (lun..dim)
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

    final vals = norm.values.toList();
    final maxVal = vals.isEmpty ? 0 : vals.reduce((a, b) => a > b ? a : b);
    final allZero = maxVal == 0;

    double levelFor(int minutes) {
      if (minutes <= 0 || maxVal == 0) return 0.0;
      final ratio = minutes / maxVal;
      if (ratio < 0.2) return 0.2;
      if (ratio < 0.4) return 0.4;
      if (ratio < 0.6) return 0.6;
      if (ratio < 0.8) return 0.8;
      return 1.0;
    }

    final grid = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: weeks.map((week) {
        return Padding(
          padding: EdgeInsets.only(right: gutter * 2),
          child: Column(
            children: week.map((day) {
              final minutes = norm[day] ?? 0;
              final alpha = levelFor(minutes);
              final color = alpha == 0
                  ? baseColor.withAlphaCompat(.06) // visible même à 0
                  : baseColor.withAlphaCompat(alpha);
              return Padding(
                padding: EdgeInsets.symmetric(vertical: gutter),
                child: GestureDetector(
                  onTap: onDayTap == null ? null : () => onDayTap!(day, minutes),
                  child: Container(
                    width: tileSize,
                    height: tileSize,
                    decoration: BoxDecoration(
                      color: color,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        );
      }).toList(),
    );

    if (!showWeekdayLabels) {
      return SingleChildScrollView(scrollDirection: Axis.horizontal, child: grid);
    }

    // Colonne de labels pour Lun / Mer / Ven (index 0,2,4)
    final labels = ['Lun', '', 'Mer', '', 'Ven', '', '']; // 7 lignes
    final labelsColumn = Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(7, (i) {
        return Padding(
          padding: EdgeInsets.symmetric(vertical: gutter),
          child: SizedBox(
            height: tileSize,
            child: Text(
              labels[i],
              style: Theme.of(context).textTheme.labelSmall,
            ),
          ),
        );
      }),
    );

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 28, child: labelsColumn),
          const SizedBox(width: 6),
          grid,
        ],
      ),
    );
  }

  Widget _emptyBox(BuildContext context) {
    return Container(
      height: tileSize * 7 + gutter * 14,
      alignment: Alignment.centerLeft,
      child: Text(
        "Aucune donnée",
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}
