# -*- coding: utf-8 -*-
"""Lot 003 — normaliser les noms Construction:/Build: Tinker encore mixtes EN-FR."""
from pathlib import Path

root = Path(__file__).resolve().parents[1] / "DB"

# N= / n= display titles
NAME_MAP = {
    'N="Construction: Alarm balise"': 'N="Construction : Balise d\'alarme"',
    'N="Construction: Assistant mécanique"': 'N="Construction : Assistant mécanique"',
    'N="Construction: Battery recharge Station"': 'N="Construction : Station de recharge"',
    'N="Construction: Bounce Pad!"': 'N="Construction : Tremplin !"',
    'N="Construction: Destructo-Bot"': 'N="Construction : Destructo-Bot"',
    'N="Construction: Firepot drone"': 'N="Construction : Drone incendiaire"',
    'N="Construction: Mechano-Bear"': 'N="Construction : Méca-ours"',
    'N="Construction: Oil-Spill Pylon"': 'N="Construction : Pylône de nappe d\'huile"',
    'N="Construction: Repulsion Unit"': 'N="Construction : Unité de répulsion"',
    'N="Construction: Rusthound"': 'N="Construction : Limier de rouille"',
    'N="Construction: Scrapmaw"': 'N="Construction : Gueule-de-ferraille"',
    'N="Construction: araignée bombe"': 'N="Construction : Bombe araignée"',
    'N="Construction: araignée bombe Factory"': 'N="Construction : Usine à bombes araignées"',
    'N="Construction: puissance Foundry"': 'N="Construction : Fonderie d\'énergie"',
    # lowercase n= variants in SortsLignes
    'n="Construction: Alarm balise"': 'n="Construction : Balise d\'alarme"',
    'n="Construction: Assistant mécanique"': 'n="Construction : Assistant mécanique"',
    'n="Construction: Battery recharge Station"': 'n="Construction : Station de recharge"',
    'n="Construction: Bounce Pad!"': 'n="Construction : Tremplin !"',
    'n="Construction: Destructo-Bot"': 'n="Construction : Destructo-Bot"',
    'n="Construction: Firepot drone"': 'n="Construction : Drone incendiaire"',
    'n="Construction: Mechano-Bear"': 'n="Construction : Méca-ours"',
    'n="Construction: Oil-Spill Pylon"': 'n="Construction : Pylône de nappe d\'huile"',
    'n="Construction: Repulsion Unit"': 'n="Construction : Unité de répulsion"',
    'n="Construction: Rusthound"': 'n="Construction : Limier de rouille"',
    'n="Construction: Scrapmaw"': 'n="Construction : Gueule-de-ferraille"',
    'n="Construction: araignée bombe"': 'n="Construction : Bombe araignée"',
    'n="Construction: araignée bombe Factory"': 'n="Construction : Usine à bombes araignées"',
    'n="Construction: puissance Foundry"': 'n="Construction : Fonderie d\'énergie"',
}

# SortsNoms EN key -> FR (old value may still be mixed)
NOMS_MAP = {
    '["Build: Alarm Beacon"]="Construction: Alarm balise"':
        '["Build: Alarm Beacon"]="Construction : Balise d\'alarme"',
    '["Build: Mechanical Assistant"]="Construction: Assistant mécanique"':
        '["Build: Mechanical Assistant"]="Construction : Assistant mécanique"',
    '["Build: Battery Recharge Station"]="Construction: Battery recharge Station"':
        '["Build: Battery Recharge Station"]="Construction : Station de recharge"',
    '["Build: Bounce Pad!"]="Construction: Bounce Pad!"':
        '["Build: Bounce Pad!"]="Construction : Tremplin !"',
    '["Build: Destructo-Bot"]="Construction: Destructo-Bot"':
        '["Build: Destructo-Bot"]="Construction : Destructo-Bot"',
    '["Build: Firepot Drone"]="Construction: Firepot drone"':
        '["Build: Firepot Drone"]="Construction : Drone incendiaire"',
    '["Build: Mechano-Bear"]="Construction: Mechano-Bear"':
        '["Build: Mechano-Bear"]="Construction : Méca-ours"',
    '["Build: Oil-Spill Pylon"]="Construction: Oil-Spill Pylon"':
        '["Build: Oil-Spill Pylon"]="Construction : Pylône de nappe d\'huile"',
    '["Build: Repulsion Unit"]="Construction: Repulsion Unit"':
        '["Build: Repulsion Unit"]="Construction : Unité de répulsion"',
    '["Build: Rusthound"]="Construction: Rusthound"':
        '["Build: Rusthound"]="Construction : Limier de rouille"',
    '["Build: Scrapmaw"]="Construction: Scrapmaw"':
        '["Build: Scrapmaw"]="Construction : Gueule-de-ferraille"',
    '["Build: Spider Bomb"]="Construction: araignée bombe"':
        '["Build: Spider Bomb"]="Construction : Bombe araignée"',
    '["Build: Spider Bomb Factory"]="Construction: araignée bombe Factory"':
        '["Build: Spider Bomb Factory"]="Construction : Usine à bombes araignées"',
    '["Build: Power Foundry"]="Construction: puissance Foundry"':
        '["Build: Power Foundry"]="Construction : Fonderie d\'énergie"',
}

PHRASES = {
    "Construction: Alarm Beacon": "Construction : Balise d'alarme",
    "Build: Alarm Beacon": "Construction : Balise d'alarme",
    "Construction: Battery recharge Station": "Construction : Station de recharge",
    "Build: Battery Recharge Station": "Construction : Station de recharge",
    "Construction: Bounce Pad!": "Construction : Tremplin !",
    "Build: Bounce Pad!": "Construction : Tremplin !",
    "Construction: Firepot drone": "Construction : Drone incendiaire",
    "Build: Firepot Drone": "Construction : Drone incendiaire",
    "Construction: Mechano-Bear": "Construction : Méca-ours",
    "Build: Mechano-Bear": "Construction : Méca-ours",
    "Construction: Oil-Spill Pylon": "Construction : Pylône de nappe d'huile",
    "Build: Oil-Spill Pylon": "Construction : Pylône de nappe d'huile",
    "Construction: Repulsion Unit": "Construction : Unité de répulsion",
    "Build: Repulsion Unit": "Construction : Unité de répulsion",
    "Construction: Rusthound": "Construction : Limier de rouille",
    "Build: Rusthound": "Construction : Limier de rouille",
    "Construction: Scrapmaw": "Construction : Gueule-de-ferraille",
    "Build: Scrapmaw": "Construction : Gueule-de-ferraille",
    "Construction: araignée bombe": "Construction : Bombe araignée",
    "Build: Spider Bomb": "Construction : Bombe araignée",
    "Construction: araignée bombe Factory": "Construction : Usine à bombes araignées",
    "Build: Spider Bomb Factory": "Construction : Usine à bombes araignées",
    "Construction: puissance Foundry": "Construction : Fonderie d'énergie",
    "Build: Power Foundry": "Construction : Fonderie d'énergie",
}


def apply_map(path: Path, mapping: dict) -> int:
    t = path.read_text(encoding="utf-8")
    n = 0
    for a, b in mapping.items():
        c = t.count(a)
        if c:
            t = t.replace(a, b)
            n += c
            print(f"  {path.name}: {c}x {a[:55]}")
        else:
            # try case variants for Battery
            pass
    path.write_text(t, encoding="utf-8", newline="\n")
    return n


def main():
    print("=== DB_Sorts ===")
    n1 = apply_map(root / "DB_Sorts.lua", {k: v for k, v in NAME_MAP.items() if k.startswith("N=")})
    print("=== DB_SortsLignes ===")
    n2 = apply_map(root / "DB_SortsLignes.lua", {k: v for k, v in NAME_MAP.items() if k.startswith("n=")})
    print("=== DB_SortsNoms ===")
    t = (root / "DB_SortsNoms.lua").read_text(encoding="utf-8")
    n3 = 0
    for a, b in NOMS_MAP.items():
        c = t.count(a)
        if c:
            t = t.replace(a, b)
            n3 += c
            print(f"  SortsNoms: {c}x {a[:60]}")
        else:
            # fuzzy: find Build: X key and rewrite FR side
            print(f"  MISS exact: {a[:70]}")
    (root / "DB_SortsNoms.lua").write_text(t, encoding="utf-8", newline="\n")

    # Phrases
    ph = root / "Phrases.lua"
    pt = ph.read_text(encoding="utf-8")
    if "Fonderie d'énergie" not in pt:
        lines = []
        for en, fr in PHRASES.items():
            lines.append(f'    ["{en}"] = "{fr}",')
        block = "\n    -- Lot 003 — suite Construction Tinker\n" + "\n".join(lines) + "\n"
        pt = pt.replace(
            '    ["Fishing"] = "Pêche",\n',
            '    ["Fishing"] = "Pêche",\n' + block,
        )
        ph.write_text(pt, encoding="utf-8", newline="\n")
        print("Phrases +", len(PHRASES))
    else:
        print("Phrases already lot 003")

    # Verify remaining dirty Construction:
    import re
    t = (root / "DB_Sorts.lua").read_text(encoding="utf-8")
    left = sorted(set(re.findall(r'N="(Construction:[^"]*)"', t)))
    print("Remaining Construction: (no space after colon)", len(left))
    for x in left:
        print(" ", x)
    print("TOTAL edits", n1 + n2 + n3)


if __name__ == "__main__":
    main()
