import 'package:isar/isar.dart';

part 'session_record.g.dart';

@collection
class SessionRecord {
  Id id = Isar.autoIncrement;

  @Index()
  late String activityUid;

  @Index()
  late DateTime startedAt;

  DateTime? endedAt;
}
