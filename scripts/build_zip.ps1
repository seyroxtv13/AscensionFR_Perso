# Build le zip de release (structure Interface/AddOns/AscensionFR_Perso)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
if (-not (Test-Path "$root\AscensionFR_Perso.toc")) {
  $root = $PSScriptRoot
  if (-not (Test-Path "$root\AscensionFR_Perso.toc")) {
    $root = Split-Path -Parent $MyInvocation.MyCommand.Path
  }
}
# script in scripts/ or root — detect
if (Test-Path ".\AscensionFR_Perso.toc") { $root = (Get-Location).Path }

$dist = Join-Path $root "dist"
New-Item -ItemType Directory -Force -Path $dist | Out-Null
$stage = Join-Path $env:TEMP "afrp_stage_$(Get-Random)"
$addonStage = Join-Path $stage "Interface\AddOns\AscensionFR_Perso"
New-Item -ItemType Directory -Force -Path $addonStage, "$addonStage\DB", "$addonStage\Modules" | Out-Null

Copy-Item "$root\AscensionFR_Perso.toc","$root\Core.lua" -Destination $addonStage
Copy-Item "$root\DB\Phrases.lua" -Destination "$addonStage\DB\"
Copy-Item "$root\Modules\UI.lua" -Destination "$addonStage\Modules\"

$zip = Join-Path $dist "AscensionFR_Perso.zip"
if (Test-Path $zip) { Remove-Item $zip -Force }
Compress-Archive -Path (Join-Path $stage "Interface") -DestinationPath $zip -Force
Remove-Item $stage -Recurse -Force
Write-Host "OK $zip ($((Get-Item $zip).Length) bytes)"
