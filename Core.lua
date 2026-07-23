-- ============================================================================
-- AscensionFR_Perso — noyau
-- Overlay léger : complète AscensionFR sans toucher à ses fichiers.
-- ============================================================================

AscensionFR_Perso = AscensionFR_Perso or {}
local AFRP = AscensionFR_Perso

if not string.trim then
    function string.trim(s)
        return (string.gsub(s or "", "^%s*(.-)%s*$", "%1"))
    end
end

AFRP.VERSION = GetAddOnMetadata("AscensionFR_Perso", "Version") or "0.1.0"
AFRP.DB = AFRP.DB or {}

local function Actif()
    return AscensionFR_PersoDB == nil or AscensionFR_PersoDB.enabled ~= false
end
AFRP.Actif = Actif

local function CompterPhrases()
    local n = 0
    if AFRP.DB.Phrases then
        for _ in pairs(AFRP.DB.Phrases) do n = n + 1 end
    end
    return n
end

SLASH_AFRP1 = "/afrp"
SlashCmdList["AFRP"] = function(msg)
    msg = string.lower(string.trim(msg or ""))
    AscensionFR_PersoDB = AscensionFR_PersoDB or {}
    if msg == "off" then
        AscensionFR_PersoDB.enabled = false
        print("|cff0099ffAscensionFR Perso|r : désactivé.")
        return
    end
    if msg == "on" then
        AscensionFR_PersoDB.enabled = true
        print("|cff0099ffAscensionFR Perso|r : activé.")
        return
    end
    print(string.format(
        "|cff0099ffAscensionFR Perso|r %s — %d phrase(s), %s. /afrp on|off",
        AFRP.VERSION, CompterPhrases(), Actif() and "actif" or "inactif"))
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function()
    AscensionFR_PersoDB = AscensionFR_PersoDB or { enabled = true }
    print(string.format(
        "|cff0099ffAscensionFR Perso|r %s chargé (%d phrases). /afrp",
        AFRP.VERSION, CompterPhrases()))
end)
