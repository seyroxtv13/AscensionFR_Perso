# AscensionFR Perso

Overlay de corrections françaises pour Project Ascension.  
Fonctionne **à côté** de [AscensionFR](https://github.com/LePetitDan/AscensionFR) : les mises à jour officielles **n’écrasent pas** tes corrects.

## Installation

1. Installe **AscensionFR** (officiel).
2. Installe **AscensionFR_Perso** :
   - **Compagnon** : lance `AscensionFR_Perso_Compagnon.exe` → choisis le dossier `ascension-live` → Installer ; ou
   - **Manuel** : extrais `AscensionFR_Perso.zip` dans le dossier du jeu (fusionner `Interface`).
3. Écran de sélection des personnages → **AddOns** → coche *Load Out of Date AddOns* → coche **AscensionFR_Perso**.
4. En jeu : `/reload` puis `/afrp` pour le statut.

Windows SmartScreen peut bloquer l’exe non signé : *Informations complémentaires* → *Exécuter quand même*.

## Contenu MVP (0.1.0)

- Phrases UI manquantes : **Agility** → Agilité, **Haste Rating** → Score de hâte (+ stats voisines).
- Commandes : `/afrp`, `/afrp on`, `/afrp off`.

## Ajouter une traduction

Édite `DB/Phrases.lua` :

```lua
["Texte anglais exact"] = "Texte français",
```

Incrémente `## Version` dans le `.toc`, publie une release avec un nouvel `AscensionFR_Perso.zip`.

## Compagnon (dev)

```text
cd compagnon
pip install pyinstaller
python -m PyInstaller AscensionFR_Perso_Compagnon.spec
```

L’exe sort dans `compagnon/dist/`. Variable optionnelle : `AFRP_DEPOT=seyroxtv13/AscensionFR_Perso`.

Release : `powershell -File scripts\publish_release.ps1`

## Licence

Projet perso / communautaire. Non affilié à Blizzard ni Project Ascension.
