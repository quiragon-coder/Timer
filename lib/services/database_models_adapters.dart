import '../models/activity.dart';
import '../models/session.dart';
import '../models/pause.dart';
import 'database_service.dart';

class DbAdapters {
  final DatabaseService db;
  DbAdapters(this.db);

  Future<List<Session>> listSessionsByActivityModel(Activity a) {
    return db.listSessionsByActivityUid(a.uid);
  }

  Future<List<Pause>> listPausesBySessionModel(Session s) {
    return db.listPausesBySession(s.id);
  }

  Future<Duration> effectiveDurationFor(Session s) {
    return db.effectiveDurationFor(s);
  }
}
