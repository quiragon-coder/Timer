import 'package:isar/isar.dart';

part 'session.g.dart';

@collection
class Session {
  Id isarId = Isar.autoIncrement;

  @Index(unique: true, replace: true)
  late String id;

  @Index()
  late String activityId;

  @Index()
  late DateTime startAt;

  DateTime? endAt;

  Session({
    required this.id,
    required this.activityId,
    required this.startAt,
    this.endAt,
  });
}
