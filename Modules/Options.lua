-- ============================================================================
-- AscensionFR_Perso — panneau options (/afrp)
-- Style launcher sombre / or, 3.3.5 compatible
-- ============================================================================
local AFRP = AscensionFR_Perso

local cadre

local OR = { 0.94, 0.76, 0.29 }
local MUTE = { 0.55, 0.58, 0.62 }
local TEXTE = { 0.92, 0.93, 0.95 }

local function Compter()
    local n = 0
    if AFRP.DB and AFRP.DB.Phrases then
        for _ in pairs(AFRP.DB.Phrases) do n = n + 1 end
    end
    return n
end

local function OfficielCharge()
    return type(IsAddOnLoaded) == "function" and IsAddOnLoaded("AscensionFR")
end

local function Ligne(parent, y, label, valeur)
    local l = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    l:SetPoint("TOPLEFT", 28, y)
    l:SetText(label)
    l:SetTextColor(MUTE[1], MUTE[2], MUTE[3])
    local v = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    v:SetPoint("TOPRIGHT", -28, y)
    v:SetJustifyH("RIGHT")
    v:SetText(valeur or "—")
    return v
end

local function Separateur(parent, y)
    local t = parent:CreateTexture(nil, "ARTWORK")
    t:SetPoint("TOPLEFT", 24, y)
    t:SetPoint("TOPRIGHT", -24, y)
    t:SetHeight(1)
    t:SetTexture("Interface\\Buttons\\WHITE8X8")
    t:SetVertexColor(OR[1], OR[2], OR[3], 0.35)
    return t
end

local function BoutonOr(parent, texte, w)
    local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
    b:SetWidth(w or 120)
    b:SetHeight(26)
    b:SetText(texte)
    return b
end

local function Rafraichir()
    if not cadre then return end
    local on = AFRP.Actif and AFRP.Actif()
    cadre.valVersion:SetText("v" .. (AFRP.VERSION or "?"))
    cadre.valStatut:SetText(on and "|cff3dd68cActif|r" or "|cffff6b6bInactif|r")
    cadre.valPhrases:SetText(tostring(Compter()))
    cadre.valOfficiel:SetText(OfficielCharge()
        and "|cff5eb1ffDetecte — pas de conflit|r"
        or "|cff8a929cNon charge (optionnel)|r")
    if cadre.btnToggle then
        cadre.btnToggle:SetText(on and "Desactiver l'overlay" or "Activer l'overlay")
    end
end

local function Creer()
    if cadre then return cadre end

    local f = CreateFrame("Frame", "AscensionFR_PersoOptions", UIParent)
    f:SetWidth(420)
    f:SetHeight(340)
    f:SetPoint("CENTER")
    f:SetFrameStrata("DIALOG")
    f:SetToplevel(true)
    f:SetMovable(true)
    f:EnableMouse(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:SetBackdrop({
        bgFile = "Interface\\Buttons\\WHITE8X8",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 16,
        insets = { left = 3, right = 3, top = 3, bottom = 3 },
    })
    f:SetBackdropColor(0.05, 0.06, 0.08, 0.97)
    f:SetBackdropBorderColor(OR[1], OR[2], OR[3], 0.95)
    f:Hide()
    tinsert(UISpecialFrames, "AscensionFR_PersoOptions")

    -- Bandeau titre
    local header = f:CreateTexture(nil, "ARTWORK")
    header:SetPoint("TOPLEFT", 4, -4)
    header:SetPoint("TOPRIGHT", -4, -4)
    header:SetHeight(52)
    header:SetTexture("Interface\\Buttons\\WHITE8X8")
    header:SetVertexColor(0.08, 0.09, 0.11, 1)

    local accent = f:CreateTexture(nil, "OVERLAY")
    accent:SetPoint("TOPLEFT", header, "BOTTOMLEFT", 0, 0)
    accent:SetPoint("TOPRIGHT", header, "BOTTOMRIGHT", 0, 0)
    accent:SetHeight(2)
    accent:SetTexture("Interface\\Buttons\\WHITE8X8")
    accent:SetVertexColor(OR[1], OR[2], OR[3], 1)

    local titre = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    titre:SetPoint("TOPLEFT", 20, -14)
    titre:SetText("|cff0099ffAscensionFR|r |cfff0c14bPerso|r")

    local sous = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    sous:SetPoint("TOPLEFT", 20, -34)
    sous:SetText("Overlay FR professionnel — survit aux maj officielles")
    sous:SetTextColor(MUTE[1], MUTE[2], MUTE[3])

    local x = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    x:SetPoint("TOPRIGHT", -2, -2)

    -- Infos
    f.valVersion = Ligne(f, -72, "VERSION", "—")
    f.valStatut = Ligne(f, -96, "STATUT", "—")
    Separateur(f, -118)
    f.valPhrases = Ligne(f, -136, "PHRASES OVERLAY", "—")
    f.valOfficiel = Ligne(f, -160, "ASCENSIONFR OFFICIEL", "—")
    Separateur(f, -182)

    local aide = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    aide:SetPoint("TOPLEFT", 28, -200)
    aide:SetPoint("RIGHT", -28, 0)
    aide:SetJustifyH("LEFT")
    aide:SetSpacing(3)
    aide:SetText("Perso complete AscensionFR sans ecraser ses fichiers. Ajoute tes corrects dans DB/Phrases.lua, mets a jour via le Compagnon apres ta session.")
    aide:SetTextColor(0.72, 0.75, 0.78)

    -- Actions
    local btnToggle = BoutonOr(f, "Activer l'overlay", 160)
    btnToggle:SetPoint("BOTTOMLEFT", 24, 52)
    btnToggle:SetScript("OnClick", function()
        AscensionFR_PersoDB = AscensionFR_PersoDB or {}
        AscensionFR_PersoDB.enabled = not (AFRP.Actif and AFRP.Actif())
        Rafraichir()
        DEFAULT_CHAT_FRAME:AddMessage("|cff0099ffAscensionFR Perso|r : "
            .. ((AFRP.Actif and AFRP.Actif()) and "active." or "desactive."))
    end)
    f.btnToggle = btnToggle

    local btnReload = BoutonOr(f, "Reload UI", 100)
    btnReload:SetPoint("LEFT", btnToggle, "RIGHT", 8, 0)
    btnReload:SetScript("OnClick", function() ReloadUI() end)

    local btnClose = BoutonOr(f, "Fermer", 90)
    btnClose:SetPoint("BOTTOMRIGHT", -24, 52)
    btnClose:SetScript("OnClick", function() f:Hide() end)

    local pied = f:CreateFontString(nil, "OVERLAY", "GameFontDisableSmall")
    pied:SetPoint("BOTTOM", 0, 18)
    pied:SetText("/afrp  ·  /afrp on|off  ·  /afrp status")
    pied:SetTextColor(MUTE[1], MUTE[2], MUTE[3])

    cadre = f
    return f
end

function AFRP.OuvrirOptions()
    local f = Creer()
    Rafraichir()
    f:Show()
    PlaySound("igMainMenuOpen")
end

AFRP.RafraichirOptions = Rafraichir
