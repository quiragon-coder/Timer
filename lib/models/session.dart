import 'package:flutter/foundation.dart';

class Session {
  final String id;
  final String activityId;
  final DateTime startAt;
  final DateTime? endAt;

  const Session({
    required this.id,
    required this.activityId,
    required this.startAt,
    this.endAt,
  });

  Session copyWith({
    String? id,
    String? activityId,
    DateTime? startAt,
    DateTime? endAt,
  }) {
    return Session(
      id: id ?? this.id,
      activityId: activityId ?? this.activityId,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
    );
  }
}
