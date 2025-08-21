import 'dart:async';
import 'package:flutter/material.dart';

import '../models/activity.dart';

class DbPause {
  final DateTime startAt;
  DateTime? endAt;
  DbPause({required this.startAt, this.endAt});
  bool get isOpen => endAt == null;

  Duration durationUntil(DateTime t) {
    final end = endAt ?? t;
    return end.difference(startAt);
  }
}

class DbSession {
  final String id;
  final String activityId;
  final DateTime startAt;
  final DateTime endAt;
  final List<DbPause> pauses;

  DbSession({
    required this.id,
    required this.activityId,
    required this.startAt,
    required this.endAt,
    required this.pauses,
  });

  int effectiveMinutes() {
    final total = endAt.difference(startAt);
    final paused = pauses.fold<Duration>(
      Duration.zero,
          (acc, p) => acc + p.durationUntil(endAt),
    );
    final eff = total - paused;
    return eff.inMinutes < 0 ? 0 : eff.inMinutes;
  }
}

class _RunState {
  final String activityId;
  final DateTime sessionStart;
  DateTime? lastResume;          // null si en pause
  Duration accumulated;          // temps cumulé hors pause
  final List<DbPause> pauses;    // pauses (la dernière peut être ouverte)

  _RunState({
    required this.activityId,
    required this.sessionStart,
    required this.lastResume,
    required this.accumulated,
    required this.pauses,
  });

  bool get isPaused => lastResume == null;

  Duration effectiveElapsedAt(DateTime t) {
    var d = accumulated;
    if (!isPaused && lastResume != null) {
      d += t.difference(lastResume!);
    }
    return d;
  }
}

class DatabaseService extends ChangeNotifier {
  // -------------------- Activités --------------------
  final Map<String, Activity> _activities = {};
  List<Activity> get activities => _activities.values.toList(growable: false);

  Future<List<Activity>> getActivities() async => activities;

  Future<Activity> createActivity({
    required String name,
    required String emoji,
    required Color color,
    int? dailyGoalMinutes,
    int? weeklyGoalMinutes,
    int? monthlyGoalMinutes,
    int? yearlyGoalMinutes,
  }) async {
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
    _activities[id] = a;
    notifyListeners();
    return a;
  }

  Future<void> updateActivity(Activity updated) async {
    _activities[updated.id] = updated;
    notifyListeners();
  }

  // -------------------- Sessions & historique --------------------
  final Map<String, _RunState> _runs = {};          // par activityId
  final Map<String, List<DbSession>> _history = {}; // par activityId

  List<DbSession> sessionsByActivity(String activityId) =>
      List.unmodifiable(_history[activityId] ?? const []);

  // === Wrappers legacy (attendus par ton code existant) ==========
  List<DbSession> listSessionsByActivity(String activityId) => sessionsByActivity(activityId);

  List<DbPause> listPausesBySession(String activityId, String sessionId) {
    final s = (_history[activityId] ?? const []).firstWhere(
          (e) => e.id == sessionId,
      orElse: () => DbSession(
        id: '_missing',
        activityId: activityId,
        startAt: DateTime.now(),
        endAt: DateTime.now(),
        pauses: const [],
      ),
    );
    return List.unmodifiable(s.pauses);
  }
  // ===============================================================

  bool isRunning(String activityId) => _runs.containsKey(activityId);
  bool isPaused (String activityId) => _runs[activityId]?.isPaused ?? false;

  DateTime? currentSessionStart(String activityId) =>
      _runs[activityId]?.sessionStart;

  Duration runningElapsed(String activityId) {
    final r = _runs[activityId];
    if (r == null) return Duration.zero;
    return r.effectiveElapsedAt(DateTime.now());
  }

  Future<void> start(String activityId) async {
    final now = DateTime.now();
    final r = _runs[activityId];
    if (r == null) {
      _runs[activityId] = _RunState(
        activityId: activityId,
        sessionStart: now,
        lastResume: now,
        accumulated: Duration.zero,
        pauses: [],
      );
    } else {
      if (r.isPaused) {
        r.lastResume = now; // reprise
      }
      // sinon déjà en cours → noop
    }
    notifyListeners();
  }

  Future<void> togglePause(String activityId) async {
    final r = _runs[activityId];
    if (r == null) return;
    final now = DateTime.now();

    if (r.isPaused) {
      // reprise
      final last = r.pauses.isNotEmpty ? r.pauses.last : null;
      if (last != null && last.isOpen) last.endAt = now;
      r.lastResume = now;
    } else {
      // mise en pause
      if (r.lastResume != null) {
        r.accumulated += now.difference(r.lastResume!);
      }
      r.lastResume = null;
      r.pauses.add(DbPause(startAt: now));
    }
    notifyListeners();
  }

  Future<void> stop(String activityId) async {
    final r = _runs[activityId];
    if (r == null) return;
    final now = DateTime.now();

    if (!r.isPaused && r.lastResume != null) {
      r.accumulated += now.difference(r.lastResume!);
    }
    if (r.isPaused && r.pauses.isNotEmpty && r.pauses.last.isOpen) {
      r.pauses.last.endAt = now;
    }

    final s = DbSession(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      activityId: activityId,
      startAt: r.sessionStart,
      endAt: now,
      pauses: List<DbPause>.from(r.pauses),
    );
    final list = _history.putIfAbsent(activityId, () => []);
    list.add(s);

    _runs.remove(activityId);
    notifyListeners();
  }

  // -------------------- Aide stats --------------------
  int effectiveMinutes(DbSession s) => s.effectiveMinutes();

  int effectiveMinutesOnDay(String activityId, DateTime day) {
    final dayStart = DateTime(day.year, day.month, day.day);
    final dayEnd   = dayStart.add(const Duration(days: 1));

    int minutes = 0;

    for (final s in sessionsByActivity(activityId)) {
      final overlapStart = s.startAt.isBefore(dayStart) ? dayStart : s.startAt;
      final overlapEnd   = s.endAt.isAfter(dayEnd) ? dayEnd : s.endAt;

      if (overlapEnd.isAfter(overlapStart)) {
        var dur = overlapEnd.difference(overlapStart);
        for (final p in s.pauses) {
          final ps = p.startAt.isBefore(dayStart) ? dayStart : p.startAt;
          final pe = (p.endAt ?? s.endAt).isAfter(dayEnd) ? dayEnd : (p.endAt ?? s.endAt);
          if (pe.isAfter(ps)) {
            dur -= pe.difference(ps);
          }
        }
        minutes += dur.inMinutes;
      }
    }

    final r = _runs[activityId];
    if (r != null) {
      final now = DateTime.now();
      final runningEnd = now.isAfter(dayEnd) ? dayEnd : now;
      final runningStart = r.sessionStart.isBefore(dayStart) ? dayStart : r.sessionStart;

      if (runningEnd.isAfter(runningStart)) {
        var dur = runningEnd.difference(runningStart);
        for (final p in r.pauses) {
          final ps = p.startAt.isBefore(dayStart) ? dayStart : p.startAt;
          final pe = (p.endAt ?? now).isAfter(dayEnd) ? dayEnd : (p.endAt ?? now);
          if (pe.isAfter(ps)) {
            dur -= pe.difference(ps);
          }
        }
        final live = r.effectiveElapsedAt(now).inMinutes;
        minutes += dur.inMinutes.clamp(0, live);
      }
    }

    return minutes < 0 ? 0 : minutes;
  }

  List<int> hourlyToday(String activityId) {
    final today = DateTime.now();
    final startDay = DateTime(today.year, today.month, today.day);
    final endDay   = startDay.add(const Duration(days: 1));
    final buckets = List<int>.filled(24, 0);

    void addRange(DateTime a, DateTime b, List<DbPause> pauses) {
      var start = a.isBefore(startDay) ? startDay : a;
      var end   = b.isAfter(endDay) ? endDay : b;
      if (!end.isAfter(start)) return;

      DateTime cursor = start;
      while (cursor.isBefore(end)) {
        final next = cursor.add(const Duration(minutes: 1));
        bool inPause = false;
        for (final p in pauses) {
          final ps = p.startAt.isBefore(startDay) ? startDay : p.startAt;
          final pe = (p.endAt ?? end).isAfter(endDay) ? endDay : (p.endAt ?? end);
          if (next.isAfter(ps) && cursor.isBefore(pe)) {
            inPause = true;
            break;
          }
        }
        if (!inPause) {
          buckets[cursor.hour] += 1;
        }
        cursor = next;
      }
    }

    for (final s in sessionsByActivity(activityId)) {
      addRange(s.startAt, s.endAt, s.pauses);
    }
    final r = _runs[activityId];
    if (r != null) {
      final now = DateTime.now();
      addRange(r.sessionStart, now, r.pauses);
    }
    return buckets;
  }
}
