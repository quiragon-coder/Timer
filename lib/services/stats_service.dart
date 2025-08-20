import '../models/stats.dart';
import '../models/session.dart';
import '../models/pause.dart';
import 'database_service.dart';

class StatsService {
  final DatabaseService db;
  StatsService(this.db);

  DateTime _startOfDay(DateTime d) => DateTime(d.year, d.month, d.day);

  Duration _effectiveInRange({
    required DateTime rangeStart,
    required DateTime rangeEnd,
    required DateTime sessionStart,
    required DateTime? sessionEnd,
    required List<Pause> pauses,
  }) {
    final s = sessionStart.isAfter(rangeStart) ? sessionStart : rangeStart;
    final e = (sessionEnd ?? DateTime.now()).isBefore(rangeEnd)
        ? (sessionEnd ?? DateTime.now())
        : rangeEnd;
    if (!e.isAfter(s)) return Duration.zero;

    var active = e.difference(s);
    for (final p in pauses) {
      final ps = p.startAt.isAfter(rangeStart) ? p.startAt : rangeStart;
      final pe = (p.endAt ?? DateTime.now()).isBefore(rangeEnd) ? (p.endAt ?? DateTime.now()) : rangeEnd;
      final overlapStart = ps.isAfter(s) ? ps : s;
      final overlapEnd = pe.isBefore(e) ? pe : e;
      if (overlapEnd.isAfter(overlapStart)) {
        active -= overlapEnd.difference(overlapStart);
      }
    }
    return active.isNegative ? Duration.zero : active;
  }

  Future<int> minutesForActivityOnDay(String activityId, DateTime day) async {
    final from = _startOfDay(day);
    final to   = _startOfDay(day.add(const Duration(days: 1)));
    final sessions = await db.getSessionsByActivity(activityId);
    int minutes = 0;
    for (final s in sessions) {
      final pauses = await db.getPausesBySession(s.id);
      final dur = _effectiveInRange(
        rangeStart: from,
        rangeEnd: to,
        sessionStart: s.startAt,
        sessionEnd: s.endAt,
        pauses: pauses,
      );
      minutes += dur.inMinutes;
    }
    return minutes;
  }

  Future<List<DailyStat>> last7DaysStats(String activityId) async {
    final today = DateTime.now();
    final start = _startOfDay(today.subtract(const Duration(days: 6)));
    final days = List.generate(7, (i) => _startOfDay(start.add(Duration(days: i))));
    final result = <DailyStat>[];
    for (final d in days) {
      final m = await minutesForActivityOnDay(activityId, d);
      result.add(DailyStat(day: d, minutes: m));
    }
    return result;
  }

  Future<List<HourlyBucket>> hourlyDistribution(String activityId, DateTime day) async {
    final from = _startOfDay(day);
    final to = _startOfDay(day.add(const Duration(days: 1)));
    final buckets = List.generate(24, (h) => HourlyBucket(hour: h, minutes: 0));
    final sessions = await db.getSessionsByActivity(activityId);

    for (final s in sessions) {
      final pauses = await db.getPausesBySession(s.id);
      final effStart = s.startAt.isAfter(from) ? s.startAt : from;
      final effEnd = (s.endAt ?? DateTime.now()).isBefore(to) ? (s.endAt ?? DateTime.now()) : to;
      if (!effEnd.isAfter(effStart)) continue;

      // minute resolution for a single day (simple & OK at this scale)
      for (var t = effStart; t.isBefore(effEnd); t = t.add(const Duration(minutes: 1))) {
        final inPause = pauses.any((p) {
          final ps = p.startAt;
          final pe = p.endAt ?? DateTime.now();
          return !t.isBefore(ps) && t.isBefore(pe);
        });
        if (inPause) continue;
        final h = t.hour;
        buckets[h] = HourlyBucket(hour: h, minutes: buckets[h].minutes + 1);
      }
    }
    return buckets;
  }
}
