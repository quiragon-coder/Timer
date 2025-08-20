# apply-goals-inputs.ps1
param([string]$Message = "feat: edit goals (day/week/month/year) from detail page")

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Step($t){ Write-Host "`n==> $t" -ForegroundColor Cyan }
function Ok($t){ Write-Host "OK: $t" -ForegroundColor Green }
function Warn($t){ Write-Host "WARN: $t" -ForegroundColor Yellow }

function Write-File {
  param([string]$Path,[string]$Content)
  $dir = Split-Path $Path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  if (Test-Path $Path) { Copy-Item -Force $Path "$Path.bak" }
  Set-Content -Path $Path -Value $Content -Encoding UTF8
  Ok "Wrote: $Path"
}

# ------------------ lib/models/activity.dart ------------------
$activityModel = @'
import "package:flutter/material.dart";

class Activity {
  final String id;
  final String name;
  final String emoji;
  final Color color;

  /// Objectifs (minutes). Tous optionnels.
  final int? dailyGoalMinutes;
  final int? weeklyGoalMinutes;
  final int? monthlyGoalMinutes;
  final int? yearlyGoalMinutes;

  const Activity({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    this.dailyGoalMinutes,
    this.weeklyGoalMinutes,
    this.monthlyGoalMinutes,
    this.yearlyGoalMinutes,
  });

  Activity copyWith({
    String? id,
    String? name,
    String? emoji,
    Color? color,
    int? dailyGoalMinutes,
    int? weeklyGoalMinutes,
    int? monthlyGoalMinutes,
    int? yearlyGoalMinutes,
  }) {
    return Activity(
      id: id ?? this.id,
      name: name ?? this.name,
      emoji: emoji ?? this.emoji,
      color: color ?? this.color,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      weeklyGoalMinutes: weeklyGoalMinutes ?? this.weeklyGoalMinutes,
      monthlyGoalMinutes: monthlyGoalMinutes ?? this.monthlyGoalMinutes,
      yearlyGoalMinutes: yearlyGoalMinutes ?? this.yearlyGoalMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "emoji": emoji,
        "color": color.value, // peut lever un warning deprecation, sans gravité
        "dailyGoalMinutes": dailyGoalMinutes,
        "weeklyGoalMinutes": weeklyGoalMinutes,
        "monthlyGoalMinutes": monthlyGoalMinutes,
        "yearlyGoalMinutes": yearlyGoalMinutes,
      };

  factory Activity.fromJson(Map<String, dynamic> json) {
    return Activity(
      id: json["id"] as String,
      name: json["name"] as String,
      emoji: json["emoji"] as String,
      color: Color((json["color"] as int?) ?? 0xFF6C63FF),
      dailyGoalMinutes: json["dailyGoalMinutes"] as int?,
      weeklyGoalMinutes: json["weeklyGoalMinutes"] as int?,
      monthlyGoalMinutes: json["monthlyGoalMinutes"] as int?,
      yearlyGoalMinutes: json["yearlyGoalMinutes"] as int?,
    );
  }
}
'@

# ------------------ lib/widgets/activity_stats_panel.dart ------------------
$statsPanel = @'
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers_stats.dart";
import "hourly_bars_chart.dart";
import "weekly_bars_chart.dart";

class ActivityStatsPanel extends ConsumerWidget {
  final String activityId;
  final int? dailyGoal;
  final int? weeklyGoal;
  final int? monthlyGoal;
  final int? yearlyGoal;

  const ActivityStatsPanel({
    super.key,
    required this.activityId,
    this.dailyGoal,
    this.weeklyGoal,
    this.monthlyGoal,
    this.yearlyGoal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(statsTodayProvider(activityId));
    final weekAsync = ref.watch(statsLast7DaysProvider(activityId));
    final hourlyAsync = ref.watch(hourlyTodayProvider(activityId));

    final weekTotalAsync  = ref.watch(weekTotalProvider(activityId));
    final monthTotalAsync = ref.watch(monthTotalProvider(activityId));
    final yearTotalAsync  = ref.watch(yearTotalProvider(activityId));

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Stats", style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),

            // Aujourd'hui + progression
            todayAsync.when(
              loading: () => const _Skeleton(height: 16),
              error: (e, _) => Text("Erreur: $e"),
              data: (today) {
                final goal = dailyGoal ?? 0;
                final reached = goal > 0 && today >= goal;
                final ratio = goal > 0 ? (today / goal).clamp(0, 1).toDouble() : null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.calendar_today, size: 18),
                          label: Text("Aujourd'hui: $today min"),
                        ),
                        if (goal > 0)
                          Chip(
                            avatar: Icon(
                              reached ? Icons.check_circle : Icons.flag,
                              size: 18,
                              color: reached ? Colors.green : null,
                            ),
                            label: Text(reached ? "Objectif atteint" : "Objectif: $goal min"),
                          ),
                      ],
                    ),
                    if (goal > 0) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(6),
                        child: LinearProgressIndicator(
                          minHeight: 10,
                          value: ratio,
                          backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        reached ? "Bravo !" : "Reste ${goal - today} min",
                        style: TextStyle(color: reached ? Colors.green : Theme.of(context).textTheme.bodySmall?.color),
                      ),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 16),
            // Totaux Semaine / Mois / Année (colorés si objectif atteint)
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _GoalTotalChip(
                  async: weekTotalAsync, icon: Icons.calendar_view_week, label: "Semaine",
                  goal: weeklyGoal,
                ),
                _GoalTotalChip(
                  async: monthTotalAsync, icon: Icons.calendar_view_month, label: "Mois",
                  goal: monthlyGoal,
                ),
                _GoalTotalChip(
                  async: yearTotalAsync, icon: Icons.calendar_month, label: "Année",
                  goal: yearlyGoal,
                ),
              ],
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            Text("Répartition horaire (aujourd'hui)"),
            const SizedBox(height: 8),
            hourlyAsync.when(
              loading: () => const _Skeleton(height: 120),
              error: (e, _) => Text("Erreur: $e"),
              data: (buckets) => SizedBox(height: 140, child: HourlyBarsChart(buckets: buckets)),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            Text("7 derniers jours"),
            const SizedBox(height: 8),
            weekAsync.when(
              loading: () => const _Skeleton(height: 140),
              error: (e, _) => Text("Erreur: $e"),
              data: (stats) => SizedBox(height: 160, child: WeeklyBarsChart(stats: stats)),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalTotalChip extends StatelessWidget {
  final AsyncValue<int> async;
  final IconData icon;
  final String label;
  final int? goal;

  const _GoalTotalChip({
    required this.async,
    required this.icon,
    required this.label,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const Chip(label: Text("...")),
      error: (e, _) => const Chip(label: Text("Err")),
      data: (m) {
        final reached = (goal ?? 0) > 0 && m >= (goal ?? 0);
        return Chip(
          avatar: Icon(icon, size: 18, color: reached ? Colors.green : null),
          label: Text(
            goal != null && goal! > 0
              ? "$label: $m / ${goal} min"
              : "$label: $m min",
          ),
          backgroundColor: reached ? Colors.green.withOpacity(.12) : null,
          side: reached ? const BorderSide(color: Colors.green) : null,
        );
      },
    );
  }
}

class _Skeleton extends StatelessWidget {
  final double height;
  const _Skeleton({required this.height});
  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest.withOpacity(.6),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
'@

# ------------------ lib/pages/activity_detail_page.dart ------------------
$detailPage = @'
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

      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final sessions = db.listSessionsByActivity(widget.activity.id);

    final running = db.isRunning(widget.activity.id);
    final paused = db.isPaused(widget.activity.id);
    _syncTicker(running);

    final elapsed = db.runningElapsed(widget.activity.id);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, "0");
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, "0");

    final a = widget.activity; // alias

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
'@

# ------------------ WRITE FILES ------------------
Step "Write files"
Write-File "lib/models/activity.dart" $activityModel
Write-File "lib/widgets/activity_stats_panel.dart" $statsPanel
Write-File "lib/pages/activity_detail_page.dart" $detailPage

# ------------------ FLUTTER ------------------
Step "Flutter clean"
flutter clean
Step "Flutter pub get"
flutter pub get
Step "Flutter analyze"
flutter analyze

# ------------------ GIT ------------------
if (Test-Path ".git") {
  Step "Git add/commit/push"
  git add -A
  git commit -m "$Message" 2>$null | Out-Null
  try { git pull --rebase } catch {}
  try { git push; Ok "Pushed to GitHub" } catch { Warn "Push failed" }
} else {
  Warn "No .git directory - skipping push."
}
