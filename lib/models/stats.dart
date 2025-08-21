import 'package:flutter/foundation.dart';

/// Stat par jour (utilisée par les courbes / heatmaps)
@immutable
class DailyStat {
  final DateTime date;
  final int minutes;

  const DailyStat({
    required this.date,
    required this.minutes,
  });

  DailyStat copyWith({
    DateTime? date,
    int? minutes,
  }) {
    return DailyStat(
      date: date ?? this.date,
      minutes: minutes ?? this.minutes,
    );
  }

  @override
  String toString() => 'DailyStat(date: $date, minutes: $minutes)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is DailyStat &&
              runtimeType == other.runtimeType &&
              date == other.date &&
              minutes == other.minutes;

  @override
  int get hashCode => Object.hash(date, minutes);
}

/// Bucket horaire (0–23) pour la répartition dans la journée
@immutable
class HourlyBucket {
  final int hour;     // 0..23
  final int minutes;  // minutes cumulées sur cette heure

  const HourlyBucket({
    required this.hour,
    required this.minutes,
  });

  HourlyBucket copyWith({
    int? hour,
    int? minutes,
  }) {
    return HourlyBucket(
      hour: hour ?? this.hour,
      minutes: minutes ?? this.minutes,
    );
  }

  @override
  String toString() => 'HourlyBucket(hour: $hour, minutes: $minutes)';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
          other is HourlyBucket &&
              runtimeType == other.runtimeType &&
              hour == other.hour &&
              minutes == other.minutes;

  @override
  int get hashCode => Object.hash(hour, minutes);
}
