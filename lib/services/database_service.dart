import 'dart:collection';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/session.dart';
import '../models/pause.dart';

/// Base de données en mémoire + notifications UI.
class DatabaseService extends ChangeNotifier {
  final Map<String, Activity> _activities = {};
  final List<Session> _sessions = [];
  final List<Pause> _pauses = [];

  // ---------- Helpers ----------
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

  // ---------- Activities ----------
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

  // ---------- Sessions ----------
  /// Démarre une session si rien n'est en cours.
  Future<void> quickStart(String activityId) async {
    if (_currentSession(activityId) != null) return; // déjà en cours
    _sessions.add(Session(
      id: _newId(),
      activityId: activityId,
      startAt: DateTime.now(),
      endAt: null,
    ));
    notifyListeners();
  }

  /// Pause / Reprise la session courante s'il y en a une.
  Future<void> quickTogglePause(String activityId) async {
    final current = _currentSession(activityId);
    if (current == null) return;

    final open = _openPause(current.id);
    if (open != null) {
      final i = _pauses.indexWhere((p) => p.id == open.id);
      if (i >= 0) {
        _pauses[i] = open.copyWith(endAt: DateTime.now());
      }
    } else {
      _pauses.add(Pause(
        id: _newId(),
        sessionId: current.id,
        startAt: DateTime.now(),
        endAt: null,
      ));
    }
    notifyListeners();
  }

  /// Stoppe la session courante s'il y en a une.
  Future<void> quickStop(String activityId) async {
    final current = _currentSession(activityId);
    if (current == null) return;

    // ferme une pause ouverte
    final open = _openPause(current.id);
    if (open != null) {
      final pIdx = _pauses.indexWhere((p) => p.id == open.id);
      if (pIdx >= 0) _pauses[pIdx] = open.copyWith(endAt: DateTime.now());
    }

    // remplace la session par une version terminée (copyWith endAt)
    final sIdx = _sessions.indexWhere((s) => s.id == current.id);
    if (sIdx >= 0) {
      _sessions[sIdx] = current.copyWith(endAt: DateTime.now());
    }
    notifyListeners();
  }

  // ---------- Queries (synchro pour l'UI) ----------
  List<Session> listSessionsByActivity(String activityId) {
    final all = _sessionsForActivity(activityId);
    all.sort((a, b) => b.startAt.compareTo(a.startAt)); // récentes d'abord
    return UnmodifiableListView(all);
  }

  List<Pause> listPausesBySession(String sessionId) {
    final all = _pauses.where((p) => p.sessionId == sessionId).toList();
    all.sort((a, b) => a.startAt.compareTo(b.startAt));
    return UnmodifiableListView(all);
  }

  bool isRunning(String activityId) => _currentSession(activityId) != null;

  // ---------- Compat (APIs async attendues par StatsService) ----------
  Future<List<Session>> getSessionsByActivity(String activityId) async =>
      listSessionsByActivity(activityId);

  Future<List<Pause>> getPausesBySession(String sessionId) async =>
      listPausesBySession(sessionId);
}
