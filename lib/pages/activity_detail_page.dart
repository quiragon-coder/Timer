import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:intl/intl.dart";

import "../models/activity.dart";
import "../models/session.dart";
import "../providers.dart";
import "../widgets/activity_controls.dart";
import "../widgets/activity_stats_panel.dart";

class ActivityDetailPage extends ConsumerStatefulWidget {
  final Activity activity;
  const ActivityDetailPage({super.key, required this.activity});

  @override
  ConsumerState<ActivityDetailPage> createState() => _ActivityDetailPageState();
}

class _ActivityDetailPageState extends ConsumerState<ActivityDetailPage> {
  @override
  void initState() {
    super.initState();
    _current = _current;
  }

  late Activity _current;
  final _df = DateFormat("dd MMM HH:mm");
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

  Future<void> _openGoalsSheet(Activity a) async {
    final dailyCtrl  = TextEditingController(text: a.dailyGoalMinutes?.toString()  ?? "");
    final weeklyCtrl = TextEditingController(text: a.weeklyGoalMinutes?.toString() ?? "");
    final monthCtrl  = TextEditingController(text: a.monthlyGoalMinutes?.toString()?? "");
    final yearCtrl   = TextEditingController(text: a.yearlyGoalMinutes?.toString() ?? "");

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
            top: 16, left: 16, right: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.flag_outlined),
                  const SizedBox(width: 8),
                  Text("Objectifs", style: Theme.of(ctx).textTheme.titleLarge),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx, false),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _NumField(label: "Objectif journalier (min)", controller: dailyCtrl),
              const SizedBox(height: 8),
              _NumField(label: "Objectif hebdo (min)", controller: weeklyCtrl),
              const SizedBox(height: 8),
              _NumField(label: "Objectif mensuel (min)", controller: monthCtrl),
              const SizedBox(height: 8),
              _NumField(label: "Objectif annuel (min)", controller: yearCtrl),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  icon: const Icon(Icons.save),
                  label: const Text("Enregistrer"),
                  onPressed: () {
                    Navigator.pop(ctx, true);
                  },
                ),
              ),
            ],
          ),
        );
      },
    );

    if (saved == true) {
      int? parseOrNull(String s) => s.trim().isEmpty ? null : int.tryParse(s.trim());

      final updated = a.copyWith(
        dailyGoalMinutes:  parseOrNull(dailyCtrl.text),
        weeklyGoalMinutes: parseOrNull(weeklyCtrl.text),
        monthlyGoalMinutes:parseOrNull(monthCtrl.text),
        yearlyGoalMinutes: parseOrNull(yearCtrl.text),
      );

      final db = ref.read(dbProvider);
      // On suppose que DatabaseService expose updateActivity(...)
      db.updateActivity(updated);

      
      _current = updated;
      if (mounted) setState(() {});
}
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final sessions = db.listSessionsByActivity(_current.id);

    final running = db.isRunning(_current.id);
    final paused = db.isPaused(_current.id);
    _syncTicker(running);

    final elapsed = db.runningElapsed(_current.id);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, "0");
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, "0");

    final a = _current; // alias

    return Scaffold(
      appBar: AppBar(
        title: Text("${a.emoji} ${a.name}", overflow: TextOverflow.ellipsis),
        actions: [
          if (running)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (paused ? Colors.orange : Colors.green).withOpacity(.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(paused ? Icons.pause : Icons.timer_outlined, size: 16),
                      const SizedBox(width: 4),
                      Text("$mm:$ss"),
                    ],
                  ),
                ),
              ),
            ),
          IconButton(
            tooltip: "Objectifs",
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => _openGoalsSheet(a),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            Card(
              elevation: 0,
              color: Theme.of(context).colorScheme.surface,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(a.emoji, style: const TextStyle(fontSize: 28)),
                        Container(width: 12, height: 12,
                          decoration: BoxDecoration(color: a.color, shape: BoxShape.circle)),
                        Text(
                          "Objectif: ${a.dailyGoalMinutes ?? 0} min/j",
                          maxLines: 1, overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OverflowBar(
                      alignment: MainAxisAlignment.start,
                      spacing: 8, overflowSpacing: 8,
                      children: [
                        ActivityControls(activityId: a.id, compact: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
            Text("Historique", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            if (sessions.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Text("Aucune session pour le moment."),
              )
            else
              Column(children: [ for (final s in sessions) _SessionTile(df: _df, s: s) ]),

            ActivityStatsPanel(
              activityId: a.id,
              dailyGoal: a.dailyGoalMinutes,
              weeklyGoal: a.weeklyGoalMinutes,
              monthlyGoal: a.monthlyGoalMinutes,
              yearlyGoal: a.yearlyGoalMinutes,
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
    final dur = s.duration;
    final hh = dur.inHours.toString().padLeft(2, "0");
    final mm = dur.inMinutes.remainder(60).toString().padLeft(2, "0");
    final ss = dur.inSeconds.remainder(60).toString().padLeft(2, "0");

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(
        end == null ? Icons.play_circle_fill : Icons.check_circle,
        color: end == null ? Colors.orange : Colors.green,
      ),
      title: Text(
        end == null ? "En cours" : "Fini ($hh:$mm:$ss)",
        maxLines: 1, overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        "${df.format(s.startAt)} -> ${end == null ? "en cours" : df.format(end)}",
        maxLines: 1, overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

class _NumField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  const _NumField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        hintText: "ex: 30",
        border: const OutlineInputBorder(),
      ),
    );
  }
}

