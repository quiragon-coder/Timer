import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart'               // dbProvider
import '../services/stats_service.dart'; // StatsService
import '../models/stats.dart';           // DailyStat, HourlyBucket

/// Service de stats branché sur la DB.
/// IMPORTANT: StatsService utilise un constructeur *positionnel*: StatsService(db)
final statsServiceProvider = Provider<StatsService>((ref) {
  final db = ref.watch(dbProvider);
  return StatsService(db);
});

/// ---------- Providers "minutes" ----------
final minutesTodayProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final s = ref.watch(statsServiceProvider);
  return s.minutesToday(activityId);
});

final minutesThisWeekProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final s = ref.watch(statsServiceProvider);
  return s.minutesThisWeek(activityId);
});

final minutesThisMonthProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final s = ref.watch(statsServiceProvider);
  return s.minutesThisMonth(activityId);
});

final minutesThisYearProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final s = ref.watch(statsServiceProvider);
  return s.minutesThisYear(activityId);
});

/// ---------- Providers "séries temporelles" ----------
final hourlyTodayProvider = FutureProvider.family<List<HourlyBucket>, String>((ref, activityId) async {
  final s = ref.watch(statsServiceProvider);
  return s.hourlyToday(activityId);
});

/// Arguments typés pour N derniers jours (heatmap & mini-heatmap)
class LastNDaysArgs {
  final String activityId;
  final int n;
  const LastNDaysArgs({required this.activityId, required this.n});
}

final lastNDaysProvider = FutureProvider.family<List<DailyStat>, LastNDaysArgs>((ref, args) async {
  final s = ref.watch(statsServiceProvider);
  // StatsService.lastNDays attend: (String activityId, {required int n})
  return s.lastNDays(args.activityId, n: args.n);
});

/// Raccourci pratique pour 7 jours
final last7DaysProvider = FutureProvider.family<List<DailyStat>, String>((ref, activityId) async {
  final s = ref.watch(statsServiceProvider);
  return s.lastNDays(activityId, n: 7);
});

/// ---------- ALIAS conservés pour compatibilité avec tes widgets ----------
final statsTodayProvider  = minutesTodayProvider;
final weekTotalProvider   = minutesThisWeekProvider;
final monthTotalProvider  = minutesThisMonthProvider;
final yearTotalProvider   = minutesThisYearProvider;
