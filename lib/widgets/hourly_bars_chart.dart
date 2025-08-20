import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/stats.dart';

class HourlyBarsChart extends StatelessWidget {
  final List<HourlyBucket> buckets;
  const HourlyBarsChart({super.key, required this.buckets});

  @override
  Widget build(BuildContext context) {
    final maxVal = (buckets.map((b) => b.minutes).fold<int>(0, (a, b) => a > b ? a : b)).clamp(1, 9999);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 18,
              getTitlesWidget: (val, meta) {
                final h = val.toInt();
                if ({0, 6, 12, 18, 23}.contains(h)) {
                  return Text('$h', style: const TextStyle(fontSize: 10));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        barGroups: [
          for (final b in buckets)
            BarChartGroupData(
              x: b.hour,
              barRods: [
                BarChartRodData(
                  toY: b.minutes.toDouble(),
                  width: 6,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
        ],
        maxY: maxVal.toDouble() * 1.2,
      ),
    );
  }
}
