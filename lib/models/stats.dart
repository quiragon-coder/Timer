import 'package:flutter/foundation.dart';

@immutable
class DailyStat {
  final DateTime day; // truncated to local midnight
  final int minutes;
  const DailyStat({required this.day, required this.minutes});
}

@immutable
class HourlyBucket {
  final int hour; // 0..23
  final int minutes;
  const HourlyBucket({required this.hour, required this.minutes});
}
