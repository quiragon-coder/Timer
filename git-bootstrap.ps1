# git-bootstrap.ps1
param(
  [string]$Remote = "https://github.com/quiragon-coder/Timer.git",
  [string]$Message = "feat: initial import"
)

$ErrorActionPreference = "Stop"
Set-Location -Path (Split-Path -Parent $MyInvocation.MyCommand.Path)

if (-not (Test-Path ".git")) {
  git init
}

# Branche main (recrée/écrase au besoin)
git checkout -B main

# Remote origin
git remote remove origin 2>$null
git remote add origin $Remote

# Stage + commit (si changements)
$changes = git status --porcelain
if (-not [string]::IsNullOrWhiteSpace($changes)) {
  git add -A
  git commit -m $Message
}

# Push
git push -u origin main
Write-Host "OK: dépôt initial poussé sur $Remote" -ForegroundColor Green
