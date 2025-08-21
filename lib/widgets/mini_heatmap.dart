import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers.dart';                 // dbProvider
import 'heatmap.dart' as hw;                // widget grille
import '../pages/heatmap_page.dart' as hp;  // page détaillée "Heatmap" (data + baseColor)

class MiniHeatmap extends ConsumerStatefulWidget {
  final String activityId;
  final int days; // ex: 28
  final Color baseColor;

  const MiniHeatmap({
    super.key,
    required this.activityId,
    required this.days,
    required this.baseColor,
  });

  @override
  ConsumerState<MiniHeatmap> createState() => _MiniHeatmapState();
}

class _MiniHeatmapState extends ConsumerState<MiniHeatmap> {
  DateTime? _lastTapDay;
  OverlayEntry? _overlay;

  @override
  void dispose() {
    _overlay?.remove();
    super.dispose();
  }

  Future<Map<DateTime, int>> _loadMap() async {
    final db = ref.read(dbProvider);
    final today = DateUtils.dateOnly(DateTime.now());
    final start = today.subtract(Duration(days: widget.days - 1));
    final map = <DateTime, int>{};

    for (int i = 0; i < widget.days; i++) {
      final day = DateUtils.dateOnly(start.add(Duration(days: i)));
      map[day] = db.effectiveMinutesOnDay(widget.activityId, day);
    }
    return map;
  }

  void _showPopover(BuildContext context, DateTime day, int minutes, int goal) {
    _overlay?.remove();

    final txt = goal > 0
        ? '${minutes} min • ${(minutes - goal >= 0 ? '▲' : '▼')}${(minutes - goal).abs()} vs obj'
        : '${minutes} min';

    _overlay = OverlayEntry(
      builder: (_) => Positioned.fill(
        child: IgnorePointer(
          child: Center(
            child: Material(
              elevation: 12,
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Text(
                  '${day.toLocal().toString().split(' ').first}\n$txt',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    Overlay.of(context).insert(_overlay!);
    Future.delayed(const Duration(seconds: 2), () {
      _overlay?.remove();
      _overlay = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final goal = db.activities
        .firstWhere((a) => a.id == widget.activityId, orElse: () => db.activities.first)
        .dailyGoalMinutes ?? 0;

    return FutureBuilder<Map<DateTime, int>>(
      future: _loadMap(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const SizedBox(height: 80, child: Center(child: CircularProgressIndicator(strokeWidth: 2)));
        }
        if (snap.hasError) {
          return SizedBox(height: 60, child: Center(child: Text('Erreur: ${snap.error}')));
        }

        final map = snap.data ?? const <DateTime, int>{};

        return GestureDetector(
          onDoubleTap: () {
            // Ouvre la page Heatmap détaillée avec la même map (ou recalcul 365 jours si tu veux)
            Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => hp.Heatmap(
                data: map, // tu peux recalculer avec 365 jours si besoin
                baseColor: widget.baseColor,
              ),
            ));
          },
          child: hw.Heatmap(
            data: map,
            baseColor: widget.baseColor,
            onDayTap: (day, minutes) {
              _lastTapDay = day;
              _showPopover(context, day, minutes, goal);
            },
          ),
        );
      },
    );
  }
}
