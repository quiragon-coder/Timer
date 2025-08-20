import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/stats.dart';
import 'providers.dart';

final statsTodayProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final stats = ref.read(statsServiceProvider);
  return stats.minutesForActivityOnDay(activityId, DateTime.now());
});

final statsLast7DaysProvider = FutureProvider.family<List<DailyStat>, String>((ref, activityId) async {
  final stats = ref.read(statsServiceProvider);
  return stats.last7DaysStats(activityId);
});

final hourlyTodayProvider = FutureProvider.family<List<HourlyBucket>, String>((ref, activityId) async {
  final stats = ref.read(statsServiceProvider);
  return stats.hourlyDistribution(activityId, DateTime.now());
});
