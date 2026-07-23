# Conventions de traduction — AscensionFR Perso

Objectif : français cohérent avec **World of Warcraft** (client FR WotLK / Project Ascension), sans calque littéral ni casse des formats.

## Règles dures (ne pas casser)

1. **Ne jamais altérer** les jetons de format :
   - `%s` `%d` `%.1f` etc.
   - `$B` `$b` `$n` `$c` `$r` `$N` …
   - `|cAARRGGBB…|r` `|H…|h…|h`
   - `@ext:…:ext@` `$?s…[…]` `${…}` (sorts Ascension)
2. **Préserver l’ordre et le nombre** des jetons : autant dans le FR que dans l’EN.
3. **Ne pas traduire** les noms propres de joueurs, les IDs numériques purs, ni les clés techniques (`GlobalStrings` déjà listés en liste noire).
4. Fichiers **ID** (`DB_Sorts`, `DB_Objets`, `DB_Quetes`…) : éditer seulement avec relecture d’alignement ; privilégier `DB_SortsCorrections.lua` pour les correctifs manuels.

## Vocabulaire WoW FR (référence)

| EN | FR |
|----|----|
| Quest | Quête |
| Spell | Sort |
| Talent | Talent |
| Glyph | Glyphe |
| Achievement | Haut fait |
| Nameplate | Plaque de nom |
| Socket | Châsse |
| Hit / Crit / Haste / Expertise Rating | Score de toucher / coup critique / hâte / expertise |
| Spell Power / Attack Power | Puissance des sorts / d’attaque |
| Binds when picked up / equipped | Lié quand ramassé / équipé |
| Equip: / Use: | Équipé : / Utilise : |
| Dungeon / Raid / Battleground | Donjon / Raid / Champ de bataille |

En cas de doute : **même terme que le client FR Blizzard** (pas l’invention d’un synonyme).

## Où écrire quoi

| Besoin | Fichier |
|--------|---------|
| Courte phrase EN exacte (tooltip / UI) | `DB/Phrases.lua` (prioritaire) ou `DB/DB_Divers.lua` |
| Option de dialogue PNJ | `DB/DB_Gossip.lua` |
| Texte de bulle / page | `DB/DB_TextesPNJ.lua` / `DB/DB_Pages.lua` |
| Objectif de quête (ligne tracker) | `DB/DB_QuetesObjectifs.lua` |
| Correctif de sort cassé | `DB/DB_SortsCorrections.lua` |

`Phrases.lua` est fusionné dans `Divers` au chargement (`PersoBoot.lua`) : idéal pour les lots sûrs.

## Processus d’un lot

1. Choisir une cible (ex. libellés d’objets, gossip, correctifs Hauts faits).
2. Traduire en respectant les règles ci-dessus.
3. Écrire un **devblog** dans `docs/devblog/` (numéro incrémental).
4. Commit + push GitHub.
5. Installer / `/reload` en jeu pour smoke-test.

## Interdit dans un lot « safe »

- Réécriture massive de `DB_Sorts.lua` / `DB_Objets.lua` sans script d’alignement.
- Traduction de `DB_Interface.lua` tant que `TRADUIRE_INTERFACE` est désactivé (taint).
- Remplacer un EN long par un FR trop court / hors-sujet (ex. junk « Contender! »).
