import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../models/activity.dart';
import '../models/session.dart';
import '../models/pause.dart';

class DatabaseService {
  final Map<String, Activity> _activities = {};
  final Map<String, Session> _sessions = {};
  final Map<String, Pause> _pauses = {};

  final Map<String, List<String>> _activityToSessions = {};
  final Map<String, List<String>> _sessionToPauses = {};

  String _newId([String prefix = 'id_']) =>
      '$prefix${DateTime.now().microsecondsSinceEpoch}${UniqueKey()}';

  // -------- Activities --------
  Future<Activity> createActivity({
    required String name,
    required String emoji,
    required Color color,
    int? dailyGoalMinutes,
    int? weeklyGoalMinutes,
    int? monthlyGoalMinutes,
    int? yearlyGoalMinutes,
  }) async {
    final id = _newId('act_');
    final activity = Activity(
      id: id,
      name: name,
      emoji: emoji,
      color: color,
      dailyGoalMinutes: dailyGoalMinutes,
      weeklyGoalMinutes: weeklyGoalMinutes,
      monthlyGoalMinutes: monthlyGoalMinutes,
      yearlyGoalMinutes: yearlyGoalMinutes,
    );
    _activities[id] = activity;
    _activityToSessions.putIfAbsent(id, () => []);
    return activity;
  }

  Future<List<Activity>> getActivities() async {
    final list = _activities.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  Future<Activity?> getActivityById(String activityId) async {
    return _activities[activityId];
  }

  Future<Activity?> updateActivity(Activity updated) async {
    if (!_activities.containsKey(updated.id)) return null;
    _activities[updated.id] = updated;
    return updated;
  }

  Future<bool> deleteActivity(String activityId) async {
    if (!_activities.containsKey(activityId)) return false;
    final sessIds = List<String>.from(_activityToSessions[activityId] ?? const []);
    for (final sid in sessIds) {
      await deleteSession(sid);
    }
    _activities.remove(activityId);
    _activityToSessions.remove(activityId);
    return true;
  }

  // -------- Sessions --------
  Future<Session> startSession(String activityId) async {
    final active = await getActiveSessionForActivity(activityId);
    if (active != null) return active;
    final id = _newId('ses_');
    final s = Session(id: id, activityId: activityId, startAt: DateTime.now(), endAt: null);
    _sessions[id] = s;
    _activityToSessions.putIfAbsent(activityId, () => []).add(id);
    _sessionToPauses.putIfAbsent(id, () => []);
    return s;
  }

  Future<Session?> stopSession(String sessionId) async {
    final s = _sessions[sessionId];
    if (s == null) return null;
    if (s.endAt != null) return s;
    final currentPause = await getCurrentPause(sessionId);
    if (currentPause != null) {
      await unpauseSession(sessionId);
    }
    final finished = s.copyWith(endAt: DateTime.now());
    _sessions[sessionId] = finished;
    return finished;
  }

  Future<Session?> getActiveSessionForActivity(String activityId) async {
    final ids = _activityToSessions[activityId] ?? const [];
    for (final sid in ids.reversed) {
      final s = _sessions[sid];
      if (s != null && s.endAt == null) return s;
    }
    return null;
  }

  Future<List<Session>> getSessionsByActivity(String activityId) async {
    final ids = _activityToSessions[activityId] ?? const [];
    final list = ids.map((sid) => _sessions[sid]).whereType<Session>().toList()
      ..sort((a, b) {
        final aTime = a.endAt ?? a.startAt;
        final bTime = b.endAt ?? b.startAt;
        return bTime.compareTo(aTime);
      });
    return list;
  }

  Future<bool> deleteSession(String sessionId) async {
    final s = _sessions.remove(sessionId);
    if (s == null) return false;
    _activityToSessions[s.activityId]?.remove(sessionId);
    final pids = List<String>.from(_sessionToPauses[sessionId] ?? const []);
    for (final pid in pids) {
      _pauses.remove(pid);
    }
    _sessionToPauses.remove(sessionId);
    return true;
  }

  // -------- Pauses --------
  Future<Pause?> pauseSession(String sessionId) async {
    final s = _sessions[sessionId];
    if (s == null || s.endAt != null) return null;
    final current = await getCurrentPause(sessionId);
    if (current != null) return current;
    final id = _newId('pau_');
    final p = Pause(id: id, sessionId: sessionId, startAt: DateTime.now(), endAt: null);
    _pauses[id] = p;
    _sessionToPauses.putIfAbsent(sessionId, () => []).add(id);
    return p;
  }

  Future<Pause?> unpauseSession(String sessionId) async {
    final p = await getCurrentPause(sessionId);
    if (p == null) return null;
    final done = p.copyWith(endAt: DateTime.now());
    _pauses[p.id] = done;
    return done;
  }

  Future<Pause?> getCurrentPause(String sessionId) async {
    final ids = _sessionToPauses[sessionId] ?? const [];
    for (final pid in ids.reversed) {
      final p = _pauses[pid];
      if (p != null && p.endAt == null) return p;
    }
    return null;
  }

  Future<List<Pause>> getPausesBySession(String sessionId) async {
    final ids = _sessionToPauses[sessionId] ?? const [];
    final list = ids.map((pid) => _pauses[pid]).whereType<Pause>().toList()
      ..sort((a, b) {
        final aTime = a.endAt ?? a.startAt;
        final bTime = b.endAt ?? b.startAt;
        return bTime.compareTo(aTime);
      });
    return list;
  }

  // Quick controls
  Future<Session> quickStart(String activityId) => startSession(activityId);
  Future<void> quickTogglePause(String activityId) async {
    final s = await getActiveSessionForActivity(activityId);
    if (s == null) return;
    final p = await getCurrentPause(s.id);
    if (p == null) {
      await pauseSession(s.id);
    } else {
      await unpauseSession(s.id);
    }
  }
  Future<void> quickStop(String activityId) async {
    final s = await getActiveSessionForActivity(activityId);
    if (s != null) { await stopSession(s.id); }
  }

  // Export / Import
  Future<String> exportJson() async {
    final data = {
      'activities': _activities.values.map((a) => a.toJson()).toList(),
      'sessions': _sessions.values.map((s) => s.toJson()).toList(),
      'pauses': _pauses.values.map((p) => p.toJson()).toList(),
    };
    return const JsonEncoder.withIndent('  ').convert(data);
  }

  Future<void> importJson(String jsonStr) async {
    final map = json.decode(jsonStr);
    _activities.clear();
    _sessions.clear();
    _pauses.clear();
    _activityToSessions.clear();
    _sessionToPauses.clear();

    for (final raw in (map['activities'] as List? ?? const [])) {
      final a = Activity.fromJson(Map<String, dynamic>.from(raw as Map));
      _activities[a.id] = a;
      _activityToSessions[a.id] = [];
    }
    for (final raw in (map['sessions'] as List? ?? const [])) {
      final s = Session.fromJson(Map<String, dynamic>.from(raw as Map));
      _sessions[s.id] = s;
      _activityToSessions.putIfAbsent(s.activityId, () => []).add(s.id);
      _sessionToPauses.putIfAbsent(s.id, () => []);
    }
    for (final raw in (map['pauses'] as List? ?? const [])) {
      final p = Pause.fromJson(Map<String, dynamic>.from(raw as Map));
      _pauses[p.id] = p;
      _sessionToPauses.putIfAbsent(p.sessionId, () => []).add(p.id);
    }
  }

  Future<void> resetAll() async {
    _activities.clear();
    _sessions.clear();
    _pauses.clear();
    _activityToSessions.clear();
    _sessionToPauses.clear();
  }
}
