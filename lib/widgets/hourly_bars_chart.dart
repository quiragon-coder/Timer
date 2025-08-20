import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

/// Chart horaire 0→23 h.
/// On accepte une liste de *buckets* dynamiques avec champs `hour` et `minutes`.
/// (Ça évite ton erreur “HourlyBucket n’est pas un type” si la classe n’est
/// pas visible dans ce fichier.)
class HourlyBarsChart extends StatelessWidget {
  final List<dynamic> buckets; // chaque élément doit exposer .hour et .minutes
  const HourlyBarsChart({super.key, required this.buckets});

  int _minutesAt(int h) {
    for (final b in buckets) {
      final bh = (b as dynamic).hour as int?;
      if (bh == h) {
        final m = (b as dynamic).minutes as int?;
        return m ?? 0;
      }
    }
    return 0;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SizedBox(
      height: 220,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8.0),
        child: BarChart(
          BarChartData(
            gridData: FlGridData(show: true, horizontalInterval: 10),
            borderData: FlBorderData(show: false),
            alignment: BarChartAlignment.spaceBetween,
            titlesData: FlTitlesData(
              topTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              rightTitles: const AxisTitles(
                sideTitles: SideTitles(showTitles: false),
              ),
              leftTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  reservedSize: 32,
                  getTitlesWidget: (value, _) => Text(
                    value.toInt().toString(),
                    style: theme.textTheme.bodySmall,
                  ),
                ),
              ),
              bottomTitles: AxisTitles(
                sideTitles: SideTitles(
                  showTitles: true,
                  getTitlesWidget: (value, _) {
                    final v = value.toInt();
                    if (v == 0 || v == 6 || v == 12 || v == 18 || v == 23) {
                      return Padding(
                        padding: const EdgeInsets.only(top: 4.0),
                        child: Text('$v', style: theme.textTheme.bodySmall),
                      );
                    }
                    return const SizedBox.shrink();
                  },
                ),
              ),
            ),
            barGroups: List.generate(24, (h) {
              final minutes = _minutesAt(h).toDouble();
              return BarChartGroupData(
                x: h,
                barRods: [
                  BarChartRodData(
                    toY: minutes,
                    width: 8,
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ],
              );
            }),
          ),
        ),
      ),
    );
  }
}
