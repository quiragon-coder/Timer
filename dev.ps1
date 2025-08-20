param(
    [string]$Message = "chore: dev update"
)

$ProjectRoot = "C:\Users\Quiragon\Desktop\Dev\habits_timer"
Set-Location $ProjectRoot

function Step($t) { Write-Host "`n==> $t" -ForegroundColor Cyan }
function Ok($t)   { Write-Host "✔ $t" -ForegroundColor Green }

# Flutter pub get
Step "Flutter pub get"
flutter pub get
if ($LASTEXITCODE -eq 0) { Ok "Dependencies installed" } else { exit 1 }

# Flutter analyze
Step "Flutter analyze"
flutter analyze
if ($LASTEXITCODE -eq 0) { Ok "Analysis complete" } else { Write-Host "⚠ Issues found" -ForegroundColor Yellow }

# Flutter run
Step "Flutter run"
flutter run
if ($LASTEXITCODE -eq 0) { Ok "App started" } else { Write-Host "⚠ Could not start app" -ForegroundColor Yellow }

# Git update
Step "Git add/commit/pull/push"
git status
git add .
git commit -m "$Message"
git pull --rebase
git push
if ($LASTEXITCODE -eq 0) { Ok "Code pushed to GitHub" }
