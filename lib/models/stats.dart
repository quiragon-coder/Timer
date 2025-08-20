class DailyStat {
  final DateTime day;
  final int minutes;
  const DailyStat({required this.day, required this.minutes});

  DailyStat copyWith({DateTime? day, int? minutes}) =>
      DailyStat(day: day ?? this.day, minutes: minutes ?? this.minutes);
}

class HourlyBucket {
  final int hour;     // 0..23
  final int minutes;  // minutes actifs dans l’heure
  const HourlyBucket({required this.hour, required this.minutes});

  HourlyBucket copyWith({int? hour, int? minutes}) =>
      HourlyBucket(hour: hour ?? this.hour, minutes: minutes ?? this.minutes);
}
