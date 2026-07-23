# AscensionFR Perso

Traduction française autonome pour Project Ascension.  
Addon + Compagnon par **Seyrox**.

## Installation

1. Compagnon `AscensionFR_Perso.exe` (Releases GitHub)
2. En jeu : **désactive AscensionFR**, garde **AscensionFR Perso**
3. Relance → `/afrp`

## Commandes

- `/afrp` — options
- `/afrp on|off` — active / coupe
- `/afrp signaler` — photographier un texte encore anglais (via modules AFR)

## Traduction (chantier en cours)

- Conventions WoW FR : [`docs/CONVENTIONS_TRAD.md`](docs/CONVENTIONS_TRAD.md)
- Devblogs (chaque lot) : [`docs/devblog/`](docs/devblog/)

## Dev

```bash
python scripts/import_ascensionfr.py
```

Puis bump `## Version` + publish release.

## Dev Compagnon

```text
cd compagnon
pip install pyinstaller
python -m PyInstaller AscensionFR_Perso_Compagnon.spec
powershell -File ..\scripts\publish_release.ps1
```

## Licence

Projet perso. Non affilié à Project Ascension / AscensionFR officiel.
