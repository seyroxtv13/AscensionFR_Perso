# -*- coding: utf-8 -*-
"""Fix Overcharge EN leftovers only inside French D=\"...\" fields (not DE)."""
from pathlib import Path
import re
import subprocess

root = Path(__file__).resolve().parents[1]
p = root / "DB" / "DB_Sorts.lua"

# Restore clean file from git first
subprocess.run(
    ["git", "checkout", "HEAD", "--", "DB/DB_Sorts.lua"],
    cwd=root,
    check=True,
)

t = p.read_text(encoding="utf-8")

REPS = [
    (
        "|cffffffffOvercharge|r: Heals all allies within 15 yds for $560710s1% of their maximum health plus ${$560710m3+$560710ppl3+$BH*.8}.",
        "|cffffffffSurcharge|r : Soigne tous les alliés dans un rayon de 15 m à hauteur de $560710s1% de leurs points de vie maximum, plus ${$560710m3+$560710ppl3+$BH*.8}.",
    ),
    (
        "|cffffffffOvercharge|r: Restores $560753s1% maximum mana to all allies within 15 yds.",
        "|cffffffffSurcharge|r : Restaure $560753s1% du mana maximum de tous les alliés dans un rayon de 15 m.",
    ),
    (
        "|cffffffffOvercharge|r: Dispels $560757s1 harmful magic and curse effect from all allies within 15 yds.",
        "|cffffffffSurcharge|r : Dissipe $560757s1 effet(s) magique(s) et de malédiction nuisible(s) de tous les alliés dans un rayon de 15 m.",
    ),
    (
        "@ext:Shares a cooldown with other |cffffffffBeacons|r:ext@",
        "@ext:Partage un temps de recharge avec d'autres |cffffffffbalises|r:ext@",
    ),
    (
        "avec d'autres |cffffffffBeacons|r:ext@",
        "avec d'autres |cffffffffbalises|r:ext@",
    ),
    (
        "avec d'autres |cffffffffBeacons|r",
        "avec d'autres |cffffffffbalises|r",
    ),
]

pat = re.compile(r'D="((?:\\.|[^"\\])*)"')


def sub_d(m: re.Match) -> str:
    d = m.group(1)
    for a, b in REPS:
        d = d.replace(a, b)
    return 'D="' + d + '"'


newt, nfields = pat.subn(sub_d, t)
p.write_text(newt, encoding="utf-8", newline="\n")
print("D fields scanned", nfields)

# Re-apply lot 002/003 Construction N= fixes (checkout wiped them)
name_reps = [
    ('N="Construction: Sentry tourelle"', 'N="Construction : Tourelle sentinelle"'),
    ('N="Deconstruct Sentry tourelle"', 'N="Déconstruire la tourelle sentinelle"'),
    ('N="Construction: Restorative Beacon"', 'N="Construction : Balise réparatrice"'),
    ('N="Déconcerter!"', 'N="Discombobuler !"'),
    ('N="Construction: Alarm balise"', 'N="Construction : Balise d\'alarme"'),
    ('N="Construction: Assistant mécanique"', 'N="Construction : Assistant mécanique"'),
    ('N="Construction: Battery recharge Station"', 'N="Construction : Station de recharge"'),
    ('N="Construction: Bounce Pad!"', 'N="Construction : Tremplin !"'),
    ('N="Construction: Destructo-Bot"', 'N="Construction : Destructo-Bot"'),
    ('N="Construction: Firepot drone"', 'N="Construction : Drone incendiaire"'),
    ('N="Construction: Mechano-Bear"', 'N="Construction : Méca-ours"'),
    ('N="Construction: Oil-Spill Pylon"', 'N="Construction : Pylône de nappe d\'huile"'),
    ('N="Construction: Repulsion Unit"', 'N="Construction : Unité de répulsion"'),
    ('N="Construction: Rusthound"', 'N="Construction : Limier de rouille"'),
    ('N="Construction: Scrapmaw"', 'N="Construction : Gueule-de-ferraille"'),
    ('N="Construction: araignée bombe"', 'N="Construction : Bombe araignée"'),
    ('N="Construction: araignée bombe Factory"', 'N="Construction : Usine à bombes araignées"'),
    ('N="Construction: puissance Foundry"', 'N="Construction : Fonderie d\'énergie"'),
]
t = p.read_text(encoding="utf-8")
nc = 0
for a, b in name_reps:
    c = t.count(a)
    if c:
        t = t.replace(a, b)
        nc += c
p.write_text(t, encoding="utf-8", newline="\n")
print("N= reapplied", nc)

chunk_d = t.split("DB[801801]={")[1].split(",DE=")[0]
chunk_de = t.split("DB[801801]={")[1].split(',DE="')[1].split('"')[0]
print("D FR ok", "Soigne tous les alliés" in chunk_d)
print("D no EN", "Heals all allies" not in chunk_d)
print("DE still EN", "Heals all allies" in chunk_de)
print("size", p.stat().st_size)
assert "DB[801801]" in t and "DB[807197]" in t
assert "Heals all allies" not in chunk_d
assert "Heals all allies" in chunk_de
print("VERIFY OK")
