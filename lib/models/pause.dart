import 'package:isar/isar.dart';

part 'pause.g.dart';

@collection
class Pause {
  Id id = Isar.autoIncrement;

  /// Référence à Session.id
  @Index()
  late int sessionId;

  /// Début/fin de la pause
  late DateTime startedAt;
  DateTime? endedAt;

  Pause({
    required this.sessionId,
    required this.startedAt,
    this.endedAt,
  });
}
