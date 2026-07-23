-- Bouton minimap AscensionFR Perso (sans OnUpdate = pas de taint)
local AFRP = AscensionFR_Perso

local ICONE = "Interface\\AddOns\\AscensionFR_Perso\\Media\\icon"

local bouton = CreateFrame("Button", "AscensionFR_PersoMinimap", Minimap)
bouton:SetWidth(32)
bouton:SetHeight(32)
bouton:SetFrameStrata("MEDIUM")
bouton:SetFrameLevel(8)
bouton:EnableMouse(true)
bouton:RegisterForClicks("LeftButtonUp", "RightButtonUp")
-- Pas de drag / OnUpdate : source classique de taint sur 3.3.5

bouton.icon = bouton:CreateTexture(nil, "BACKGROUND")
bouton.icon:SetWidth(20)
bouton.icon:SetHeight(20)
bouton.icon:SetPoint("CENTER", 0, 0)
bouton.icon:SetTexture(ICONE)

bouton.border = bouton:CreateTexture(nil, "OVERLAY")
bouton.border:SetWidth(52)
bouton.border:SetHeight(52)
bouton.border:SetPoint("CENTER", 0, 0)
bouton.border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

local function Placer()
    local angle = (AscensionFR_PersoDB and AscensionFR_PersoDB.minimapAngle) or 220
    local rad = math.rad(angle)
    bouton:ClearAllPoints()
    bouton:SetPoint("CENTER", Minimap, "CENTER", math.cos(rad) * 80, math.sin(rad) * 80)
end

bouton:SetScript("OnClick", function(_, btn)
    if type(InCombatLockdown) == "function" and InCombatLockdown() then
        DEFAULT_CHAT_FRAME:AddMessage("|cffc47030AscensionFR Perso|r : indisponible en combat.")
        return
    end
    if btn == "RightButton" then
        AscensionFR_PersoDB = AscensionFR_PersoDB or {}
        AscensionFR_PersoDB.enabled = not (AFRP.Actif and AFRP.Actif())
        local on = AFRP.Actif and AFRP.Actif()
        DEFAULT_CHAT_FRAME:AddMessage("|cffc47030AscensionFR Perso|r : "
            .. (on and "|cff3dd68cactif|r" or "|cffff6666inactif|r"))
        if AFRP.RafraichirOptions then AFRP.RafraichirOptions() end
    else
        if AFRP.OuvrirOptions then AFRP.OuvrirOptions() end
    end
end)

bouton:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Ascension FR Perso", 0.77, 0.44, 0.19)
    GameTooltip:AddLine("Clic gauche : menu", 1, 1, 1)
    GameTooltip:AddLine("Clic droit : activer / desactiver", 0.7, 0.7, 0.7)
    GameTooltip:Show()
end)
bouton:SetScript("OnLeave", function() GameTooltip:Hide() end)

local boot = CreateFrame("Frame")
boot:RegisterEvent("PLAYER_LOGIN")
boot:RegisterEvent("PLAYER_ENTERING_WORLD")
boot:SetScript("OnEvent", function()
    AscensionFR_PersoDB = AscensionFR_PersoDB or {}
    if AscensionFR_PersoDB.minimapHide then
        bouton:Hide()
    else
        bouton:Show()
        Placer()
    end
end)

-- Visible tout de suite si la minimap existe deja
if Minimap then
    bouton:Show()
    Placer()
end

AFRP.MinimapBouton = bouton
AFRP.MinimapPlacer = Placer
