import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/stats.dart';
import '../providers_stats.dart';
import '../providers_heatmap.dart';

class MiniHeatmap extends ConsumerWidget {
  final String activityUid;
  const MiniHeatmap({super.key, required this.activityUid});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysAsync = ref.watch(miniHeatmapProvider(activityUid));

    return daysAsync.when(
      data: (days) {
        if (days.isEmpty) return const SizedBox.shrink();
        final max = ref.read(heatmapMaxProvider(days));
        return Wrap(
          spacing: 4,
          runSpacing: 4,
          children: [
            for (final d in days) _Tile(day: d, max: max),
          ],
        );
      },
      loading: () => const SizedBox(height: 32, child: Center(child: CircularProgressIndicator(strokeWidth: 2))),
      error: (e, _) => Text('Erreur heatmap: $e'),
    );
  }
}

class _Tile extends StatelessWidget {
  final DayStat day;
  final int max;
  const _Tile({required this.day, required this.max});

  @override
  Widget build(BuildContext context) {
    final t = (day.minutes / max).clamp(0.0, 1.0);
    // Légère couleur qui fonce avec la progression
    final base = Theme.of(context).colorScheme.primary;
    final color = Color.alphaBlend(base.withOpacity(0.12 + 0.58 * t), Colors.transparent);

    return Tooltip(
      message: "${day.date.toIso8601String().substring(0,10)} – ${day.minutes} min",
      child: Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: base.withOpacity(0.15)),
        ),
      ),
    );
  }
}
