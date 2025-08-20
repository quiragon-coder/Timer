import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';                       // dbProvider
import 'services/stats_service.dart';
import 'models/stats.dart';                    // DailyStat

/// Service de stats basé sur le DatabaseService existant.
final statsServiceProvider = Provider<StatsService>((ref) {
  final db = ref.read(dbProvider);
  return StatsService(db);
});

/// === Noms historiques (déjà présents dans ton app) =========================
/// Gardés pour compat' avec les anciens widgets.
final statsTodayProvider =
FutureProvider.family<int, String>((ref, activityId) {
  return ref.read(statsServiceProvider).minutesToday(activityId: activityId);
});

final weekTotalProvider =
FutureProvider.family<int, String>((ref, activityId) {
  return ref.read(statsServiceProvider).minutesThisWeek(activityId: activityId);
});

final monthTotalProvider =
FutureProvider.family<int, String>((ref, activityId) {
  return ref.read(statsServiceProvider).minutesThisMonth(activityId: activityId);
});

final yearTotalProvider =
FutureProvider.family<int, String>((ref, activityId) {
  return ref.read(statsServiceProvider).minutesThisYear(activityId: activityId);
});

/// === Nouveaux alias (utilisés par mes derniers extraits) ====================
/// Même résultat, juste d'autres identifiants pour éviter les erreurs "undefined".
final minutesTodayProvider =
FutureProvider.family<int, String>((ref, activityId) {
  return ref.read(statsServiceProvider).minutesToday(activityId: activityId);
});

final minutesThisWeekProvider =
FutureProvider.family<int, String>((ref, activityId) {
  return ref.read(statsServiceProvider).minutesThisWeek(activityId: activityId);
});

final minutesThisMonthProvider =
FutureProvider.family<int, String>((ref, activityId) {
  return ref.read(statsServiceProvider).minutesThisMonth(activityId: activityId);
});

final minutesThisYearProvider =
FutureProvider.family<int, String>((ref, activityId) {
  return ref.read(statsServiceProvider).minutesThisYear(activityId: activityId);
});

/// 7 jours tout prêts (utile pour mini-heatmap si besoin rapide)
final last7DaysProvider =
FutureProvider.family<List<DailyStat>, String>((ref, activityId) {
  return ref.read(statsServiceProvider).lastNDays(
    activityId: activityId,
    n: 7,
  );
});

/// Provider flexible: on lui passe un Map {activityId, n}.
/// => évite les erreurs "named param not defined" vues chez toi.
final lastNDaysProvider = FutureProvider.family<List<DailyStat>,
    Map<String, dynamic>>((ref, args) {
  final id = args['activityId'] as String;
  final n = args['n'] as int;
  return ref.read(statsServiceProvider).lastNDays(activityId: id, n: n);
});
