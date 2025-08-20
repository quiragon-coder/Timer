import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/database_service.dart';
import 'services/stats_service.dart';
import 'providers.dart';

/// Fournit un StatsService connecté au DatabaseService
final statsServiceProvider = Provider<StatsService>((ref) {
  final db = ref.watch(dbProvider);
  return StatsService(db);
});

/// Aujourd’hui (minutes)
final statsTodayProvider =
FutureProvider.family<int, String>((ref, activityId) async {
  final s = ref.watch(statsServiceProvider);
  return s.todayTotal(activityId);
});

/// Semaine / Mois / Année (minutes)
final weekTotalProvider =
FutureProvider.family<int, String>((ref, activityId) async {
  final s = ref.watch(statsServiceProvider);
  return s.weekTotal(activityId);
});

final monthTotalProvider =
FutureProvider.family<int, String>((ref, activityId) async {
  final s = ref.watch(statsServiceProvider);
  return s.monthTotal(activityId);
});

final yearTotalProvider =
FutureProvider.family<int, String>((ref, activityId) async {
  final s = ref.watch(statsServiceProvider);
  return s.yearTotal(activityId);
});

/// Répartition horaire aujourd’hui
final hourlyTodayProvider = FutureProvider.family<List<HourlyBucket>, String>(
        (ref, activityId) async {
      final s = ref.watch(statsServiceProvider);
      return s.hourlyToday(activityId);
    });

/// 7 derniers jours
final last7DaysProvider =
FutureProvider.family<List<DailyStat>, String>((ref, activityId) async {
  final s = ref.watch(statsServiceProvider);
  return s.last7Days(activityId);
});
