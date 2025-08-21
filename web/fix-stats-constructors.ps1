# fix-stats-constructors.ps1
$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Step($t){ Write-Host "`n==> $t" -ForegroundColor Cyan }
function Ok($t){ Write-Host "OK: $t" -ForegroundColor Green }

function Write-File($path, $content) {
  $dir = Split-Path $path -Parent
  if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir | Out-Null }
  if (Test-Path $path) { Copy-Item -Force $path "$path.bak" }
  Set-Content -Path $path -Value $content -Encoding UTF8
  Ok "Wrote: $path"
}

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

    final buckets = List.generate(24, (i) => HourlyBucket(hour: i, minutes: 0));
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
      if (effective <= 0) continue;

      // Répartir par heure
      var cursor = ovStart;
      var remain = effective;
      while (remain > 0 && cursor.isBefore(ovEnd)) {
        final bucketHourStart = DateTime(cursor.year, cursor.month, cursor.day, cursor.hour);
        final bucketHourEnd = bucketHourStart.add(const Duration(hours: 1));
        final splitEnd = bucketHourEnd.isBefore(ovEnd) ? bucketHourEnd : ovEnd;
        final mins = splitEnd.difference(cursor).inMinutes;
        if (mins > 0) {
          final h = cursor.hour;
          buckets[h] = HourlyBucket(hour: h, minutes: buckets[h].minutes + mins);
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
      days.add(DailyStat(day: dStart, minutes: m));
    }
    return days;
  }

  Future<int> minutesThisWeek(String activityId) async {
    final now = DateTime.now();
    final dow = now.weekday; // 1..7 (Mon..Sun)
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: dow - 1));
    final end = start.add(const Duration(days: 7));
    return _minutesInRange(activityId, start, end);
  }

  Future<int> minutesThisMonth(String activityId) async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, 1);
    final end = (now.month == 12)
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
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

# write file
Step "Update stats_service.dart (use named params)"
Write-File "lib/services/stats_service.dart" $statsService

# optional: remove unused db import from providers_stats.dart to silence warning
$prov = "lib/providers_stats.dart"
if (Test-Path $prov) {
  $txt = Get-Content $prov -Raw
  $new = $txt -replace '^\s*import\s+"package:habits_timer/services/database_service.dart";\s*\r?\n',''
  if ($new -ne $txt) { Set-Content -Path $prov -Value $new -Encoding UTF8; Ok "Cleaned import in providers_stats.dart" }
}

Step "Flutter clean"
flutter clean
Step "Flutter pub get"
flutter pub get
Step "Flutter analyze"
flutter analyze
