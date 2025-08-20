// lib/services/database_service.dart
import 'dart:collection';
import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/session.dart';
import '../models/pause.dart';

/// Base de données en mémoire + notifications UI.
class DatabaseService extends ChangeNotifier {
  // ------- Storage (in-memory) -------
  final Map<String, Activity> _activities = <String, Activity>{};
  final List<Session> _sessions = <Session>[];
  final List<Pause> _pauses = <Pause>[];

  // Exposition en lecture (synchrone) pour l’UI
  List<Activity> get activities =>
      _activities.values.toList(growable: false);
  Activity? activityById(String id) => _activities[id];

  // ------- Helpers -------
  String _newId() => DateTime.now().microsecondsSinceEpoch.toString();

  List<Session> _sessionsForActivity(String activityId) =>
      _sessions.where((s) => s.activityId == activityId).toList();

  Session? _currentSession(String activityId) {
    try {
      return _sessionsForActivity(activityId).lastWhere((s) => s.endAt == null);
    } catch (_) {
      return null;
    }
  }

  Pause? _openPause(String sessionId) {
    try {
      return _pauses
          .where((p) => p.sessionId == sessionId)
          .lastWhere((p) => p.endAt == null);
    } catch (_) {
      return null;
    }
  }

  // ------- Activities -------
  Future<Activity> createActivity({
    required String name,
    required String emoji,
    required Color color,
    int? dailyGoalMinutes,
    int? weeklyGoalMinutes,
    int? monthlyGoalMinutes,
    int? yearlyGoalMinutes,
  }) async {
    final id = _newId();
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
    _activities[id] = a;
    notifyListeners();
    return a;
  }

  Future<List<Activity>> getActivities() async =>
      _activities.values.toList(growable: false);

  void updateActivity(Activity updated) {
    _activities[updated.id] = updated;
    notifyListeners();
  }

  // ------- Sessions -------
  Future<void> quickStart(String activityId) async {
    if (_currentSession(activityId) != null) return; // déjà en cours
    _sessions.add(
      Session(
        id: _newId(),
        activityId: activityId,
        startAt: DateTime.now(),
        endAt: null,
      ),
    );
    notifyListeners();
  }

  Future<void> quickTogglePause(String activityId) async {
    final current = _currentSession(activityId);
    if (current == null) return;

    final open = _openPause(current.id);
    if (open != null) {
      final idx = _pauses.indexWhere((p) => p.id == open.id);
      if (idx >= 0) {
        _pauses[idx] = open.copyWith(endAt: DateTime.now());
      }
    } else {
      _pauses.add(
        Pause(
          id: _newId(),
          sessionId: current.id,
          startAt: DateTime.now(),
          endAt: null,
        ),
      );
    }
    notifyListeners();
  }

  Future<void> quickStop(String activityId) async {
    final current = _currentSession(activityId);
    if (current == null) return;

    final open = _openPause(current.id);
    if (open != null) {
      final pIdx = _pauses.indexWhere((p) => p.id == open.id);
      if (pIdx >= 0) {
        _pauses[pIdx] = open.copyWith(endAt: DateTime.now());
      }
    }

    final sIdx = _sessions.indexWhere((s) => s.id == current.id);
    if (sIdx >= 0) {
      _sessions[sIdx] = current.copyWith(endAt: DateTime.now());
    }
    notifyListeners();
  }

  // ------- Queries -------
  List<Session> listSessionsByActivity(String activityId) {
    final all = _sessionsForActivity(activityId);
    all.sort((a, b) => b.startAt.compareTo(a.startAt));
    return UnmodifiableListView(all);
  }

  List<Pause> listPausesBySession(String sessionId) {
    final all = _pauses.where((p) => p.sessionId == sessionId).toList();
    all.sort((a, b) => a.startAt.compareTo(b.startAt));
    return UnmodifiableListView(all);
  }

  bool isRunning(String activityId) => _currentSession(activityId) != null;

  bool isPaused(String activityId) {
    final s = _currentSession(activityId);
    if (s == null) return false;
    return _openPause(s.id) != null;
  }

  Duration runningElapsed(String activityId) {
    final s = _currentSession(activityId);
    if (s == null) return Duration.zero;

    final pause = _openPause(s.id);
    final end = pause != null ? pause.startAt : DateTime.now();
    return end.difference(s.startAt) - _pausedAccumulated(s.id, until: end);
  }

  Duration _pausedAccumulated(String sessionId, {DateTime? until}) {
    final pauses = listPausesBySession(sessionId);
    final limit = until ?? DateTime.now();
    var total = Duration.zero;

    for (final p in pauses) {
      final stop = (p.endAt ?? limit).isAfter(limit) ? limit : (p.endAt ?? limit);
      if (stop.isAfter(p.startAt)) {
        total += stop.difference(p.startAt);
      }
    }
    return total.isNegative ? Duration.zero : total;
  }

  // ------- Compat async -------
  Future<List<Session>> getSessionsByActivity(String activityId) async =>
      listSessionsByActivity(activityId);

  Future<List<Pause>> getPausesBySession(String sessionId) async =>
      listPausesBySession(sessionId);
}
