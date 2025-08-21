param(
  [string]$ProjectRoot = ".",
  [string]$Message = "feat: yearly heatmap (UI + providers + stats extension)",
  [switch]$NoGit
)

function Step($t){ Write-Host "`n==> $t" -ForegroundColor Cyan }
function Ok($t){ Write-Host "OK: $t" -ForegroundColor Green }
function Warn($t){ Write-Host "WARN: $t" -ForegroundColor Yellow }

Set-Location $ProjectRoot
if (-not (Test-Path "lib")) { Write-Error "lib folder not found"; exit 1 }

# 1) lib/widgets/heatmap.dart
Step "Write lib/widgets/heatmap.dart"
$heatmapWidget = @"
import "package:flutter/material.dart";

class Heatmap extends StatelessWidget {
  final Map<DateTime, int> data;   // day -> minutes
  final Color baseColor;
  final int maxMinutes;            // minutes for full intensity
  final EdgeInsets padding;

  const Heatmap({
    super.key,
    required this.data,
    required this.baseColor,
    this.maxMinutes = 60,
    this.padding = const EdgeInsets.all(12),
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text("No data"));
    }

    final dates = data.keys.toList()..sort();
    final first = _mondayOfWeek(DateTime(dates.first.year, dates.first.month, dates.first.day));
    final last  = _sundayOfWeek(DateTime(dates.last.year,  dates.last.month,  dates.last.day));

    final normalized = <DateTime, int>{};
    for (final e in data.entries) {
      final d = DateTime(e.key.year, e.key.month, e.key.day);
      normalized[d] = e.value;
    }

    final daysCount = last.difference(first).inDays + 1;
    final weeks = (daysCount / 7).ceil();

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxWidth = constraints.maxWidth.isFinite ? constraints.maxWidth : 600.0;
        final colSpacing = 2.0;
        final rowSpacing = 2.0;
        final sidePadding = padding.left + padding.right;
        final monthLabelHeight = 16.0;

        final totalColSpacing = colSpacing * (weeks - 1);
        final cellSize = ((maxWidth - sidePadding - totalColSpacing) / weeks).clamp(8.0, 16.0);

        Color levelColor(double t) => Color.lerp(Colors.transparent, baseColor, t) ?? baseColor;

        final cells = <Widget>[];
        final monthLabels = <int, String>{};
        DateTime iter = first;
        int prevMonth = -1;

        for (int w = 0; w < weeks; w++) {
          final monthAtCol = iter.month;
          if (monthAtCol != prevMonth) {
            monthLabels[w] = _monthShort(monthAtCol);
            prevMonth = monthAtCol;
          }

          final columnCells = <Widget>[];
          for (int weekday = 0; weekday < 7; weekday++) {
            final day = iter.add(Duration(days: weekday));
            if (day.isAfter(last)) break;

            final key = DateTime(day.year, day.month, day.day);
            final minutes = normalized[key] ?? 0;

            double t;
            if (maxMinutes <= 0) {
              t = minutes > 0 ? 1.0 : 0.0;
            } else {
              t = (minutes / maxMinutes).clamp(0.0, 1.0);
            }
            final color = levelColor(t);

            columnCells.add(Container(
              width: cellSize,
              height: cellSize,
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(3),
                border: Border.all(color: Colors.black.withOpacity(0.04), width: 0.5),
              ),
            ));
          }

          cells.add(Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(height: monthLabelHeight),
              ..._withRowSpacing(columnCells, rowSpacing),
            ],
          ));

          if (w < weeks - 1) {
            cells.add(SizedBox(width: colSpacing));
          }
          iter = iter.add(const Duration(days: 7));
        }

        final monthRow = <Widget>[];
        for (int w = 0; w < weeks; w++) {
          final label = monthLabels[w] ?? "";
          monthRow.add(SizedBox(
            width: cellSize,
            height: monthLabelHeight,
            child: Center(child: Text(label, style: const TextStyle(fontSize: 10))),
          ));
          if (w < weeks - 1) monthRow.add(SizedBox(width: colSpacing));
        }

        final grid = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: monthRow),
            Row(children: cells),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text("Less", style: TextStyle(fontSize: 10)),
                const SizedBox(width: 6),
                _legendBox(Color.lerp(Colors.transparent, baseColor, 0.2) ?? baseColor, cellSize),
                const SizedBox(width: 2),
                _legendBox(Color.lerp(Colors.transparent, baseColor, 0.4) ?? baseColor, cellSize),
                const SizedBox(width: 2),
                _legendBox(Color.lerp(Colors.transparent, baseColor, 0.6) ?? baseColor, cellSize),
                const SizedBox(width: 2),
                _legendBox(Color.lerp(Colors.transparent, baseColor, 0.8) ?? baseColor, cellSize),
                const SizedBox(width: 6),
                const Text("More", style: TextStyle(fontSize: 10)),
              ],
            ),
          ],
        );

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: padding,
          child: grid,
        );
      },
    );
  }

  static List<Widget> _withRowSpacing(List<Widget> items, double space) {
    final out = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      out.add(items[i]);
      if (i < items.length - 1) out.add(SizedBox(height: space));
    }
    return out;
  }

  static String _monthShort(int m) {
    const names = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"];
    return (m >= 1 && m <= 12) ? names[m] : "";
  }

  static DateTime _mondayOfWeek(DateTime d) {
    final weekday = d.weekday; // 1=Mon..7=Sun
    return DateTime(d.year, d.month, d.day).subtract(Duration(days: weekday - 1));
  }

  static DateTime _sundayOfWeek(DateTime d) {
    final weekday = d.weekday;
    return DateTime(d.year, d.month, d.day).add(Duration(days: 7 - weekday));
  }

  static Widget _legendBox(Color c, double s) {
    return Container(
      width: s, height: s,
      decoration: BoxDecoration(
        color: c,
        borderRadius: BorderRadius.circular(3),
        border: Border.all(color: Colors.black12, width: .5),
      ),
    );
  }
}
"@
Set-Content -Path "lib\widgets\heatmap.dart" -Value $heatmapWidget -Encoding UTF8
Ok "wrote lib/widgets/heatmap.dart"

# 2) lib/pages/heatmap_page.dart
Step "Write lib/pages/heatmap_page.dart"
$heatmapPage = @"
import "package:flutter/material.dart";
import "package:flutter_riverpod/flutter_riverpod.dart";

import "../providers_heatmap.dart";
import "../widgets/heatmap.dart";

class ActivityHeatmapPage extends ConsumerWidget {
  final String activityId;
  final String name;
  final Color color;

  const ActivityHeatmapPage({
    super.key,
    required this.activityId,
    required this.name,
    required this.color,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncMap = ref.watch(heatmapYearProvider(activityId));
    return Scaffold(
      appBar: AppBar(title: Text("Heatmap - " + name)),
      body: asyncMap.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text("Error: " + e.toString())),
        data: (map) {
          return ListView(
            padding: const EdgeInsets.all(12),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text("Last 12 months", style: TextStyle(fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Heatmap(
                        data: map,
                        baseColor: color,
                        maxMinutes: 60,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Each square is one day. Color intensity scales with minutes tracked.",
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
"@
Set-Content -Path "lib\pages\heatmap_page.dart" -Value $heatmapPage -Encoding UTF8
Ok "wrote lib/pages/heatmap_page.dart"

# 3) lib/services/stats_heatmap_extension.dart
Step "Write lib/services/stats_heatmap_extension.dart"
$statsExt = @"
import "./stats_service.dart";
import "./database_service.dart";
import "../models/session.dart";
import "../models/pause.dart";

extension StatsHeatmapExt on StatsService {
  Future<Map<DateTime, int>> dailyMinutesRange({
    required String activityId,
    required DateTime from,
    required DateTime to,
  }) async {
    final startDay = DateTime(from.year, from.month, from.day);
    final endDay = DateTime(to.year, to.month, to.day);

    final List<Session> sessions = db.listSessionsByActivity(activityId);
    final Map<String, List<Pause>> pausesBySession = {
      for (final s in sessions) s.id: db.listPausesBySession(s.id),
    };

    final result = <DateTime, int>{};
    DateTime d = startDay;
    while (!d.isAfter(endDay)) {
      final dayStart = d;
      final dayEnd = d.add(const Duration(days: 1));
      int minutes = 0;

      for (final s in sessions) {
        final sStart = s.startAt;
        final sEnd = s.endAt ?? DateTime.now();
        final overlapStart = _max(dayStart, sStart);
        final overlapEnd   = _min(dayEnd, sEnd);
        if (!overlapEnd.isAfter(overlapStart)) continue;

        int eff = overlapEnd.difference(overlapStart).inMinutes;

        final pauses = pausesBySession[s.id] ?? const <Pause>[];
        for (final p in pauses) {
          final ps = _max(overlapStart, p.startAt);
          final pe = _min(overlapEnd,   p.endAt ?? DateTime.now());
          if (pe.isAfter(ps)) {
            eff -= pe.difference(ps).inMinutes;
          }
        }
        if (eff > 0) minutes += eff;
      }

      result[DateTime(d.year, d.month, d.day)] = minutes;
      d = d.add(const Duration(days: 1));
    }
    return result;
  }

  DateTime _max(DateTime a, DateTime b) => a.isAfter(b) ? a : b;
  DateTime _min(DateTime a, DateTime b) => a.isBefore(b) ? a : b;
}
"@
Set-Content -Path "lib\services\stats_heatmap_extension.dart" -Value $statsExt -Encoding UTF8
Ok "wrote lib/services/stats_heatmap_extension.dart"

# 4) lib/providers_heatmap.dart (nouveau fichier, on n'édite pas providers_stats.dart)
Step "Write lib/providers_heatmap.dart"
$providersHeatmap = @"
import "package:flutter_riverpod/flutter_riverpod.dart";

import "providers.dart";
import "services/stats_service.dart";
import "services/stats_heatmap_extension.dart";

final heatmapYearProvider = FutureProvider.family<Map<DateTime, int>, String>((ref, activityId) async {
  final db = ref.read(dbProvider);
  final stats = StatsService(db);
  final now = DateTime.now();
  final from = DateTime(now.year - 1, now.month, now.day);
  return stats.dailyMinutesRange(activityId: activityId, from: from, to: now);
});
"@
Set-Content -Path "lib\providers_heatmap.dart" -Value $providersHeatmap -Encoding UTF8
Ok "wrote lib/providers_heatmap.dart"

# 5) Patch activity_detail_page.dart (import + bouton AppBar)
Step "Patch lib/pages/activity_detail_page.dart"
$detailPath = "lib\pages\activity_detail_page.dart"
if (Test-Path $detailPath) {
  $dart = Get-Content $detailPath -Raw -Encoding UTF8
  $modified = $false

  if ($dart -notmatch "heatmap_page\.dart") {
    $dart = $dart -replace 'import\s+"package:flutter/material\.dart";',
      'import "package:flutter/material.dart";
import "heatmap_page.dart";'
    $modified = $true
  }

  if ($dart -match 'appBar:\s*AppBar\(' -and $dart -notmatch 'ActivityHeatmapPage') {
    $dart = $dart -replace 'appBar:\s*AppBar\(',
      'appBar: AppBar(actions: [IconButton(icon: const Icon(Icons.grid_on), onPressed: () { Navigator.of(context).push(MaterialPageRoute(builder: (_) => ActivityHeatmapPage(activityId: widget.activity.id, name: widget.activity.name, color: widget.activity.color))); })], '
    $modified = $true
  }

  if ($modified) {
    Set-Content -Path $detailPath -Value $dart -Encoding UTF8
    Ok "patched activity_detail_page.dart"
  } else {
    Ok "activity_detail_page.dart already patched"
  }
} else {
  Warn "activity_detail_page.dart not found - skipping patch"
}

# 6) Flutter commands
Step "Flutter clean"
flutter clean
Step "Flutter pub get"
flutter pub get
Step "Flutter analyze"
flutter analyze

# 7) Git
if (-not $NoGit) {
  if (Get-Command git -ErrorAction SilentlyContinue) {
    Step "Git add/commit/pull/push"
    git add lib/widgets/heatmap.dart lib/pages/heatmap_page.dart lib/services/stats_heatmap_extension.dart lib/providers_heatmap.dart $detailPath
    git commit -m $Message
    git pull --rebase
    git push
    Ok "Pushed to GitHub"
  } else {
    Warn "git not found - skipping push"
  }
}
