import 'package:flutter/material.dart';
import '../models/stats.dart';
import 'database_service.dart';

class StatsService {
  final DatabaseService db;
  StatsService(this.db);

  Future<int> minutesToday(String activityId) async {
    final today = DateTime.now();
    return db.effectiveMinutesOnDay(activityId, DateTime(today.year, today.month, today.day));
  }

  Future<int> minutesThisWeek(String activityId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day)
        .subtract(Duration(days: (now.weekday + 6) % 7)); // lundi
    int sum = 0;
    for (int i = 0; i < 7; i++) {
      sum += db.effectiveMinutesOnDay(activityId, start.add(Duration(days: i)));
    }
    return sum;
  }

  Future<int> minutesThisMonth(String activityId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final nextMonth = (now.month == 12)
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
    int sum = 0;
    for (DateTime d = start; d.isBefore(nextMonth); d = d.add(const Duration(days: 1))) {
      sum += db.effectiveMinutesOnDay(activityId, d);
    }
    return sum;
  }

  Future<int> minutesThisYear(String activityId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year + 1, 1, 1);
    int sum = 0;
    for (DateTime d = start; d.isBefore(end); d = d.add(const Duration(days: 1))) {
      sum += db.effectiveMinutesOnDay(activityId, d);
    }
    return sum;
  }

  Future<List<DailyStat>> lastNDays(String activityId, {required int n}) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(Duration(days: n - 1));
    final out = <DailyStat>[];
    for (int i = 0; i < n; i++) {
      final day = start.add(Duration(days: i));
      out.add(DailyStat(date: day, minutes: db.effectiveMinutesOnDay(activityId, day)));
    }
    return out;
  }

  Future<List<HourlyBucket>> hourlyToday(String activityId) async {
    final buckets = db.hourlyToday(activityId);
    return List<HourlyBucket>.generate(
      24,
          (h) => HourlyBucket(hour: h, minutes: buckets[h]),
    );
  }
}
