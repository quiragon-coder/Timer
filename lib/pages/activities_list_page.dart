import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../providers.dart';                 // dbProvider
import '../widgets/activity_controls.dart'; // start / pause / stop
import 'create_activity_page.dart';
import 'activity_detail_page.dart';

class ActivitiesListPage extends ConsumerWidget {
  const ActivitiesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Si tu as un activitiesProvider (FutureProvider<List<Activity>>), dé-commente la ligne suivante
    // final activitiesAsync = ref.watch(activitiesProvider);

    // Sinon on lit directement la liste depuis le service (synchrone)
    final db = ref.watch(dbProvider);
    final list = db.activities;

    return Scaffold(
      appBar: AppBar(title: const Text('Activities')),
      body: list.isEmpty
          ? const Center(
        child: Text('Aucune activité. Ajoute-en une →'),
      )
          : ListView.separated(
        padding: const EdgeInsets.all(12),
        itemCount: list.length,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (_, i) => _ActivityTile(a: list[i]),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateActivityPage()),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Ajouter'),
      ),
    );

    // --- Variante si tu utilises activitiesProvider (AsyncValue) ---
    // return Scaffold(
    //   appBar: AppBar(title: const Text('Activities')),
    //   body: activitiesAsync.when(
    //     loading: () => const Center(child: CircularProgressIndicator()),
    //     error: (e, _) => Center(child: Text('Erreur: $e')),
    //     data: (list) {
    //       if (list.isEmpty) {
    //         return const Center(child: Text('Aucune activité. Ajoute-en une →'));
    //       }
    //       return ListView.separated(
    //         padding: const EdgeInsets.all(12),
    //         itemCount: list.length,
    //         separatorBuilder: (_, __) => const Divider(height: 1),
    //         itemBuilder: (_, i) => _ActivityTile(a: list[i]),
    //       );
    //     },
    //   ),
    //   floatingActionButton: FloatingActionButton.extended(
    //     onPressed: () => Navigator.of(context).push(
    //       MaterialPageRoute(builder: (_) => const CreateActivityPage()),
    //     ),
    //     icon: const Icon(Icons.add),
    //     label: const Text('Ajouter'),
    //   ),
    // );
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
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _syncTicker(bool tick) {
    final active = _ticker?.isActive ?? false;
    if (tick && !active) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!tick && active) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);               // WATCH pour rebuild quand notifyListeners()
    final running = db.isRunning(widget.a.id);
    final paused  = db.isPaused(widget.a.id);

    // Le ticker ne tourne que quand la session est démarrée et non en pause
    _syncTicker(running && !paused);

    final elapsed = db.runningElapsed(widget.a.id);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      leading: Text(widget.a.emoji, style: const TextStyle(fontSize: 24)),
      title: Text(widget.a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: widget.a.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  "Objectif: ${(widget.a.dailyGoalMinutes ?? 0)} min/j",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (running)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: paused ? Colors.orange.withOpacity(.15) : Colors.green.withOpacity(.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(paused ? Icons.pause : Icons.timer_outlined, size: 14),
                      const SizedBox(width: 4),
                      Text("$mm:$ss"),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          // Contrôles Start/Pause/Stop
          OverflowBar(
            alignment: MainAxisAlignment.start,
            spacing: 8,
            overflowSpacing: 8,
            children: [ActivityControls(activityId: widget.a.id, compact: true)],
          ),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => ActivityDetailPage(activity: widget.a)),
        );
      },
    );
  }
}
