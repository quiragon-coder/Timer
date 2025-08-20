import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../providers.dart';
import '../widgets/activity_controls.dart';
import 'activity_detail_page.dart';
import 'create_activity_page.dart';

class ActivitiesListPage extends ConsumerWidget {
  const ActivitiesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(activitiesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Habits Timer'),
      ),
      body: activitiesAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('Aucune activité. Appuie sur + pour créer.'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final a = list[i];
              return ListTile(
                leading: Text(a.emoji, style: const TextStyle(fontSize: 22)),
                title: Text(a.name),
                subtitle: Text('Objectif jour: ${a.dailyGoalMinutes ?? 0} min'),
                trailing: ActivityControls(activityId: a.id),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => ActivityDetailPage(activity: a)),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, st) => Center(child: Text('Erreur: $e')),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateActivityPage()),
          );
          // refresh
          ref.invalidate(activitiesProvider);
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );
  }
}
