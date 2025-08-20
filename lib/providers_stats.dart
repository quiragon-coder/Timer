import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart'; // dbProvider
import 'services/stats_service.dart';
import 'models/stats.dart'; // <-- fournit HourlyBucket & DailyStat

/// Fournit un StatsService basé sur le DatabaseService.
final statsServiceProvider = Provider<StatsService>((ref) {
  final db = ref.watch(dbProvider);
  return StatsService(db);
});

/// Minutes totales aujourd’hui pour une activité
final statsTodayProvider =
Provider.family.autoDispose<int, String>((ref, activityId) {
  final svc = ref.watch(statsServiceProvider);
  return svc.todayTotal(activityId);
});

/// Répartition horaire aujourd’hui (24 buckets)
final hourlyTodayProvider =
Provider.family.autoDispose<List<HourlyBucket>, String>((ref, activityId) {
  final svc = ref.watch(statsServiceProvider);
  return svc.hourlyToday(activityId);
});

/// Totaux semaine / mois / année
final weekTotalProvider =
Provider.family.autoDispose<int, String>((ref, activityId) {
  final svc = ref.watch(statsServiceProvider);
  return svc.weekTotal(activityId);
});

final monthTotalProvider =
Provider.family.autoDispose<int, String>((ref, activityId) {
  final svc = ref.watch(statsServiceProvider);
  return svc.monthTotal(activityId);
});

final yearTotalProvider =
Provider.family.autoDispose<int, String>((ref, activityId) {
  final svc = ref.watch(statsServiceProvider);
  return svc.yearTotal(activityId);
});

/// 7 derniers jours (chaque élément = minutes pour la journée)
final last7DaysProvider =
Provider.family.autoDispose<List<DailyStat>, String>((ref, activityId) {
  final svc = ref.watch(statsServiceProvider);
  return svc.last7Days(activityId);
});
