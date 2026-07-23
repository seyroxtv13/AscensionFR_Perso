# -*- coding: utf-8 -*-
"""Scan EN-keyed DBs for identity translations and extract Recolte from SV."""
from pathlib import Path
import re

root = Path(r"C:\Users\Seyrox.DESKTOP-5NR0U8I\Desktop\AscensionFR_Perso\DB")
pat = re.compile(r'^DB\["((?:\\.|[^"\\])*)"\]="((?:\\.|[^"\\])*)"')
files = [
    "DB_Libelles.lua",
    "DB_Gossip.lua",
    "DB_Zones.lua",
    "DB_QuetesObjectifs.lua",
    "DB_TextesPNJ.lua",
    "DB_Divers.lua",
    "DB_HautsFaits.lua",
]
for name in files:
    p = root / name
    if not p.exists():
        print(name, "MISSING")
        continue
    same = 0
    total = 0
    samples = []
    for line in p.open(encoding="utf-8", errors="replace"):
        m = pat.match(line.strip())
        if not m:
            continue
        total += 1
        en, fr = m.group(1), m.group(2)
        if en == fr and len(en) > 2:
            same += 1
            if len(samples) < 8:
                samples.append(en[:100])
    print(f"{name}: total~{total} identity={same}")
    for s in samples:
        print("  =", s)

sv = Path(
    r"E:\Play Ascension\resources\ascension-live\WTF\Account\Seyrox\SavedVariables\AscensionFR_Perso.lua"
)
print("\nSV exists", sv.exists(), sv)
if sv.exists():
    text = sv.read_text(encoding="utf-8", errors="replace")
    # Rough extract Recolte section size
    for key in ("Recolte", "Signalements", "EchecsAlignement"):
        print(key, "mentions", text.count(key))
    # Dump Divers keys from Recolte if present
    m = re.search(r'\["Divers"\]\s*=\s*\{(.*?)\n\t\t\}', text, re.S)
    if m:
        chunk = m.group(1)
        keys = re.findall(r'\["((?:\\.|[^"\\])*)"\]', chunk)
        print("Recolte Divers keys", len(keys))
        for k in keys[:40]:
            print("  R", k[:120])
    else:
        # try alternate indent
        m = re.search(r'Recolte\s*=\s*\{(.*?)(?:Echecs|Signalements|Options)\s*=', text, re.S)
        if m:
            chunk = m.group(1)
            print("Recolte blob len", len(chunk))
            keys = re.findall(r'\["((?:\\.|[^"\\])*)"\]\s*=', chunk)
            print("keys sample", len(keys))
            for k in keys[:50]:
                print("  R", k[:120])
