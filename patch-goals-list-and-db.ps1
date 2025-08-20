# patch-goals-list-and-db.ps1
# - Ajoute DatabaseService.updateActivity(...)
# - Améliore la liste: sous-titre 2 (objectifs Semaine/Mois/Année)
# - Corrige la page détail pour refléter immédiatement les objectifs modifiés
# - Clean/pub get/analyze + (commit/push si .git)

param([string]$Message = "feat: goals chips in list + updateActivity in DB")

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Step($t){ Write-Host "`n==> $t" -ForegroundColor Cyan }
function Ok($t){ Write-Host "OK: $t" -ForegroundColor Green }
function Warn($t){ Write-Host "WARN: $t" -ForegroundColor Yellow }

# -------- helper: safe write (with .bak) --------
function Write-File {
  param([string]$Path,[string]$Content)
  $dir = Split-Path $Path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  if (Test-Path $Path) { Copy-Item -Force $Path "$Path.bak" }
  Set-Content -Path $Path -Value $Content -Encoding UTF8
  Ok "Wrote: $Path"
}

# -------- 1) Patch DatabaseService: add updateActivity(...) --------
Step "Patch DatabaseService.updateActivity(...)"
$svcPath = "lib/services/database_service.dart"
if (-not (Test-Path $svcPath)) { throw "Fichier manquant: $svcPath" }
$svc = Get-Content $svcPath -Raw

if ($svc -notmatch "class\s+DatabaseService") {
  throw "Impossible de trouver class DatabaseService dans $svcPath"
}

if ($svc -notmatch "void\s+updateActivity\s*\(") {
  # On insère la méthode juste avant la dernière '}' du fichier
  $method = @'
  // -- added by patch: update an activity goals/name/color etc.
  void updateActivity(Activity updated) {
    // met à jour l'activité (in-memory)
    final idx = _activities.indexWhere((a) => a.id == updated.id);
    if (idx != -1) {
      _activities[idx] = updated;
    }
  }
'@

  # S'assure que l'import de Activity est présent (au cas où)
  if ($svc -notmatch 'import\s+["''].*models\/activity\.dart["''];') {
    $svc = $svc -replace '(import\s+["'']package:flutter\/material\.dart["''];\s*)',
      "`$1import ""package:habits_timer/models/activity.dart"";" + [Environment]::NewLine
  }

  $svcNew = [regex]::Replace($svc, "\}\s*$", "$method`n}", 1)
  Set-Content -Path $svcPath -Value $svcNew -Encoding UTF8
  Ok "updateActivity(...) ajouté dans DatabaseService"
} else {
  Ok "updateActivity(...) déjà présent - rien à faire"
}

# -------- 2) Remplace ActivitiesListPage avec objectifs S/M/A --------
Step "Replace lib/pages/activities_list_page.dart (goals chips)"
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

    // Totaux pour les chips
    final weekTotalAsync  = ref.watch(weekTotalProvider(widget.a.id));
    final monthTotalAsync = ref.watch(monthTotalProvider(widget.a.id));
    final yearTotalAsync  = ref.watch(yearTotalProvider(widget.a.id));

    // minutes today -> pour objectif journalier
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
          // Ligne 1: point couleur + objectif journalier + badge temps en cours
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

          // Ligne 1 bis: reste aujourd'hui / objectif atteint
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

          const SizedBox(height: 6),

          // Ligne 2: chips Semaine / Mois / Année (verts si atteint)
          Wrap(
            spacing: 8, runSpacing: 8,
            children: [
              if ((widget.a.weeklyGoalMinutes ?? 0) > 0)
                _GoalChip(async: weekTotalAsync, icon: Icons.calendar_view_week, label: "Sem.",
                          goal: widget.a.weeklyGoalMinutes),
              if ((widget.a.monthlyGoalMinutes ?? 0) > 0)
                _GoalChip(async: monthTotalAsync, icon: Icons.calendar_view_month, label: "Mois",
                          goal: widget.a.monthlyGoalMinutes),
              if ((widget.a.yearlyGoalMinutes ?? 0) > 0)
                _GoalChip(async: yearTotalAsync, icon: Icons.calendar_month, label: "Ann.",
                          goal: widget.a.yearlyGoalMinutes),
            ],
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

class _GoalChip extends StatelessWidget {
  final AsyncValue<int> async;
  final IconData icon;
  final String label;
  final int? goal;

  const _GoalChip({required this.async, required this.icon, required this.label, required this.goal});

  @override
  Widget build(BuildContext context) {
    return async.when(
      loading: () => const Chip(label: Text("...")),
      error: (e, _) => const Chip(label: Text("Err")),
      data: (m) {
        final g = goal ?? 0;
        final reached = g > 0 && m >= g;
        return Chip(
          avatar: Icon(icon, size: 16, color: reached ? Colors.green : null),
          label: Text(g > 0 ? "$label: $m / $g" : "$label: $m"),
          backgroundColor: reached ? Colors.green.withOpacity(.12) : null,
          side: reached ? const BorderSide(color: Colors.green) : null,
        );
      },
    );
  }
}
'@
Write-File -Path "lib/pages/activities_list_page.dart" -Content $activitiesList

# -------- 3) Patch ActivityDetailPage pour refléter de suite les objectifs --------
Step "Patch lib/pages/activity_detail_page.dart (keep current activity instance)"
$detailPath = "lib/pages/activity_detail_page.dart"
if (-not (Test-Path $detailPath)) { throw "Fichier manquant: $detailPath" }
$detail = Get-Content $detailPath -Raw

# Si pas déjà présent, on introduit _current et on l'utilise
if ($detail -notmatch "_current\s*;") {
  # inject 'late Activity _current;' après la classe State
  $detail = $detail -replace "(class\s+_ActivityDetailPageState\s+extends\s+ConsumerState<ActivityDetailPage>\s*\{)",
    "`$1`n  late Activity _current;"

  # initState
  if ($detail -notmatch "void\s+initState\s*\(") {
    $detail = $detail -replace "(class\s+_ActivityDetailPageState[^{]*\{)",
      "`$1`n  @override`n  void initState() {`n    super.initState();`n    _current = widget.activity;`n  }`n"
  } else {
    $detail = $detail -replace "void\s+initState\s*\(\)\s*\{\s*super\.initState\(\);\s*\}",
      "void initState() { super.initState(); _current = widget.activity; }"
  }

  # remplacer usages de widget.activity par _current
  $detail = $detail -replace "widget\.activity", "_current"

  # après sauvegarde dans _openGoalsSheet: _current = updated;
  $detail = $detail -replace "(db\.updateActivity\(updated\);\s*[\r\n\s]*)(if\s*\(mounted\)\s*setState\(\(\)\s*\{\s*\}\);\s*)",
    "`$1`n      _current = updated;`n      if (mounted) setState(() {});`n"
  $detail | Set-Content -Path $detailPath -Encoding UTF8
  Ok "ActivityDetailPage patché (utilise _current)"
} else {
  Ok "ActivityDetailPage déjà patché"
}

# -------- 4) Flutter toolchain --------
Step "Flutter clean"
flutter clean
Step "Flutter pub get"
flutter pub get
Step "Flutter analyze"
flutter analyze

# -------- 5) Git --------
if (Test-Path ".git") {
  Step "Git add/commit/push"
  git add -A
  git commit -m "$Message" 2>$null | Out-Null
  try { git pull --rebase } catch {}
  try { git push; Ok "Pushed to GitHub" } catch { Warn "Push failed (check auth/remote)" }
} else {
  Warn "Pas de repo Git détecté - push ignoré"
}
