// lib/pages/activities_list_page.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../providers.dart'; // dbProvider, activitiesProvider
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
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const CreateActivityPage()),
          );
        },
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
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _ensureTicker(bool running) {
    final active = _ticker?.isActive ?? false;
    if (running && !active) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {}); // tick visuel du badge
      });
    } else if (!running && active) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);

    final id      = widget.a.id;
    final running = db.isRunning(id);
    final paused  = db.isPaused(id);

    // Lance/arrête le ticker selon l’état courant
    _ensureTicker(running);

    Duration elapsed;
    try {
      elapsed = db.runningElapsed(id);
    } catch (_) {
      elapsed = Duration.zero;
    }
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      leading: Text(widget.a.emoji, style: const TextStyle(fontSize: 24)),
      title: Text(widget.a.name, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne d’info + badge ⏱
          Row(
            children: [
              // pastille couleur
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: widget.a.color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              // objectif jour (si défini)
              Expanded(
                child: Text(
                  (widget.a.dailyGoalMinutes ?? 0) > 0
                      ? "Objectif: ${widget.a.dailyGoalMinutes} min/j"
                      : "Aucun objectif journalier",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              // Badge temps en cours (uniquement si running)
              if (running)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (paused ? Colors.orange : Colors.green).withOpacity(.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(paused ? Icons.pause : Icons.timer_outlined, size: 14),
                    const SizedBox(width: 4),
                    Text("$mm:$ss"),
                  ]),
                ),
            ],
          ),

          const SizedBox(height: 8),

          // Contrôles compacts
          OverflowBar(
            alignment: MainAxisAlignment.start,
            spacing: 8,
            overflowSpacing: 8,
            children: [
              ActivityControls(activityId: id, compact: true),
            ],
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
