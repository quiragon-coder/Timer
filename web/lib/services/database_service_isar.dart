import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart';

import '../models/activity.dart';
import '../models/session.dart';
import '../models/pause.dart';
import '../utils/color_compat.dart';
import '../isar/activity_record.dart';
import '../isar/session_record.dart';
import '../isar/pause_record.dart';

/// A drop-in replacement for [DatabaseService] that persists to Isar.
class DatabaseServiceIsar extends ChangeNotifier {
  late final Isar _isar;

  // In-memory fast state for current sessions / pauses to keep UI sync-friendly.
  // Keys by activityUid for sessions; by sessionId for pauses.
  final Map<String, SessionRecord> _openSessions = {};
  final Map<int, PauseRecord> _openPauses = {};

  DatabaseServiceIsar();

  /// Must be awaited once before using any method to open the database and seed caches.
  static Future<DatabaseServiceIsar> init() async {
    final service = DatabaseServiceIsar();
    final dir = await getApplicationDocumentsDirectory();

    service._isar = await Isar.open(
      [
        ActivityRecordSchema,
        SessionRecordSchema,
        PauseRecordSchema,
      ],
      directory: dir.path,
      inspector: false,
    );

    // seed caches
    final openSessions = service._isar.sessionRecords.filter().endedAtIsNull().findAllSync();
    for (final s in openSessions) {
      service._openSessions[s.activityUid] = s;
      final p = service._isar.pauseRecords
          .filter()
          .sessionIdEqualTo(s.id)
          .and()
          .endedAtIsNull()
          .findFirstSync();
      if (p != null) service._openPauses[s.id] = p;
    }

    // Hydrate demo data if empty
    if (service._isar.activityRecords.countSync() == 0) {
      final now = DateTime.now();
      service._isar.writeTxnSync(() {
        // sample activities
        for (final a in [
          ActivityRecord()
            ..uid = 'a_study'
            ..name = 'Étude'
            ..emoji = '📚'
            ..colorValue = defaultBaseColor.value,
          ActivityRecord()
            ..uid = 'a_sport'
            ..name = 'Sport'
            ..emoji = '💪'
            ..colorValue = (defaultBaseColor).withValues(alpha: 0.9).value,
        ]) {
          service._isar.activityRecords.putSync(a);
        }
        // seed 5 sessions for Étude
        for (int i = 0; i < 5; i++) {
          final s = SessionRecord()
            ..activityUid = 'a_study'
            ..startedAt = now.subtract(Duration(days: i + 1, hours: 1));
          s.endedAt = s.startedAt.add(Duration(minutes: 30 + i * 10));
          service._isar.sessionRecords.putSync(s);
        }
      });
    }

    return service;
  }

  // ------------------ API mirrored from in-memory DatabaseService ------------------

  List<Activity> get activities {
    final items = _isar.activityRecords.where().sortByName().findAllSync();
    return items
        .map((r) => Activity(
              id: r.uid,
              name: r.name,
              emoji: r.emoji,
              color: Color(r.colorValue),
              dailyGoalMinutes: r.dailyGoalMinutes,
              weeklyGoalMinutes: r.weeklyGoalMinutes,
              monthlyGoalMinutes: r.monthlyGoalMinutes,
              yearlyGoalMinutes: r.yearlyGoalMinutes,
            ))
        .toList(growable: false);
  }

  Activity? getActivity(String id) {
    final r = _isar.activityRecords.filter().uidEqualTo(id).findFirstSync();
    if (r == null) return null;
    return Activity(
      id: r.uid,
      name: r.name,
      emoji: r.emoji,
      color: Color(r.colorValue),
      dailyGoalMinutes: r.dailyGoalMinutes,
      weeklyGoalMinutes: r.weeklyGoalMinutes,
      monthlyGoalMinutes: r.monthlyGoalMinutes,
      yearlyGoalMinutes: r.yearlyGoalMinutes,
    );
  }

  Future<void> createActivity(Activity a) async {
    _isar.writeTxnSync(() {
      final r = ActivityRecord()
        ..uid = a.id
        ..name = a.name
        ..emoji = a.emoji
        ..colorValue = a.color.value
        ..dailyGoalMinutes = a.dailyGoalMinutes
        ..weeklyGoalMinutes = a.weeklyGoalMinutes
        ..monthlyGoalMinutes = a.monthlyGoalMinutes
        ..yearlyGoalMinutes = a.yearlyGoalMinutes;
      _isar.activityRecords.putSync(r);
    });
    notifyListeners();
  }

  bool isRunning(String activityId) => _openSessions[activityId] != null;
  bool isPaused(String activityId) {
    final s = _openSessions[activityId];
    if (s == null) return false;
    return _openPauses[s.id] != null;
  }

  Duration runningElapsed(String activityId) {
    final s = _openSessions[activityId];
    if (s == null) return Duration.zero;

    DateTime end = DateTime.now();
    final pauses = listPausesBySessionId(s.id);
    int pausedMs = 0;
    for (final p in pauses) {
      final start = p.startAt;
      final e = p.endAt ?? DateTime.now();
      pausedMs += e.difference(start).inMilliseconds;
    }
    return end.difference(s.startedAt).minus(Duration(milliseconds: pausedMs));
  }

  /// Start a session. If already running, no-op.
  Future<void> start(String activityId) async {
    if (isRunning(activityId)) return;
    _isar.writeTxnSync(() {
      final s = SessionRecord()
        ..activityUid = activityId
        ..startedAt = DateTime.now();
      final id = _isar.sessionRecords.putSync(s);
      s.id = id;
      _openSessions[activityId] = s;
    });
    notifyListeners();
  }

  /// Toggle pause on the current session of an activity.
  Future<void> togglePause(String activityId) async {
    final s = _openSessions[activityId];
    if (s == null) return;
    _isar.writeTxnSync(() {
      final current = _openPauses[s.id];
      if (current == null) {
        final p = PauseRecord()
          ..sessionId = s.id
          ..startedAt = DateTime.now();
        final id = _isar.pauseRecords.putSync(p);
        p.id = id;
        _openPauses[s.id] = p;
      } else {
        current.endedAt = DateTime.now();
        _isar.pauseRecords.putSync(current);
        _openPauses.remove(s.id);
      }
    });
    notifyListeners();
  }

  /// Stop the current session.
  Future<void> stop(String activityId) async {
    final s = _openSessions[activityId];
    if (s == null) return;
    _isar.writeTxnSync(() {
      // Close pause if any
      final p = _openPauses[s.id];
      if (p != null) {
        p.endedAt = DateTime.now();
        _isar.pauseRecords.putSync(p);
        _openPauses.remove(s.id);
      }
      // End session
      s.endedAt = DateTime.now();
      _isar.sessionRecords.putSync(s);
      _openSessions.remove(activityId);
    });
    notifyListeners();
  }

  List<Session> listSessionsByActivity(String activityId) {
    final records = _isar.sessionRecords
        .filter()
        .activityUidEqualTo(activityId)
        .sortByStartedAtDesc()
        .findAllSync();
    return records
        .map((r) => Session(
              id: r.id,
              activityId: r.activityUid,
              startAt: r.startedAt,
              endAt: r.endedAt,
            ))
        .toList(growable: false);
  }

  List<Pause> listPausesBySessionId(int sessionId) {
    final records = _isar.pauseRecords
        .filter()
        .sessionIdEqualTo(sessionId)
        .sortByStartedAt()
        .findAllSync();
    return records
        .map((r) => Pause(
              id: r.id,
              sessionId: r.sessionId,
              startAt: r.startedAt,
              endAt: r.endedAt,
            ))
        .toList(growable: false);
  }

  Duration effectiveDurationFor(Session s) {
    final end = s.endAt ?? DateTime.now();
    final pauses = listPausesBySessionId(s.id);
    int pausedMs = 0;
    for (final p in pauses) {
      final pEnd = p.endAt ?? DateTime.now();
      pausedMs += pEnd.difference(p.startAt).inMilliseconds;
    }
    final effectiveMs = end.difference(s.startAt).inMilliseconds - pausedMs;
    return Duration(milliseconds: max(0, effectiveMs));
  }

  int effectiveMinutesOnDay(String activityId, DateTime day) {
    final startOfDay = DateTime(day.year, day.month, day.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));
    final sessions = _isar.sessionRecords
        .filter()
        .activityUidEqualTo(activityId)
        .and()
        .startedAtLessThan(endOfDay)
        .and()
        .group((q) => q.endedAtIsNull().or().endedAtGreaterThan(startOfDay))
        .findAllSync();

    int totalMs = 0;
    for (final s in sessions) {
      final sStart = s.startedAt.isBefore(startOfDay) ? startOfDay : s.startedAt;
      final sEnd = (s.endedAt ?? DateTime.now()).isAfter(endOfDay) ? endOfDay : (s.endedAt ?? DateTime.now());
      int ms = sEnd.difference(sStart).inMilliseconds;

      // subtract pauses overlap
      final pauses = _isar.pauseRecords
          .filter()
          .sessionIdEqualTo(s.id)
          .findAllSync();
      for (final p in pauses) {
        final pStart = p.startedAt.isBefore(startOfDay) ? startOfDay : p.startedAt;
        final pEndRaw = p.endedAt ?? DateTime.now();
        final pEnd = pEndRaw.isAfter(endOfDay) ? endOfDay : pEndRaw;
        if (pEnd.isAfter(pStart)) {
          ms -= pEnd.difference(pStart).inMilliseconds;
        }
      }
      totalMs += ms;
    }
    return Duration(milliseconds: max(0, totalMs)).inMinutes;
  }
}

extension _DurationMinus on Duration {
  Duration minus(Duration other) => Duration(milliseconds: inMilliseconds - other.inMilliseconds);
}
