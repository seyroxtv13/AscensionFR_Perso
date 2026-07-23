-- Panneau options /afrp (WoW 3.3.5)
local AFRP = AscensionFR_Perso

local cadre

local function Compter()
    local n = 0
    if AFRP.DB and AFRP.DB.Phrases then
        for _ in pairs(AFRP.DB.Phrases) do n = n + 1 end
    end
    return n
end

local function Rafraichir()
    if not cadre then return end
    local on = AFRP.Actif and AFRP.Actif()
    cadre.statut:SetText(on and "|cff3dd68cActif|r" or "|cffff6b6bInactif|r")
    cadre.phrases:SetText(Compter() .. " phrases overlay")
    cadre.version:SetText("v" .. (AFRP.VERSION or "?"))
    if cadre.btnToggle then
        cadre.btnToggle:SetText(on and "Desactiver" or "Activer")
    end
end

local function Creer()
    if cadre then return cadre end

    local f = CreateFrame("Frame", "AscensionFR_PersoOptions", UIParent)
    f:SetWidth(360)
    f:SetHeight(220)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 16, edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 },
    })
    f:SetBackdropBorderColor(0.94, 0.76, 0.29, 0.9)
    f:Hide()
    tinsert(UISpecialFrames, "AscensionFR_PersoOptions")

    local titre = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titre:SetPoint("TOP", 0, -16)
    titre:SetText("|cff0099ffAscensionFR|r |cfff0c14bPerso|r")

    local sous = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sous:SetPoint("TOP", titre, "BOTTOM", 0, -4)
    sous:SetText("Overlay FR — complete AscensionFR, dossiers separes")
    sous:SetTextColor(0.7, 0.72, 0.75)

    f.version = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.version:SetPoint("TOPLEFT", 24, -58)
    f.statut = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    f.statut:SetPoint("LEFT", f.version, "RIGHT", 16, 0)
    f.phrases = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.phrases:SetPoint("TOPLEFT", 24, -82)

    local note = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    note:SetPoint("TOPLEFT", 24, -108)
    note:SetPoint("RIGHT", -24, 0)
    note:SetJustifyH("LEFT")
    note:SetText("Pas de conflit avec AscensionFR officiel : Perso n'ecrit que ses propres phrases (ex. Agility, Haste Rating). Les maj officielles n'effacent pas Perso.")
    note:SetTextColor(0.75, 0.78, 0.82)

    local btnToggle = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnToggle:SetWidth(110)
    btnToggle:SetHeight(24)
    btnToggle:SetPoint("BOTTOMLEFT", 24, 24)
    btnToggle:SetScript("OnClick", function()
        AscensionFR_PersoDB = AscensionFR_PersoDB or {}
        local on = AFRP.Actif and AFRP.Actif()
        AscensionFR_PersoDB.enabled = not on
        Rafraichir()
    end)
    f.btnToggle = btnToggle

    local btnClose = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
    btnClose:SetWidth(80)
    btnClose:SetHeight(24)
    btnClose:SetPoint("BOTTOMRIGHT", -24, 24)
    btnClose:SetText("Fermer")
    btnClose:SetScript("OnClick", function() f:Hide() end)

    local x = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    x:SetPoint("TOPRIGHT", -4, -4)

    cadre = f
    return f
end

function AFRP.OuvrirOptions()
    local f = Creer()
    Rafraichir()
    f:Show()
end

AFRP.RafraichirOptions = Rafraichir
