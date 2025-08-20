import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/activity.dart';
import '../models/session.dart';
import '../providers.dart';
import '../widgets/activity_controls.dart';

class ActivityDetailPage extends ConsumerWidget {
  final Activity activity;
  ActivityDetailPage({super.key, required this.activity});

  final _df = DateFormat('dd MMM HH:mm');

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // watch -> rebuild quand le service notifie
    final db = ref.watch(dbProvider);
    final sessions = db.listSessionsByActivity(activity.id);

    return Scaffold(
      appBar: AppBar(title: Text('${activity.emoji} ${activity.name}')),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            Row(
              children: [
                Container(
                  width: 16, height: 16,
                  decoration: BoxDecoration(color: activity.color, shape: BoxShape.circle),
                ),
                const SizedBox(width: 8),
                Text('Objectif jour: ${activity.dailyGoalMinutes ?? 0} min'),
                const Spacer(),
                ActivityControls(activityId: activity.id),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text('Historique', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text('Aucune session pour le moment.'),
              )
            else
              Column(
                children: [
                  for (final s in sessions) _SessionTile(df: _df, s: s),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final DateFormat df;
  final Session s;
  const _SessionTile({required this.df, required this.s});

  @override
  Widget build(BuildContext context) {
    final end = s.endAt;
    final mm = s.duration.inMinutes.toString();
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        end == null ? Icons.play_circle_fill : Icons.check_circle,
        color: end == null ? Colors.orange : Colors.green,
      ),
      title: Text(end == null ? 'En cours' : 'Fini ($mm min)'),
      subtitle: Text('${df.format(s.startAt)} → ${end == null ? 'en cours' : df.format(end)}'),
    );
  }
}
