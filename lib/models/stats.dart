// lib/models/stats.dart
class DailyStat {
  final DateTime date;
  final int minutes;
  const DailyStat({required this.date, required this.minutes});
}

class HourlyBucket {
  final int hour;   // 0..23
  final int minutes;
  const HourlyBucket({required this.hour, required this.minutes});
}
