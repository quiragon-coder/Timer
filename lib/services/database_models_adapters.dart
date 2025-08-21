import '../models/session.dart';
import '../models/pause.dart';
import 'database_service.dart';

/// Adaptateurs "compat" pour l’UI existante.
///
/// Tu avais des extensions qui appelaient `listSessionsByActivity(...)`
/// et `listPausesBySession(...)`. On les mappe ici sur les nouvelles
/// méthodes synchrones qui renvoient bien les modèles dominants.
extension DatabaseModelsAdapters on DatabaseService {
  /// Ex-`listSessionsByActivity(...)`
  List<Session> listSessionsByActivity(String activityId) {
    return listSessionsByActivityModel(activityId);
  }

  /// Ex-`listPausesBySession(...)`
  List<Pause> listPausesBySession(String activityId, String sessionId) {
    return listPausesBySessionModel(activityId, sessionId);
  }
}
