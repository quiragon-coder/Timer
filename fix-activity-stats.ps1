# fix-activity-stats.ps1
param(
  [string]$Message = "chore: fix ActivityStatsPanel duplicates"
)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Step($t){ Write-Host "`n==> $t" -ForegroundColor Cyan }
function Ok($t){ Write-Host "OK: $t" -ForegroundColor Green }
function Warn($t){ Write-Host "WARN: $t" -ForegroundColor Yellow }

# 1) Ecrire le fichier canonique
Step "Write canonical: lib/widgets/activity_stats_panel.dart"
$widgetDir = "lib/widgets"
if (-not (Test-Path $widgetDir)) { New-Item -ItemType Directory -Path $widgetDir | Out-Null }

$panelPath = Join-Path $widgetDir "activity_stats_panel.dart"
$panelContent = @'
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

Set-Content -Path $panelPath -Value $panelContent -Encoding UTF8
Ok "Wrote: $panelPath"

# 2) Trouver toutes les autres definitions et les sauvegarder .bak
Step "Scan for duplicates of 'class ActivityStatsPanel'"
$matches = Get-ChildItem -Path . -Recurse -Include *.dart |
  Select-String -Pattern 'class\s+ActivityStatsPanel\b' |
  Select-Object -ExpandProperty Path -Unique

$canonical = (Resolve-Path $panelPath).ToString()
$duplicates = @()
foreach ($p in $matches) {
  $rp = (Resolve-Path $p).ToString()
  if ($rp -ne $canonical) { $duplicates += $rp }
}

if ($duplicates.Count -gt 0) {
  Warn "Duplicates found:"
  $duplicates | ForEach-Object { Write-Host " - $_" -ForegroundColor Yellow }
  foreach ($dup in $duplicates) {
    $bak = "$dup.bak"
    Move-Item -Force $dup $bak
    Ok "Renamed to backup: $bak"
  }
} else {
  Ok "No duplicates."
}

# 3) S'assurer de l'import dans activity_detail_page.dart
Step "Ensure import in lib/pages/activity_detail_page.dart"
$detailPath = "lib/pages/activity_detail_page.dart"
if (Test-Path $detailPath) {
  $content = Get-Content $detailPath -Raw
  if ($content -notmatch "widgets/activity_stats_panel.dart") {
    $content = "import '../widgets/activity_stats_panel.dart';`r`n" + $content
    Set-Content -Path $detailPath -Value $content -Encoding UTF8
    Ok "Import inserted at top of activity_detail_page.dart"
  } else {
    Ok "Import already present."
  }
} else {
  Warn "$detailPath not found (skipped)."
}

# 4) Flutter clean/get/analyze
Step "Flutter clean"
flutter clean

Step "Flutter pub get"
flutter pub get

Step "Flutter analyze"
flutter analyze

# 5) Git add/commit/push si repo present
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
