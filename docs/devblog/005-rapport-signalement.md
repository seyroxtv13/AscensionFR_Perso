# Devblog #005 — Rapport signalement (Folie, Nanobots, Eureka…)

**Date :** 23 juillet 2026  
**Source :** rapport in-game Seyrox (AscensionFR Perso 1.0.3)

## Échecs d'alignement corrigés

| SpellID | Anglais affiché | Français |
|---------|-----------------|----------|
| 500706 | If this reaches 100 stacks, you will lose your mind. | Si ceci atteint 100 cumuls, vous perdrez la raison. |
| 2101864 | Haunted... | Hanté... |
| 502557 | Healing for 56 every sec. | Rend 56 points de vie toutes les secondes. |

Ajoutés en modèles d'aura `DE2`/`D2` dans `DB_SortsCorrections.lua` (le texte de buff ≠ description de lancement).

## Récolte → fiches créées

| ID | Nom EN | Nom FR |
|----|--------|--------|
| 503553 | Eureka! | Eureka ! |
| 706255 | Rejuvenating Gas | Gaz rajeunissant |
| 560709 | Overcharge: Shield Beacon | Surcharge : Balise de protection |
| 806158 | Healthy | En bonne santé |

## Bonus technique

- Motif générique `Healing for N every sec.` sur les info-bulles d'aura (`Tooltips.lua`)
- Phrases exactes en filet Divers

`/reload` puis retester les buffs concernés.
