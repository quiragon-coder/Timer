import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';              // dbProvider
import 'services/stats_service.dart';
import 'models/stats.dart';

final statsServiceProvider = Provider<StatsService>((ref) {
  final db = ref.watch(dbProvider);
  return StatsService(db);
});

// Totaux
final statsTodayProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.minutesToday(activityId);
});
final weekTotalProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.minutesThisWeek(activityId);
});
final monthTotalProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.minutesThisMonth(activityId);
});
final yearTotalProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.minutesThisYear(activityId);
});

// Graphes
final hourlyTodayProvider =
FutureProvider.family<List<HourlyBucket>, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.hourlyToday(activityId);
});

final lastNDaysProvider =
FutureProvider.family<List<DailyStat>, ({String id, int n})>((ref, params) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.lastNDays(params.id, n: params.n);
});

final last7DaysProvider =
FutureProvider.family<List<DailyStat>, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.lastNDays(activityId, n: 7);
});
