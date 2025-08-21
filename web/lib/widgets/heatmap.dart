import "package:flutter/material.dart";

class Heatmap extends StatelessWidget {
  final Map<DateTime, int> data;   // day -> minutes
  final Color baseColor;
  final int maxMinutes;            // minutes for full intensity
  final EdgeInsets padding;

  const Heatmap({
    super.key,
    required this.data,
    required this.baseColor,
    this.maxMinutes = 60,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text("No data"));
    }

    final dates = data.keys.toList()..sort();
    final first = _mondayOfWeek(DateTime(dates.first.year, dates.first.month, dates.first.day));
    final last  = _sundayOfWeek(DateTime(dates.last.year,  dates.last.month,  dates.last.day));

    final normalized = <DateTime, int>{};
    for (final e in data.entries) {
      final d = DateTime(e.key.year, e.key.month, e.key.day);
      normalized[d] = e.value;
    }

    final daysCount = last.difference(first).inDays + 1;
    final weeks = (daysCount / 7).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 600.0;
        final colSpacing = 2.0;
        final rowSpacing = 2.0;
        final sidePadding = padding.left + padding.right;
        final monthLabelHeight = 16.0;

        final totalColSpacing = colSpacing * (weeks - 1);
        final cellSize = ((maxWidth - sidePadding - totalColSpacing) / weeks).clamp(8.0, 16.0);

        Color levelColor(double t) => Color.lerp(Colors.transparent, baseColor, t) ?? baseColor;

        final cells = <Widget>[];
        final monthLabels = <int, String>{};
        DateTime iter = first;
        int prevMonth = -1;

        for (int w = 0; w < weeks; w++) {
          final monthAtCol = iter.month;
          if (monthAtCol != prevMonth) {
            monthLabels[w] = _monthShort(monthAtCol);
            prevMonth = monthAtCol;
          }

          final columnCells = <Widget>[];
          for (int weekday = 0; weekday < 7; weekday++) {
            final day = iter.add(Duration(days: weekday));
            if (day.isAfter(last)) break;

            final key = DateTime(day.year, day.month, day.day);
            final minutes = normalized[key] ?? 0;

            double t;
            if (maxMinutes <= 0) {
              t = minutes > 0 ? 1.0 : 0.0;
            } else {
              t = (minutes / maxMinutes).clamp(0.0, 1.0);
            }
            final color = levelColor(t);

            columnCells.add(Container(
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.black.withOpacity(0.04), width: 0.5),
              ),
            ));
          }

          cells.add(Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: monthLabelHeight),
              ..._withRowSpacing(columnCells, rowSpacing),
            ],
          ));

          if (w < weeks - 1) {
            cells.add(SizedBox(width: colSpacing));
          }
          iter = iter.add(const Duration(days: 7));
        }

        final monthRow = <Widget>[];
        for (int w = 0; w < weeks; w++) {
          final label = monthLabels[w] ?? "";
          monthRow.add(SizedBox(
            width: cellSize,
            height: monthLabelHeight,
            child: Center(child: Text(label, style: const TextStyle(fontSize: 10))),
          ));
          if (w < weeks - 1) monthRow.add(SizedBox(width: colSpacing));
        }

        final grid = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: monthRow),
            Row(children: cells),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text("Less", style: TextStyle(fontSize: 10)),
                const SizedBox(width: 6),
                _legendBox(Color.lerp(Colors.transparent, baseColor, 0.2) ?? baseColor, cellSize),
                const SizedBox(width: 2),
                _legendBox(Color.lerp(Colors.transparent, baseColor, 0.4) ?? baseColor, cellSize),
                const SizedBox(width: 2),
                _legendBox(Color.lerp(Colors.transparent, baseColor, 0.6) ?? baseColor, cellSize),
                const SizedBox(width: 2),
                _legendBox(Color.lerp(Colors.transparent, baseColor, 0.8) ?? baseColor, cellSize),
                const SizedBox(width: 6),
                const Text("More", style: TextStyle(fontSize: 10)),
              ],
            ),
          ],
        );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: padding,
          child: grid,
        );
      },
    );
  }

  static List<Widget> _withRowSpacing(List<Widget> items, double space) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i < items.length - 1) out.add(SizedBox(height: space));
    }
    return out;
  }

  static String _monthShort(int m) {
    const names = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return (m >= 1 && m <= 12) ? names[m] : "";
  }

  static DateTime _mondayOfWeek(DateTime d) {
    final weekday = d.weekday; // 1=Mon..7=Sun
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: weekday - 1));
  }

  static DateTime _sundayOfWeek(DateTime d) {
    final weekday = d.weekday;
    return DateTime(d.year, d.month, d.day).add(Duration(days: 7 - weekday));
  }

  static Widget _legendBox(Color c, double s) {
    return Container(
      width: s, height: s,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.black12, width: .5),
      ),
    );
  }
}
