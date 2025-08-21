import "package:flutter/material.dart";

class Activity {
  final String id;
  final String name;
  final String emoji;
  final Color color;

  /// Objectifs (minutes). Tous optionnels.
  final int? dailyGoalMinutes;
  final int? weeklyGoalMinutes;
  final int? monthlyGoalMinutes;
  final int? yearlyGoalMinutes;

  const Activity({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    this.dailyGoalMinutes,
    this.weeklyGoalMinutes,
    this.monthlyGoalMinutes,
    this.yearlyGoalMinutes,
  });

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
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "emoji": emoji,
        "color": color.value, // peut lever un warning deprecation, sans gravitÃ©
        "dailyGoalMinutes": dailyGoalMinutes,
        "weeklyGoalMinutes": weeklyGoalMinutes,
        "monthlyGoalMinutes": monthlyGoalMinutes,
        "yearlyGoalMinutes": yearlyGoalMinutes,
      };

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json["id"] as String,
      name: json["name"] as String,
      emoji: json["emoji"] as String,
      color: Color((json["color"] as int?) ?? 0xFF6C63FF),
      dailyGoalMinutes: json["dailyGoalMinutes"] as int?,
      weeklyGoalMinutes: json["weeklyGoalMinutes"] as int?,
      monthlyGoalMinutes: json["monthlyGoalMinutes"] as int?,
      yearlyGoalMinutes: json["yearlyGoalMinutes"] as int?,
    );
  }
}
