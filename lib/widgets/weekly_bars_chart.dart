import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/stats.dart';

class WeeklyBarsChart extends StatelessWidget {
  final List<DailyStat> stats; // 7 elements
  const WeeklyBarsChart({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final maxVal = (stats.map((d) => d.minutes).fold<int>(0, (a, b) => a > b ? a : b)).clamp(1, 9999);
    final df = DateFormat.E(Localizations.localeOf(context).languageCode);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
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
                final i = val.toInt();
                if (i < 0 || i >= stats.length) return const SizedBox.shrink();
                final label = df.format(stats[i].day);
                return Text(label, style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < stats.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: stats[i].minutes.toDouble(),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
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
