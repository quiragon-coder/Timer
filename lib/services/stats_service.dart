import 'dart:math';
import '../models/stats.dart';
import '../models/session.dart';
import '../models/pause.dart';
import 'database_service.dart';

class StatsService {
  final DatabaseService db;
  StatsService(this.db);

  // bornes utiles
  DateTime _d0(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _d1(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  DateTime _weekStart(DateTime d) => _d0(d).subtract(Duration(days: d.weekday - 1));
  DateTime _monthStart(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _yearStart(DateTime d) => DateTime(d.year, 1, 1);

  Future<int> minutesToday(String activityId) async {
    final now = DateTime.now();
    return _minutesRange(activityId, _d0(now), _d1(now));
  }

  Future<int> minutesThisWeek(String activityId) async {
    final now = DateTime.now();
    final from = _weekStart(now);
    return _minutesRange(activityId, _d0(from), _d1(now));
  }

  Future<int> minutesThisMonth(String activityId) async {
    final now = DateTime.now();
    final from = _monthStart(now);
    return _minutesRange(activityId, _d0(from), _d1(now));
  }

  Future<int> minutesThisYear(String activityId) async {
    final now = DateTime.now();
    final from = _yearStart(now);
    return _minutesRange(activityId, _d0(from), _d1(now));
  }

  Future<List<DailyStat>> lastNDays(String activityId, {required int n}) async {
    final today = _d0(DateTime.now());
    final from = today.subtract(Duration(days: n - 1));
    final out = <DailyStat>[];
    for (int i = 0; i < n; i++) {
      final day = from.add(Duration(days: i));
      final m = await _minutesRange(activityId, _d0(day), _d1(day));
      out.add(DailyStat(date: day, minutes: m));
    }
    return out;
  }

  Future<List<HourlyBucket>> hourlyToday(String activityId) async {
    final today = _d0(DateTime.now());
    final tomorrow = today.add(const Duration(days: 1));

    final sessions = db.listSessionsByActivity(activityId).where((s) {
      final end = s.endAt ?? DateTime.now();
      return s.startAt.isBefore(tomorrow) && end.isAfter(today);
    });

    final buckets = List<int>.filled(24, 0);
    for (final s in sessions) {
      final sFrom = s.startAt.isAfter(today) ? s.startAt : today;
      final sTo = (s.endAt ?? DateTime.now()).isBefore(tomorrow) ? (s.endAt ?? DateTime.now()) : tomorrow;

      final pauses = db.listPausesBySession(s.id);
      _accumulateByHour(buckets, sFrom, sTo, pauses);
    }

    return List.generate(24, (h) => HourlyBucket(hour: h, minutes: buckets[h]));
  }

  Future<Map<DateTime, int>> dailyMinutesRange({
    required String activityId,
    required DateTime from,
    required DateTime to,
  }) async {
    final map = <DateTime, int>{};
    var d = _d0(from);
    final end = _d1(to);
    while (!d.isAfter(end)) {
      map[_d0(d)] = await _minutesRange(activityId, _d0(d), _d1(d));
      d = d.add(const Duration(days: 1));
    }
    return map;
  }

  // ---- helpers ----
  Future<int> _minutesRange(String activityId, DateTime from, DateTime to) async {
    int minutes = 0;

    final sessions = db.listSessionsByActivity(activityId);
    for (final s in sessions) {
      final end = s.endAt ?? DateTime.now();
      if (end.isBefore(from) || s.startAt.isAfter(to)) continue;

      final start = s.startAt.isBefore(from) ? from : s.startAt;
      final finish = end.isAfter(to) ? to : end;

      int sec = finish.difference(start).inSeconds;

      final pauses = db.listPausesBySession(s.id);
      for (final p in pauses) {
        final pEnd = p.endAt ?? finish;
        sec -= _overlapSec(start, finish, p.startAt, pEnd);
      }
      if (sec > 0) minutes += sec ~/ 60;
    }

    return max(0, minutes);
  }

  void _accumulateByHour(List<int> buckets, DateTime from, DateTime to, List<Pause> pauses) {
    DateTime cursor = from;
    while (cursor.isBefore(to)) {
      final hourEnd = DateTime(cursor.year, cursor.month, cursor.day, cursor.hour).add(const Duration(hours: 1));
      final sliceEnd = hourEnd.isBefore(to) ? hourEnd : to;
      int sec = sliceEnd.difference(cursor).inSeconds;

      for (final p in pauses) {
        final pEnd = p.endAt ?? sliceEnd;
        sec -= _overlapSec(cursor, sliceEnd, p.startAt, pEnd);
      }
      if (sec > 0) buckets[cursor.hour] += sec ~/ 60;

      cursor = sliceEnd;
    }
  }

  int _overlapSec(DateTime a1, DateTime a2, DateTime b1, DateTime b2) {
    final s = a1.isAfter(b1) ? a1 : b1;
    final e = a2.isBefore(b2) ? a2 : b2;
    final d = e.difference(s).inSeconds;
    return d > 0 ? d : 0;
  }
}
