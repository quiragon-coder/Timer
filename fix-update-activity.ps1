# fix-update-activity.ps1
$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Step($t){ Write-Host "`n==> $t" -ForegroundColor Cyan }
function Ok($t){ Write-Host "OK: $t" -ForegroundColor Green }
function Fail($t){ Write-Host "ERR: $t" -ForegroundColor Red; exit 1 }

$svcPath = "lib/services/database_service.dart"
if (-not (Test-Path $svcPath)) { Fail "Fichier introuvable: $svcPath" }

$dart = Get-Content $svcPath -Raw

# Remplace n'importe quelle version existante de updateActivity(...) par une version compatible Map/List
$pattern = 'void\s+updateActivity\s*\(\s*Activity\s+updated\s*\)\s*\{[\s\S]*?\}'
$replacement = @'
void updateActivity(Activity updated) {
  if (_activities is Map<String, Activity>) {
    final map = _activities as Map<String, Activity>;
    map[updated.id] = updated;
  } else if (_activities is List<Activity>) {
    final list = _activities as List<Activity>;
    final idx = list.indexWhere((a) => a.id == updated.id);
    if (idx != -1) {
      list[idx] = updated;
    }
  }
}
'@

if ($dart -match $pattern) {
  $dart = [regex]::Replace($dart, $pattern, $replacement, 1)
  Set-Content -Path $svcPath -Value $dart -Encoding UTF8
  Ok "updateActivity(...) corrigée (Map/List)"
} else {
  # Si la méthode n'existe pas, on l'ajoute juste avant la dernière }
  $dart = [regex]::Replace($dart, "\}\s*$", "$replacement`n}", 1)
  Set-Content -Path $svcPath -Value $dart -Encoding UTF8
  Ok "updateActivity(...) ajoutée"
}

Step "Flutter clean / pub get / analyze"
flutter clean
flutter pub get
flutter analyze
