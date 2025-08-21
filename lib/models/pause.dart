class Pause {
  final String id;
  final String sessionId;
  final String activityId;
  final DateTime startAt;
  final DateTime? endAt;

  const Pause({
    required this.id,
    required this.sessionId,
    required this.activityId,
    required this.startAt,
    this.endAt,
  });

  Pause copyWith({
    String? id,
    String? sessionId,
    String? activityId,
    DateTime? startAt,
    DateTime? endAt,
  }) {
    return Pause(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      activityId: activityId ?? this.activityId,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
    );
  }
}
