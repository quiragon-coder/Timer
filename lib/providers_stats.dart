import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/database_service.dart';
import 'services/stats_service.dart';
import 'providers.dart'; // dbProvider

// Service de stats branché sur le DB
final statsServiceProvider = Provider<StatsService>((ref) {
  final db = ref.watch(dbProvider);
  return StatsService(db);
});

// Minutes today / semaine / mois / année
final minutesTodayProvider = FutureProvider.family<int, String>((ref, activityId) {
  return ref.watch(statsServiceProvider).minutesToday(activityId);
});

final minutesThisWeekProvider = FutureProvider.family<int, String>((ref, activityId) {
  return ref.watch(statsServiceProvider).minutesThisWeek(activityId);
});

final minutesThisMonthProvider = FutureProvider.family<int, String>((ref, activityId) {
  return ref.watch(statsServiceProvider).minutesThisMonth(activityId);
});

final minutesThisYearProvider = FutureProvider.family<int, String>((ref, activityId) {
  return ref.watch(statsServiceProvider).minutesThisYear(activityId);
});

// Derniers N jours
class LastNDaysArgs {
  final String activityId;
  final int n;
  const LastNDaysArgs({required this.activityId, required this.n});
}

final lastNDaysProvider = FutureProvider.family<List<DailyStat>, LastNDaysArgs>((ref, args) {
  return ref.watch(statsServiceProvider).lastNDays(args.activityId, n: args.n);
});

// Buckets horaires (aujourd’hui)
final hourlyTodayProvider = FutureProvider.family<List<HourlyBucket>, String>((ref, activityId) {
  return ref.watch(statsServiceProvider).hourlyToday(activityId);
});
