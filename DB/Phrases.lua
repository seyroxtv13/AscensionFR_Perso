-- ============================================================================
-- Phrases exactes EN -> FR (overlay). Ajouter une ligne = une correction.
-- ============================================================================

local AFRP = AscensionFR_Perso
AFRP.DB = AFRP.DB or {}

local P = {
    -- Stats (capture : fiche / objets)
    ["Agility"] = "Agilité",
    ["Strength"] = "Force",
    ["Stamina"] = "Endurance",
    ["Intellect"] = "Intelligence",
    ["Spirit"] = "Esprit",
    ["Haste Rating"] = "Score de hâte",
    ["Hit Rating"] = "Score de toucher",
    ["Critical Strike Rating"] = "Score de coup critique",
    ["Crit Rating"] = "Score de crit",
    ["Expertise Rating"] = "Score d'expertise",
    ["Dodge Rating"] = "Score d'esquive",
    ["Parry Rating"] = "Score de parade",
    ["Defense Rating"] = "Score de défense",
    ["Armor Penetration Rating"] = "Score de pénétration d'armure",
    ["Spell Power"] = "Puissance des sorts",
    ["Attack Power"] = "Puissance d'attaque",
    ["Armor"] = "Armure",
    ["Resilience Rating"] = "Score de résilience",
    ["Mana Regeneration"] = "Régénération de mana",
    ["Health Regeneration"] = "Régénération de vie",

    -- Variantes avec deux-points (souvent affichées ainsi)
    ["Agility:"] = "Agilité :",
    ["Haste Rating:"] = "Score de hâte :",
    ["Hit Rating:"] = "Score de toucher :",
    ["Critical Strike Rating:"] = "Score de coup critique :",
    ["Strength:"] = "Force :",
    ["Stamina:"] = "Endurance :",
    ["Intellect:"] = "Intelligence :",
    ["Spirit:"] = "Esprit :",
}

AFRP.DB.Phrases = P
