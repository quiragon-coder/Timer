import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'services/database_service.dart';
import 'services/stats_service.dart';

/// Fournit une instance unique de StatsService branchée sur dbProvider.
final statsServiceProvider = Provider<StatsService>((ref) {
  final db = ref.watch(dbProvider);
  return StatsService(db);
});

/// Minutes aujourd’hui pour une activité.
final minutesTodayProvider =
Provider.family<int, String>((ref, activityId) {
  final stats = ref.watch(statsServiceProvider);
  return stats.minutesToday(activityId);
});

/// Minutes cette semaine pour une activité.
final minutesThisWeekProvider =
Provider.family<int, String>((ref, activityId) {
  final stats = ref.watch(statsServiceProvider);
  return stats.minutesThisWeek(activityId);
});

/// Minutes ce mois pour une activité.
final minutesThisMonthProvider =
Provider.family<int, String>((ref, activityId) {
  final stats = ref.watch(statsServiceProvider);
  return stats.minutesThisMonth(activityId);
});

/// Minutes cette année pour une activité.
final minutesThisYearProvider =
Provider.family<int, String>((ref, activityId) {
  final stats = ref.watch(statsServiceProvider);
  return stats.minutesThisYear(activityId);
});

/// Buckets horaires pour aujourd’hui (24 cases).
final hourlyTodayProvider =
Provider.family<List<int>, String>((ref, activityId) {
  final stats = ref.watch(statsServiceProvider);
  return stats.hourlyToday(activityId);
});

/// Données des N derniers jours (du plus ancien au plus récent).
class LastNDaysArgs {
  final String activityId;
  final int n;
  LastNDaysArgs(this.activityId, this.n);
}

final lastNDaysProvider =
Provider.family<List<dynamic>, LastNDaysArgs>((ref, args) {
  final stats = ref.watch(statsServiceProvider);
  return stats.lastNDays(args.activityId, args.n);
});
