import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../models/activity.dart';
import '../models/session.dart';
import '../providers.dart';
import '../widgets/activity_controls.dart';
import '../widgets/activity_stats_panel.dart';

class ActivityDetailPage extends ConsumerStatefulWidget {
  final Activity activity;
  const ActivityDetailPage({super.key, required this.activity});

  @override
  ConsumerState<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends ConsumerState<ActivityDetailPage> {
  final _df = DateFormat('dd MMM HH:mm');

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.activity.emoji} ${widget.activity.name}'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(12),
        child: ListView(
          children: [
            Row(
              children: [
                Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: widget.activity.color,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Text('Objectif jour: ${widget.activity.dailyGoalMinutes ?? 0} min'),
                const Spacer(),
                ActivityControls(activityId: widget.activity.id),
              ],
            ),
            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),
            Text('Historique', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            FutureBuilder<List<Session>>(
              future: ref.read(dbProvider).getSessionsByActivity(widget.activity.id),
              builder: (context, snap) {
                if (!snap.hasData) {
                  if (snap.hasError) return Text('Erreur: ${snap.error}');
                  return const Padding(
                    padding: EdgeInsets.all(24),
                    child: Center(child: CircularProgressIndicator()),
                  );
                }
                final sessions = snap.data!;
                if (sessions.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.symmetric(vertical: 24),
                    child: Text('Aucune session pour le moment.'),
                  );
                }
                return Column(
                  children: [
                    for (final s in sessions) _SessionTile(df: _df, s: s),
                  ],
                );
              },
            ),
            const SizedBox(height: 16),
            ActivityStatsPanel(activity: widget.activity),
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
    final dur = s.duration;
    final mm = dur.inMinutes.toString();
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
