param(
  [string]$ProjectRoot = ".",
  [string]$Message = "fix: add start/togglePause/stop wrappers to DatabaseService",
  [switch]$NoGit
)

function Step($t){ Write-Host "`n==> $t" -ForegroundColor Cyan }
function Ok($t){ Write-Host "OK: $t" -ForegroundColor Green }
function Warn($t){ Write-Host "WARN: $t" -ForegroundColor Yellow }

Set-Location $ProjectRoot

# 1) Target DB file
$DbPath = Join-Path $ProjectRoot "lib\services\database_service.dart"
if (-not (Test-Path $DbPath)) {
  Write-Error "Not found: $DbPath"
  exit 1
}

$src = Get-Content $DbPath -Raw -Encoding UTF8
if ($src -notmatch 'class\s+DatabaseService\b') {
  Write-Error "Class DatabaseService not found in file"
  exit 1
}

$needsStart  = -not ($src -match 'Future<\s*void\s*>\s*start\s*\(')
$needsToggle = -not ($src -match 'Future<\s*void\s*>\s*togglePause\s*\(')
$needsStop   = -not ($src -match 'Future<\s*void\s*>\s*stop\s*\(')

if ($needsStart -or $needsToggle -or $needsStop) {
  Copy-Item $DbPath "$DbPath.bak" -Force

  $methods = @()

  if ($needsStart) {
$methods += @'
  Future<void> start(String activityId) async {
    // Wrapper for widget compatibility
    return quickStart(activityId);
  }
'@
  }

  if ($needsToggle) {
$methods += @'
  Future<void> togglePause(String activityId) async {
    // Wrapper for widget compatibility
    return quickTogglePause(activityId);
  }
'@
  }

  if ($needsStop) {
$methods += @'
  Future<void> stop(String activityId) async {
    // Wrapper for widget compatibility
    return quickStop(activityId);
  }
'@
  }

  $insertion = ($methods -join "`r`n")

  # Insert before the very last closing brace of the file
  $patched = $src -replace '(?s)\}\s*$', "`r`n$insertion`r`n}"
  Set-Content -Path $DbPath -Value $patched -Encoding UTF8

  Ok "Inserted wrappers into database_service.dart"
} else {
  Ok "Wrappers already present - no changes"
}

# 2) Quick verify
Step "flutter analyze"
flutter analyze
if ($LASTEXITCODE -eq 0) {
  Ok "Analysis OK"
} else {
  Warn "Analyzer found issues - see output above"
}

# 3) Git (optional)
if (-not $NoGit) {
  if (Get-Command git -ErrorAction SilentlyContinue) {
    Step "Git add/commit/pull/push"
    git add $DbPath
    git commit -m $Message
    git pull --rebase
    git push
    Ok "Pushed to GitHub"
  } else {
    Warn "git not found - skipping push"
  }
}
