# -*- coding: utf-8 -*-
"""Fix Tinker spell display names from user screenshots."""
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "DB"

# Exact N= / n= replacements (spell bar titles)
repls = [
    ('N="Construction: Sentry tourelle"', 'N="Construction : Tourelle sentinelle"'),
    ('N="Deconstruct Sentry tourelle"', 'N="Déconstruire la tourelle sentinelle"'),
    ('N="Construction: Restorative Beacon"', 'N="Construction : Balise réparatrice"'),
    ('N="Déconcerter!"', 'N="Discombobuler !"'),
    ('n="Construction: Sentry tourelle"', 'n="Construction : Tourelle sentinelle"'),
    ('n="Deconstruct Sentry tourelle"', 'n="Déconstruire la tourelle sentinelle"'),
    ('n="Construction: Restorative Beacon"', 'n="Construction : Balise réparatrice"'),
    # SortsNoms lazy maps (EN key -> FR name)
    '["Build: Sentry Turret"]="Construction: Sentry tourelle"',
]

# For SortsNoms use tuple style separately
noms_repls = [
    (
        '["Build: Sentry Turret"]="Construction: Sentry tourelle"',
        '["Build: Sentry Turret"]="Construction : Tourelle sentinelle"',
    ),
    (
        '["Build: Restorative Beacon"]="Construction: Restorative Beacon"',
        '["Build: Restorative Beacon"]="Construction : Balise réparatrice"',
    ),
    (
        '["Discombobulate!"]="Déconcerter!"',
        '["Discombobulate!"]="Discombobuler !"',
    ),
    (
        '["Deconstruct Sentry Turret"]="Deconstruct Sentry tourelle"',
        '["Deconstruct Sentry Turret"]="Déconstruire la tourelle sentinelle"',
    ),
]

for fname in ("DB_Sorts.lua", "DB_SortsLignes.lua"):
    p = root / fname
    t = p.read_text(encoding="utf-8")
    total = 0
    for a, b in [
        ('N="Construction: Sentry tourelle"', 'N="Construction : Tourelle sentinelle"'),
        ('N="Deconstruct Sentry tourelle"', 'N="Déconstruire la tourelle sentinelle"'),
        ('N="Construction: Restorative Beacon"', 'N="Construction : Balise réparatrice"'),
        ('N="Déconcerter!"', 'N="Discombobuler !"'),
        ('n="Construction: Sentry tourelle"', 'n="Construction : Tourelle sentinelle"'),
        ('n="Deconstruct Sentry tourelle"', 'n="Déconstruire la tourelle sentinelle"'),
        ('n="Construction: Restorative Beacon"', 'n="Construction : Balise réparatrice"'),
    ]:
        n = t.count(a)
        if n:
            t = t.replace(a, b)
            total += n
            print(f"{fname}: {n}x {a[:40]}...")
    p.write_text(t, encoding="utf-8", newline="\n")
    print(f"{fname}: wrote, changes={total}, size={p.stat().st_size}")

p = root / "DB_SortsNoms.lua"
t = p.read_text(encoding="utf-8")
total = 0
for a, b in noms_repls:
    n = t.count(a)
    if n:
        t = t.replace(a, b)
        total += n
        print(f"SortsNoms: {n}x {a[:50]}")
    else:
        print(f"SortsNoms MISS: {a[:60]}")
p.write_text(t, encoding="utf-8", newline="\n")
print("SortsNoms changes", total)

# Phrases overlay (exact bar strings)
phrases = root / "Phrases.lua"
pt = phrases.read_text(encoding="utf-8")
block = """
    -- Lot 1b — cast bar Tinker (captures écran joueur)
    ["Construction: Restorative Beacon"] = "Construction : Balise réparatrice",
    ["Construction: Sentry Turret"] = "Construction : Tourelle sentinelle",
    ["Construction: Sentry tourelle"] = "Construction : Tourelle sentinelle",
    ["Build: Restorative Beacon"] = "Construction : Balise réparatrice",
    ["Build: Sentry Turret"] = "Construction : Tourelle sentinelle",
    ["Discombobulate!"] = "Discombobuler !",
    ["Déconcerter!"] = "Discombobuler !",
    ["Deconstruct Sentry Turret"] = "Déconstruire la tourelle sentinelle",
    ["Deconstruct Sentry tourelle"] = "Déconstruire la tourelle sentinelle",
"""
if "Balise réparatrice" not in pt:
    pt = pt.replace(
        '    ["Fishing"] = "Pêche",\n}\n',
        '    ["Fishing"] = "Pêche",\n' + block + "}\n",
    )
    phrases.write_text(pt, encoding="utf-8", newline="\n")
    print("Phrases updated")
else:
    print("Phrases already has balise")

# Verify
t = (root / "DB_Sorts.lua").read_text(encoding="utf-8")
assert "DB[801801]" in t and "DB[807197]" in t
assert 'N="Construction : Balise réparatrice"' in t
assert 'N="Discombobuler !"' in t
assert 'N="Construction : Tourelle sentinelle"' in t
print("VERIFY OK")
