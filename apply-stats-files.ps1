# apply-stats-files.ps1
param(
  [string]$Message = "feat: stats panel + charts"
)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Step($t){ Write-Host "`n==> $t" -ForegroundColor Cyan }
function Ok($t){ Write-Host "OK: $t" -ForegroundColor Green }
function Warn($t){ Write-Host "WARN: $t" -ForegroundColor Yellow }

function Write-File-With-Backup {
  param(
    [string]$Path,
    [string]$Content
  )
  $dir = Split-Path $Path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  if (Test-Path $Path) {
    Copy-Item -Force $Path "$Path.bak"
  }
  Set-Content -Path $Path -Value $Content -Encoding UTF8
  Ok "Wrote: $Path"
}

# 0) Sanity check
if (-not (Test-Path "pubspec.yaml")) {
  throw "pubspec.yaml not found. Please run this at the project root."
}

# 1) Files content -------------------------------------------------------------

$activityStatsPanel = @'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers_stats.dart';
import 'hourly_bars_chart.dart';
import 'weekly_bars_chart.dart';

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

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Stats', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 12),

            // Minutes du jour + objectif
            todayAsync.when(
              loading: () => const _Skeleton(height: 16),
              error: (e, _) => Text('Erreur: $e'),
              data: (today) {
                final goal = dailyGoal ?? 0;
                final reached = goal > 0 && today >= goal;
                final ratio = goal > 0 ? (today / goal).clamp(0, 1).toDouble() : null;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Chip(
                          label: Text('Aujourd\'hui: $today min'),
                          avatar: const Icon(Icons.today, size: 18),
                        ),
                        if (goal > 0)
                          Chip(
                            label: Text('Objectif: $goal min'),
                            avatar: Icon(
                              reached ? Icons.check_circle : Icons.flag,
                              size: 18,
                              color: reached ? Colors.green : null,
                            ),
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
                        reached ? 'Objectif atteint !' : '${(100 * (ratio ?? 0)).toStringAsFixed(0)}%',
                        style: TextStyle(
                          color: reached ? Colors.green : Theme.of(context).textTheme.bodySmall?.color,
                        ),
                      ),
                    ],
                  ],
                );
              },
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // Repartition horaire (aujourd'hui)
            Text('Repartition horaire (aujourd\'hui)'),
            const SizedBox(height: 8),
            hourlyAsync.when(
              loading: () => const _Skeleton(height: 120),
              error: (e, _) => Text('Erreur: $e'),
              data: (buckets) => SizedBox(
                height: 140,
                child: HourlyBarsChart(buckets: buckets),
              ),
            ),

            const SizedBox(height: 16),
            const Divider(),
            const SizedBox(height: 8),

            // 7 derniers jours
            Text('7 derniers jours'),
            const SizedBox(height: 8),
            weekAsync.when(
              loading: () => const _Skeleton(height: 140),
              error: (e, _) => Text('Erreur: $e'),
              data: (stats) => SizedBox(
                height: 160,
                child: WeeklyBarsChart(stats: stats),
              ),
            ),
          ],
        ),
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

$hourlyBarsChart = @'
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import '../models/stats.dart';

class HourlyBarsChart extends StatelessWidget {
  final List<HourlyBucket> buckets;
  const HourlyBarsChart({super.key, required this.buckets});

  @override
  Widget build(BuildContext context) {
    final maxVal = (buckets.map((b) => b.minutes).fold<int>(0, (a, b) => a > b ? a : b)).clamp(1, 9999);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceBetween,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 18,
              getTitlesWidget: (val, meta) {
                final h = val.toInt();
                if ({0, 6, 12, 18, 23}.contains(h)) {
                  return Text('$h', style: const TextStyle(fontSize: 10));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
        barGroups: [
          for (final b in buckets)
            BarChartGroupData(
              x: b.hour,
              barRods: [
                BarChartRodData(
                  toY: b.minutes.toDouble(),
                  width: 6,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
        ],
        maxY: maxVal.toDouble() * 1.2,
      ),
    );
  }
}
'@

$weeklyBarsChart = @'
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/stats.dart';

class WeeklyBarsChart extends StatelessWidget {
  final List<DailyStat> stats; // 7 elements
  const WeeklyBarsChart({super.key, required this.stats});

  @override
  Widget build(BuildContext context) {
    final maxVal = (stats.map((d) => d.minutes).fold<int>(0, (a, b) => a > b ? a : b)).clamp(1, 9999);
    final df = DateFormat.E(Localizations.localeOf(context).languageCode);

    return BarChart(
      BarChartData(
        alignment: BarChartAlignment.spaceAround,
        borderData: FlBorderData(show: false),
        gridData: FlGridData(show: false),
        titlesData: FlTitlesData(
          leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 18,
              getTitlesWidget: (val, meta) {
                final i = val.toInt();
                if (i < 0 || i >= stats.length) return const SizedBox.shrink();
                final label = df.format(stats[i].day);
                return Text(label, style: const TextStyle(fontSize: 10));
              },
            ),
          ),
        ),
        barGroups: [
          for (int i = 0; i < stats.length; i++)
            BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: stats[i].minutes.toDouble(),
                  width: 18,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                  color: Theme.of(context).colorScheme.primary,
                ),
              ],
            ),
        ],
        maxY: maxVal.toDouble() * 1.2,
      ),
    );
  }
}
'@

$activityDetailPage = @'
import 'dart:async';
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
    final db = ref.watch(dbProvider);
    final sessions = db.listSessionsByActivity(widget.activity.id);

    final running = db.isRunning(widget.activity.id);
    final paused = db.isPaused(widget.activity.id);
    _syncTicker(running);

    final elapsed = db.runningElapsed(widget.activity.id);
    final mm = elapsed.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = elapsed.inSeconds.remainder(60).toString().padLeft(2, '0');

    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.activity.emoji} ${widget.activity.name}',
            overflow: TextOverflow.ellipsis),
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
                  child: Text(paused ? '⏸ $mm:$ss' : '⏱ $mm:$ss'),
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            // Header + boutons
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
                        Text(widget.activity.emoji, style: const TextStyle(fontSize: 28)),
                        Container(
                          width: 12, height: 12,
                          decoration: BoxDecoration(color: widget.activity.color, shape: BoxShape.circle),
                        ),
                        Text(
                          'Objectif: ${widget.activity.dailyGoalMinutes ?? 0} min/j',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    OverflowBar(
                      alignment: MainAxisAlignment.start,
                      spacing: 8,
                      overflowSpacing: 8,
                      children: [
                        ActivityControls(activityId: widget.activity.id, compact: true),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),
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

            // Panneau Stats
            ActivityStatsPanel(
              activityId: widget.activity.id,
              dailyGoal: widget.activity.dailyGoalMinutes,
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
    final hh = dur.inHours.toString().padLeft(2, '0');
    final mm = dur.inMinutes.remainder(60).toString().padLeft(2, '0');
    final ss = dur.inSeconds.remainder(60).toString().padLeft(2, '0');

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8),
      leading: Icon(
        end == null ? Icons.play_circle_fill : Icons.check_circle,
        color: end == null ? Colors.orange : Colors.green,
      ),
      title: Text(
        end == null ? 'En cours' : 'Fini ($hh:$mm:$ss)',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${df.format(s.startAt)} → ${end == null ? 'en cours' : df.format(end)}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
'@

# 2) Write files with backup ---------------------------------------------------
Step "Write stats files"
Write-File-With-Backup -Path "lib/widgets/activity_stats_panel.dart" -Content $activityStatsPanel
Write-File-With-Backup -Path "lib/widgets/hourly_bars_chart.dart" -Content $hourlyBarsChart
Write-File-With-Backup -Path "lib/widgets/weekly_bars_chart.dart" -Content $weeklyBarsChart
Write-File-With-Backup -Path "lib/pages/activity_detail_page.dart" -Content $activityDetailPage

# 3) Ensure dependencies in pubspec.yaml --------------------------------------
Step "Ensure dependencies in pubspec.yaml"
$pub = Get-Content "pubspec.yaml" -Raw

if ($pub -notmatch "(?ms)dependencies:\s*(?:.*\n)*?\sfl_chart:") {
  $pub = $pub -replace "(?ms)(dependencies:\s*(?:.*\n)*)", "`$1  fl_chart: ^0.68.0`r`n"
  Ok "Added fl_chart to dependencies"
}
if ($pub -notmatch "(?ms)dependencies:\s*(?:.*\n)*?\sintl:") {
  $pub = $pub -replace "(?ms)(dependencies:\s*(?:.*\n)*)", "`$1  intl: ^0.19.0`r`n"
  Ok "Added intl to dependencies"
}
Set-Content -Path "pubspec.yaml" -Value $pub -Encoding UTF8

# 4) Flutter clean/get/analyze -------------------------------------------------
Step "Flutter clean"
flutter clean

Step "Flutter pub get"
flutter pub get

Step "Flutter analyze"
flutter analyze

# 5) Git add/commit/push if in repo -------------------------------------------
if (Test-Path ".git") {
  Step "Git add/commit/push"
  git add -A
  git commit -m "$Message" 2>$null | Out-Null
  try { git pull --rebase } catch {}
  try {
    git push
    Ok "Pushed to GitHub"
  } catch {
    Warn "Push failed (no remote or no auth?)"
  }
} else {
  Warn "No .git directory - skipping commit/push."
}
