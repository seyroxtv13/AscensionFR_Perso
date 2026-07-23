# -*- coding: utf-8 -*-
"""Fix Contender! junk in DB_HautsFaits.lua with coherent FR."""
from pathlib import Path
import re

p = Path(__file__).resolve().parents[1] / "DB" / "DB_HautsFaits.lua"
text = p.read_text(encoding="utf-8")

# Pattern: (TBC) - Completed Mythic: N  -> Contender!
def repl_mythic(m):
    prefix = m.group(1)  # (TBC) or (WotLK) etc
    n = m.group(2)
    return f'DB["{prefix} - Completed Mythic: {n}"]="{prefix} - Mythique terminé : {n}"'

new, n1 = re.subn(
    r'^DB\["(\([^"]+\)) - Completed Mythic: (\d+)"\]="Contender!"$',
    repl_mythic,
    text,
    flags=re.M,
)
print("mythic fixed", n1)

# Broader: any remaining Contender! with Completed Mythic in key
def repl_any(m):
    en = m.group(1)
    # try parse
    m2 = re.match(r"^(\(.+?\)) - Completed Mythic: (\d+)$", en)
    if m2:
        return f'DB["{en}"]="{m2.group(1)} - Mythique terminé : {m2.group(2)}"'
    # generic fallback: keep meaning
    if "Completed Mythic" in en:
        fr = en.replace("Completed Mythic", "Mythique terminé")
        return f'DB["{en}"]="{fr}"'
    return m.group(0)

new2, n2 = re.subn(
    r'^DB\["((?:\\.|[^"\\])*)"\]="Contender!"$',
    repl_any,
    new,
    flags=re.M,
)
print("remaining contender pass", n2)
print("still Contender", new2.count("Contender!"))
p.write_text(new2, encoding="utf-8", newline="\n")
print("written")
