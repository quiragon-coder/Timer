# apply-goals-ui.ps1
param([string]$Message = "feat: goals progress (day/week/month/year)")

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

# ---------- FILE CONTENTS ----------

$statsService = @'
import "package:habits_timer/models/stats.dart";
import "package:habits_timer/services/database_service.dart";

class StatsService {
  final DatabaseService db;
  StatsService(this.db);

  Future<int> minutesToday(String activityId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));
    return _minutesInRange(activityId, start, end);
  }

  Future<List<HourlyBucket>> hourlyToday(String activityId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final end = start.add(const Duration(days: 1));

    final buckets = List.generate(24, (i) => HourlyBucket(i, 0));
    final sessions = db.listSessionsByActivity(activityId);
    for (final s in sessions) {
      final sStart = s.startAt;
      final sEnd = s.endAt ?? DateTime.now();
      final ovStart = sStart.isAfter(start) ? sStart : start;
      final ovEnd = sEnd.isBefore(end) ? sEnd : end;
      if (!ovEnd.isAfter(ovStart)) continue;

      // Soustraire les pauses
      var effective = ovEnd.difference(ovStart).inMinutes;
      final pauses = db.listPausesBySession(s.id);
      for (final p in pauses) {
        final ppStart = p.startAt.isAfter(ovStart) ? p.startAt : ovStart;
        final ppEnd = (p.endAt ?? DateTime.now()).isBefore(ovEnd) ? (p.endAt ?? DateTime.now()) : ovEnd;
        if (ppEnd.isAfter(ppStart)) {
          effective -= ppEnd.difference(ppStart).inMinutes;
        }
      }

      // Répartir par heure
      var cursor = ovStart;
      var remain = effective;
      while (remain > 0 && cursor.isBefore(ovEnd)) {
        final bucketHourEnd = DateTime(cursor.year, cursor.month, cursor.day, cursor.hour).add(const Duration(hours: 1));
        final splitEnd = bucketHourEnd.isBefore(ovEnd) ? bucketHourEnd : ovEnd;
        final mins = splitEnd.difference(cursor).inMinutes;
        if (mins > 0) {
          buckets[cursor.hour] = HourlyBucket(cursor.hour, buckets[cursor.hour].minutes + mins);
          remain -= mins;
        }
        cursor = splitEnd;
      }
    }
    return buckets;
  }

  Future<List<DailyStat>> last7DaysStats(String activityId) async {
    final today = DateTime.now();
    final start = DateTime(today.year, today.month, today.day).subtract(const Duration(days: 6));
    final days = <DailyStat>[];
    for (int i = 0; i < 7; i++) {
      final dStart = DateTime(start.year, start.month, start.day).add(Duration(days: i));
      final dEnd = dStart.add(const Duration(days: 1));
      final m = await _minutesInRange(activityId, dStart, dEnd);
      days.add(DailyStat(dStart, m));
    }
    return days;
  }

  Future<int> minutesThisWeek(String activityId) async {
    final now = DateTime.now();
    // Semaine Lundi->Dimanche
    final dow = now.weekday; // 1..7
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: dow - 1));
    final end = start.add(const Duration(days: 7));
    return _minutesInRange(activityId, start, end);
  }

  Future<int> minutesThisMonth(String activityId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = (now.month == 12) ? DateTime(now.year + 1, 1, 1) : DateTime(now.year, now.month + 1, 1);
    return _minutesInRange(activityId, start, end);
  }

  Future<int> minutesThisYear(String activityId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, 1, 1);
    final end = DateTime(now.year + 1, 1, 1);
    return _minutesInRange(activityId, start, end);
  }

  // ---- Helpers ----
  Future<int> _minutesInRange(String activityId, DateTime start, DateTime end) async {
    int total = 0;
    final sessions = db.listSessionsByActivity(activityId);
    for (final s in sessions) {
      final sStart = s.startAt;
      final sEnd = s.endAt ?? DateTime.now();
      final ovStart = sStart.isAfter(start) ? sStart : start;
      final ovEnd = sEnd.isBefore(end) ? sEnd : end;
      if (!ovEnd.isAfter(ovStart)) continue;

      var eff = ovEnd.difference(ovStart).inMinutes;
      final pauses = db.listPausesBySession(s.id);
      for (final p in pauses) {
        final ppStart = p.startAt.isAfter(ovStart) ? p.startAt : ovStart;
        final ppEnd = (p.endAt ?? DateTime.now()).isBefore(ovEnd) ? (p.endAt ?? DateTime.now()) : ovEnd;
        if (ppEnd.isAfter(ppStart)) {
          eff -= ppEnd.difference(ppStart).inMinutes;
        }
      }
      if (eff > 0) total += eff;
    }
    return total;
  }
}
'@

$providersStats = @'
import "package:flutter_riverpod/flutter_riverpod.dart";
import "package:habits_timer/models/stats.dart";
import "package:habits_timer/services/database_service.dart";
import "package:habits_timer/services/stats_service.dart";
import "providers.dart";

final statsServiceProvider = Provider<StatsService>((ref) {
  final db = ref.read(dbProvider);
  return StatsService(db);
});

// Jour
final statsTodayProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final svc = ref.read(statsServiceProvider);
  return svc.minutesToday(activityId);
});

// Horaires aujourd'hui
final hourlyTodayProvider = FutureProvider.family<List<HourlyBucket>, String>((ref, activityId) async {
  final svc = ref.read(statsServiceProvider);
  return svc.hourlyToday(activityId);
});

// 7 derniers jours
final statsLast7DaysProvider = FutureProvider.family<List<DailyStat>, String>((ref, activityId) async {
  final svc = ref.read(statsServiceProvider);
  return svc.last7DaysStats(activityId);
});

// Totaux Semaine / Mois / Annee
final weekTotalProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final svc = ref.read(statsServiceProvider);
  return svc.minutesThisWeek(activityId);
});

final monthTotalProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final svc = ref.read(statsServiceProvider);
  return svc.minutesThisMonth(activityId);
});

final yearTotalProvider = FutureProvider.family<int, String>((ref, activityId) async {
  final svc = ref.read(statsServiceProvider);
  return svc.minutesThisYear(activityId);
});
'@

$activityStatsPanel = @'
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers_stats.dart";
import "hourly_bars_chart.dart";
import "weekly_bars_chart.dart";

class ActivityStatsPanel extends ConsumerWidget {
  final String activityId;
  final int? dailyGoal; // minutes

  const ActivityStatsPanel({
    super.key,
    required this.activityId,
    this.dailyGoal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final todayAsync = ref.watch(statsTodayProvider(activityId));
    final weekAsync = ref.watch(statsLast7DaysProvider(activityId));
    final hourlyAsync = ref.watch(hourlyTodayProvider(activityId));

    // nouveaux totaux
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

            // --- Minutes du jour + objectif ---
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
                            avatar: Icon(reached ? Icons.check_circle : Icons.flag,
                                size: 18, color: reached ? Colors.green : null),
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
                          backgroundColor: Theme.of(context).colorScheme.surfaceVariant,
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
            // --- Totaux Week / Month / Year ---
            Wrap(
              spacing: 8, runSpacing: 8,
              children: [
                _TotalChip(async: weekTotalAsync, icon: Icons.calendar_view_week, label: "Semaine"),
                _TotalChip(async: monthTotalAsync, icon: Icons.calendar_view_month, label: "Mois"),
                _TotalChip(async: yearTotalAsync, icon: Icons.calendar_month, label: "Année"),
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

class _TotalChip extends StatelessWidget {
  final AsyncValue<int> async;
  final IconData icon;
  final String label;
  const _TotalChip({required this.async, required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const Chip(label: Text("...")),
      error: (e, _) => Chip(label: Text("Err")),
      data: (m) => Chip(
        avatar: Icon(icon, size: 18),
        label: Text("$label: $m min"),
      ),
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
        color: Theme.of(context).colorScheme.surfaceVariant.withOpacity(.6),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}
'@

$activitiesList = @'
import "dart:async";
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../models/activity.dart";
import "../providers.dart";
import "../providers_stats.dart";
import "../widgets/activity_controls.dart";
import "create_activity_page.dart";
import "activity_detail_page.dart";

class ActivitiesListPage extends ConsumerWidget {
  const ActivitiesListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activitiesAsync = ref.watch(activitiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text("Activities")),
      body: activitiesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Erreur: $e")),
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text("Aucune activité. Ajoute-en une ➕"));
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
        label: const Text("Ajouter"),
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

  void _syncTicker(bool running) {
    final active = _ticker?.isActive ?? false;
    if (running && !active) {
      _ticker = Timer.periodic(const Duration(seconds: 1), (_) { if (mounted) setState(() {}); });
    } else if (!running && active) {
      _ticker?.cancel();
      _ticker = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = ref.watch(dbProvider);
    final running = db.isRunning(widget.a.id);
    final paused = db.isPaused(widget.a.id);
    _syncTicker(running);

    // minutes today -> pour objectif
    final todayAsync = ref.watch(statsTodayProvider(widget.a.id));

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
              Container(width: 10, height: 10, decoration: BoxDecoration(color: widget.a.color, shape: BoxShape.circle)),
              const SizedBox(width: 8),
              Expanded(
                child: Text("Objectif: ${widget.a.dailyGoalMinutes ?? 0} min/j",
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 8),
              if (running)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: paused ? Colors.orange.withOpacity(.15) : Colors.green.withOpacity(.15),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(paused ? Icons.pause : Icons.timer_outlined, size: 14),
                    const SizedBox(width: 4), Text("$mm:$ss"),
                  ]),
                ),
            ],
          ),
          const SizedBox(height: 6),

          // Reste X min aujourd'hui ou check
          todayAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (e, _) => const SizedBox.shrink(),
            data: (today) {
              final goal = widget.a.dailyGoalMinutes ?? 0;
              if (goal <= 0) return const SizedBox.shrink();
              if (today >= goal) {
                return Row(children: const [
                  Icon(Icons.check_circle, size: 16, color: Colors.green),
                  SizedBox(width: 6),
                  Text("Objectif du jour atteint", maxLines: 1, overflow: TextOverflow.ellipsis),
                ]);
              } else {
                final remain = goal - today;
                return Text("Reste $remain min aujourd'hui",
                    style: Theme.of(context).textTheme.bodySmall);
              }
            },
          ),

          const SizedBox(height: 8),
          OverflowBar(
            alignment: MainAxisAlignment.start,
            spacing: 8, overflowSpacing: 8,
            children: [ ActivityControls(activityId: widget.a.id, compact: true) ],
          ),
        ],
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ActivityDetailPage(activity: widget.a)),
      ),
    );
  }
}
'@

# ---------- WRITE FILES ----------
Step "Write files"
Write-File -Path "lib/services/stats_service.dart" -Content $statsService
Write-File -Path "lib/providers_stats.dart"       -Content $providersStats
Write-File -Path "lib/widgets/activity_stats_panel.dart" -Content $activityStatsPanel
Write-File -Path "lib/pages/activities_list_page.dart"   -Content $activitiesList

# ---------- FLUTTER ----------
Step "Flutter clean"
flutter clean

Step "Flutter pub get"
flutter pub get

Step "Flutter analyze"
flutter analyze

# ---------- GIT ----------
if (Test-Path ".git") {
  Step "Git add/commit/push"
  git add -A
  git commit -m "$Message" 2>$null | Out-Null
  try { git pull --rebase } catch {}
  try { git push; Ok "Pushed to GitHub" } catch { Warn "Push failed" }
} else {
  Warn "No .git directory - skipping push."
}
