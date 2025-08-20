import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../providers.dart';
import '../providers_stats.dart';
import '../widgets/activity_controls.dart';
import 'create_activity_page.dart';
import 'activity_detail_page.dart';

// Ticker global : notifie 1 fois / seconde -> force un rebuild des widgets qui le watch
final tickerProvider = StreamProvider<DateTime>(
      (ref) => Stream.periodic(const Duration(seconds: 1), (_) => DateTime.now()),
);

class ActivitiesListPage extends ConsumerWidget {
  const ActivitiesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(activitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Activities')),
      body: activitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('Aucune activit\u00E9. Ajoute-en une \u2192'),
            );
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _ActivityTile(a: list[i]),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const CreateActivityPage()),
        ),
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}

class _ActivityTile extends ConsumerWidget {
  final Activity a;
  const _ActivityTile({required this.a});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Tick chaque seconde pour rafraîchir le badge mm:ss
    ref.watch(tickerProvider);

    final db = ref.watch(dbProvider);
    final running = db.isRunning(a.id);
    final paused = db.isPaused(a.id);

    // Totaux pour les chips
    final weekTotalAsync = ref.watch(weekTotalProvider(a.id));
    final monthTotalAsync = ref.watch(monthTotalProvider(a.id));
    final yearTotalAsync = ref.watch(yearTotalProvider(a.id));

    // minutes today -> pour objectif journalier
    final todayAsync = ref.watch(statsTodayProvider(a.id));

    final elapsed = db.runningElapsed(a.id);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      leading: Text(a.emoji, style: const TextStyle(fontSize: 24)),
      title: Text(
        a.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne 1: point couleur + objectif journalier + badge temps en cours
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: a.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Objectif: ${a.dailyGoalMinutes ?? 0} min/j',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (running)
                Container(
                  padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (paused
                        ? Colors.orange.withOpacity(.15)
                        : Colors.green.withOpacity(.15)),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        paused ? Icons.pause : Icons.timer_outlined,
                        size: 14,
                      ),
                      const SizedBox(width: 4),
                      Text('$mm:$ss'),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 6),

          // Ligne 1 bis: reste aujourd'hui / objectif atteint
          todayAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (today) {
              final goal = a.dailyGoalMinutes ?? 0;
              if (goal <= 0) return const SizedBox.shrink();
              if (today >= goal) {
                return Row(
                  children: const [
                    Icon(Icons.check_circle, size: 16, color: Colors.green),
                    SizedBox(width: 6),
                    Text(
                      'Objectif du jour atteint',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                );
              } else {
                final remain = goal - today;
                return Text(
                  'Reste $remain min aujourd\'hui',
                  style: Theme.of(context).textTheme.bodySmall,
                );
              }
            },
          ),

          const SizedBox(height: 6),

          // Ligne 2: chips Semaine / Mois / Ann.
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if ((a.weeklyGoalMinutes ?? 0) > 0)
                _GoalChip(
                  async: weekTotalAsync,
                  icon: Icons.calendar_view_week,
                  label: 'Sem.',
                  goal: a.weeklyGoalMinutes,
                ),
              if ((a.monthlyGoalMinutes ?? 0) > 0)
                _GoalChip(
                  async: monthTotalAsync,
                  icon: Icons.calendar_view_month,
                  label: 'Mois',
                  goal: a.monthlyGoalMinutes,
                ),
              if ((a.yearlyGoalMinutes ?? 0) > 0)
                _GoalChip(
                  async: yearTotalAsync,
                  icon: Icons.calendar_month,
                  label: 'Ann.',
                  goal: a.yearlyGoalMinutes,
                ),
            ],
          ),

          const SizedBox(height: 8),

          OverflowBar(
            alignment: MainAxisAlignment.start,
            spacing: 8,
            overflowSpacing: 8,
            children: [
              ActivityControls(activityId: a.id, compact: true),
            ],
          ),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ActivityDetailPage(activity: a),
        ),
      ),
    );
  }
}

class _GoalChip extends StatelessWidget {
  final AsyncValue<int> async;
  final IconData icon;
  final String label;
  final int? goal;

  const _GoalChip({
    required this.async,
    required this.icon,
    required this.label,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const Chip(label: Text('...')),
      error: (e, _) => const Chip(label: Text('Err')),
      data: (m) {
        final g = goal ?? 0;
        final reached = g > 0 && m >= g;
        return Chip(
          avatar: Icon(
            icon,
            size: 16,
            color: reached ? Colors.green : null,
          ),
          label: Text(g > 0 ? '$label: $m / $g' : '$label: $m'),
          backgroundColor: reached ? Colors.green.withOpacity(.12) : null,
          side: reached ? const BorderSide(color: Colors.green) : null,
        );
      },
    );
  }
}
