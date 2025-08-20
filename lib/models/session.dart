class Session {
  final String id;
  final String activityId;
  final DateTime startAt;
  final DateTime? endAt;

  const Session({
    required this.id,
    required this.activityId,
    required this.startAt,
    required this.endAt,
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

  Duration get duration =>
      (endAt ?? DateTime.now()).difference(startAt);

  Map<String, dynamic> toJson() => {
        'id': id,
        'activityId': activityId,
        'startAt': startAt.toIso8601String(),
        'endAt': endAt?.toIso8601String(),
      };

  factory Session.fromJson(Map<String, dynamic> json) => Session(
        id: json['id'] as String,
        activityId: json['activityId'] as String,
        startAt: DateTime.parse(json['startAt'] as String),
        endAt: json['endAt'] == null ? null : DateTime.parse(json['endAt'] as String),
      );
}
