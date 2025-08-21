// lib/pages/activities_list_page.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../providers.dart';
import '../utils/color_compat.dart';
import '../widgets/mini_heatmap.dart';
import '../widgets/elapsed_badge.dart';
import 'activity_detail_page.dart';
import 'create_activity_page.dart';

class ActivitiesListPage extends ConsumerWidget {
  const ActivitiesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final db = ref.watch(dbProvider);
    final activities = db.activities;

    void goToCreate() async {
      await Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CreateActivityPage()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mes activités'),
        actions: [
          IconButton(
            tooltip: 'Nouvelle activité',
            icon: const Icon(Icons.add_rounded),
            onPressed: goToCreate,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: goToCreate,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Créer'),
      ),
      body: activities.isEmpty
          ? _EmptyState(onCreate: goToCreate)
          : ListView.separated(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 96),
        itemCount: activities.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final a = activities[index];
          final isRunning = db.isRunning(a.id);
          final isPaused = db.isPaused(a.id);

          return Card(
            elevation: 0,
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => ActivityDetailPage(activityId: a.id),
                ));
              },
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Text(a.emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            a.name,
                            style: Theme.of(context).textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),

                        if (isRunning)
                          ElapsedBadge(
                            isRunning: isRunning,
                            isPaused: isPaused,
                            getElapsed: () => db.runningElapsed(a.id),
                          ),

                        const SizedBox(width: 8),

                        IconButton(
                          tooltip: 'Démarrer',
                          icon: const Icon(Icons.play_arrow_rounded),
                          onPressed: isRunning ? null : () async { await db.start(a.id); },
                        ),
                        IconButton(
                          tooltip: isPaused ? 'Reprendre' : 'Pause',
                          icon: Icon(isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded),
                          onPressed: isRunning ? () async { await db.togglePause(a.id); } : null,
                        ),
                        IconButton(
                          tooltip: 'Stop',
                          icon: const Icon(Icons.stop_rounded),
                          onPressed: isRunning ? () async { await db.stop(a.id); } : null,
                        ),
                      ],
                    ),

                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: MiniHeatmap(activityId: a.id, days: 28, baseColor: a.color),
                    ),

                    const SizedBox(height: 8),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: 64,
                        height: 4,
                        decoration: BoxDecoration(
                          color: a.color.withAlphaCompat(.9),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onCreate;
  const _EmptyState({required this.onCreate});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 60),
      children: [
        const SizedBox(height: 40),
        Icon(Icons.timer_outlined, size: 72, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text("Aucune activité", textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 8),
        Text("Crée ta première activité pour démarrer un timer.",
            textAlign: TextAlign.center, style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 24),
        Center(
          child: FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add_rounded), label: const Text("Créer une activité")),
        ),
      ],
    );
  }
}
