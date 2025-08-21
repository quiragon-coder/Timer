import 'package:flutter/material.dart';

/// Heatmap très simple façon "GitHub contribution"
/// [data]: Map jour -> minutes
/// [baseColor]: couleur des carrés (l’opacité varie avec l’intensité)
/// [onDayTap]: callback quand on tape un carré
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

  int _levelFor(int minutes) {
    if (minutes <= 0) return 0;
    if (minutes < 10) return 1;
    if (minutes < 30) return 2;
    if (minutes < 60) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    // Ordre chronologique par jour
    final days = data.keys.toList()..sort();
    if (days.isEmpty) {
      return const SizedBox(height: 80);
    }

    // grille 7 lignes (lun..dim), colonnes au fil des semaines
    // On part du lundi de la 1ère semaine
    final first = days.first;
    final firstMonday =
    first.subtract(Duration(days: (first.weekday - 1) % 7));
    final last = days.last;
    final weeks =
    (last.difference(firstMonday).inDays / 7).ceil().clamp(1, 54);

    // build datastruct {weekday,row} -> color level
    final Map<int, Map<int, int>> grid = {}; // col -> {row -> level}
    for (final d in days) {
      final col = d.difference(firstMonday).inDays ~/ 7;
      final row = (d.weekday - 1) % 7;
      grid.putIfAbsent(col, () => {});
      grid[col]![row] = _levelFor(data[d] ?? 0);
    }

    return SizedBox(
      height: 7 * 14 + 6 * 3, // 14px cases + 3px gap
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(weeks, (col) {
          return Padding(
            padding: const EdgeInsets.only(right: 3),
            child: Column(
              children: List.generate(7, (row) {
                final level = grid[col]?[row] ?? 0;
                final opacity = [0.10, 0.25, 0.45, 0.65, 0.85][level];
                // retrouver la date correspondante
                final day = firstMonday.add(Duration(days: col * 7 + row));
                return GestureDetector(
                  onTap: onDayTap == null ? null : () => onDayTap!(day, data[day] ?? 0),
                  child: Container(
                    width: 14,
                    height: 14,
                    margin: const EdgeInsets.only(bottom: 3),
                    decoration: BoxDecoration(
                      color: baseColor.withOpacity(opacity),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                );
              }),
            ),
          );
        }),
      ),
    );
  }
}
