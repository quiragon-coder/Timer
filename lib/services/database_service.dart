import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/activity.dart';
import '../models/session.dart';
import '../models/pause.dart';

class DatabaseService {
  static final DatabaseService _i = DatabaseService._();
  DatabaseService._();
  factory DatabaseService() => _i;

  Isar? _isar;

  Future<Isar> _getIsar() async {
    if (_isar != null) return _isar!;
    final dir = await getApplicationDocumentsDirectory();
    _isar = await Isar.open(
      schemas: [ActivitySchema, SessionSchema, PauseSchema],
      directory: dir.path,
      inspector: false,
    );
    return _isar!;
  }

  // ---------------- Activities ----------------

  Future<Activity> upsertActivity({
    required String uid,
    required String name,
    required String emoji,
    required int colorValue,
    int? dailyGoalMinutes,
    int? weeklyGoalMinutes,
    int? monthlyGoalMinutes,
    int? yearlyGoalMinutes,
  }) async {
    final isar = await _getIsar();
    final existing = await isar.activitys.filter().uidEqualTo(uid).findFirst();

    final act = existing ?? (Activity()..uid = uid);
    act
      ..name = name
      ..emoji = emoji
      ..colorValue = colorValue
      ..dailyGoalMinutes = dailyGoalMinutes
      ..weeklyGoalMinutes = weeklyGoalMinutes
      ..monthlyGoalMinutes = monthlyGoalMinutes
      ..yearlyGoalMinutes = yearlyGoalMinutes;

    await isar.writeTxn(() async => await isar.activitys.put(act));
    return act;
  }

  Future<List<Activity>> listActivities() async {
    final isar = await _getIsar();
    return isar.activitys.where().sortByName().findAll();
  }

  Future<Activity?> getActivityByUid(String uid) async {
    final isar = await _getIsar();
    return isar.activitys.filter().uidEqualTo(uid).findFirst();
  }

  Future<void> deleteActivity(String uid) async {
    final isar = await _getIsar();
    final a = await getActivityByUid(uid);
    if (a == null) return;
    await isar.writeTxn(() async {
      final sessions = await isar.sessions.filter().activityUidEqualTo(uid).findAll();
      for (final s in sessions) {
        await isar.pauses.filter().sessionIdEqualTo(s.id).deleteAll();
      }
      await isar.sessions.filter().activityUidEqualTo(uid).deleteAll();
      await isar.activitys.delete(a.id);
    });
  }

  // ---------------- Sessions ----------------

  Future<Session> startSession(String activityUid, DateTime now) async {
    final isar = await _getIsar();
    final s = Session()
      ..activityUid = activityUid
      ..startAt = now;
    await isar.writeTxn(() async => await isar.sessions.put(s));
    return s;
  }

  Future<Session?> getRunningSession(String activityUid) async {
    final isar = await _getIsar();
    return isar.sessions
        .filter()
        .activityUidEqualTo(activityUid)
        .endAtIsNull()
        .sortByStartAtDesc()
        .findFirst();
  }

  Future<void> stopSession(Id sessionId, DateTime now) async {
    final isar = await _getIsar();
    final s = await isar.sessions.get(sessionId);
    if (s == null) return;
    s.endAt ??= now;
    await isar.writeTxn(() async => await isar.sessions.put(s));
  }

  Future<List<Session>> listSessionsByActivityUid(String activityUid) async {
    final isar = await _getIsar();
    return isar.sessions
        .filter()
        .activityUidEqualTo(activityUid)
        .sortByStartAtDesc()
        .findAll();
  }

  // ---------------- Pauses ----------------

  Future<Pause> startPause({
    required String activityUid,
    required Id sessionId,
    required DateTime now,
  }) async {
    final isar = await _getIsar();
    final p = Pause()
      ..activityUid = activityUid
      ..sessionId = sessionId
      ..startAt = now;
    await isar.writeTxn(() async => await isar.pauses.put(p));
    return p;
  }

  Future<void> stopPause(Id pauseId, DateTime now) async {
    final isar = await _getIsar();
    final p = await isar.pauses.get(pauseId);
    if (p == null) return;
    p.endAt ??= now;
    await isar.writeTxn(() async => await isar.pauses.put(p));
  }

  Future<List<Pause>> listPausesBySession(Id sessionId) async {
    final isar = await _getIsar();
    return isar.pauses.filter().sessionIdEqualTo(sessionId).findAll();
  }

  // ---------------- Calculs / Stats ----------------

  /// Minutes effectives sur un jour (sessions - pauses chevauchantes)
  Future<int> effectiveMinutesOnDay({
    required String activityUid,
    required DateTime date,
  }) async {
    final isar = await _getIsar();
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    final sessions = await isar.sessions
        .filter()
        .activityUidEqualTo(activityUid)
        .startAtLessThan(end)
        .and()
        .group((q) => q.endAtGreaterThan(start).or().endAtIsNull())
        .findAll();

    int minutes = 0;
    for (final s in sessions) {
      final sStart = s.startAt.isBefore(start) ? start : s.startAt;
      final sEnd = (s.endAt ?? DateTime.now()).isAfter(end) ? end : (s.endAt ?? DateTime.now());
      if (!sEnd.isAfter(sStart)) continue;

      var effMs = sEnd.difference(sStart).inMilliseconds;

      final pauses = await listPausesBySession(s.id);
      for (final p in pauses) {
        final pStart = p.startAt.isBefore(start) ? start : p.startAt;
        final pEnd = (p.endAt ?? DateTime.now()).isAfter(end) ? end : (p.endAt ?? DateTime.now());
        final overlapStart = pStart.isAfter(sStart) ? pStart : sStart;
        final overlapEnd = pEnd.isBefore(sEnd) ? pEnd : sEnd;
        if (overlapEnd.isAfter(overlapStart)) {
          effMs -= overlapEnd.difference(overlapStart).inMilliseconds;
        }
      }
      minutes += (effMs ~/ 60000);
    }
    return minutes;
  }

  /// Durée effective d’une session (utile pour historiques)
  Future<Duration> effectiveDurationFor(Session s) async {
    final isar = await _getIsar();
    final end = s.endAt ?? DateTime.now();
    var effMs = end.difference(s.startAt).inMilliseconds;

    final pauses = await isar.pauses.filter().sessionIdEqualTo(s.id).findAll();
    for (final p in pauses) {
      final pEnd = p.endAt ?? DateTime.now();
      final overlapStart = p.startAt.isAfter(s.startAt) ? p.startAt : s.startAt;
      final overlapEnd = pEnd.isBefore(end) ? pEnd : end;
      if (overlapEnd.isAfter(overlapStart)) {
        effMs -= overlapEnd.difference(overlapStart).inMilliseconds;
      }
    }
    return Duration(milliseconds: effMs < 0 ? 0 : effMs);
  }
}
