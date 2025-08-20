import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers_stats.dart";
import "hourly_bars_chart.dart";
import "weekly_bars_chart.dart";

class ActivityStatsPanel extends ConsumerWidget {
  final String activityId;
  final int? dailyGoal;
  final int? weeklyGoal;
  final int? monthlyGoal;
  final int? yearlyGoal;

  const ActivityStatsPanel({
    super.key,
    required this.activityId,
    this.dailyGoal,
    this.weeklyGoal,
    this.monthlyGoal,
    this.yearlyGoal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(statsTodayProvider(activityId));
    final weekAsync = ref.watch(statsLast7DaysProvider(activityId));
    final hourlyAsync = ref.watch(hourlyTodayProvider(activityId));

    final weekTotalAsync  = ref.watch(weekTotalProvider(activityId));
    final monthTotalAsync = ref.watch(monthTotalProvider(activityId));
    final yearTotalAsync  = ref.watch(yearTotalProvider(activityId));

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Stats", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),

            // Aujourd'hui + progression
            todayAsync.when(
              loading: () => const _Skeleton(height: 16),
              error: (e, _) => Text("Erreur: $e"),
              data: (today) {
                final goal = dailyGoal ?? 0;
                final reached = goal > 0 && today >= goal;
                final ratio = goal > 0 ? (today / goal).clamp(0, 1).toDouble() : null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.calendar_today, size: 18),
                          label: Text("Aujourd'hui: $today min"),
                        ),
                        if (goal > 0)
                          Chip(
                            avatar: Icon(
                              reached ? Icons.check_circle : Icons.flag,
                              size: 18,
                              color: reached ? Colors.green : null,
                            ),
                            label: Text(reached ? "Objectif atteint" : "Objectif: $goal min"),
                          ),
                      ],
                    ),
                    if (goal > 0) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: ratio,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reached ? "Bravo !" : "Reste ${goal - today} min",
                        style: TextStyle(color: reached ? Colors.green : Theme.of(context).textTheme.bodySmall?.color),
                      ),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 16),
            // Totaux Semaine / Mois / AnnÃ©e (colorÃ©s si objectif atteint)
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _GoalTotalChip(
                  async: weekTotalAsync, icon: Icons.calendar_view_week, label: "Semaine",
                  goal: weeklyGoal,
                ),
                _GoalTotalChip(
                  async: monthTotalAsync, icon: Icons.calendar_view_month, label: "Mois",
                  goal: monthlyGoal,
                ),
                _GoalTotalChip(
                  async: yearTotalAsync, icon: Icons.calendar_month, label: "AnnÃ©e",
                  goal: yearlyGoal,
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            Text("RÃ©partition horaire (aujourd'hui)"),
            const SizedBox(height: 8),
            hourlyAsync.when(
              loading: () => const _Skeleton(height: 120),
              error: (e, _) => Text("Erreur: $e"),
              data: (buckets) => SizedBox(height: 140, child: HourlyBarsChart(buckets: buckets)),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            Text("7 derniers jours"),
            const SizedBox(height: 8),
            weekAsync.when(
              loading: () => const _Skeleton(height: 140),
              error: (e, _) => Text("Erreur: $e"),
              data: (stats) => SizedBox(height: 160, child: WeeklyBarsChart(stats: stats)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalTotalChip extends StatelessWidget {
  final AsyncValue<int> async;
  final IconData icon;
  final String label;
  final int? goal;

  const _GoalTotalChip({
    required this.async,
    required this.icon,
    required this.label,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const Chip(label: Text("...")),
      error: (e, _) => const Chip(label: Text("Err")),
      data: (m) {
        final reached = (goal ?? 0) > 0 && m >= (goal ?? 0);
        return Chip(
          avatar: Icon(icon, size: 18, color: reached ? Colors.green : null),
          label: Text(
            goal != null && goal! > 0
              ? "$label: $m / ${goal} min"
              : "$label: $m min",
          ),
          backgroundColor: reached ? Colors.green.withOpacity(.12) : null,
          side: reached ? const BorderSide(color: Colors.green) : null,
        );
      },
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double height;
  const _Skeleton({required this.height});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.6),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
