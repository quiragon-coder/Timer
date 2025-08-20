import 'dart:collection';
import 'package:flutter/material.dart';
import '../models/activity.dart';
import '../models/session.dart';
import '../models/pause.dart';

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
      return _sessionsForActivity(activityId)
          .lastWhere((s) => s.endAt == null);
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
  /// Start (no-op si déjà en cours)
  Future<void> quickStart(String activityId) async {
    final current = _currentSession(activityId);
    if (current != null) return; // déjà en cours
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

  /// Pause / Unpause
  Future<void> quickTogglePause(String activityId) async {
    final current = _currentSession(activityId);
    if (current == null) return; // rien à pauser

    final open = _openPause(current.id);
    if (open != null) {
      // Unpause -> on ferme la pause
      open.endAt = DateTime.now();
    } else {
      // Pause -> on ouvre une pause
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

  /// Stop (no-op si rien en cours)
  Future<void> quickStop(String activityId) async {
    final current = _currentSession(activityId);
    if (current == null) return;

    // Si une pause est ouverte, on la ferme
    final open = _openPause(current.id);
    if (open != null) {
      open.endAt = DateTime.now();
    }

    current.endAt = DateTime.now();
    notifyListeners();
  }

  // ---------- Queries ----------
  /// Liste des sessions (synchrone, ça évite d'utiliser un FutureBuilder)
  List<Session> listSessionsByActivity(String activityId) {
    final all = _sessionsForActivity(activityId);
    all.sort((a, b) => b.startAt.compareTo(a.startAt)); // récentes d'abord
    return UnmodifiableListView(all);
  }

  /// Pauses d'une session
  List<Pause> listPausesBySession(String sessionId) {
    final all = _pauses.where((p) => p.sessionId == sessionId).toList();
    all.sort((a, b) => a.st
