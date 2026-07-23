-- AscensionFR_Perso - noyau
AscensionFR_Perso = AscensionFR_Perso or {}
local AFRP = AscensionFR_Perso

local function trim(s)
    return (string.gsub(s or "", "^%s*(.-)%s*$", "%1"))
end

AFRP.VERSION = GetAddOnMetadata("AscensionFR_Perso", "Version") or "0.3.0"
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

local function Cmd(msg)
    msg = string.lower(trim(msg))
    AscensionFR_PersoDB = AscensionFR_PersoDB or {}
    if msg == "off" then
        AscensionFR_PersoDB.enabled = false
        DEFAULT_CHAT_FRAME:AddMessage("|cff0099ffAscensionFR Perso|r : desactive.")
        if AFRP.RafraichirOptions then AFRP.RafraichirOptions() end
        return
    end
    if msg == "on" then
        AscensionFR_PersoDB.enabled = true
        DEFAULT_CHAT_FRAME:AddMessage("|cff0099ffAscensionFR Perso|r : active.")
        if AFRP.RafraichirOptions then AFRP.RafraichirOptions() end
        return
    end
    if msg == "status" or msg == "statut" then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cff0099ffAscensionFR Perso|r %s - %d phrase(s), %s.",
            AFRP.VERSION, CompterPhrases(), Actif() and "actif" or "inactif"))
        return
    end
    -- Defaut : ouvre le panneau (si Options charge)
    if AFRP.OuvrirOptions then
        AFRP.OuvrirOptions()
    else
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cff0099ffAscensionFR Perso|r %s - %d phrase(s), %s. /afrp on|off",
            AFRP.VERSION, CompterPhrases(), Actif() and "actif" or "inactif"))
    end
end

SLASH_AFRP1 = "/afrp"
SLASH_AFRP2 = "/afrperso"
SlashCmdList["AFRP"] = Cmd

local boot = CreateFrame("Frame")
boot:RegisterEvent("ADDON_LOADED")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self, event, nom)
    if event == "ADDON_LOADED" then
        if nom ~= "AscensionFR_Perso" then return end
        AscensionFR_PersoDB = AscensionFR_PersoDB or { enabled = true }
        SLASH_AFRP1 = "/afrp"
        SLASH_AFRP2 = "/afrperso"
        SlashCmdList["AFRP"] = Cmd
        return
    end
    if event == "PLAYER_LOGIN" then
        DEFAULT_CHAT_FRAME:AddMessage(string.format(
            "|cff0099ffAscensionFR Perso|r %s pret (%d phrases). /afrp",
            AFRP.VERSION, CompterPhrases()))
        self:UnregisterEvent("PLAYER_LOGIN")
    end
end)
