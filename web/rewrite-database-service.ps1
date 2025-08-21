# rewrite-database-service.ps1
# Réécrit complètement lib/services/database_service.dart avec une version propre.
# Puis: flutter clean / pub get / analyze et push Git.

param([string]$Message = "fix: rewrite database_service (updateActivity + timers + stats hooks)")

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Step($t){ Write-Host "`n==> $t" -ForegroundColor Cyan }
function Ok($t){ Write-Host "OK: $t" -ForegroundColor Green }
function Warn($t){ Write-Host "WARN: $t" -ForegroundColor Yellow }

# 1) Contenu propre du fichier
$dbContent = @'
import "dart:async";
import "package:flutter/material.dart";

import "package:habits_timer/models/activity.dart";
import "package:habits_timer/models/session.dart";
import "package:habits_timer/models/pause.dart";

/// In-memory DB service (ChangeNotifier) :
/// - CRUD activités
/// - Gestion de sessions (start/pause/unpause/stop)
/// - Accès aux pauses et sessions pour le calcul des stats
class DatabaseService extends ChangeNotifier {
  // Stockage des activités
  final Map<String, Activity> _activities = <String, Activity>{};

  // Sessions par activité
  final Map<String, List<Session>> _sessionsByActivity = <String, List<Session>>{};

  // Pauses par session
  final Map<String, List<Pause>> _pausesBySession = <String, List<Pause>>{};

  // Session active par activité (si en cours)
  final Map<String, Session> _activeByActivity = <String, Session>{};

  // Pause active (non terminée) par session
  final Map<String, Pause> _activePauseBySession = <String, Pause>{};

  // Stream (utile si un provider écoute la liste)
  final StreamController<List<Activity>> _activitiesCtrl = StreamController<List<Activity>>.broadcast();
  Stream<List<Activity>> get activitiesStream => _activitiesCtrl.stream;

  List<Activity> get activities => List<Activity>.unmodifiable(_activities.values);

  void _emitActivities() {
    _activitiesCtrl.add(activities);
    notifyListeners();
  }

  // -------------------- ACTIVITIES --------------------

  Future<void> createActivity(Activity a) async {
    _activities[a.id] = a;
    _emitActivities();
  }

  void updateActivity(Activity updated) {
    _activities[updated.id] = updated;
    _emitActivities();
  }

  Future<void> deleteActivity(String id) async {
    _activities.remove(id);
    _sessionsByActivity.remove(id);
    final s = _activeByActivity.remove(id);
    if (s != null) {
      _activePauseBySession.remove(s.id);
    }
    _emitActivities();
  }

  // -------------------- TIMERS --------------------

  bool isRunning(String activityId) => _activeByActivity.containsKey(activityId);

  bool isPaused(String activityId) {
    final s = _activeByActivity[activityId];
    if (s == null) return false;
    final p = _activePauseBySession[s.id];
    return p != null && p.endAt == null;
  }

  /// Durée écoulée en tenant compte des pauses
  Duration runningElapsed(String activityId) {
    final s = _activeByActivity[activityId];
    if (s == null) return Duration.zero;
    final now = DateTime.now();
    final baseEnd = s.endAt ?? now;
    final base = baseEnd.difference(s.startAt);
    final paused = _totalPausedForSession(s.id, now: now);
    final d = base - paused;
    return d.isNegative ? Duration.zero : d;
  }

  void start(String activityId) {
    if (isRunning(activityId)) return;
    final session = Session(
      id: UniqueKey().toString(),
      activityId: activityId,
      startAt: DateTime.now(),
      endAt: null,
    );
    _activeByActivity[activityId] = session;
    (_sessionsByActivity[activityId] ??= <Session>[]).add(session);
    notifyListeners();
  }

  void pause(String activityId) {
    final s = _activeByActivity[activityId];
    if (s == null) return;
    if (isPaused(activityId)) return;
    final p = Pause(
      id: UniqueKey().toString(),
      sessionId: s.id,
      startAt: DateTime.now(),
      endAt: null,
    );
    _activePauseBySession[s.id] = p;
    (_pausesBySession[s.id] ??= <Pause>[]).add(p);
    notifyListeners();
  }

  void unpause(String activityId) {
    final s = _activeByActivity[activityId];
    if (s == null) return;
    final p = _activePauseBySession[s.id];
    if (p == null || p.endAt != null) return;
    // NOTE: assume Pause.endAt est mutable dans ton modèle
    p.endAt = DateTime.now();
    _activePauseBySession.remove(s.id);
    notifyListeners();
  }

  void stop(String activityId) {
    final s = _activeByActivity.remove(activityId);
    if (s == null) return;

    // Clôture d'une pause active éventuelle
    final p = _activePauseBySession.remove(s.id);
    if (p != null && p.endAt == null) {
      p.endAt = DateTime.now();
    }
    // NOTE: assume Session.endAt est mutable dans ton modèle
    s.endAt = DateTime.now();

    notifyListeners();
  }

  // -------------------- STATS HELPERS --------------------

  /// Sessions de l'activité (historique complet)
  List<Session> getSessionsByActivity(String activityId) {
    return List<Session>.unmodifiable(_sessionsByActivity[activityId] ?? const <Session>[]);
  }

  /// Pauses d'une session donnée
  List<Pause> getPausesBySession(String sessionId) {
    return List<Pause>.unmodifiable(_pausesBySession[sessionId] ?? const <Pause>[]);
  }

  Duration _totalPausedForSession(String sessionId, {DateTime? now}) {
    final pauses = _pausesBySession[sessionId];
    if (pauses == null || pauses.isEmpty) return Duration.zero;
    final endNow = now ?? DateTime.now();
    var total = Duration.zero;
    for (final p in pauses) {
      final end = p.endAt ?? endNow;
      total += end.difference(p.startAt);
    }
    return total;
  }

  // -------------------- DISPOSE --------------------
  @override
  void dispose() {
    _activitiesCtrl.close();
    super.dispose();
  }
}
'@

# 2) Écrit le fichier avec backup .bak
Step "Rewrite lib/services/database_service.dart"
$path = "lib/services/database_service.dart"
if (Test-Path $path) { Copy-Item $path "$path.bak" -Force }
$dir = Split-Path $path -Parent
if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
Set-Content -Path $path -Value $dbContent -Encoding UTF8
Ok "database_service.dart remplacé"

# 3) Toolchain Flutter
Step "Flutter clean"
flutter clean
Step "Flutter pub get"
flutter pub get
Step "Flutter analyze"
flutter analyze

# 4) Git (facultatif)
if (Test-Path ".git") {
  Step "Git add/commit/push"
  git add -A
  git commit -m $Message 2>$null | Out-Null
  try { git pull --rebase } catch {}
  try { git push; Ok "Code poussé sur GitHub" } catch { Warn "Push échoué — vérifie le remote/auth" }
} else {
  Warn "Pas de dépôt Git détecté — push ignoré"
}
