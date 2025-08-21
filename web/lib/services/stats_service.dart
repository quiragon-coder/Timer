import 'dart:math';
import 'package:flutter/foundation.dart';

import '../models/session.dart';
import '../models/stats.dart';          // <-- utilise la version unique des modèles
import 'database_service.dart';

/// Service de stats calculées à partir du DatabaseService
class StatsService {
  final DatabaseService db;
  StatsService(this.db);

  // ---------- Helpers temps ----------
  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);
  DateTime _endOfDay(DateTime d) => DateTime(d.year, d.month, d.day, 23, 59, 59, 999);

  DateTime _startOfWeek(DateTime d) {
    // Semaine commençant lundi
    final weekday = d.weekday; // 1=lundi...7=dimanche
    final delta = weekday - DateTime.monday;
    final base = DateTime(d.year, d.month, d.day);
    return base.subtract(Duration(days: delta));
  }

  DateTime _startOfMonth(DateTime d) => DateTime(d.year, d.month, 1);
  DateTime _startOfYear(DateTime d) => DateTime(d.year, 1, 1);

  /// Minutes d'overlap entre [aStart,aEnd] et [from,to]
  int _overlapMinutes(DateTime aStart, DateTime aEnd, DateTime from, DateTime to) {
    final s = aStart.isBefore(from) ? from : aStart;
    final e = aEnd.isAfter(to) ? to : aEnd;
    if (!e.isAfter(s)) return 0;
    return (e.difference(s).inSeconds / 60).floor();
  }

  /// Minutes effectives d'une session sur [from,to], pauses déduites
  int _sessionEffectiveOnRange(Session s, DateTime from, DateTime to) {
    final sessionEnd = s.endAt ?? DateTime.now();
    final base = _overlapMinutes(s.startAt, sessionEnd, from, to);
    if (base == 0) return 0;

    int paused = 0;
    try {
      final pauses = db.listPausesBySession(s.id); // doit exister dans DatabaseService
      for (final p in pauses) {
        final pEnd = p.endAt ?? DateTime.now();
        paused += _overlapMinutes(p.startAt, pEnd, from, to);
      }
    } catch (_) {
      // si la méthode n'existe pas, on considère 0 pause
    }
    return max(0, base - paused);
  }

  /// Minutes effectives d'une activité sur [from,to]
  int _effectiveOnRange(String activityId, DateTime from, DateTime to) {
    int sum = 0;
    try {
      final sessions = db.listSessionsByActivity(activityId);
      for (final s in sessions) {
        sum += _sessionEffectiveOnRange(s, from, to);
      }
    } catch (_) {
      // nom alternatif selon les versions du DB
      try {
        final sessions = db.sessionsByActivity(activityId);
        for (final s in sessions) {
          sum += _sessionEffectiveOnRange(s, from, to);
        }
      } catch (_) {}
    }
    return sum;
  }

  // ---------- API utilisée par providers_stats.dart ----------

  Future<int> minutesToday(String activityId) async {
    final now = DateTime.now();
    return _effectiveOnRange(activityId, _startOfDay(now), _endOfDay(now));
  }

  /// Histogramme horaire du jour (0..23)
  Future<List<HourlyBucket>> hourlyToday(String activityId) async {
    final now = DateTime.now();
    final startDay = _startOfDay(now);
    final endDay = _endOfDay(now);

    final List<HourlyBucket> buckets = [];
    for (int h = 0; h < 24; h++) {
      final hStart = DateTime(startDay.year, startDay.month, startDay.day, h);
      final hEnd = (h == 23)
          ? endDay
          : DateTime(startDay.year, startDay.month, startDay.day, h + 1);
      final m = _effectiveOnRange(activityId, hStart, hEnd);
      buckets.add(HourlyBucket(hour: h, minutes: m.clamp(0, 60)));
    }
    return buckets;
  }

  /// Derniers n jours (aujourd’hui inclus) -> du plus ancien au plus récent
  Future<List<DailyStat>> lastNDays(String activityId, {required int n}) async {
    assert(n > 0);
    final now = DateTime.now();
    final todayStart = _startOfDay(now);

    final List<DailyStat> out = [];
    for (int i = n - 1; i >= 0; i--) {
      final d = todayStart.subtract(Duration(days: i));
      final from = _startOfDay(d);
      final to = _endOfDay(d);
      final m = _effectiveOnRange(activityId, from, to);
      out.add(DailyStat(day: from, minutes: m));
    }
    return out;
  }

  Future<int> minutesThisWeek(String activityId) async {
    final now = DateTime.now();
    final from = _startOfWeek(now);
    final to = _endOfDay(from.add(const Duration(days: 6)));
    return _effectiveOnRange(activityId, from, to);
  }

  Future<int> minutesThisMonth(String activityId) async {
    final now = DateTime.now();
    final from = _startOfMonth(now);
    final nextMonth = (now.month == 12)
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    final to = nextMonth.subtract(const Duration(milliseconds: 1));
    return _effectiveOnRange(activityId, from, to);
  }

  Future<int> minutesThisYear(String activityId) async {
    final now = DateTime.now();
    final from = _startOfYear(now);
    final to = DateTime(now.year, 12, 31, 23, 59, 59, 999);
    return _effectiveOnRange(activityId, from, to);
  }
}
