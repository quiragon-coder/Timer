import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/activity.dart';
import '../providers.dart'; // activitiesProvider, dbProvider
import '../providers_settings.dart';
import '../widgets/activity_controls.dart';
import '../widgets/mini_heatmap.dart';
import 'activity_detail_page.dart';
import 'create_activity_page.dart';
import 'settings_page.dart';

class ActivitiesListPage extends ConsumerWidget {
  const ActivitiesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(activitiesProvider);
    final settings = ref.watch(settingsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Activities'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Réglages',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const SettingsPage()),
            ),
          ),
        ],
      ),
      body: activitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Erreur: $e')),
        data: (list0) {
          if (list0.isEmpty) {
            return const Center(
              child: Text('Aucune activit\u00E9. Ajoute-en une \u2192'),
            );
          }

          // Tri selon réglage
          final db = ref.watch(dbProvider);
          final list = [...list0];
          switch (settings.activitiesSort) {
            case ActivitiesSort.name:
              list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
              break;
            case ActivitiesSort.runningFirst:
              list.sort((a, b) {
                final ar = db.isRunning(a.id) ? 1 : 0;
                final br = db.isRunning(b.id) ? 1 : 0;
                if (ar != br) return br - ar; // running d'abord
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });
              break;
          }

          // Cas 1 activité -> mini-heatmap selon le réglage
          if (list.length == 1 && settings.showMiniHeatmapHome) {
            final a = list.first;
            return ListView(
              padding: const EdgeInsets.all(12),
              children: [
                _ActivityTile(a: a),
                const SizedBox(height: 12),
                Card(
                  elevation: 0,
                  clipBehavior: Clip.antiAlias,
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('7 derniers jours',
                            style: Theme.of(context).textTheme.titleMedium),
                        const SizedBox(height: 8),
                        MiniHeatmap(activityId: a.id, days: 21),
                      ],
                    ),
                  ),
                ),
              ],
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

class _ActivityTile extends ConsumerStatefulWidget {
  const _ActivityTile({required this.a});
  final Activity a;

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

  void _syncTicker(bool running) {
    final active = _ticker?.isActive ?? false;
    if (running && !active) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
        if (mounted) setState(() {});
      });
    } else if (!running && active) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    final db = ref.watch(dbProvider);

    final running = db.isRunning(widget.a.id);
    final paused = db.isPaused(widget.a.id);
    _syncTicker(running);

    final elapsed = db.runningElapsed(widget.a.id);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    final compact = settings.compactListTiles;

    return ListTile(
      dense: compact,
      contentPadding: EdgeInsets.symmetric(
        horizontal: 12,
        vertical: compact ? 4 : 8,
      ),
      leading: Text(widget.a.emoji, style: const TextStyle(fontSize: 24)),
      title: Text(
        widget.a.name,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Ligne info + badge timer
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: widget.a.color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Objectif: ${widget.a.dailyGoalMinutes ?? 0} min/j',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              if (running)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: (paused ? Colors.orange : Colors.green).withOpacity(.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(paused ? Icons.pause : Icons.timer_outlined, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      settings.showSecondsInBadges
                          ? '$mm:$ss'
                          : '${elapsed.inMinutes} min',
                    ),
                  ]),
                ),
            ],
          ),

          const SizedBox(height: 8),

          OverflowBar(
            alignment: MainAxisAlignment.start,
            spacing: 8,
            overflowSpacing: 8,
            children: [
              ActivityControls(activityId: widget.a.id, compact: true),
            ],
          ),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ActivityDetailPage(activity: widget.a)),
      ),
    );
  }
}
