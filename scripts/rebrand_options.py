# -*- coding: utf-8 -*-
"""Rebrand Modules/Options.lua from AscensionFR clone to Perso UI."""
from pathlib import Path
import re

p = Path(__file__).resolve().parents[1] / "Modules" / "Options.lua"
t = p.read_text(encoding="utf-8")

t = t.replace("local AFR = AscensionFR\n", "local AFR = AscensionFR_Perso\n", 1)
t = t.replace("-- AscensionFR - Panneau", "-- AscensionFR Perso - Panneau", 1)

# Strip Dan support block → Perso GitHub only
t = re.sub(
    r"-- -{10,}\n-- LIEN DE SOUTIEN.*?(?=local SOUTIEN_URL)",
    "-- ----------------------------------------------------------------------------\n",
    t,
    count=1,
    flags=re.S,
)

t = t.replace(
    'local DISCORD = "https://discord.gg/kFJGDJbeay"',
    "local DISCORD = SOUTIEN_URL",
)
t = t.replace(
    "https://buymeacoffee.com/lepetitdan",
    "https://github.com/seyroxtv13/AscensionFR_Perso",
)
t = t.replace(
    "https://discord.gg/kFJGDJbeay",
    "https://github.com/seyroxtv13/AscensionFR_Perso",
)

repls = [
    ("|cff0099ffAscensionFR|r", "|cffc47030Perso|r"),
    ("|cff0099ffAFR|r", "|cffc47030Perso|r"),
    (
        "Signaler un souci — Ascension |cff0099ffFR|r",
        "Signaler un souci — AscensionFR Perso",
    ),
    ("Compagnon AscensionFR", "Compagnon Perso"),
    ('titreSoutien:SetText("Soutenir le projet")', 'titreSoutien:SetText("Projet Perso")'),
    ("Soutenir le projet", "Projet Perso"),
    (
        'panneau.name = "Ascension |cffc47030FR|r Perso"',
        'panneau.name = "AscensionFR Perso"',
    ),
    (
        'titre:SetText("Ascension |cffc47030FR|r |cffffd100Perso|r")',
        'titre:SetText("|cffc47030AscensionFR Perso|r")',
    ),
    (
        'sousTitre:SetText("Traduit tout le jeu en français. Ce qui manque est noté, "\n'
        '    .. "puis traduit à la prochaine version.")',
        'sousTitre:SetText("Traduction FR indépendante par Seyrox. '
        'Ce qui manque : /afrp signaler.")',
    ),
    (
        'boutonAider:SetText("Envoyer mes découvertes")',
        'boutonAider:SetText("Préparer un rapport")',
    ),
    (
        "introAddons:SetText(\"Ces addons sont l'œuvre d'autres auteurs ; AscensionFR \"",
        "introAddons:SetText(\"Addons d'autres auteurs ; Perso \"",
    ),
    (
        'etiquetteDiscord:SetText("Discord (Ctrl+C) :")',
        'etiquetteDiscord:SetText("GitHub (Ctrl+C) :")',
    ),
    (
        'and GetAddOnMetadata("AscensionFR", "Version") or "?"',
        'and GetAddOnMetadata("AscensionFR_Perso", "Version") or "?"',
    ),
    (
        'table.insert(lignesContexte, "AscensionFR " .. tostring(version))',
        'table.insert(lignesContexte, "AscensionFR Perso " .. tostring(version))',
    ),
    (
        '.."utilisez /afr on | off | debug.")',
        '.."utilisez /afrp on | off | debug.")',
    ),
]
for a, b in repls:
    n = t.count(a)
    t = t.replace(a, b)
    print("%r -> %d" % (a[:55], n))

# Support paragraph (may be split)
old_soutien = (
    'texteSoutien:SetText("Cet addon est gratuit et le restera. S\'il vous rend le "\n'
    '    .. "jeu plus agréable, vous pouvez soutenir son auteur :")'
)
new_soutien = (
    'texteSoutien:SetText("Addon indépendant par Seyrox. '
    'Suivre les mises à jour :")'
)
if old_soutien in t:
    t = t.replace(old_soutien, new_soutien)
    print("soutien split ok")
else:
    # single-line / other wrap
    t2, n = re.subn(
        r'texteSoutien:SetText\("Cet addon est gratuit.*?auteur\s*:"\)',
        'texteSoutien:SetText("Addon indépendant par Seyrox. Suivre les mises à jour :")',
        t,
        count=1,
        flags=re.S,
    )
    print("soutien regex", n)
    t = t2

# Aide companion block
t2, n = re.subn(
    r'aide:SetText\("Un texte resté en anglais\?.*?Discord\."\)',
    'aide:SetText("Texte resté en anglais ? Survolez-le puis /afrp signaler.\\n"\n'
    '    .. "Sinon : Compagnon Perso, ou « Préparer un rapport » puis Ctrl+C.")',
    t,
    count=1,
    flags=re.S,
)
print("aide", n)
t = t2

# Astuce compagnon
t2, n = re.subn(
    r'astuceCompagnon:SetText\("Le plus simple :.*?\)',
    'astuceCompagnon:SetText("|cffffd100Compagnon Perso|r : envoi du rapport en un clic.")',
    t,
    count=1,
    flags=re.S,
)
print("astuce", n)
t = t2

# Fenêtre copie aide
t2, n = re.subn(
    r'aideCopie:SetText\("Votre rapport est prêt.*?ferme\."\)',
    'aideCopie:SetText("Rapport prêt. |cffffff00Ctrl+C|r pour copier, '
    'puis collez-le où vous voulez.\\n"\n'
    '    .. "(Plus simple : Compagnon Perso.) |cffffff00Échap|r ferme.")',
    t,
    count=1,
    flags=re.S,
)
print("aideCopie", n)
t = t2

# Coffee icon → bag/scroll vibe (less AFR donation)
t = t.replace(
    'iconeCafe:SetTexture("Interface\\\\Icons\\\\INV_Drink_18")',
    'iconeCafe:SetTexture("Interface\\\\Icons\\\\INV_Misc_Book_09")',
)

HOOK = """
-- Boutons bas de la fenêtre Interface (partagés) : Accepter / Quitter
-- uniquement tant que le panneau Perso est affiché.
local _okTxt, _cancelTxt
local function _PersoBoutonsBas(actif)
    local ok = _G.InterfaceOptionsFrameOkay
    local cancel = _G.InterfaceOptionsFrameCancel
    if not ok or not cancel then return end
    if actif then
        if not _okTxt then
            _okTxt = ok:GetText()
            _cancelTxt = cancel:GetText()
        end
        ok:SetText("Accepter")
        cancel:SetText("Quitter")
    elseif _okTxt then
        ok:SetText(_okTxt)
        cancel:SetText(_cancelTxt)
    end
end
"""

if "_PersoBoutonsBas" not in t:
    if "AFR.DISCORD = DISCORD\n" in t:
        t = t.replace("AFR.DISCORD = DISCORD\n", "AFR.DISCORD = DISCORD\n" + HOOK, 1)
        print("hook injected")
    else:
        print("HOOK insert point missing")

old_onshow = """panneau:SetScript("OnShow", function()
    AfficherOnglet(panneau.selectedTab or 1)
end)"""
new_onshow = """panneau:SetScript("OnShow", function()
    AfficherOnglet(panneau.selectedTab or 1)
    _PersoBoutonsBas(true)
end)
panneau:HookScript("OnHide", function()
    _PersoBoutonsBas(false)
end)"""
if "_PersoBoutonsBas(true)" not in t:
    if old_onshow in t:
        t = t.replace(old_onshow, new_onshow, 1)
        print("OnShow/OnHide wired")
    else:
        print("OnShow block missing")

# Leftover blue FR
t = t.replace("|cff0099ffFR|r", "|cffc47030Perso|r")

p.write_text(t, encoding="utf-8", newline="\n")
print("OK written", p)
# sanity
for needle in (
    "buymeacoffee",
    "discord.gg",
    "Compagnon AscensionFR",
    "Soutenir le projet",
    "D'accord",
    "_PersoBoutonsBas",
    "Accepter",
    "Quitter",
    "AscensionFR Perso",
):
    print("  %s: %d" % (needle, t.count(needle)))
