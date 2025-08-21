class Pause {
  final String id;
  final String sessionId;
  final DateTime startAt;
  final DateTime? endAt;

  const Pause({
    required this.id,
    required this.sessionId,
    required this.startAt,
    required this.endAt,
  });

  Pause copyWith({
    String? id,
    String? sessionId,
    DateTime? startAt,
    DateTime? endAt,
  }) {
    return Pause(
      id: id ?? this.id,
      sessionId: sessionId ?? this.sessionId,
      startAt: startAt ?? this.startAt,
      endAt: endAt ?? this.endAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'sessionId': sessionId,
        'startAt': startAt.toIso8601String(),
        'endAt': endAt?.toIso8601String(),
      };

  factory Pause.fromJson(Map<String, dynamic> json) => Pause(
        id: json['id'] as String,
        sessionId: json['sessionId'] as String,
        startAt: DateTime.parse(json['startAt'] as String),
        endAt: json['endAt'] == null ? null : DateTime.parse(json['endAt'] as String),
      );
}
