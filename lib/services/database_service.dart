import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:path_provider/path_provider.dart' as path;

import '../models/activity.dart';
import '../models/session.dart';
import '../models/pause.dart';

class DatabaseService {
  DatabaseService._();
  static final DatabaseService instance = DatabaseService._();

  Isar? _isar;

  /// Mémoire (pour l’UI)
  final List<Activity> activities = [];
  final Map<String, Session> _runningByActivity = {}; // activityId -> session en cours
  final Map<String, Pause> _currentPauseByActivity = {}; // activityId -> pause ouverte

  Future<void> init() async {
    if (_isar != null) return;

    if (!kIsWeb) {
      final dir = await path.getApplicationDocumentsDirectory();
      _isar = await Isar.open(
        [ActivitySchema, SessionSchema, PauseSchema],
        directory: dir.path,
      );
    } else {
      _isar = await Isar.open([ActivitySchema, SessionSchema, PauseSchema]);
    }

    // Charger les activités
    activities
      ..clear()
      ..addAll(await _isar!.activitys.where().findAll());

    // Sessions ouvertes & pauses ouvertes
    final openSessions = await _isar!.sessions.filter().endAtIsNull().findAll();
    for (final s in openSessions) {
      _runningByActivity[s.activityId] = s;
      final openPauses = await _isar!.pauses
          .filter()
          .sessionIdEqualTo(s.id)
          .and()
          .endAtIsNull()
          .findAll();
      if (openPauses.isNotEmpty) {
        _currentPauseByActivity[s.activityId] = openPauses.last;
      }
    }
  }

  // ----------------- CRUD Activités -----------------
  Future<Activity> createActivity({
    required String name,
    required String emoji,
    required int colorValue,
    int dailyGoalMinutes = 0,
    int weeklyGoalMinutes = 0,
    int monthlyGoalMinutes = 0,
    int yearlyGoalMinutes = 0,
  }) async {
    await init();
    final id = _genId();
    final a = Activity(
      id: id,
      name: name,
      emoji: emoji,
      color: Color(colorValue),
      dailyGoalMinutes: dailyGoalMinutes,
      weeklyGoalMinutes: weeklyGoalMinutes,
      monthlyGoalMinutes: monthlyGoalMinutes,
      yearlyGoalMinutes: yearlyGoalMinutes,
    );
    await _isar!.writeTxn(() async {
      await _isar!.activitys.put(a);
    });
    activities.add(a);
    return a;
  }

  Future<void> updateActivity(Activity a) async {
    await init();
    await _isar!.writeTxn(() async {
      await _isar!.activitys.put(a);
    });
    final idx = activities.indexWhere((x) => x.id == a.id);
    if (idx >= 0) activities[idx] = a;
  }

  Future<void> deleteActivity(String activityId) async {
    await init();
    await _isar!.writeTxn(() async {
      final sess = await _isar!.sessions.filter().activityIdEqualTo(activityId).findAll();
      final ids = sess.map((e) => e.id).toList();
      await _isar!.pauses.filter().sessionIdIn(ids).deleteAll();
      await _isar!.sessions.filter().activityIdEqualTo(activityId).deleteAll();
      await _isar!.activitys.filter().idEqualTo(activityId).deleteAll();
    });
    activities.removeWhere((a) => a.id == activityId);
    _runningByActivity.remove(activityId);
    _currentPauseByActivity.remove(activityId);
  }

  // ----------------- Timer -----------------
  bool isRunning(String activityId) => _runningByActivity.containsKey(activityId);
  bool isPaused(String activityId) => _currentPauseByActivity.containsKey(activityId);

  Future<void> start(String activityId) async {
    await init();
    if (_runningByActivity[activityId] != null) return;
    final s = Session(
      id: _genId(),
      activityId: activityId,
      startAt: DateTime.now(),
    );
    await _isar!.writeTxn(() async {
      await _isar!.sessions.put(s);
    });
    _runningByActivity[activityId] = s;
    _currentPauseByActivity.remove(activityId);
  }

  Future<void> togglePause(String activityId) async {
    await init();
    final s = _runningByActivity[activityId];
    if (s == null) return;

    final current = _currentPauseByActivity[activityId];
    if (current == null) {
      final p = Pause(
        id: _genId(),
        sessionId: s.id,
        activityId: activityId,
        startAt: DateTime.now(),
      );
      await _isar!.writeTxn(() async {
        await _isar!.pauses.put(p);
      });
      _currentPauseByActivity[activityId] = p;
    } else {
      current.endAt = DateTime.now();
      await _isar!.writeTxn(() async {
        await _isar!.pauses.put(current);
      });
      _currentPauseByActivity.remove(activityId);
    }
  }

  Future<void> stop(String activityId) async {
    await init();
    final s = _runningByActivity[activityId];
    if (s == null) return;

    final p = _currentPauseByActivity[activityId];
    if (p != null) {
      p.endAt = DateTime.now();
      await _isar!.writeTxn(() async {
        await _isar!.pauses.put(p);
      });
      _currentPauseByActivity.remove(activityId);
    }

    s.endAt = DateTime.now();
    await _isar!.writeTxn(() async {
      await _isar!.sessions.put(s);
    });
    _runningByActivity.remove(activityId);
  }

  Duration runningElapsed(String activityId) {
    final s = _runningByActivity[activityId];
    if (s == null) return Duration.zero;
    final now = DateTime.now();
    final pauses = _currentPauseByActivity.containsKey(activityId)
        ? <Pause>[_currentPauseByActivity[activityId]!]
        : <Pause>[];
    final eff = _effectiveDurationBetween(s.startAt, now, pauses);
    return eff < Duration.zero ? Duration.zero : eff;
  }

  // ----------------- Listage / calculs -----------------
  List<Session> listSessionsByActivityModel(String activityId) {
    return _isar!.sessions
        .filter()
        .activityIdEqualTo(activityId)
        .sortByStartAtDesc()
        .findAllSync();
  }

  List<Pause> listPausesBySessionModel(String activityId, String sessionId) {
    return _isar!.pauses
        .filter()
        .sessionIdEqualTo(sessionId)
        .sortByStartAt()
        .findAllSync();
  }

  Duration effectiveDurationFor(Session s, List<Pause> pauses) {
    final end = s.endAt ?? DateTime.now();
    return _effectiveDurationBetween(s.startAt, end, pauses);
  }

  /// Minutes loggées sur un jour (00:00 → 23:59)
  int effectiveMinutesOnDay(String activityId, DateTime day) {
    final startDay = DateTime(day.year, day.month, day.day);
    final endDay = startDay.add(const Duration(days: 1));

    final sessions = _isar!.sessions
        .filter()
        .activityIdEqualTo(activityId)
        .and()
        .startAtLessThan(endDay)
        .and()
        .group((q) => q.endAtIsNull().or().endAtGreaterThan(startDay))
        .findAllSync();

    int minutes = 0;
    for (final s in sessions) {
      final sStart = s.startAt.isAfter(startDay) ? s.startAt : startDay;
      final sEnd = (s.endAt ?? DateTime.now()).isBefore(endDay) ? (s.endAt ?? DateTime.now()) : endDay;

      final pauses = _isar!.pauses.filter().sessionIdEqualTo(s.id).findAllSync();
      final eff = _effectiveDurationBetween(sStart, sEnd, pauses);
      minutes += eff.inMinutes;
    }
    return max(0, minutes);
  }

  // ----------------- Helpers -----------------
  Duration _effectiveDurationBetween(DateTime start, DateTime end, List<Pause> pauses) {
    if (!end.isAfter(start)) return Duration.zero;
    int total = end.difference(start).inSeconds;

    for (final p in pauses) {
      final ps = p.startAt;
      final pe = p.endAt ?? end;
      final overlap = _overlapInSeconds(start, end, ps, pe);
      total -= overlap;
    }
    if (total < 0) total = 0;
    return Duration(seconds: total);
  }

  int _overlapInSeconds(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
    final s = aStart.isAfter(bStart) ? aStart : bStart;
    final e = aEnd.isBefore(bEnd) ? aEnd : bEnd;
    final d = e.difference(s).inSeconds;
    return d > 0 ? d : 0;
  }

  String _genId() => DateTime.now().millisecondsSinceEpoch.toString();
}
