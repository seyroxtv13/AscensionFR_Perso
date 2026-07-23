-- ============================================================================
-- PersoBoot — /afrp, surcharge Phrases, alerte si AscensionFR encore actif
-- ============================================================================
local AFRP = AscensionFR_Perso

local _actif = AFRP.Actif
function AFRP.Actif()
    local db = AscensionFR_PersoDB
    if db and db.enabled == false then return false end
    if type(_actif) == "function" then return _actif() end
    return true
end

if AFRP.DB and AFRP.DB.Phrases and AFRP.DB.Divers then
    for en, fr in pairs(AFRP.DB.Phrases) do
        AFRP.DB.Divers[en] = fr
    end
end

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:SetScript("OnEvent", function(self)
    self:UnregisterEvent("PLAYER_LOGIN")
    AscensionFR_PersoDB = AscensionFR_PersoDB or { enabled = true }
    if AscensionFR_PersoDB.enabled == nil then
        AscensionFR_PersoDB.enabled = true
    end
    if type(IsAddOnLoaded) == "function" and IsAddOnLoaded("AscensionFR") then
        DEFAULT_CHAT_FRAME:AddMessage(
            "|cffc47030AscensionFR Perso|r : desactive AscensionFR (Esc > AddOns) pour eviter les conflits.")
    end
    if AscensionFR_PersoDB.msgLogin ~= false then
        local ver = GetAddOnMetadata("AscensionFR_Perso", "Version") or "?"
        DEFAULT_CHAT_FRAME:AddMessage("|cffc47030AscensionFR Perso|r " .. ver .. " pret. /afrp")
    end
end)

SLASH_AFRP1 = "/afrp"
SLASH_AFRP2 = "/afrperso"
SlashCmdList["AFRP"] = function(msg)
    msg = string.lower(string.gsub(msg or "", "^%s*(.-)%s*$", "%1"))
    AscensionFR_PersoDB = AscensionFR_PersoDB or {}
    if msg == "off" then
        AscensionFR_PersoDB.enabled = false
        DEFAULT_CHAT_FRAME:AddMessage("|cffc47030AscensionFR Perso|r : desactive.")
        return
    end
    if msg == "on" then
        AscensionFR_PersoDB.enabled = true
        if AscensionFR_PersoDB.Options then AscensionFR_PersoDB.Options.desactive = nil end
        DEFAULT_CHAT_FRAME:AddMessage("|cffc47030AscensionFR Perso|r : active.")
        return
    end
    if AFRP.OuvrirOptions then
        AFRP.OuvrirOptions()
    elseif SlashCmdList["ASCENSIONFR"] then
        SlashCmdList["ASCENSIONFR"]("")
    else
        DEFAULT_CHAT_FRAME:AddMessage("|cffc47030AscensionFR Perso|r : /afrp on|off")
    end
end
