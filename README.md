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

## Antivirus / Windows Defender

Le Compagnon est un `.exe` **PyInstaller non signé**. Defender le classe souvent à tort
(`Trojan:Win32/Wacatac…`, `Bearfoos…`, etc. — suffixe `!ml` = heuristique ML).

**Ce n’est pas un virus** (code open-source dans ce dépôt). Contournements :

1. Sur la release, télécharge plutôt **`AscensionFR_Perso.zip`** (addon seul) si tu n’as besoin que du jeu.
2. Si le `.exe` est bloqué au téléchargement : navigateur → **Conservez quand même** / SmartScreen → **Informations supplémentaires** → **Exécuter quand même**.
3. Après téléchargement : clic droit sur le fichier → **Propriétés** → coche **Débloquer** → OK.
4. Defender → Protection contre les virus → **Historique** → Autoriser / Restaurer.
5. Signalement Microsoft (améliore le whitelist pour tout le monde) :
   https://www.microsoft.com/en-us/wdsi/filesubmission  
   → *Incorrectly detected as malware / false positive*.

Sans `.exe` : `cd compagnon` puis `python compagnon.py` (Python 3 installé).

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
