import 'package:flutter_riverpod/flutter_riverpod.dart';

import './providers.dart';
import './services/stats_service.dart';
import './models/stats.dart';

/// Service de stats branché sur le DB service
final statsServiceProvider = Provider<StatsService>((ref) {
  final db = ref.watch(dbProvider);
  return StatsService(db);
});

/// Minutes aujourd'hui
final minutesTodayProvider =
FutureProvider.family<int, String>((ref, activityId) {
  final svc = ref.watch(statsServiceProvider);
  return svc.minutesToday(activityId);
});

/// Minutes semaine/mois/année courantes
final minutesThisWeekProvider =
FutureProvider.family<int, String>((ref, activityId) {
  final svc = ref.watch(statsServiceProvider);
  return svc.minutesThisWeek(activityId);
});

final minutesThisMonthProvider =
FutureProvider.family<int, String>((ref, activityId) {
  final svc = ref.watch(statsServiceProvider);
  return svc.minutesThisMonth(activityId);
});

final minutesThisYearProvider =
FutureProvider.family<int, String>((ref, activityId) {
  final svc = ref.watch(statsServiceProvider);
  return svc.minutesThisYear(activityId);
});

/// Stats “N derniers jours”
class LastNDaysArgs {
  final String activityId;
  final int n;
  const LastNDaysArgs({required this.activityId, required this.n});
}

final lastNDaysProvider =
FutureProvider.family<List<DailyStat>, LastNDaysArgs>((ref, args) {
  final svc = ref.watch(statsServiceProvider);
  return svc.lastNDays(args.activityId, n: args.n);
});

/// Buckets horaires pour aujourd’hui (0..23)
final hourlyTodayProvider =
FutureProvider.family<List<HourlyBucket>, String>((ref, activityId) {
  final svc = ref.watch(statsServiceProvider);
  return svc.hourlyToday(activityId);
});
