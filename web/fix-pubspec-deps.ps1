# fix-pubspec-deps.ps1 (v2, ASCII only)
$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Step($t){ Write-Host "`n==> $t" -ForegroundColor Cyan }
function Ok($t){ Write-Host "OK: $t" -ForegroundColor Green }
function Warn($t){ Write-Host "WARN: $t" -ForegroundColor Yellow }

Step "Backup pubspec.yaml"
Copy-Item -Force "pubspec.yaml" "pubspec.yaml.bak"
Ok "Backup -> pubspec.yaml.bak"

# Charge le YAML en lignes
$lines = Get-Content "pubspec.yaml"

# 1) Enlever fl_chart / intl mal places sous le bloc racine "flutter:"
# On cible UNIQUEMENT la cle flutter au niveau racine (colonne 0)
$rootFlutterLineObj = ($lines | Select-String -Pattern '^[fF]lutter:\s*$' | Select-Object -First 1)
if ($rootFlutterLineObj) {
  $rootFlutterIdx = $rootFlutterLineObj.LineNumber - 1  # 0-based
  # Cherche la fin du bloc racine 'flutter:' (prochaine cle racine)
  $endIdx = $lines.Count - 1
  for ($i = $rootFlutterIdx + 1; $i -lt $lines.Count; $i++) {
    if ($lines[$i] -match '^[a-zA-Z_]+:\s*$') { $endIdx = $i - 1; break }
  }
  # Supprime 'fl_chart:' et 'intl:' dans CE bloc uniquement
  $kept = @()
  for ($i = 0; $i -lt $lines.Count; $i++) {
    if ($i -ge $rootFlutterIdx -and $i -le $endIdx) {
      if ($lines[$i] -match '^\s*(fl_chart|intl)\s*:') { continue }
    }
    $kept += $lines[$i]
  }
  $lines = $kept
  Ok "Nettoye le bloc racine 'flutter:'"
}

# 2) S'assurer que 'dependencies:' existe avec 'flutter: sdk: flutter'
$depsLineObj = ($lines | Select-String -Pattern '^dependencies:\s*$' | Select-Object -First 1)
if (-not $depsLineObj) {
  $lines += ''
  $lines += 'dependencies:'
  $lines += '  flutter:'
  $lines += '    sdk: flutter'
  Ok "Ajoute bloc 'dependencies:' par defaut"
}

# Recalcule l'index du bloc dependencies (debut et fin)
$depsStart = (($lines | Select-String -Pattern '^dependencies:\s*$' | Select-Object -First 1).LineNumber) - 1
$depsEnd = $lines.Count - 1
for ($i = $depsStart + 1; $i -lt $lines.Count; $i++) {
  if ($lines[$i] -match '^[a-zA-Z_]+:\s*$') { $depsEnd = $i - 1; break }
}

# 3) Upsert des dependances
function Upsert-Dep {
  param([string]$name, [string]$version)

  # Cherche si deja present dans le bloc dependencies
  $found = $false
  for ($i = $depsStart + 1; $i -le $depsEnd; $i++) {
    if ($lines[$i] -match ("^\s*{0}\s*:" -f [regex]::Escape($name))) {
      $lines[$i] = "  ${name}: ${version}"
      $found = $true
      break
    }
  }
  if (-not $found) {
    # Inserer en fin de bloc dependencies
    $before = $lines[0..$depsEnd]
    $after  = $lines[($depsEnd+1)..($lines.Count-1)]
    $before += "  ${name}: ${version}"
    $lines = $before + $after
    $script:depsEnd++
  }
}

Upsert-Dep -name 'fl_chart' -version '^0.68.0'
Upsert-Dep -name 'intl' -version '^0.19.0'
Ok "Dependencies fl_chart / intl OK"

# 4) Ecrit le fichier
Set-Content -Path "pubspec.yaml" -Value $lines -Encoding UTF8
Ok "pubspec.yaml mis a jour"

# 5) Flutter cmds
Step "Flutter clean"
flutter clean

Step "Flutter pub get"
flutter pub get

Step "Flutter analyze"
flutter analyze
