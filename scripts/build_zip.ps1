# Build AscensionFR_Perso.zip (structure Interface/AddOns/...)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path (Join-Path $root "AscensionFR_Perso.toc"))) {
  throw "TOC introuvable sous $root"
}
$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$stage = Join-Path $env:TEMP ("afrp_stage_" + [guid]::NewGuid().ToString("N").Substring(0, 8))
$addonStage = Join-Path $stage "Interface\AddOns\AscensionFR_Perso"
New-Item -ItemType Directory -Force -Path $addonStage, (Join-Path $addonStage "DB"), (Join-Path $addonStage "Modules") | Out-Null
Copy-Item (Join-Path $root "AscensionFR_Perso.toc"), (Join-Path $root "Core.lua") -Destination $addonStage -Force
Copy-Item (Join-Path $root "DB\Phrases.lua") -Destination (Join-Path $addonStage "DB") -Force
Copy-Item (Join-Path $root "Modules\UI.lua") -Destination (Join-Path $addonStage "Modules") -Force
$zip = Join-Path $dist "AscensionFR_Perso.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $stage "Interface") -DestinationPath $zip -Force
Remove-Item $stage -Recurse -Force
Write-Host "OK $zip ($((Get-Item $zip).Length) bytes)"
