# AscensionFR Perso

Overlay de corrections françaises pour Project Ascension.  
Fonctionne **à côté** de [AscensionFR](https://github.com/LePetitDan/AscensionFR) : les mises à jour officielles **n’écrasent pas** tes corrects.

## Conflit avec AscensionFR officiel ?

**Non**, en usage normal :

| | AscensionFR | AscensionFR Perso |
|---|---|---|
| Dossier | `AddOns/AscensionFR` | `AddOns/AscensionFR_Perso` |
| Rôle | Base complète | Petites corrections manquantes |
| Maj | Via leur Compagnon | Via **ton** Compagnon (ce repo) |

Perso ne touche **jamais** aux fichiers officiels. `OptionalDeps: AscensionFR` le charge après, pour surcharger seulement les phrases exactes de `DB/Phrases.lua` (ex. `Agility`, `Haste Rating`).

## Installation / maj

1. Garde **AscensionFR** officiel.
2. Lance `AscensionFR_Perso_Compagnon.exe` (release) → il trouve le jeu et installe/maj **Perso seul**.
3. Après ta session de jeu : AddOns → Perso coché → `/reload` (ou relance si nouvel addon).

[Releases](https://github.com/seyroxtv13/AscensionFR_Perso/releases)

## En jeu

- `/afrp` — panneau options  
- `/afrp on` / `/afrp off` — active / coupe l’overlay  
- `/afrp status` — résumé chat  

## Ajouter une traduction

```lua
-- DB/Phrases.lua
["Texte anglais exact"] = "Texte français",
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

Projet perso. Non affilié à Blizzard / Project Ascension / AscensionFR officiel.
