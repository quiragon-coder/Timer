import 'dart:collection';
import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/session.dart';
import '../models/pause.dart';

class DatabaseService extends ChangeNotifier {
  // ---------- Activités ----------
  final List<Activity> _activities = <Activity>[];
  List<Activity> get activities => UnmodifiableListView(_activities);

  Activity createActivity({
    required String name,
    required String emoji,
    required Color color,
    int? dailyGoalMinutes,
    int? weeklyGoalMinutes,
    int? monthlyGoalMinutes,
    int? yearlyGoalMinutes,
  }) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final a = Activity(
      id: id,
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

  Activity updateActivity(Activity updated) {
    final i = _activities.indexWhere((x) => x.id == updated.id);
    if (i >= 0) {
      _activities[i] = updated;
      notifyListeners();
    }
    return updated;
  }

  // ---------- Sessions / Pauses ----------
  final Map<String, List<Session>> _sessionsByActivity = {};
  final Map<String, List<Pause>> _pausesBySession = {};

  Map<String, List<Session>> get sessions =>
      UnmodifiableMapView(_sessionsByActivity);
  Map<String, List<Pause>> get pauses =>
      UnmodifiableMapView(_pausesBySession);

  final Map<String, Session> _currentByActivity = {};
  final Map<String, Pause> _currentPauseBySession = {};

  // Aliases attendus par l'ancien code
  List<Session> getSessionsByActivity(String activityId) =>
      UnmodifiableListView(_sessionsByActivity[activityId] ?? const []);
  List<Session> listSessionsByActivity(String activityId) =>
      getSessionsByActivity(activityId);
  List<Session> sessionsByActivity(String activityId) =>
      getSessionsByActivity(activityId);

  List<Pause> getPausesBySession(String sessionId) =>
      UnmodifiableListView(_pausesBySession[sessionId] ?? const []);
  List<Pause> listPausesBySession(String sessionId) =>
      getPausesBySession(sessionId);

  bool isRunning(String activityId) => _currentByActivity[activityId] != null;

  bool isPaused(String activityId) {
    final s = _currentByActivity[activityId];
    if (s == null) return false;
    final p = _currentPauseBySession[s.id];
    return p?.endAt == null;
  }

  DateTime? currentSessionStart(String activityId) =>
      _currentByActivity[activityId]?.startAt;

  Duration runningElapsed(String activityId) {
    final s = _currentByActivity[activityId];
    if (s == null) return Duration.zero;
    final end = DateTime.now();
    final pauses = _pausesBySession[s.id] ?? const [];
    var paused = Duration.zero;
    for (final p in pauses) {
      final pEnd = p.endAt ?? end;
      paused += pEnd.difference(p.startAt);
    }
    return end.difference(s.startAt) - paused;
  }

  // ---------- Actions rapides ----------
  void quickStart(String activityId) {
    if (_currentByActivity[activityId] != null) return;
    final s = Session(
      id: 's_${DateTime.now().microsecondsSinceEpoch}',
      activityId: activityId,
      startAt: DateTime.now(),
      endAt: null,
    );
    (_sessionsByActivity[activityId] ??= []).add(s);
    _currentByActivity[activityId] = s;
    notifyListeners();
  }

  void quickTogglePause(String activityId) {
    final s = _currentByActivity[activityId];
    if (s == null) return;

    final current = _currentPauseBySession[s.id];
    if (current == null || current.endAt != null) {
      // démarrer une pause
      final p = Pause(
        id: 'p_${DateTime.now().microsecondsSinceEpoch}',
        sessionId: s.id,
        startAt: DateTime.now(),
        endAt: null,
      );
      (_pausesBySession[s.id] ??= []).add(p);
      _currentPauseBySession[s.id] = p;
    } else {
      // terminer la pause -> remplacer l'objet (champs final)
      final ended = Pause(
        id: current.id,
        sessionId: current.sessionId,
        startAt: current.startAt,
        endAt: DateTime.now(),
      );
      final list = _pausesBySession[s.id]!;
      final idx = list.indexWhere((x) => x.id == current.id);
      if (idx >= 0) list[idx] = ended;
      _currentPauseBySession.remove(s.id);
    }
    notifyListeners();
  }

  void quickStop(String activityId) {
    final s = _currentByActivity[activityId];
    if (s == null) return;

    // clôturer une pause en cours
    final current = _currentPauseBySession[s.id];
    if (current != null && current.endAt == null) {
      final endedPause = Pause(
        id: current.id,
        sessionId: current.sessionId,
        startAt: current.startAt,
        endAt: DateTime.now(),
      );
      final pList = _pausesBySession[s.id]!;
      final pIdx = pList.indexWhere((x) => x.id == current.id);
      if (pIdx >= 0) pList[pIdx] = endedPause;
      _currentPauseBySession.remove(s.id);
    }

    // clôturer la session -> remplacer l'objet (champs final)
    final ended = Session(
      id: s.id,
      activityId: s.activityId,
      startAt: s.startAt,
      endAt: DateTime.now(),
    );
    final list = _sessionsByActivity[activityId]!;
    final idx = list.indexWhere((x) => x.id == s.id);
    if (idx >= 0) list[idx] = ended;

    _currentByActivity.remove(activityId);
    notifyListeners();
  }

  // ---------- Aide stats ----------
  int effectiveMinutes(Session s) {
    final end = s.endAt ?? DateTime.now();
    var paused = Duration.zero;
    for (final p in _pausesBySession[s.id] ?? const []) {
      final pEnd = p.endAt ?? end;
      paused += pEnd.difference(p.startAt);
    }
    final d = end.difference(s.startAt) - paused;
    final m = d.inMinutes;
    return m < 0 ? 0 : m;
  }

  Future<void> start(String activityId) async {
    // Wrapper for widget compatibility
    return quickStart(activityId);
  }
  Future<void> togglePause(String activityId) async {
    // Wrapper for widget compatibility
    return quickTogglePause(activityId);
  }
  Future<void> stop(String activityId) async {
    // Wrapper for widget compatibility
    return quickStop(activityId);
  }
}
