import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';                 // dbProvider
import 'services/stats_service.dart';    // StatsService
import 'models/stats.dart';              // HourlyBucket, DailyStat

/// Service de stats basé sur le DatabaseService
final statsServiceProvider = Provider<StatsService>((ref) {
  final db = ref.watch(dbProvider);
  return StatsService(db);
});

/// Minutes effectuées aujourd’hui pour une activité
final statsTodayProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.minutesToday(activityId);
});

/// Histogramme horaire (0..23) pour aujourd’hui
final hourlyTodayProvider =
FutureProvider.family<List<HourlyBucket>, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.hourlyToday(activityId);
});

/// Statistiques des N derniers jours (par défaut 7 via last7DaysProvider)
final lastNDaysProvider =
FutureProvider.family<List<DailyStat>, ({String id, int n})>((ref, params) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.lastNDays(params.id, n: params.n);
});

/// Raccourci pratique pour 7 jours
final last7DaysProvider =
FutureProvider.family<List<DailyStat>, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.lastNDays(activityId, n: 7);
});

/// Totaux période courante
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
