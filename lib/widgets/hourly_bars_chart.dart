import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../models/stats.dart';

/// Chart horaire 0→23 h (typé).
class HourlyBarsChart extends StatelessWidget {
  final List<HourlyBucket> buckets;
  const HourlyBarsChart({super.key, required this.buckets});

  @override
  Widget build(BuildContext context) {
    final byHour = {for (final b in buckets) b.hour: b.minutes};
    final maxVal = (byHour.values.isEmpty ? 0 : byHour.values.reduce((a, b) => a > b ? a : b)).clamp(1, 9999);

    return BarChart(
      BarChartData(
        barTouchData: BarTouchData(enabled: false),
        gridData: FlGridData(show: false),
        borderData: FlBorderData(show: false),
        titlesData: FlTitlesData(
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 3,
              getTitlesWidget: (value, _) => Text(value.toInt().toString(), style: const TextStyle(fontSize: 10)),
            ),
          ),
        ),
        barGroups: List.generate(24, (h) {
          final minutes = (byHour[h] ?? 0).toDouble();
          return BarChartGroupData(
            x: h,
            barsSpace: 2,
            barRods: [
              BarChartRodData(
                  toY: minutes,
                  width: 8,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4))),
            ],
          );
        }),
        maxY: maxVal.toDouble() * 1.2,
      ),
    );
  }
}
