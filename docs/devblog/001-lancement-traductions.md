# Devblog #001 — Lancement du chantier de traduction

**Date :** 23 juillet 2026  
**Auteur :** Seyrox / Auto  
**Version addon :** 1.0.3 (cible)

## Contexte

AscensionFR Perso charge désormais le moteur + les bases (fork technique). Le français « de base » est là (~130k+ entrées), mais :

- des libellés courts d’info-bulles passent encore en anglais ;
- `DB_Divers` était quasi vide (3 lignes) ;
- des hauts faits Ascension avaient des traductions poubelle (`Contender!`).

Ce blog ouvre le **rythme de travail** : lots ciblés, cohérence WoW FR, push GitHub à chaque vague.

## Lot 1 livré

1. **`docs/CONVENTIONS_TRAD.md`** — règles anti-casse (jetons `$B`, `|c`, `@ext@`…) + glossaire WoW FR.
2. **`DB/Phrases.lua`** — élargi (~stats WotLK, liaisons d’objets, châsses, métiers, messages combat courts). Fusionné dans Divers au boot.
3. **`DB/DB_Divers.lua`** — correctifs qualité (plaques de nom) + libellés UI / quêtes / marchand courants.
4. **`DB/DB_HautsFaits.lua`** — remplacement des clés `Completed Mythic` qui affichaient `Contender!` par un français cohérent (`Mythique terminé : N`).

## Ce que ça change en jeu

- Moins d’anglais sur les stats d’objets / tooltips génériques.
- Moins de libellés UI bruts (`Equip:`, `Binds when picked up`, châsses…).
- Hauts faits mythiques TBC/WotLK Ascension : plus de titre absurde « Contender! ».

## Prochains lots (prévus)

| # | Cible | Risque |
|---|--------|--------|
| 002 | Gossip / options de dialogue encore EN | Faible |
| 003 | Objectifs de quêtes (tracker) manquants | Faible/moyen (`$B`) |
| 004 | Correctifs `SortsCorrections` signalés | Moyen (alignement) |
| 005+ | Récolte joueur (`/afrp signaler` + Compagnon) | Selon reports |

## Comment aider

1. Survole un texte encore anglais → `/afrp signaler` (ou Compagnon).
2. Explore du contenu Ascension inédit (récolte auto).
3. Envoie le rapport : il alimente le lot suivant.

## Note technique GitHub

Premier push « fondation » : moteur + DB + UI Perso + ce lot. Les fichiers les plus gros restent sous la limite GitHub (~25 Mo max ici pour `DB_Objets.lua`).
