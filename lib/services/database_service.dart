import 'dart:collection';
import 'dart:math';
import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/session.dart';
import '../models/pause.dart';

class DatabaseService extends ChangeNotifier {
  // ---------- Activités ----------
  final List<Activity> _activities = <Activity>[];
  List<Activity> get activities => UnmodifiableListView(_activities);

  Future<Activity> createActivity({
    required String name,
    required String emoji,
    required Color color,
    int? dailyGoalMinutes,
    int? weeklyGoalMinutes,
    int? monthlyGoalMinutes,
    int? yearlyGoalMinutes,
  }) async {
    final a = Activity(
      id: _genId(),
      name: name,
      emoji: emoji,
      color: color,
      dailyGoalMinutes: dailyGoalMinutes,
      weeklyGoalMinutes: weeklyGoalMinutes,
      monthlyGoalMinutes: monthlyGoalMinutes,
      yearlyGoalMinutes: yearlyGoalMinutes,
    );
    _activities.add(a);
    notifyListeners();
    return a;
  }

  void deleteActivity(String activityId) {
    _activities.removeWhere((a) => a.id == activityId);
    // supprime sessions/pauses liées
    final sessionIds = _sessions.where((s) => s.activityId == activityId).map((s) => s.id).toSet();
    _sessions.removeWhere((s) => s.activityId == activityId);
    _pausesBySession.removeWhere((sid, _) => sessionIds.contains(sid));
    _running.remove(activityId);
    _currentPause.remove(activityId);
    notifyListeners();
  }

  // ---------- Sessions & Pauses ----------
  final List<Session> _sessions = <Session>[];
  final Map<String, List<Pause>> _pausesBySession = <String, List<Pause>>{};

  List<Session> listSessionsByActivity(String activityId) {
    final out = _sessions.where((s) => s.activityId == activityId).toList();
    out.sort((a, b) => b.startAt.compareTo(a.startAt));
    return out;
  }

  List<Pause> listPausesBySession(String sessionId) {
    final list = _pausesBySession[sessionId] ?? const <Pause>[];
    final out = List<Pause>.from(list);
    out.sort((a, b) => a.startAt.compareTo(b.startAt));
    return out;
  }

  // --- Compat (anciens appels) ---
  List<Session> listSessionsByActivityModel(String activityId) =>
      listSessionsByActivity(activityId);
  List<Pause> listPausesBySessionModel(String activityId, String sessionId) =>
      listPausesBySession(sessionId);

  // ---------- Timer état courant ----------
  final Map<String, Session> _running = <String, Session>{};   // activityId -> session ouverte
  final Map<String, Pause> _currentPause = <String, Pause>{};  // activityId -> pause ouverte

  bool isRunning(String activityId) => _running.containsKey(activityId);
  bool isPaused(String activityId) => _currentPause.containsKey(activityId);

  Duration runningElapsed(String activityId) {
    final s = _running[activityId];
    if (s == null) return Duration.zero;

    final now = DateTime.now();
    int sec = now.difference(s.startAt).inSeconds;

    // soustraire pauses (y compris pause courante)
    final allPauses = <Pause>[];
    allPauses.addAll(_pausesBySession[s.id] ?? const []);
    final cp = _currentPause[activityId];
    if (cp != null && cp.endAt == null) {
      allPauses.add(cp);
    }
    for (final p in allPauses) {
      final pe = p.endAt ?? now;
      sec -= _overlapSec(s.startAt, now, p.startAt, pe);
    }
    if (sec < 0) sec = 0;
    return Duration(seconds: sec);
  }

  // ---------- Timer actions ----------
  Future<void> start(String activityId) async {
    if (_running[activityId] != null) return;
    final s = Session(
      id: _genId(),
      activityId: activityId,
      startAt: DateTime.now(),
    );
    _running[activityId] = s;
    _sessions.add(s);
    notifyListeners();
  }

  Future<void> togglePause(String activityId) async {
    final s = _running[activityId];
    if (s == null) return;

    final current = _currentPause[activityId];
    if (current == null) {
      final p = Pause(
        id: _genId(),
        sessionId: s.id,
        activityId: activityId,
        startAt: DateTime.now(),
      );
      (_pausesBySession[s.id] ??= <Pause>[]).add(p);
      _currentPause[activityId] = p;
    } else {
      final ended = current.copyWith(endAt: DateTime.now());
      final list = _pausesBySession[s.id];
      if (list != null) {
        final idx = list.indexWhere((x) => x.id == current.id);
        if (idx >= 0) list[idx] = ended;
      }
      _currentPause.remove(activityId);
    }
    notifyListeners();
  }

  Future<void> stop(String activityId) async {
    final s = _running.remove(activityId);
    if (s == null) return;

    // fermer pause courante s'il y en a une
    final current = _currentPause.remove(activityId);
    if (current != null) {
      final ended = current.copyWith(endAt: DateTime.now());
      final list = _pausesBySession[s.id];
      if (list != null) {
        final idx = list.indexWhere((x) => x.id == current.id);
        if (idx >= 0) list[idx] = ended;
      }
    }

    // clôturer la session
    final idxS = _sessions.indexWhere((x) => x.id == s.id);
    if (idxS >= 0) _sessions[idxS] = s.copyWith(endAt: DateTime.now());

    notifyListeners();
  }

  // ---------- Calculs ----------
  /// Durée effective d’une session donnée, à partir d’une liste de pauses (déjà triées).
  Duration effectiveDurationFor(Session s, List<Pause> pauses) {
    final end = s.endAt ?? DateTime.now();
    int sec = end.difference(s.startAt).inSeconds;
    for (final p in pauses) {
      final pe = p.endAt ?? end;
      sec -= _overlapSec(s.startAt, end, p.startAt, pe);
    }
    if (sec < 0) sec = 0;
    return Duration(seconds: sec);
  }

  /// Minutes loggées pour une activité sur un jour (00:00 → 24:00).
  int effectiveMinutesOnDay(String activityId, DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd = dayStart.add(const Duration(days: 1));
    final now = DateTime.now();

    int minutes = 0;

    // sessions recoupant le jour
    final sessions = _sessions.where((s) =>
    s.activityId == activityId &&
        s.startAt.isBefore(dayEnd) &&
        (s.endAt ?? now).isAfter(dayStart));

    for (final s in sessions) {
      final sFrom = s.startAt.isAfter(dayStart) ? s.startAt : dayStart;
      final sTo = (s.endAt ?? now).isBefore(dayEnd) ? (s.endAt ?? now) : dayEnd;

      // pauses de la session (inclut pause courante si ouverte sur cette session)
      final pauses = <Pause>[];
      pauses.addAll(_pausesBySession[s.id] ?? const []);
      final cp = _currentPause[activityId];
      if (cp != null && cp.sessionId == s.id && cp.endAt == null) {
        pauses.add(cp);
      }

      int sec = sTo.difference(sFrom).inSeconds;
      for (final p in pauses) {
        final pe = p.endAt ?? sTo;
        sec -= _overlapSec(sFrom, sTo, p.startAt, pe);
      }
      if (sec > 0) minutes += sec ~/ 60;
    }

    return max(0, minutes);
  }

  // ---------- Helpers ----------
  int _overlapSec(DateTime aStart, DateTime aEnd, DateTime bStart, DateTime bEnd) {
    final s = aStart.isAfter(bStart) ? aStart : bStart;
    final e = aEnd.isBefore(bEnd) ? aEnd : bEnd;
    final d = e.difference(s).inSeconds;
    return d > 0 ? d : 0;
  }

  String _genId() => DateTime.now().microsecondsSinceEpoch.toString();
}
