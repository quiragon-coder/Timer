import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers_stats.dart';
import 'hourly_bars_chart.dart';
import 'weekly_bars_chart.dart';

class ActivityStatsPanel extends ConsumerWidget {
  final String activityId;
  const ActivityStatsPanel({super.key, required this.activityId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(statsTodayProvider(activityId));
    final week  = ref.watch(weekTotalProvider(activityId));
    final month = ref.watch(monthTotalProvider(activityId));
    final year  = ref.watch(yearTotalProvider(activityId));

    final hourly = ref.watch(hourlyTodayProvider(activityId));
    final last7  = ref.watch(last7DaysProvider(activityId));

    final theme = Theme.of(context);
    final cardColor = theme.colorScheme.surfaceContainerHighest;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Chips des totaux
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _TotalChip(icon: Icons.calendar_today,  label: "Aujourd'hui", value: today),
              _TotalChip(icon: Icons.calendar_view_week, label: "Semaine",  value: week),
              _TotalChip(icon: Icons.calendar_view_month, label: "Mois",     value: month),
              _TotalChip(icon: Icons.calendar_month,     label: "Année",   value: year),
            ],
          ),

          const SizedBox(height: 16),
          Divider(color: theme.dividerColor.withOpacity(.5)),
          const SizedBox(height: 12),

          Text("Répartition horaire (aujourd'hui)",
              style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 220,
            child: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: hourly.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const Center(child: Text('Erreur')),
                data: (buckets) => HourlyBarsChart(buckets: buckets),
              ),
            ),
          ),

          const SizedBox(height: 16),
          Divider(color: theme.dividerColor.withOpacity(.5)),
          const SizedBox(height: 12),

          Text("7 derniers jours", style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          SizedBox(
            height: 200,
            child: last7.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => const Center(child: Text('Erreur')),
              data: (stats) => WeeklyBarsChart(stats: stats),
            ),
          ),
        ],
      ),
    );
  }
}

class _TotalChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final AsyncValue<int> value;

  const _TotalChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return value.when(
      loading: () => Chip(
        avatar: Icon(icon, size: 16),
        label: const Text('...'),
      ),
      error: (_, __) => Chip(
        avatar: Icon(icon, size: 16),
        label: const Text('Err'),
      ),
      data: (m) => Chip(
        avatar: Icon(icon, size: 16),
        label: Text('$label: $m min'),
        side: BorderSide(color: theme.colorScheme.outlineVariant),
      ),
    );
  }
}
