import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart'; // dbProvider
import 'services/stats_service.dart';
import 'models/stats.dart'; // HourlyBucket & DailyStat

/// Service de stats basé sur DatabaseService
final statsServiceProvider = Provider<StatsService>((ref) {
  final db = ref.watch(dbProvider);
  return StatsService(db);
});

/// Minutes totales aujourd’hui (Async)
final statsTodayProvider =
FutureProvider.autoDispose.family<int, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.todayTotal(activityId);
});

/// Répartition horaire aujourd’hui (24 buckets) (Async)
final hourlyTodayProvider = FutureProvider.autoDispose
    .family<List<HourlyBucket>, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.hourlyToday(activityId);
});

/// Totaux Semaine / Mois / Année (Async)
final weekTotalProvider =
FutureProvider.autoDispose.family<int, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.weekTotal(activityId);
});

final monthTotalProvider =
FutureProvider.autoDispose.family<int, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.monthTotal(activityId);
});

final yearTotalProvider =
FutureProvider.autoDispose.family<int, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.yearTotal(activityId);
});

/// 7 derniers jours (Async)
final last7DaysProvider = FutureProvider.autoDispose
    .family<List<DailyStat>, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.last7Days(activityId);
});
