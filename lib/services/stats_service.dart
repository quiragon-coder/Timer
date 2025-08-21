import 'package:flutter/material.dart';
import '../models/session.dart';
import '../models/pause.dart';
import 'database_service.dart';

class StatsService {
  final DatabaseService db;
  StatsService(this.db);

  // ---------- Minutes agrégées ----------
  int minutesOnDay(String activityId, DateTime day) {
    return db.effectiveMinutesOnDay(activityId, DateUtils.dateOnly(day));
  }

  int minutesToday(String activityId) => minutesOnDay(activityId, DateTime.now());

  int minutesThisWeek(String activityId) {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    var total = 0;
    for (int i = 0; i < 7; i++) {
      total += minutesOnDay(activityId, monday.add(Duration(days: i)));
    }
    return total;
  }

  int minutesThisMonth(String activityId) {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final next = (now.month == 12) ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
    var total = 0;
    for (DateTime d = start; d.isBefore(next); d = d.add(const Duration(days: 1))) {
      total += minutesOnDay(activityId, d);
    }
    return total;
  }

  int minutesThisYear(String activityId) {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final next = DateTime(now.year + 1, 1, 1);
    var total = 0;
    for (DateTime d = start; d.isBefore(next); d = d.add(const Duration(days: 1))) {
      total += minutesOnDay(activityId, d);
    }
    return total;
  }

  /// 7 derniers jours (du plus ancien au plus récent)
  List<_Daily> lastNDays(String activityId, int n) {
    final today = DateUtils.dateOnly(DateTime.now());
    final start = today.subtract(Duration(days: n - 1));
    final out = <_Daily>[];
    for (int i = 0; i < n; i++) {
      final day = DateUtils.dateOnly(start.add(Duration(days: i)));
      out.add(_Daily(day, minutesOnDay(activityId, day)));
    }
    return out;
  }

  // ---------- Buckets horaires (aujourd’hui) ----------
  /// Renvoie un tableau de 24 cases (minutes par heure aujourd’hui).
  List<int> hourlyToday(String activityId) {
    final List<int> buckets = List<int>.filled(24, 0);
    final today = DateUtils.dateOnly(DateTime.now());
    final endOfDay = today.add(const Duration(days: 1));

    // Sessions recoupant aujourd’hui
    final sessions = db.listSessionsByActivityModel(activityId).where((s) {
      final end = s.endAt ?? DateTime.now();
      return s.startAt.isBefore(endOfDay) && end.isAfter(today);
    });

    for (final s in sessions) {
      final start = s.startAt.isAfter(today) ? s.startAt : today;
      final end = (s.endAt ?? DateTime.now()).isBefore(endOfDay) ? (s.endAt ?? DateTime.now()) : endOfDay;

      final pauses = db.listPausesBySessionModel(activityId, s.id);
      _accumulateBuckets(buckets, start, end, pauses);
    }

    return buckets;
  }

  // ---------- Helpers ----------
  void _accumulateBuckets(List<int> buckets, DateTime start, DateTime end, List<Pause> pauses) {
    if (!end.isAfter(start)) return;

    // On parcours heure par heure dans l’intervalle
    DateTime cursor = start;
    while (cursor.isBefore(end)) {
      final hourEnd = DateTime(cursor.year, cursor.month, cursor.day, cursor.hour).add(const Duration(hours: 1));
      final sliceEnd = hourEnd.isBefore(end) ? hourEnd : end;

      // durée nette entre cursor et sliceEnd
      final net = _effectiveBetween(cursor, sliceEnd, pauses).inMinutes;
      if (net > 0) buckets[cursor.hour] += net;

      cursor = sliceEnd;
    }
  }

  Duration _effectiveBetween(DateTime a, DateTime b, List<Pause> pauses) {
    int sec = b.difference(a).inSeconds;
    for (final p in pauses) {
      final ps = p.startAt;
      final pe = p.endAt ?? b;
      final overlap = _overlapSec(a, b, ps, pe);
      sec -= overlap;
    }
    if (sec < 0) sec = 0;
    return Duration(seconds: sec);
  }

  int _overlapSec(DateTime a1, DateTime a2, DateTime b1, DateTime b2) {
    final s = a1.isAfter(b1) ? a1 : b1;
    final e = a2.isBefore(b2) ? a2 : b2;
    final d = e.difference(s).inSeconds;
    return d > 0 ? d : 0;
  }
}

class _Daily {
  final DateTime day;
  final int minutes;
  _Daily(this.day, this.minutes);
}
