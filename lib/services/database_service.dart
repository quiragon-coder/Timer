import 'dart:collection';
import 'package:flutter/material.dart';

import '../models/activity.dart';

/// Modèles internes simples pour les sessions et les pauses.
/// (on les garde ici pour éviter les conflits et faciliter la maintenance)
class Session {
  final String id;
  final String activityId;
  final DateTime startAt;
  DateTime? endAt;

  Session({
    required this.id,
    required this.activityId,
    required this.startAt,
    this.endAt,
  });

  bool get isRunning => endAt == null;
}

class Pause {
  final String id;
  final String sessionId;
  final DateTime startAt;
  DateTime? endAt;

  Pause({
    required this.id,
    required this.sessionId,
    required this.startAt,
    this.endAt,
  });

  bool get isOngoing => endAt == null;
}

/// Service “base de données” en mémoire.
/// Il notifie via ChangeNotifier (utilisé par Riverpod).
class DatabaseService extends ChangeNotifier {
  // --- Activités ------------------------------------------------------------
  final List<Activity> _activities = <Activity>[];

  /// Liste non modifiable à exposer publiquement
  List<Activity> get activities => UnmodifiableListView(_activities);

  /// Création d’une activité
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

  /// Mise à jour partielle d’une activité (utilisé quand tu modifies les objectifs)
  Activity updateActivity(Activity updated) {
    final i = _activities.indexWhere((x) => x.id == updated.id);
    if (i >= 0) {
      _activities[i] = updated;
      notifyListeners();
    }
    return updated;
  }

  // --- Sessions & Pauses ----------------------------------------------------
  final Map<String, List<Session>> _sessionsByActivity = {};
  final Map<String, List<Pause>> _pausesBySession = {};

  // Exposition en lecture seule – pour compatibilité avec
  // le code qui fait `db.sessions[...]` et `db.pauses[...]`.
  Map<String, List<Session>> get sessions =>
      UnmodifiableMapView(_sessionsByActivity);
  Map<String, List<Pause>> get pauses =>
      UnmodifiableMapView(_pausesBySession);

  /// Session en cours par activité
  final Map<String, Session> _currentByActivity = {};
  /// Pause en cours par session
  final Map<String, Pause> _currentPauseBySession = {};

  List<Session> getSessionsByActivity(String activityId) {
    return UnmodifiableListView(_sessionsByActivity[activityId] ?? const []);
  }

  List<Pause> getPausesBySession(String sessionId) {
    return UnmodifiableListView(_pausesBySession[sessionId] ?? const []);
  }

  bool isRunning(String activityId) => _currentByActivity[activityId] != null;
  bool isPaused(String activityId) {
    final s = _currentByActivity[activityId];
    if (s == null) return false;
    final p = _currentPauseBySession[s.id];
    return p?.isOngoing == true;
  }

  /// Durée écoulée effective (maintenant - startAt - pauses)
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

  // --- Actions rapides (Start / Pause / Resume / Stop) ----------------------

  /// Démarrer une session (si aucune en cours pour cette activité)
  void quickStart(String activityId) {
    if (_currentByActivity[activityId] != null) return;

    final s = Session(
      id: 's_${DateTime.now().microsecondsSinceEpoch}',
      activityId: activityId,
      startAt: DateTime.now(),
    );
    (_sessionsByActivity[activityId] ??= []).add(s);
    _currentByActivity[activityId] = s;
    notifyListeners();
  }

  /// Pause <-> Reprendre
  void quickTogglePause(String activityId) {
    final s = _currentByActivity[activityId];
    if (s == null) return;

    final currentPause = _currentPauseBySession[s.id];
    if (currentPause == null || !currentPause.isOngoing) {
      // On démarre une pause
      final p = Pause(
        id: 'p_${DateTime.now().microsecondsSinceEpoch}',
        sessionId: s.id,
        startAt: DateTime.now(),
      );
      (_pausesBySession[s.id] ??= []).add(p);
      _currentPauseBySession[s.id] = p;
    } else {
      // On termine la pause
      currentPause.endAt = DateTime.now();
      _currentPauseBySession.remove(s.id);
    }
    notifyListeners();
  }

  /// Arrêter la session en cours (et fermer la pause si ouverte)
  void quickStop(String activityId) {
    final s = _currentByActivity[activityId];
    if (s == null) return;

    // clôture pause éventuelle
    final p = _currentPauseBySession[s.id];
    if (p != null && p.isOngoing) {
      p.endAt = DateTime.now();
      _currentPauseBySession.remove(s.id);
    }

    s.endAt = DateTime.now();
    _currentByActivity.remove(activityId);
    notifyListeners();
  }

  // Helpers pour les stats ----------------------------------------------------
  /// Toutes les sessions terminées d’un jour donné (UTC libre)
  Iterable<Session> sessionsOnDay(String activityId, DateTime day) sync* {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    for (final s in _sessionsByActivity[activityId] ?? const []) {
      final sEnd = s.endAt ?? DateTime.now();
      if (sEnd.isAfter(start) && s.startAt.isBefore(end)) {
        yield s;
      }
    }
  }

  /// Durée effective d’une session (en minutes) sur tout son intervalle
  int effectiveMinutes(Session s) {
    final end = s.endAt ?? DateTime.now();
    var paused = Duration.zero;
    for (final p in _pausesBySession[s.id] ?? const []) {
      final pEnd = p.endAt ?? end;
      paused += pEnd.difference(p.startAt);
    }
    final dur = end.difference(s.startAt) - paused;
    final m = dur.inMinutes;
    return m < 0 ? 0 : m;
  }
}
