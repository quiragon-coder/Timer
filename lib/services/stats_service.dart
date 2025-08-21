import 'package:flutter/material.dart';

import './database_service.dart';
import '../models/session.dart';
import '../models/pause.dart';
import '../models/stats.dart';

/// Service de calcul des statistiques à partir du DatabaseService.
/// S’appuie sur:
///  - db.listSessionsByActivity(activityId)
///  - db.listPausesBySession(sessionId)
class StatsService {
  final DatabaseService db;
  StatsService(this.db);

  /// Minutes effectives dans [rangeStart, rangeEnd]
  int _effectiveMinutesInRange({
    required DateTime sessionStart,
    required DateTime? sessionEnd,
    required List<Pause> pauses,
    required DateTime rangeStart,
    required DateTime rangeEnd,
  }) {
    final end = sessionEnd ?? DateTime.now();
    // Intersection session/range
    final s = _max(sessionStart, rangeStart);
    final e = _min(end, rangeEnd);
    if (!e.isAfter(s)) return 0;

    int secs = e.difference(s).inSeconds;
    // Soustraire pauses
    for (final p in pauses) {
      final ps = _max(p.startAt, s);
      final pe = _min(p.endAt ?? DateTime.now(), e);
      if (pe.isAfter(ps)) {
        secs -= pe.difference(ps).inSeconds;
      }
    }
    return secs > 0 ? (secs / 60).floor() : 0;
  }

  /// Minutes pour une journée
  int _minutesForDay(String activityId, DateTime day) {
    final from = DateTime(day.year, day.month, day.day);
    final to = from.add(const Duration(days: 1));

    final sessions = db.listSessionsByActivity(activityId);
    int total = 0;

    // Précharger pauses par session
    final Map<String, List<Pause>> pausesBySession = {};
    for (final s in sessions) {
      pausesBySession[s.id] = db.listPausesBySession(s.id);
    }

    for (final s in sessions) {
      final pauses = pausesBySession[s.id] ?? const <Pause>[];
      total += _effectiveMinutesInRange(
        sessionStart: s.startAt,
        sessionEnd: s.endAt,
        pauses: pauses,
        rangeStart: from,
        rangeEnd: to,
      );
    }
    return total;
  }

  Future<int> minutesToday(String activityId) async {
    final now = DateTime.now();
    return _minutesForDay(activityId, now);
  }

  Future<int> minutesThisWeek(String activityId) async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: (now.weekday - 1) % 7));
    final start = DateTime(monday.year, monday.month, monday.day);
    final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    int total = 0;

    DateTime d = start;
    while (d.isBefore(end)) {
      total += _minutesForDay(activityId, d);
      d = d.add(const Duration(days: 1));
    }
    return total;
  }

  Future<int> minutesThisMonth(String activityId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = DateTime(now.year, now.month + 1, 1);
    int total = 0;
    DateTime d = start;
    while (d.isBefore(end)) {
      total += _minutesForDay(activityId, d);
      d = d.add(const Duration(days: 1));
    }
    return total;
  }

  Future<int> minutesThisYear(String activityId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year + 1, 1, 1);
    int total = 0;
    DateTime d = start;
    while (d.isBefore(end)) {
      total += _minutesForDay(activityId, d);
      d = d.add(const Duration(days: 1));
    }
    return total;
  }

  /// N derniers jours (incluant aujourd’hui)
  Future<List<DailyStat>> lastNDays(String activityId, {required int n}) async {
    assert(n > 0);
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day)
        .subtract(Duration(days: n - 1));

    final List<DailyStat> out = [];
    DateTime d = start;
    while (!d.isAfter(today)) {
      out.add(DailyStat(date: DateTime(d.year, d.month, d.day), minutes: _minutesForDay(activityId, d)));
      d = d.add(const Duration(days: 1));
    }
    return out;
  }

  /// Buckets horaires de 0..23 pour aujourd’hui
  Future<List<HourlyBucket>> hourlyToday(String activityId) async {
    final today = DateTime.now();
    final dayStart = DateTime(today.year, today.month, today.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final sessions = db.listSessionsByActivity(activityId);
    final Map<String, List<Pause>> pausesBySession = {};
    for (final s in sessions) {
      pausesBySession[s.id] = db.listPausesBySession(s.id);
    }

    final buckets = List<HourlyBucket>.generate(24, (i) => HourlyBucket(hour: i, minutes: 0));

    for (final s in sessions) {
      final sStart = _max(s.startAt, dayStart);
      final sEnd = _min(s.endAt ?? DateTime.now(), dayEnd);
      if (!sEnd.isAfter(sStart)) continue;

      // découpe par heure
      DateTime cursor = sStart;
      while (cursor.isBefore(sEnd)) {
        final hourStart = DateTime(cursor.year, cursor.month, cursor.day, cursor.hour);
        final hourEnd = hourStart.add(const Duration(hours: 1));
        final intervalEnd = _min(hourEnd, sEnd);

        int mins = _effectiveMinutesInRange(
          sessionStart: s.startAt,
          sessionEnd: s.endAt,
          pauses: pausesBySession[s.id] ?? const <Pause>[],
          rangeStart: cursor,
          rangeEnd: intervalEnd,
        );
        final idx = hourStart.hour;
        buckets[idx] = buckets[idx].copyWith(minutes: buckets[idx].minutes + mins);

        cursor = intervalEnd;
      }
    }

    return buckets;
  }

  DateTime _max(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
  DateTime _min(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
}
