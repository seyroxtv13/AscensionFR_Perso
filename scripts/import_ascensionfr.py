# -*- coding: utf-8 -*-
"""
Import AscensionFR -> Perso : DB/Modules octet-pour-octet + alias Core.
"""
from __future__ import annotations

import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SRC = Path(r"E:\Play Ascension\resources\ascension-live\Interface\AddOns\AscensionFR")
SKIP_MODULES = {"Minimap.lua"}


def main() -> None:
    if not SRC.is_dir():
        raise SystemExit(f"Source introuvable: {SRC}")

    core_src = (SRC / "Core.lua").read_text(encoding="utf-8")
    core_src = core_src.replace(
        "AscensionFR = AscensionFR or {}",
        "AscensionFR_Perso = AscensionFR_Perso or {}\n"
        "AscensionFR = AscensionFR_Perso",
        1,
    )
    core_src = core_src.replace(
        "local AFR = AscensionFR\n",
        "local AFR = AscensionFR_Perso\n"
        "AscensionFR_PersoDB = AscensionFR_PersoDB or {}\n"
        "AscensionFRSaved = AscensionFR_PersoDB\n",
        1,
    )
    (ROOT / "Core.lua").write_text(core_src, encoding="utf-8", newline="\n")
    print("OK Core.lua")

    db_out = ROOT / "DB"
    db_out.mkdir(exist_ok=True)
    for f in sorted((SRC / "DB").glob("DB_*.lua")):
        shutil.copy2(f, db_out / f.name)
        print("OK", f.name)

    mod_out = ROOT / "Modules"
    mod_out.mkdir(exist_ok=True)
    for f in sorted((SRC / "Modules").glob("*.lua")):
        if f.name in SKIP_MODULES:
            print("SKIP", f.name)
            continue
        text = f.read_text(encoding="utf-8")
        text = text.replace('arg1 == "AscensionFR"', 'arg1 == "AscensionFR_Perso"')
        text = text.replace("SLASH_ASCENSIONFR1 = \"/afr\"",
                            "SLASH_ASCENSIONFR1 = \"/afrp\"\nSLASH_ASCENSIONFR2 = \"/afr\"")
        if f.name == "Options.lua":
            text = text.replace(
                'panneau.name = "Ascension |cff0099ffFR|r"',
                'panneau.name = "Ascension |cffc47030FR|r Perso"',
            )
            text = text.replace(
                'titre:SetText("Ascension |cff0099ffFR|r — traduction française")',
                'titre:SetText("Ascension |cffc47030FR|r |cffffd100Perso|r")',
            )
            text = text.replace(
                "https://buymeacoffee.com/lepetitdan",
                "https://github.com/seyroxtv13/AscensionFR_Perso",
            )
            old = ("Cet addon est gratuit et le restera. S'il vous rend le "
                   "jeu plus agréable, vous pouvez soutenir son auteur :")
            text = text.replace(old, "AscensionFR Perso par Seyrox. Mises a jour :")
        (mod_out / f.name).write_text(text, encoding="utf-8", newline="\n")
        print("OK Modules/", f.name)

    if (SRC / "Bindings.xml").is_file():
        shutil.copy2(SRC / "Bindings.xml", ROOT / "Bindings.xml")

    # verify
    a = (SRC / "DB" / "DB_Interface.lua").read_bytes()
    b = (db_out / "DB_Interface.lua").read_bytes()
    print("Interface identical:", a == b)
    a = (SRC / "DB" / "DB_Objets.lua").read_bytes()
    b = (db_out / "DB_Objets.lua").read_bytes()
    print("Objets identical:", a == b)
    print("DONE")


if __name__ == "__main__":
    main()
