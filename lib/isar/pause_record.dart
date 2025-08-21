import 'package:isar/isar.dart';

part 'pause_record.g.dart';

@collection
class PauseRecord {
  Id id = Isar.autoIncrement;

  @Index()
  late int sessionId;

  @Index()
  late DateTime startedAt;

  DateTime? endedAt;
}
