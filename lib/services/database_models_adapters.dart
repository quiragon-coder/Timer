import '../models/session.dart';
import '../models/pause.dart';
import 'database_service.dart';

extension DatabaseModelsAdapters on DatabaseService {
  List<Session> listSessionsByActivityCompat(String activityId) =>
      listSessionsByActivity(activityId);

  List<Pause> listPausesBySessionCompat(String sessionId) =>
      listPausesBySession(sessionId);
}
