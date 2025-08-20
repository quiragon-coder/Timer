import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../providers.dart';
import '../widgets/activity_controls.dart';
import 'create_activity_page.dart';
import 'activity_detail_page.dart';

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
            return const Center(child: Text('Aucune activité. Ajoute-en une ➕'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(12),
            itemCount: list.length,
            separatorBuilder: (_, __) => const Divider(),
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

class _ActivityTile extends ConsumerStatefulWidget {
  final Activity a;
  const _ActivityTile({required this.a});

  @override
  ConsumerState<_ActivityTile> createState() => _ActivityTileState();
}

class _ActivityTileState extends ConsumerState<_ActivityTile> {
  Timer? _ticker;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _armTicker();
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _armTicker() {
    _ticker?.cancel();
    if (ref.read(dbProvider).isRunning(widget.a.id)) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final running = db.isRunning(widget.a.id);
    final paused = db.isPaused(widget.a.id);
    final elapsed = db.runningElapsed(widget.a.id);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return ListTile(
      leading: Text(widget.a.emoji, style: const TextStyle(fontSize: 24)),
      title: Text(widget.a.name),
      subtitle: Row(
        children: [
          Container(width: 10, height: 10, decoration: BoxDecoration(color: widget.a.color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Text('Objectif: ${widget.a.dailyGoalMinutes ?? 0} min/j'),
          const SizedBox(width: 8),
          if (running)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: paused ? Colors.orange.withOpacity(.15) : Colors.green.withOpacity(.15),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(paused ? '⏸ $mm:$ss' : '⏱ $mm:$ss'),
            ),
        ],
      ),
      trailing: ActivityControls(activityId: widget.a.id),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ActivityDetailPage(activity: widget.a)),
      ),
    );
  }
}
