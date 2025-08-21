import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart'; // dbProvider
import '../services/database_models_adapters.dart'; // extension typée

/// Carte "Historique (aujourd'hui)" + badge Total du jour.
class HistoryTodayCard extends ConsumerStatefulWidget {
  final String activityId;
  final String activityName;
  final int maxRows; // nombre max de lignes (sessions) à afficher

  const HistoryTodayCard({
    super.key,
    required this.activityId,
    required this.activityName,
    this.maxRows = 5,
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
          return const Card(child: SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2))));
        }
        if (snap.hasError) {
          return Card(child: Padding(padding: const EdgeInsets.all(12), child: Text("Erreur: ${snap.error}")));
        }

        final rows = (snap.data ?? const <_HistRow>[]);
        final total = rows.fold<int>(0, (sum, r) => sum + r.effectiveMinutes).clamp(0, 1000000);

        return Card(
          elevation: 0,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Titre + Badge Total
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        "Historique (aujourd’hui) — ${widget.activityName}",
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primaryContainer,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text("${total} min", style: Theme.of(context).textTheme.labelLarge),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (rows.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20),
                    child: Center(child: Text("Aucune session aujourd’hui")),
                  )
                else
                  ...rows.take(widget.maxRows).map((r) {
                    final title = _fmtTimeRange(r.start, r.end);
                    final eff = _fmtDuration(Duration(minutes: r.effectiveMinutes));
                    final pauses = r.pausesMinutes;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w500)),
                      subtitle: pauses == 0 ? const Text("Aucune pause") : Text("$pauses min de pause"),
                      trailing: Text(eff, style: const TextStyle(fontWeight: FontWeight.w600)),
                    );
                  }),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<List<_HistRow>> _loadToday(dynamic db, String activityId) async {
    final sessions = db.listSessionsByActivityModel(activityId);
    final today = DateUtils.dateOnly(DateTime.now());
    final rows = <_HistRow>[];

    for (final s in sessions) {
      final start = s.startAt;
      final end = s.endAt ?? DateTime.now();
      if (!_isSameDay(start, today)) continue;

      final pauses = db.listPausesBySessionModel(activityId, s.id);
      final eff = db.effectiveDurationFor(s, pauses);
      final paused = pauses.fold<int>(0, (acc, p) {
        final pe = p.endAt ?? end;
        if (pe.isAfter(p.startAt)) return acc + pe.difference(p.startAt).inMinutes;
        return acc;
      });

      rows.add(_HistRow(start: start, end: s.endAt, effectiveMinutes: eff.inMinutes, pausesMinutes: paused));
    }

    rows.sort((a, b) => b.start.compareTo(a.start));
    return rows;
  }

  bool _isSameDay(DateTime a, DateTime b) {
    final al = a.toLocal(), bl = b.toLocal();
    return al.year == bl.year && al.month == bl.month && al.day == bl.day;
  }

  String _fmtTimeRange(DateTime start, DateTime? end) {
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

class _HistRow {
  final DateTime start;
  final DateTime? end;
  final int effectiveMinutes;
  final int pausesMinutes;
  _HistRow({required this.start, required this.end, required this.effectiveMinutes, required this.pausesMinutes});
}
