import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

part 'activity.g.dart';

@collection
class Activity {
  /// Id interne Isar
  Id isarId = Isar.autoIncrement;

  /// Id logique String (utilisé partout dans l’UI/services)
  @Index(unique: true, replace: true)
  late String id;

  late String name;
  String emoji = '⏱️';

  /// Couleur stockée comme entier ARGB
  @Index()
  late int colorValue;

  /// Objectifs en minutes (on conserve les mêmes noms que ton UI)
  int dailyGoalMinutes = 0;
  int weeklyGoalMinutes = 0;
  int monthlyGoalMinutes = 0;
  int yearlyGoalMinutes = 0;

  Activity({
    required this.id,
    required this.name,
    this.emoji = '⏱️',
    required Color color,
    this.dailyGoalMinutes = 0,
    this.weeklyGoalMinutes = 0,
    this.monthlyGoalMinutes = 0,
    this.yearlyGoalMinutes = 0,
  }) : colorValue = color.value;

  /// ----- Helpers non persistés -----

  @ignore
  Color get color => Color(colorValue);

  @ignore
  set color(Color c) => colorValue = c.value;

  Activity copyWith({
    String? id,
    String? name,
    String? emoji,
    Color? color,
    int? dailyGoalMinutes,
    int? weeklyGoalMinutes,
    int? monthlyGoalMinutes,
    int? yearlyGoalMinutes,
  }) {
    return Activity(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      weeklyGoalMinutes: weeklyGoalMinutes ?? this.weeklyGoalMinutes,
      monthlyGoalMinutes: monthlyGoalMinutes ?? this.monthlyGoalMinutes,
      yearlyGoalMinutes: yearlyGoalMinutes ?? this.yearlyGoalMinutes,
    )..isarId = isarId;
  }
}
