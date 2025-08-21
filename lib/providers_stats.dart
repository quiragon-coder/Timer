import 'package:flutter_riverpod/flutter_riverpod.dart';

import './providers.dart' show dbProvider;
import './services/stats_service.dart' show StatsService, DailyStat, HourlyBucket;

/// Fournit un StatsService branché sur le DatabaseService courant.
final statsServiceProvider = Provider<StatsService>((ref) {
  final db = ref.read(dbProvider);
  return StatsService(db);
});

/// Aujourd'hui (minutes)
final minutesTodayProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final s = ref.read(statsServiceProvider);
  return s.minutesToday(activityId);
});

/// Cette semaine (minutes)
final minutesThisWeekProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final s = ref.read(statsServiceProvider);
  return s.minutesThisWeek(activityId);
});

/// Ce mois (minutes)
final minutesThisMonthProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final s = ref.read(statsServiceProvider);
  return s.minutesThisMonth(activityId);
});

/// Cette année (minutes)
final minutesThisYearProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final s = ref.read(statsServiceProvider);
  return s.minutesThisYear(activityId);
});

/// Arguments pour lastNDaysProvider
class LastNDaysArgs {
  final String activityId;
  final int n;
  const LastNDaysArgs({required this.activityId, required this.n});
}

/// 7 / 30 / 365 derniers jours (liste de DailyStat)
final lastNDaysProvider = FutureProvider.family<List<DailyStat>, LastNDaysArgs>((ref, args) async {
  final s = ref.read(statsServiceProvider);
  return s.lastNDays(args.activityId, n: args.n);
});

/// Buckets horaires d'aujourd'hui (0..23)
final hourlyTodayProvider = FutureProvider.family<List<HourlyBucket>, String>((ref, activityId) async {
  final s = ref.read(statsServiceProvider);
  return s.hourlyToday(activityId);
});
