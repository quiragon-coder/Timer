param()

$pub = Join-Path $PSScriptRoot 'pubspec.yaml'
if (!(Test-Path $pub)) { Write-Host "pubspec.yaml introuvable"; exit 1 }

$y = Get-Content $pub -Raw

if ($y -notmatch "(?m)^\s*flutter_localizations:\s*\n\s*sdk:\s*flutter") {
  $y = $y -replace "(?m)^dependencies:\s*\n", "dependencies:`n  flutter:`n    sdk: flutter`n  flutter_localizations:`n    sdk: flutter`n"
}

if ($y -notmatch "(?m)^\s*shared_preferences:\s*\^") {
  $y = $y -replace "(?m)^dependencies:\s*\n", "dependencies:`n  shared_preferences: ^2.3.2`n"
}

Set-Content -Path $pub -Value $y -Encoding UTF8

flutter pub get
flutter analyze
