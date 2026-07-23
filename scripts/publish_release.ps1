# Publie v0.1.0 sur GitHub (nécessite: gh auth login)
# Usage: powershell -File scripts\publish_release.ps1 [-Owner Seyrox]
param(
  [string]$Owner = "",
  [string]$Repo = "AscensionFR_Perso",
  [string]$Tag = "v0.2.0"
)
$ErrorActionPreference = "Stop"
$env:Path = [System.Environment]::GetEnvironmentVariable("Path","Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path","User")
$root = Split-Path -Parent $PSScriptRoot
Set-Location $root

gh auth status
if (-not $Owner) {
  $Owner = (gh api user --jq .login)
}
$full = "$Owner/$Repo"
Write-Host "Repo: $full"

# Met à jour le dépôt attendu par le Compagnon
$py = Join-Path $root "compagnon\compagnon.py"
$txt = Get-Content $py -Raw -Encoding UTF8
$txt2 = [regex]::Replace($txt, 'DEPOT = os\.environ\.get\("AFRP_DEPOT", "[^"]+"\)', "DEPOT = os.environ.get(`"AFRP_DEPOT`", `"$full`")")
if ($txt2 -ne $txt) {
  Set-Content -Path $py -Value $txt2 -Encoding UTF8 -NoNewline
  Write-Host "compagnon.py -> DEPOT=$full"
}

# Rebuild zip
& powershell -NoProfile -File (Join-Path $PSScriptRoot "build_zip.ps1")
$zip = Join-Path $root "dist\AscensionFR_Perso.zip"
$exe = Join-Path $root "dist\AscensionFR_Perso_Compagnon.exe"
if (-not (Test-Path $exe)) {
  $exe = Join-Path $root "compagnon\dist\AscensionFR_Perso_Compagnon.exe"
}
if (-not (Test-Path $zip) -or -not (Test-Path $exe)) {
  throw "Assets manquants: $zip / $exe"
}

# Crée le dépôt s'il n'existe pas
$exists = $true
gh repo view $full 2>$null | Out-Null
if ($LASTEXITCODE -ne 0) { $exists = $false }
if (-not $exists) {
  Write-Host "Création du dépôt $full…"
  gh repo create $full --public --source=. --remote=origin --push
} else {
  git remote remove origin 2>$null
  git remote add origin "https://github.com/$full.git" 2>$null
  if (-not (git remote get-url origin 2>$null)) {
    git remote add origin "https://github.com/$full.git"
  }
  git push -u origin HEAD
}

# Release
$notes = @"
## AscensionFR Perso $Tag

Overlay FR personnel (à côté d'AscensionFR officiel).

### Contenu
- Phrases UI : Agility, Haste Rating + stats voisines
- Compagnon : install / maj depuis cette release
- Commande jeu : ``/afrp``

### Installation
1. AscensionFR officiel
2. Lance ``AscensionFR_Perso_Compagnon.exe`` ou extrais le zip à la racine du jeu
3. Coche *Load Out of Date AddOns* + AscensionFR_Perso
4. ``/reload``
"@

gh release create $Tag $zip $exe --title "AscensionFR Perso $Tag" --notes $notes --repo $full
Write-Host "OK https://github.com/$full/releases/tag/$Tag"
