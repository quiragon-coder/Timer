import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart'; // dbProvider

class ActivityHistoryPage extends ConsumerStatefulWidget {
  final String activityId;
  final String activityName;

  const ActivityHistoryPage({
    super.key,
    required this.activityId,
    required this.activityName,
  });

  @override
  ConsumerState<ActivityHistoryPage> createState() => _ActivityHistoryPageState();
}

class _ActivityHistoryPageState extends ConsumerState<ActivityHistoryPage> {
  /// Filtre de période.
  /// 0 = Aujourd’hui, 7 = 7 jours, 30 = 30 jours, -1 = tout
  int _range = -1;

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    return Scaffold(
      appBar: AppBar(
        title: Text("Historique • ${widget.activityName}"),
        actions: [
          PopupMenuButton<int>(
            initialValue: _range,
            onSelected: (v) => setState(() => _range = v),
            itemBuilder: (context) => const [
              PopupMenuItem(value: 0, child: Text("Aujourd’hui")),
              PopupMenuItem(value: 7, child: Text("7 jours")),
              PopupMenuItem(value: 30, child: Text("30 jours")),
              PopupMenuItem(value: -1, child: Text("Tout")),
            ],
            icon: const Icon(Icons.filter_list),
          ),
        ],
      ),
      body: FutureBuilder<List<_HistRow>>(
        future: _loadHistory(db, widget.activityId),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(strokeWidth: 2));
          }
          if (snap.hasError) {
            return Center(child: Text("Erreur: ${snap.error}"));
          }
          var rows = snap.data ?? const <_HistRow>[];

          // Applique le filtre de période
          rows = _applyRangeFilter(rows, _range);

          if (rows.isEmpty) {
            return const Center(child: Text("Aucune session."));
          }

          final grouped = _groupByDay(rows);

          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: grouped.length,
            separatorBuilder: (_, __) => const Divider(height: 16),
            itemBuilder: (_, gi) {
              final g = grouped[gi];
              final totalMinutes = g.rows.fold<int>(0, (sum, r) => sum + r.effectiveMinutes);

              return Card(
                elevation: 0,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // En-tête jour + total du jour
                      Row(
                        children: [
                          Text(_fmtDay(g.date), style: Theme.of(context).textTheme.titleMedium),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.blueGrey.withOpacity(.10),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.summarize, size: 14),
                                const SizedBox(width: 6),
                                Text("Total : ${_fmtDuration(totalMinutes)}",
                                    style: Theme.of(context).textTheme.labelMedium),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      ...g.rows.map((r) => _HistoryRowTile(r: r)),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  Future<List<_HistRow>> _loadHistory(dynamic db, String activityId) async {
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
          sessions = all.where((s) => _stringField(s, 'activityId') == activityId).toList();
        }
      } catch (_) {}
    }

    // Tri décroissant par début de session
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

      final totalMinutes = ((end ?? DateTime.now()).difference(start).inSeconds / 60).round();

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
            pauses = all.where((p) => _stringField(p, 'sessionId') == _idOf(s)).toList();
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

  List<_HistRow> _applyRangeFilter(List<_HistRow> rows, int range) {
    if (range == -1) return rows; // Tout
    final now = DateTime.now();
    if (range == 0) {
      // Aujourd’hui
      return rows.where((r) => _isSameDay(r.start, now)).toList();
    }
    final since = now.subtract(Duration(days: range));
    return rows.where((r) => r.start.isAfter(since)).toList();
  }

  List<_HistGroup> _groupByDay(List<_HistRow> rows) {
    final map = <String, List<_HistRow>>{};
    for (final r in rows) {
      final key = _dayKey(r.start);
      (map[key] ??= []).add(r);
    }
    final groups = map.entries.map((e) {
      final parts = e.key.split('-').map(int.parse).toList();
      final date = DateTime(parts[0], parts[1], parts[2]);
      final list = e.value..sort((a, b) => a.start.compareTo(b.start));
      return _HistGroup(date: date, rows: list);
    }).toList();
    groups.sort((a, b) => b.date.compareTo(a.date));
    return groups;
  }

  String _dayKey(DateTime d) {
    final local = d.toLocal();
    return "${local.year.toString().padLeft(4, '0')}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}";
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
      final val = (name == 'activityId') ? v.activityId : v.sessionId;
      if (val is String) return val;
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

class _HistGroup {
  final DateTime date;
  final List<_HistRow> rows;
  _HistGroup({required this.date, required this.rows});
}

class _HistoryRowTile extends StatelessWidget {
  final _HistRow r;
  const _HistoryRowTile({required this.r});

  @override
  Widget build(BuildContext context) {
    final timeStr = "${_fmtTime(r.start)}–${r.end == null ? 'en cours' : _fmtTime(r.end!)}";
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

String _fmtDay(DateTime d) {
  final local = d.toLocal();
  final y = local.year.toString().padLeft(4, '0');
  final m = local.month.toString().padLeft(2, '0');
  final dd = local.day.toString().padLeft(2, '0');
  return "$y-$m-$dd";
}

String _fmtTime(DateTime d) {
  final local = d.toLocal();
  final h = local.hour.toString().padLeft(2, '0');
  final min = local.minute.toString().padLeft(2, '0');
  return "$h:$min";
}

String _fmtDuration(int minutes) {
  if (minutes < 60) return "${minutes}m";
  final h = minutes ~/ 60;
  final m = minutes % 60;
  if (m == 0) return "${h}h";
  return "${h}h${m}m";
}
