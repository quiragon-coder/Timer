// Helpers typés pour consommer DatabaseService sans casts dynamiques.
import 'package:flutter/material.dart' show DateUtils;

import '../models/session.dart' as M;
import '../models/pause.dart' as M;
import './database_service.dart';

extension DatabaseModelsAdapter on DatabaseService {
  /// Sessions -> modèles UI typés
  List<M.Session> listSessionsByActivityModel(String activityId) {
    final raw = listSessionsByActivity(activityId);
    return raw
        .map((s) => M.Session(
      id: s.id,
      activityId: s.activityId,
      startAt: s.startAt,
      endAt: s.endAt,
    ))
        .toList(growable: false);
  }

  /// Pauses -> modèles UI typés
  List<M.Pause> listPausesBySessionModel(String activityId, String sessionId) {
    final raw = listPausesBySession(activityId, sessionId);
    return raw
        .map((p) => M.Pause(
      // Id synthétique (si pas stocké en DB)
      id: 'p_${p.startAt.microsecondsSinceEpoch}_${p.endAt?.microsecondsSinceEpoch ?? 0}',
      sessionId: sessionId,
      startAt: p.startAt,
      endAt: p.endAt,
    ))
        .toList(growable: false);
  }

  /// Durée effective d'une session (hors pauses)
  Duration effectiveDurationFor(M.Session s, List<M.Pause> pauses, {DateTime? now}) {
    final end = s.endAt ?? (now ?? DateTime.now());
    var dur = end.difference(s.startAt);
    for (final p in pauses) {
      final pe = p.endAt ?? end;
      if (pe.isAfter(p.startAt)) {
        dur -= pe.difference(p.startAt);
      }
    }
    return dur.isNegative ? Duration.zero : dur;
  }

  /// Minutes effectives **sur un jour précis** pour une activité.
  /// (Sugar pour usage typé dans l’UI)
  int minutesOnDayTyped(String activityId, DateTime day) {
    return effectiveMinutesOnDay(activityId, DateUtils.dateOnly(day));
  }
}
