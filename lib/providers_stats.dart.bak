import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:habits_timer/models/stats.dart";
import "package:habits_timer/services/database_service.dart";
import "package:habits_timer/services/stats_service.dart";
import "providers.dart";

final statsServiceProvider = Provider<StatsService>((ref) {
  final db = ref.read(dbProvider);
  return StatsService(db);
});

// Jour
final statsTodayProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final svc = ref.read(statsServiceProvider);
  return svc.minutesToday(activityId);
});

// Horaires aujourd'hui
final hourlyTodayProvider = FutureProvider.family<List<HourlyBucket>, String>((ref, activityId) async {
  final svc = ref.read(statsServiceProvider);
  return svc.hourlyToday(activityId);
});

// 7 derniers jours
final statsLast7DaysProvider = FutureProvider.family<List<DailyStat>, String>((ref, activityId) async {
  final svc = ref.read(statsServiceProvider);
  return svc.last7DaysStats(activityId);
});

// Totaux Semaine / Mois / Annee
final weekTotalProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final svc = ref.read(statsServiceProvider);
  return svc.minutesThisWeek(activityId);
});

final monthTotalProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final svc = ref.read(statsServiceProvider);
  return svc.minutesThisMonth(activityId);
});

final yearTotalProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final svc = ref.read(statsServiceProvider);
  return svc.minutesThisYear(activityId);
});
