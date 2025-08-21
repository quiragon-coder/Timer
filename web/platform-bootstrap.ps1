# platform-bootstrap.ps1
param(
  [string]$Message = "chore: add platforms and run",
  [string]$Remote  # ex: https://github.com/quiragon-coder/Timer.git (optionnel)
)

$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Step($t){ Write-Host "`n==> $t" -ForegroundColor Cyan }
function OK($t){ Write-Host "OK: $t" -ForegroundColor Green }
function Warn($t){ Write-Host "WARN: $t" -ForegroundColor Yellow }

# 0) Sanity
foreach ($t in @("flutter","git")) { if (-not (Get-Command $t -ErrorAction SilentlyContinue)) { throw "$t introuvable dans le PATH." } }
if (-not (Test-Path "pubspec.yaml")) { throw "Lance ce script à la racine du projet (pubspec.yaml introuvable)." }

# 1) Activer plateformes utiles (Windows + Web)
Step "Activer Windows/Desktop & Web"
flutter config --enable-windows-desktop
flutter config --enable-web

# 2) Générer les dossiers de plateforme manquants
Step "flutter create . (génère android/, ios/, windows/, web/ … si absents)"
flutter create .

# 3) Dépendances + analyse
Step "flutter pub get"
flutter pub get
Step "flutter analyze"
flutter analyze

# 4) Choisir un device de lancement
Step "Détection des devices"
$devices = flutter devices
Write-Host $devices

# priorité Windows, sinon Chrome
$target = $null
if ($devices -match "windows\s+•") { $target = "windows" }
elseif ($devices -match "chrome\s+•") { $target = "chrome" }

if ($target) {
  Step "flutter run -d $target"
  flutter run -d $target
} else {
  Warn "Aucun device compatible trouvé. Démarre un émulateur Android OU utilise -d chrome après avoir activé le Web."
}

# 5) Git init/push (si souhaité)
if (-not (Test-Path ".git")) {
  Step "git init"
  git init
}
git checkout -B main

if ($Remote) {
  Step "Configurer remote origin -> $Remote"
  git remote remove origin 2>$null
  git remote add origin $Remote
}

Step "Git commit & push"
$changes = git status --porcelain
if (-not [string]::IsNullOrWhiteSpace($changes)) {
  git add -A
  git commit -m "$Message"
} else {
  Warn "Aucun changement à committer."
}
try {
  git pull --rebase
  git push -u origin main
  OK "Code poussé sur GitHub"
} catch {
  Warn "Pas de remote configuré ? Ajoute -Remote https://github.com/quiragon-coder/Timer.git"
}
