import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/stats.dart';
import 'services/database_service.dart';
import 'services/stats_service.dart';

final dbProvider = Provider<DatabaseService>((ref) => DatabaseService());
final statsProvider = Provider<StatsService>((ref) => StatsService(ref.watch(dbProvider)));

/// Minutes d’un jour (par activité)
final dayMinutesProvider = FutureProvider.family<int, ({String activityUid, DateTime date})>((ref, args) {
  return ref.watch(statsProvider).dayMinutes(args.activityUid, args.date);
});

/// Total semaine (lundi->dimanche du jour donné)
final weekMinutesProvider = FutureProvider.family<int, ({String activityUid, DateTime inWeek})>((ref, args) {
  return ref.watch(statsProvider).weekMinutes(args.activityUid, args.inWeek);
});

/// Total mois
final monthMinutesProvider = FutureProvider.family<int, ({String activityUid, DateTime inMonth})>((ref, args) {
  return ref.watch(statsProvider).monthMinutes(args.activityUid, args.inMonth);
});

/// Derniers 28 jours (pour mini heatmap)
final last28DaysProvider = FutureProvider.family<List<DayStat>, String>((ref, activityUid) async {
  final db = ref.watch(dbProvider);
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final List<DayStat> out = [];
  for (int i = 27; i >= 0; i--) {
    final d = today.subtract(Duration(days: i));
    final m = await db.effectiveMinutesOnDay(activityUid: activityUid, date: d);
    out.add(DayStat(date: d, minutes: m));
  }
  return out;
});
