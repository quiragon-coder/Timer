import 'package:flutter/material.dart';
import 'package:isar/isar.dart';

part 'activity.g.dart';

@collection
class Activity {
  Id id = Isar.autoIncrement;

  /// Nom de l’activité (ex: “Lecture”)
  late String name;

  /// Emoji affiché (ex: “📚”)
  late String emoji;

  /// Couleur stockée en int (ARGB)
  late int colorValue;

  /// Objectifs en minutes (facultatifs)
  int? dailyGoalMinutes;
  int? weeklyGoalMinutes;
  int? monthlyGoalMinutes;
  int? yearlyGoalMinutes;

  Activity({
    required this.name,
    required this.emoji,
    required Color color,
    this.dailyGoalMinutes,
    this.weeklyGoalMinutes,
    this.monthlyGoalMinutes,
    this.yearlyGoalMinutes,
  }) : colorValue = color.value;


  /// Accès pratique à la Color Flutter
  @ignore
  Color get color => Color(colorValue);
}
