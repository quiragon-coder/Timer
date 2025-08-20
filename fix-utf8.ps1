# fix-utf8.ps1 - normalize text files to UTF-8 (no BOM) and run Flutter cmds
$ErrorActionPreference = "Stop"
Set-Location -Path $PSScriptRoot

function Step([string]$t) { Write-Host "`n==> $t" -ForegroundColor Cyan }
function Ok([string]$t)   { Write-Host "OK: $t" -ForegroundColor Green }
function Warn([string]$t) { Write-Host "WARN: $t" -ForegroundColor Yellow }

# UTF-8 without BOM encoder
$Utf8NoBom = New-Object System.Text.UTF8Encoding($false)

# File patterns to re-encode
$patterns = @("*.dart","*.yaml","*.yml","*.html","*.md")

Step "Re-encoding files to UTF-8 (no BOM)"
$files = Get-ChildItem -Recurse -File -Include $patterns
foreach ($f in $files) {
  try {
    $text = [System.IO.File]::ReadAllText($f.FullName)
    [System.IO.File]::WriteAllText($f.FullName, $text, $Utf8NoBom)
  } catch {
    Warn "Skip $($f.FullName): $($_.Exception.Message)"
  }
}
Ok "Encoding normalized for $($files.Count) files"

Step "Flutter clean"
flutter clean
if ($LASTEXITCODE -ne 0) { exit 1 }

Step "Flutter pub get"
flutter pub get
if ($LASTEXITCODE -ne 0) { exit 1 }

Step "Flutter analyze"
flutter analyze
