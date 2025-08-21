import 'package:isar/isar.dart';

part 'pause.g.dart';

@collection
class Pause {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  @Index()
  late String sessionId;

  @Index()
  late String activityId;

  @Index()
  late DateTime startAt;

  DateTime? endAt;

  Pause({
    required this.id,
    required this.sessionId,
    required this.activityId,
    required this.startAt,
    this.endAt,
  });
}
