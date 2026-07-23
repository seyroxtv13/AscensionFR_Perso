# Devblog #003 — Noms Construction Tinker (suite)

**Date :** 23 juillet 2026  
**Suite de :** [#002](002-tinker-castbar.md)

## Objectif

Après les 3 captures joueur, normaliser **tous** les titres de sorts `Construction:` / `Build:` encore mixtes EN–FR (cast bar / grimoire Bricoleur).

## Exemples corrigés

| Avant | Après |
|--------|--------|
| Construction: Alarm balise | Construction : Balise d'alarme |
| Construction: Battery recharge Station | Construction : Station de recharge |
| Construction: Bounce Pad! | Construction : Tremplin ! |
| Construction: Firepot drone | Construction : Drone incendiaire |
| Construction: Mechano-Bear | Construction : Méca-ours |
| Construction: Oil-Spill Pylon | Construction : Pylône de nappe d'huile |
| Construction: Repulsion Unit | Construction : Unité de répulsion |
| Construction: Rusthound | Construction : Limier de rouille |
| Construction: Scrapmaw | Construction : Gueule-de-ferraille |
| Construction: araignée bombe | Construction : Bombe araignée |
| Construction: araignée bombe Factory | Construction : Usine à bombes araignées |
| Construction: puissance Foundry | Construction : Fonderie d'énergie |

~46 remplacements dans `DB_Sorts` / `DB_SortsLignes` / `DB_SortsNoms` + filet `Phrases.lua`.

## Suite

Lot 004 : gossip / options de dialogue encore EN, ou autres signalements `/afrp signaler`.
