import 'package:flutter/material.dart';
import 'database_service.dart';

class HourlyBucket {
  final int hour;    // 0..23
  final int minutes; // minutes passées dans l’heure
  const HourlyBucket({required this.hour, required this.minutes});
}

class DailyStat {
  final DateTime day; // minuit du jour
  final int minutes;
  const DailyStat({required this.day, required this.minutes});
}

class StatsService {
  final DatabaseService db;
  StatsService(this.db);

  // -------- Totaux simples --------
  int todayTotal(String activityId) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return _sumInRange(activityId, start, end);
  }

  int weekTotal(String activityId) {
    final now = DateTime.now();
    // Lundi 00:00 comme début de semaine
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: (now.weekday - 1)));
    final end = start.add(const Duration(days: 7));
    return _sumInRange(activityId, start, end);
  }

  int monthTotal(String activityId) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    return _sumInRange(activityId, start, end);
  }

  int yearTotal(String activityId) {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year + 1, 1, 1);
    return _sumInRange(activityId, start, end);
  }

  // -------- Répartition horaire du jour --------
  List<HourlyBucket> hourlyToday(String activityId) {
    final now = DateTime.now();
    final startDay = DateTime(now.year, now.month, now.day);
    final endDay = startDay.add(const Duration(days: 1));

    final buckets = List<int>.filled(24, 0);
    for (final s in db.getSessionsByActivity(activityId)) {
      final sStart = s.startAt.isBefore(startDay) ? startDay : s.startAt;
      final sEnd = (s.endAt ?? now).isAfter(endDay) ? endDay : (s.endAt ?? now);
      if (!sEnd.isAfter(sStart)) continue;

      // Soustraire les pauses
      var ranges = <DateTimeRange>[DateTimeRange(start: sStart, end: sEnd)];
      for (final p in db.getPausesBySession(s.id)) {
        final pStart = p.startAt;
        final pEnd = p.endAt ?? now;
        ranges = _subtractRange(ranges, DateTimeRange(start: pStart, end: pEnd));
      }

      for (final r in ranges) {
        // Réparti par heure (approx au minute près)
        DateTime cursor = r.start;
        while (cursor.isBefore(r.end)) {
          final hourEnd = DateTime(cursor.year, cursor.month, cursor.day, cursor.hour + 1);
          final sliceEnd = r.end.isBefore(hourEnd) ? r.end : hourEnd;
          final minutes = sliceEnd.difference(cursor).inMinutes;
          if (minutes > 0) {
            buckets[cursor.hour] += minutes;
          }
          cursor = sliceEnd;
        }
      }
    }

    return List<HourlyBucket>.generate(
      24,
          (h) => HourlyBucket(hour: h, minutes: buckets[h]),
    );
  }

  // -------- 7 derniers jours --------
  List<DailyStat> last7Days(String activityId) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return List<DailyStat>.generate(7, (i) {
      final day = today.subtract(Duration(days: 6 - i));
      final next = day.add(const Duration(days: 1));
      final m = _sumInRange(activityId, day, next);
      return DailyStat(day: day, minutes: m);
    });
  }

  // -------- Utils --------
  int _sumInRange(String activityId, DateTime start, DateTime end) {
    var total = 0;
    for (final s in db.getSessionsByActivity(activityId)) {
      final sStart = s.startAt;
      final sEnd = s.endAt ?? DateTime.now();
      if (!sEnd.isAfter(start) || !end.isAfter(sStart)) continue;

      var ranges = <DateTimeRange>[
        DateTimeRange(
          start: sStart.isBefore(start) ? start : sStart,
          end: sEnd.isAfter(end) ? end : sEnd,
        )
      ];

      for (final p in db.getPausesBySession(s.id)) {
        final pStart = p.startAt;
        final pEnd = p.endAt ?? DateTime.now();
        ranges = _subtractRange(ranges, DateTimeRange(start: pStart, end: pEnd));
      }

      for (final r in ranges) {
        final minutes = r.end.difference(r.start).inMinutes;
        if (minutes > 0) total += minutes;
      }
    }
    return total;
  }

  /// Soustrait une plage [cut] à une liste de plages [src] (opération de découpe).
  List<DateTimeRange> _subtractRange(
      List<DateTimeRange> src, DateTimeRange cut) {
    final out = <DateTimeRange>[];
    for (final r in src) {
      if (!r.end.isAfter(cut.start) || !cut.end.isAfter(r.start)) {
        out.add(r); // pas d'intersection
        continue;
      }
      // partie gauche
      if (cut.start.isAfter(r.start)) {
        out.add(DateTimeRange(start: r.start, end: cut.start));
      }
      // partie droite
      if (r.end.isAfter(cut.end)) {
        out.add(DateTimeRange(start: cut.end, end: r.end));
      }
    }
    return out;
  }
}
