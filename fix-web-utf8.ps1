param(
  [string]$Message = "chore: fix utf8 accents"
)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Step([string]$t){ Write-Host "`n==> $t" -ForegroundColor Cyan }
function Ok([string]$t)  { Write-Host "OK: $t" -ForegroundColor Green }
function Warn([string]$t){ Write-Host "WARN: $t" -ForegroundColor Yellow }
function Die([string]$t) { Write-Host "ERR: $t" -ForegroundColor Red; exit 1 }

# 1) Ensure UTF-8 meta in web/index.html
Step "Ensure <meta charset=""utf-8""> in web/index.html"
$indexPath = Join-Path $PSScriptRoot "web\index.html"
if (Test-Path $indexPath) {
  $html = Get-Content $indexPath -Raw
  if ($html -notmatch '(?i)<meta\s+charset\s*=\s*["'']utf-8["'']') {
    $insertion = @"
<head>
  <meta charset="utf-8">
"@
    $html = [regex]::Replace($html, '(?i)<head>', $insertion, 1)
    Set-Content -Path $indexPath -Value $html -Encoding UTF8
    Ok "Inserted meta charset"
  } else {
    Ok "Meta charset already present"
  }
} else {
  Warn "web/index.html not found (skipped)"
}

# 2) Fix mojibake string in activities_list_page.dart if present
Step "Patch mojibake in activities_list_page.dart (if found)"
$listPath = Join-Path $PSScriptRoot "lib\pages\activities_list_page.dart"
if (Test-Path $listPath) {
  $dart = Get-Content $listPath -Raw
  $before = $dart
  # Replace broken text to proper Unicode (with escapes to be encoding-agnostic)
  $dart = $dart -replace 'Aucune activitÃ©\.\s*Ajoute-en une .*', 'Aucune activit\u00e9. Ajoute-en une \u2192'
  if ($dart -ne $before) {
    Set-Content -Path $listPath -Value $dart -Encoding UTF8
    Ok "Patched mojibake string"
  } else {
    Ok "No mojibake found (nothing to patch)"
  }
} else {
  Warn "lib/pages/activities_list_page.dart not found (skipped)"
}

# 3) Re-encode text files to UTF-8 (no BOM)
Step "Re-encode .dart/.yaml/.yml/.html/.md to UTF-8 (no BOM)"
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$patterns = @("*.dart","*.yaml","*.yml","*.html","*.md")
$files = Get-ChildItem -Recurse -File -Include $patterns
foreach ($f in $files) {
  try {
    $txt = [System.IO.File]::ReadAllText($f.FullName)
    [System.IO.File]::WriteAllText($f.FullName, $txt, $Utf8NoBom)
  } catch {
    Warn ("Skip {0}: {1}" -f $f.FullName, $_.Exception.Message)
  }
}
Ok ("Re-encoded {0} files" -f $files.Count)

# 4) Flutter clean / get / analyze
Step "Flutter clean"
flutter clean | Out-Host
Step "Flutter pub get"
flutter pub get | Out-Host
Step "Flutter analyze"
flutter analyze | Out-Host

# 5) Git commit & push
if (Get-Command git -ErrorAction SilentlyContinue) {
  Step "Git add/commit/pull/push"
  git add web/index.html lib/pages/activities_list_page.dart | Out-Null
  git add . | Out-Null
  git commit -m $Message | Out-Host
  git pull --rebase | Out-Host
  git push | Out-Host
  Ok "Pushed to GitHub"
} else {
  Warn "git not found - skipping push"
}
