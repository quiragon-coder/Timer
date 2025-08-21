import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart'; // dbProvider
import '../pages/activity_history_page.dart';

/// Carte "Historique (aujourd'hui)" + badge Total du jour.
/// Utilise uniquement dbProvider (pas d'autres providers requis).
class HistoryTodayCard extends ConsumerStatefulWidget {
  final String activityId;
  final String activityName;
  final int maxRows; // nombre max de lignes (sessions) à afficher

  const HistoryTodayCard({
    super.key,
    required this.activityId,
    required this.activityName,
    this.maxRows = 6,
  });

  @override
  ConsumerState<HistoryTodayCard> createState() => _HistoryTodayCardState();
}

class _HistoryTodayCardState extends ConsumerState<HistoryTodayCard> {
  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);

    return FutureBuilder<List<_HistRow>>(
      future: _loadToday(db, widget.activityId),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Card(
            elevation: 0,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(height: 24, child: LinearProgressIndicator()),
            ),
          );
        }
        if (snap.hasError) {
          return Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Erreur: ${snap.error}'),
            ),
          );
        }

        final rows = (snap.data ?? const <_HistRow>[]);
        final total = rows.fold<int>(0, (sum, r) => sum + r.effectiveMinutes);

        return Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre + Badge Total + "Voir plus"
                Row(
                  children: [
                    Text('Historique (aujourd’hui)',
                        style: Theme.of(context).textTheme.titleMedium),
                    const Spacer(),
                    Container(
                      padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(.10),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.summarize, size: 14),
                          const SizedBox(width: 6),
                          Text("Total : ${_fmtDuration(total)}",
                              style: Theme.of(context).textTheme.labelMedium),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => ActivityHistoryPage(
                            activityId: widget.activityId,
                            activityName: widget.activityName,
                          ),
                        ));
                      },
                      icon: const Icon(Icons.chevron_right),
                      label: const Text('Voir plus'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (rows.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text("Aucune session aujourd’hui",
                        style: Theme.of(context).textTheme.bodySmall),
                  )
                else
                  ...rows.take(widget.maxRows).map((r) => _HistoryRowTile(r: r)),
              ],
            ),
          ),
        );
      },
    );
  }

  // Charge uniquement les sessions de la journée courante et calcule les minutes effectives (durée - pauses)
  Future<List<_HistRow>> _loadToday(dynamic db, String activityId) async {
    List<dynamic> sessions = [];
    try {
      final res = await db.listSessionsByActivity(activityId);
      if (res is List) sessions = res;
    } catch (_) {}
    if (sessions.isEmpty) {
      try {
        final res = await db.sessionsByActivity(activityId);
        if (res is List) sessions = res;
      } catch (_) {}
    }
    if (sessions.isEmpty) {
      try {
        final all = db.sessions;
        if (all is List) {
          sessions = all
              .where((s) => _stringField(s, 'activityId') == activityId)
              .toList();
        }
      } catch (_) {}
    }

    // Filtre: aujourd’hui uniquement
    final now = DateTime.now();
    sessions = sessions.where((s) {
      final start = _dateField(s, 'startAt');
      return start != null && _isSameDay(start, now);
    }).toList();

    // Tri descendant (plus récentes d’abord)
    sessions.sort((a, b) {
      final sa = _dateField(a, 'startAt') ?? DateTime.fromMillisecondsSinceEpoch(0);
      final sb = _dateField(b, 'startAt') ?? DateTime.fromMillisecondsSinceEpoch(0);
      return sb.compareTo(sa);
    });

    final rows = <_HistRow>[];
    for (final s in sessions) {
      final start = _dateField(s, 'startAt');
      if (start == null) continue;
      final end = _dateField(s, 'endAt');

      final totalMinutes =
      ((end ?? DateTime.now()).difference(start).inSeconds / 60).round();

      // Pauses
      int pausedMinutes = 0;
      List<dynamic> pauses = [];
      try {
        final res = await db.listPausesBySession(_idOf(s));
        if (res is List) pauses = res;
      } catch (_) {
        try {
          final all = db.pauses;
          if (all is List) {
            pauses = all
                .where((p) => _stringField(p, 'sessionId') == _idOf(s))
                .toList();
          }
        } catch (_) {}
      }
      for (final p in pauses) {
        final ps = _dateField(p, 'startAt');
        final pe = _dateField(p, 'endAt');
        if (ps == null) continue;
        final pend = pe ?? DateTime.now();
        pausedMinutes += ((pend.difference(ps).inSeconds) / 60).round();
      }

      rows.add(_HistRow(
        start: start,
        end: end,
        effectiveMinutes: (totalMinutes - pausedMinutes).clamp(0, 1000000),
      ));
    }
    return rows;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final al = a.toLocal(), bl = b.toLocal();
    return al.year == bl.year && al.month == bl.month && al.day == bl.day;
  }

  String _idOf(dynamic obj) {
    try {
      final v = obj.id;
      if (v is String) return v;
      return "$v";
    } catch (_) {
      return "";
    }
  }

  String _stringField(dynamic obj, String name) {
    try {
      final v = obj.toJson?.call()[name];
      if (v is String) return v;
    } catch (_) {}
    try {
      final v = (obj as dynamic);
      final val = v?.map?[name];
      if (val is String) return val;
    } catch (_) {}
    try {
      final v = (obj as dynamic);
      if (name == 'activityId') return (v.activityId ?? "").toString();
      if (name == 'sessionId') return (v.sessionId ?? "").toString();
    } catch (_) {}
    return "";
  }

  DateTime? _dateField(dynamic obj, String name) {
    try {
      final v = obj.toJson?.call()[name];
      if (v is DateTime) return v;
      if (v is String) return DateTime.tryParse(v);
      if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    } catch (_) {}
    try {
      final v = (obj as dynamic);
      final val = (name == 'startAt') ? v.startAt : v.endAt;
      if (val is DateTime) return val;
      if (val is String) return DateTime.tryParse(val);
      if (val is int) return DateTime.fromMillisecondsSinceEpoch(val);
    } catch (_) {}
    return null;
  }
}

class _HistRow {
  final DateTime start;
  final DateTime? end;
  final int effectiveMinutes;
  _HistRow({required this.start, required this.end, required this.effectiveMinutes});
}

class _HistoryRowTile extends StatelessWidget {
  final _HistRow r;
  const _HistoryRowTile({required this.r});

  @override
  Widget build(BuildContext context) {
    final timeStr =
        "${_fmtTime(r.start)}–${r.end == null ? 'en cours' : _fmtTime(r.end!)}";
    final durStr = _fmtDuration(r.effectiveMinutes);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(timeStr, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(.10),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(durStr, style: Theme.of(context).textTheme.labelMedium),
          ),
        ],
      ),
    );
  }
}

String _fmtTime(DateTime d) {
  final local = d.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final m = local.minute.toString().padLeft(2, '0');
  return "$h:$m";
}

String _fmtDuration(int minutes) {
  if (minutes < 60) return "${minutes}m";
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return "${h}h";
  return "${h}h${m}m";
}
