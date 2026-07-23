# Devblog #002 — Correctifs cast bar Tinker

**Date :** 23 juillet 2026  
**Version :** 1.0.3 (patch DB)

## Captures joueur

Trois textes encore mauvais / mixtes EN-FR :

| Affiché | Correction |
|---------|------------|
| `Construction: Restorative Beacon` | **Construction : Balise réparatrice** |
| `Construction: Sentry tourelle` | **Construction : Tourelle sentinelle** |
| `Déconcerter!` | **Discombobuler !** (EN : *Discombobulate!*, terme WoW « discombobulateur ») |

## Fichiers touchés

- `DB/DB_Sorts.lua` — champs `N=` (titre du sort)
- `DB/DB_SortsLignes.lua` — champs `n=`
- `DB/DB_SortsNoms.lua` — map EN → FR
- `DB/Phrases.lua` — filet de sécurité exact-match

## Note

`Déconcerter` était une mauvaise traduction de *Discombobulate* (sort d’ingénierie / bricoleur), pas « Dismiss / Renvoyer ».
