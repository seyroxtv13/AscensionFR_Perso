# Devblog #004 — Surcharge des balises (Overcharge)

**Date :** 23 juillet 2026

## Probleme
Tooltip `Construction : Balise reparatrice` : le titre etait FR, mais le bloc conditionnel restait EN :
`Overcharge: Heals all allies within 15 yds...`

## Correctif
Dans `DB_Sorts.lua` (champ `D=` uniquement, pas `DE=`) :
- Overcharge -> **Surcharge**
- Heals all allies within 15 yds... -> **Soigne tous les allies dans un rayon de 15 m...**
- Meme famille pour balises d'alarme / reapprovisionnement
- Jetons `%`, ``, `Trues524834[...]` conserves
