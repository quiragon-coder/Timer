# quick-dev.ps1
param(
  [string]$Message = "chore: maintenance",
  [string]$Remote  # ex: https://github.com/quiragon-coder/Timer.git
)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Step($t) { Write-Host "`n==> $t" -ForegroundColor Cyan }
function Info($t) { Write-Host "$t" -ForegroundColor Gray }
function OK($t)   { Write-Host "OK: $t" -ForegroundColor Green }
function Warn($t) { Write-Host "WARN: $t" -ForegroundColor Yellow }

# -------- Prérequis outils --------
foreach ($tool in @("flutter","git")) {
  if (-not (Get-Command $tool -ErrorAction SilentlyContinue)) {
    throw "$tool n'est pas accessible dans le PATH."
  }
}

# -------- Flutter --------
Step "flutter clean"
flutter clean

Step "flutter pub get"
flutter pub get

Step "flutter analyze"
flutter analyze

Step "pub get (sécurité)"
try {
  dart --version | Out-Null
  dart pub get
  OK "dart pub get terminé"
} catch {
  Warn "dart non détecté, je refais flutter pub get"
  flutter pub get
}

# -------- Git --------
# Init si besoin
if (-not (Test-Path ".git")) {
  Step "git init (repo local)"
  git init
}

# Branche main
Step "git checkout -B main"
git checkout -B main

# Remote origin (si fourni ou absent)
$haveOrigin = $false
try {
  $cur = git remote get-url origin 2>$null
  if ($cur) { $haveOrigin = $true; Info "origin actuel: $cur" }
} catch {}

if ($Remote) {
  Step "config remote origin -> $Remote"
  git remote remove origin 2>$null
  git remote add origin $Remote
  $haveOrigin = $true
}

# Stage + commit si changements
Step "git status"
$changes = git status --porcelain
if (-not [string]::IsNullOrWhiteSpace($changes)) {
  git add -A
  git commit -m "$Message"
  OK "Commit créé"
} else {
  Warn "Aucun changement à committer."
}

# Pull --rebase + push si remote dispo
if ($haveOrigin) {
  Step "git pull --rebase"
  git pull --rebase

  Step "git push (origin main)"
  git push -u origin main
  OK "Code poussé sur GitHub"
} else {
  Warn "Aucun remote 'origin' configuré. Pour le définir :"
  Write-Host "    git remote add origin <URL>" -ForegroundColor Yellow
  Write-Host "ou relance: .\quick-dev.ps1 -Remote https://github.com/ton-user/ton-repo.git" -ForegroundColor Yellow
}
