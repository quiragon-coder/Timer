import 'dart:math';
import '../models/stats.dart';
import '../models/session.dart';
import '../models/pause.dart';
import 'database_service.dart';

class StatsService {
  final DatabaseService db;
  StatsService(this.db);

  // Minutes de s utiles (sans les pauses) dans [from;to)
  int _effectiveMinutes(Session s, List<Pause> pauses, DateTime from, DateTime to) {
    final sStart = s.startAt;
    final sEnd = s.endAt ?? DateTime.now();
    final start = sStart.isAfter(from) ? sStart : from;
    final end = sEnd.isBefore(to) ? sEnd : to;
    if (!end.isAfter(start)) return 0;

    var effective = end.difference(start).inMinutes;

    // retranche le temps en pause qui intersecte
    for (final p in pauses.where((p) => p.sessionId == s.id)) {
      final pStart = p.startAt;
      final pEnd = p.endAt ?? DateTime.now();
      final ps = pStart.isAfter(start) ? pStart : start;
      final pe = pEnd.isBefore(end) ? pEnd : end;
      if (pe.isAfter(ps)) {
        effective -= pe.difference(ps).inMinutes;
      }
    }
    return max(0, effective);
  }

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) => _startOfDay(d).add(const Duration(days: 1));

  Future<int> minutesForActivityOnDay(String activityId, DateTime day) async {
    final sessions = await db.getSessionsByActivity(activityId);
    final pauses = <Pause>[];
    for (final s in sessions) {
      pauses.addAll(await db.getPausesBySession(s.id));
    }
    final from = _startOfDay(day);
    final to = _endOfDay(day);

    var total = 0;
    for (final s in sessions) {
      total += _effectiveMinutes(s, pauses, from, to);
    }
    return total;
  }

  Future<List<DailyStat>> last7DaysStats(String activityId) async {
    final List<DailyStat> out = [];
    for (int i = 6; i >= 0; i--) {
      final day = DateTime.now().subtract(Duration(days: i));
      final minutes = await minutesForActivityOnDay(activityId, day);
      out.add(DailyStat(day: DateTime(day.year, day.month, day.day), minutes: minutes));
    }
    return out;
  }

  Future<List<HourlyBucket>> hourlyDistribution(String activityId, DateTime day) async {
    final sessions = await db.getSessionsByActivity(activityId);
    final pauses = <Pause>[];
    for (final s in sessions) {
      pauses.addAll(await db.getPausesBySession(s.id));
    }

    final buckets = List.generate(24, (h) => HourlyBucket(hour: h, minutes: 0));
    for (int h = 0; h < 24; h++) {
      final from = DateTime(day.year, day.month, day.day, h);
      final to = from.add(const Duration(hours: 1));
      var mins = 0;
      for (final s in sessions) {
        mins += _effectiveMinutes(s, pauses, from, to);
      }
      buckets[h] = buckets[h].copyWith(minutes: mins);
    }
    return buckets;
  }
}
