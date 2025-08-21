# fix-db-update-activity-simple.ps1
$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Step($t){ Write-Host "`n==> $t" -ForegroundColor Cyan }
function Ok($t){ Write-Host "OK: $t" -ForegroundColor Green }
function Fail($t){ Write-Host "ERR: $t" -ForegroundColor Red; exit 1 }

$svcPath = "lib/services/database_service.dart"
if (-not (Test-Path $svcPath)) { Fail "Fichier introuvable: $svcPath" }

Step "Charger database_service.dart"
$dart = Get-Content $svcPath -Raw

# 1) S'assurer que l'import du modèle Activity est présent (insertion en tête si absent)
if ($dart -notmatch 'package:habits_timer/models/activity\.dart') {
  $dart = 'import "package:habits_timer/models/activity.dart";' + [Environment]::NewLine + $dart
  Ok "Import Activity ajouté"
}

# 2) Supprimer TOUTE méthode updateActivity existante (dotall via (?s))
$dart = $dart -replace '(?s)void\s+updateActivity\s*\(\s*Activity\s+updated\s*\)\s*\{.*?\}', ''
# (on enlève les lignes vides multiples éventuelles)
$dart = $dart -replace "(\r?\n){3,}", "`r`n`r`n"

# 3) Réinsérer une version propre avant la dernière '}' du fichier
$method = @'
  // updateActivity: met à jour l'activité en mémoire (Map<String, Activity>)
  void updateActivity(Activity updated) {
    _activities[updated.id] = updated;
  }
'@

if ($dart -notmatch "\}\s*$") { Fail "Impossible d'insérer la méthode (accolade finale non trouvée)" }
$dart = [regex]::Replace($dart, "\}\s*$", "$method`n}", 1)

# 4) Écrire le fichier
Set-Content -Path $svcPath -Value $dart -Encoding UTF8
Ok "updateActivity(...) réécrite correctement"

# 5) Flutter toolchain
Step "Flutter clean"
flutter clean
Step "Flutter pub get"
flutter pub get
Step "Flutter analyze"
flutter analyze
