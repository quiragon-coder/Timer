import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart'; // dbProvider
import '../services/database_models_adapters.dart'; // extension typée

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
  /// Filtre : 0 = aujourd’hui, 7, 30, -1 = tout
  int _range = 7;

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
            return const Center(child: Text("Aucune session"));
          }

          final groups = _groupByDay(rows);

          return ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: groups.length,
            itemBuilder: (context, i) {
              final g = groups[i];
              final total = g.rows.fold<int>(0, (a, r) => a + r.effectiveMinutes);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Titre jour + total
                      Row(
                        children: [
                          Expanded(child: Text(_fmtDay(g.date), style: Theme.of(context).textTheme.titleSmall)),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).colorScheme.secondaryContainer,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text("${total} min", style: Theme.of(context).textTheme.labelLarge),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...g.rows.map((r) => _HistoryRowTile(row: r)),
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
    final sessions = db.listSessionsByActivityModel(activityId);
    final rows = <_HistRow>[];

    for (final s in sessions) {
      final start = s.startAt;
      final end = s.endAt ?? DateTime.now();
      final pauses = db.listPausesBySessionModel(activityId, s.id);
      final eff = db.effectiveDurationFor(s, pauses);

      final paused = pauses.fold<int>(0, (acc, p) {
        final pe = p.endAt ?? end;
        if (pe.isAfter(p.startAt)) return acc + pe.difference(p.startAt).inMinutes;
        return acc;
      });

      rows.add(_HistRow(
        start: start,
        end: s.endAt,
        effectiveMinutes: eff.inMinutes,
        pausesMinutes: paused,
      ));
    }

    rows.sort((a, b) => b.start.compareTo(a.start));
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
    }).toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    return groups;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final al = a.toLocal(), bl = b.toLocal();
    return al.year == bl.year && al.month == bl.month && al.day == bl.day;
  }

  String _dayKey(DateTime d) {
    final dl = d.toLocal();
    return "${dl.year}-${dl.month.toString().padLeft(2, '0')}-${dl.day.toString().padLeft(2, '0')}";
  }

  String _fmtDay(DateTime d) {
    final dl = d.toLocal();
    return "${dl.day.toString().padLeft(2, '0')}/${dl.month.toString().padLeft(2, '0')}/${dl.year}";
  }
}

class _HistRow {
  final DateTime start;
  final DateTime? end;
  final int effectiveMinutes;
  final int pausesMinutes;
  _HistRow({required this.start, required this.end, required this.effectiveMinutes, required this.pausesMinutes});
}

class _HistGroup {
  final DateTime date;
  final List<_HistRow> rows;
  _HistGroup({required this.date, required this.rows});
}

class _HistoryRowTile extends StatelessWidget {
  final _HistRow row;
  const _HistoryRowTile({required this.row});

  @override
  Widget build(BuildContext context) {
    final title = _fmtTimeRange(context, row.start, row.end);
    final eff = _fmtDuration(Duration(minutes: row.effectiveMinutes));
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: row.pausesMinutes == 0 ? const Text("Aucune pause") : Text("${row.pausesMinutes} min de pause"),
      trailing: Text(eff, style: const TextStyle(fontWeight: FontWeight.w600)),
    );
  }

  String _fmtTimeRange(BuildContext context, DateTime start, DateTime? end) {
    final s = TimeOfDay.fromDateTime(start).format(context);
    final e = end == null ? 'en cours…' : TimeOfDay.fromDateTime(end).format(context);
    return "$s → $e";
  }

  String _fmtDuration(Duration d) {
    final h = d.inHours;
    final m = d.inMinutes.remainder(60);
    if (h > 0) return "${h}h${m.toString().padLeft(2, '0')}";
    return "${m}m";
  }
}
