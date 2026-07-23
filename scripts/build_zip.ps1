# Build AscensionFR_Perso.zip (structure Interface/AddOns/AscensionFR_Perso/...)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root "AscensionFR_Perso.toc"))) {
  throw "TOC introuvable sous $root"
}

$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null

$stage = Join-Path $env:TEMP ("afrp_stage_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$addonStage = Join-Path $stage "Interface\AddOns\AscensionFR_Perso"
New-Item -ItemType Directory -Force -Path $addonStage | Out-Null

# Fichiers racine de l'addon
$racine = @(
  "AscensionFR_Perso.toc",
  "Core.lua",
  "PersoBoot.lua",
  "Bindings.xml"
)
foreach ($f in $racine) {
  $src = Join-Path $root $f
  if (Test-Path $src) {
    Copy-Item $src -Destination $addonStage -Force
  }
}

# Dossiers complets
foreach ($dir in @("DB", "Modules", "Media")) {
  $src = Join-Path $root $dir
  if (Test-Path $src) {
    Copy-Item $src -Destination $addonStage -Recurse -Force
  }
}

$zip = Join-Path $dist "AscensionFR_Perso.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $stage "Interface") -DestinationPath $zip -Force
Remove-Item $stage -Recurse -Force

$len = (Get-Item $zip).Length
Write-Host "OK $zip ($([math]::Round($len/1MB, 2)) MB)"
