import 'package:flutter/material.dart';
import '../models/stats.dart';
import 'database_service.dart';

typedef NowFn = DateTime Function();

class StatsService {
  final DatabaseService db;
  final NowFn now;
  StatsService(this.db, {this.now = DateTime.now});

  Future<int> minutesToday(String activityId) async {
    final t = now();
    final day = DateTime(t.year, t.month, t.day);
    return db.effectiveMinutesOnDay(activityId, day);
  }

  Future<int> minutesThisWeek(String activityId) async {
    final t = now();
    final today = DateTime(t.year, t.month, t.day);
    final startOfWeek = today.subtract(Duration(days: today.weekday - 1)); // Lundi
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      sum += db.effectiveMinutesOnDay(activityId, startOfWeek.add(Duration(days: i)));
    }
    return sum;
  }

  Future<int> minutesThisMonth(String activityId) async {
    final t = now();
    final start = DateTime(t.year, t.month, 1);
    final days = DateUtils.getDaysInMonth(t.year, t.month);
    int sum = 0;
    for (int i = 0; i < days; i++) {
      sum += db.effectiveMinutesOnDay(activityId, start.add(Duration(days: i)));
    }
    return sum;
  }

  Future<int> minutesThisYear(String activityId) async {
    final t = now();
    int sum = 0;
    for (int m = 1; m <= 12; m++) {
      final days = DateUtils.getDaysInMonth(t.year, m);
      final start = DateTime(t.year, m, 1);
      for (int i = 0; i < days; i++) {
        sum += db.effectiveMinutesOnDay(activityId, start.add(Duration(days: i)));
      }
    }
    return sum;
  }

  Future<List<DailyStat>> lastNDays(String activityId, {required int n}) async {
    final t = now();
    final today = DateTime(t.year, t.month, t.day);
    final start = today.subtract(Duration(days: n - 1));
    final out = <DailyStat>[];
    for (int i = 0; i < n; i++) {
      final day = start.add(Duration(days: i));
      out.add(DailyStat(date: day, minutes: db.effectiveMinutesOnDay(activityId, day)));
    }
    return out;
  }

  Future<List<HourlyBucket>> hourlyToday(String activityId) async {
    final buckets = db.hourlyToday(activityId);
    return List<HourlyBucket>.generate(24, (h) => HourlyBucket(hour: h, minutes: buckets[h]));
  }
}
