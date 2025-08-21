import 'package:isar/isar.dart';

part 'session.g.dart';

@collection
class Session {
  Id id = Isar.autoIncrement;

  /// Référence à Activity.id
  @Index()
  late int activityId;

  /// Début/fin de la session
  late DateTime startedAt;
  DateTime? endedAt;

  Session({
    required this.activityId,
    required this.startedAt,
    this.endedAt,
  });
}
