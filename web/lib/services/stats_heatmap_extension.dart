import "./stats_service.dart";
import "./database_service.dart";
import "../models/session.dart";
import "../models/pause.dart";

extension StatsHeatmapExt on StatsService {
  Future<Map<DateTime, int>> dailyMinutesRange({
    required String activityId,
    required DateTime from,
    required DateTime to,
  }) async {
    final startDay = DateTime(from.year, from.month, from.day);
    final endDay = DateTime(to.year, to.month, to.day);

    final List<Session> sessions = db.listSessionsByActivity(activityId);
    final Map<String, List<Pause>> pausesBySession = {
      for (final s in sessions) s.id: db.listPausesBySession(s.id),
    };

    final result = <DateTime, int>{};
    DateTime d = startDay;
    while (!d.isAfter(endDay)) {
      final dayStart = d;
      final dayEnd = d.add(const Duration(days: 1));
      int minutes = 0;

      for (final s in sessions) {
        final sStart = s.startAt;
        final sEnd = s.endAt ?? DateTime.now();
        final overlapStart = _max(dayStart, sStart);
        final overlapEnd   = _min(dayEnd, sEnd);
        if (!overlapEnd.isAfter(overlapStart)) continue;

        int eff = overlapEnd.difference(overlapStart).inMinutes;

        final pauses = pausesBySession[s.id] ?? const <Pause>[];
        for (final p in pauses) {
          final ps = _max(overlapStart, p.startAt);
          final pe = _min(overlapEnd,   p.endAt ?? DateTime.now());
          if (pe.isAfter(ps)) {
            eff -= pe.difference(ps).inMinutes;
          }
        }
        if (eff > 0) minutes += eff;
      }

      result[DateTime(d.year, d.month, d.day)] = minutes;
      d = d.add(const Duration(days: 1));
    }
    return result;
  }

  DateTime _max(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
  DateTime _min(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
}
