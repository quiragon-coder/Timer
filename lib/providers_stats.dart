import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';                // dbProvider
import '../services/stats_service.dart';   // StatsService
import '../models/stats.dart';             // DailyStat, HourlyBucket

/// Service de stats à partir du DatabaseService
final statsServiceProvider = Provider<StatsService>((ref) {
  final db = ref.watch(dbProvider);
  return StatsService(db);
});

/// minutes aujourd'hui
final minutesTodayProvider =
FutureProvider.family<int, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.minutesToday(activityId);
});

/// minutes cette semaine
final minutesThisWeekProvider =
FutureProvider.family<int, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.minutesThisWeek(activityId);
});

/// minutes ce mois
final minutesThisMonthProvider =
FutureProvider.family<int, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.minutesThisMonth(activityId);
});

/// minutes cette année
final minutesThisYearProvider =
FutureProvider.family<int, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.minutesThisYear(activityId);
});

/// distribution horaire pour aujourd'hui (0..23)
final hourlyTodayProvider =
FutureProvider.family<List<HourlyBucket>, String>((ref, activityId) async {
  final svc = ref.watch(statsServiceProvider);
  return svc.hourlyToday(activityId);
});

/// arguments typés pour la famille lastNDaysProvider
class LastNDaysArgs {
  final String activityId;
  final int n;
  const LastNDaysArgs(this.activityId, this.n);
}

/// stats jour par jour sur N jours (ordre chronologique)
final lastNDaysProvider = FutureProvider.family<List<DailyStat>, LastNDaysArgs>(
        (ref, args) async {
      final svc = ref.watch(statsServiceProvider);
      return svc.lastNDays(args.activityId, args.n);
    });
