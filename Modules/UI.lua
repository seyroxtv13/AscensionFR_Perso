-- ============================================================================
-- AscensionFR_Perso — traduction UI (phrases exactes)
-- Remplace ligne par ligne via SetText. Ne touche jamais aux |T (icônes).
-- ============================================================================

local AFRP = AscensionFR_Perso

local function Traduire(texte)
    if not texte or texte == "" then return nil end
    if string.find(texte, "|T", 1, true) then return nil end
    local phrases = AFRP.DB and AFRP.DB.Phrases
    if not phrases then return nil end
    return phrases[texte]
end

local enCours = false

local function AppliquerZone(zone)
    if not zone or type(zone.GetText) ~= "function" then return end
    if not AFRP.Actif or not AFRP.Actif() then return end
    local texte = zone:GetText()
    local fr = Traduire(texte)
    if fr and fr ~= texte and type(zone.SetText) == "function" then
        enCours = true
        zone:SetText(fr)
        enCours = false
    end
end

local function TraduireBulle(bulle)
    if enCours or not bulle or type(bulle.NumLines) ~= "function" then return end
    if not AFRP.Actif or not AFRP.Actif() then return end
    local nom = bulle.GetName and bulle:GetName()
    if not nom then return end
    for i = 1, bulle:NumLines() do
        AppliquerZone(_G[nom .. "TextLeft" .. i])
        AppliquerZone(_G[nom .. "TextRight" .. i])
    end
end

for _, bulle in ipairs({ GameTooltip, ItemRefTooltip, ShoppingTooltip1,
                         ShoppingTooltip2, WorldMapTooltip }) do
    if bulle then
        if bulle.HookScript then
            bulle:HookScript("OnShow", function(self) TraduireBulle(self) end)
        end
        hooksecurefunc(bulle, "Show", function(self) TraduireBulle(self) end)
    end
end

local function AccrocherSetText(fs)
    if not fs or fs.__afrp_hooked then return end
    if type(fs.SetText) ~= "function" then return end
    fs.__afrp_hooked = true
    hooksecurefunc(fs, "SetText", function(self, texte)
        if enCours then return end
        if not AFRP.Actif or not AFRP.Actif() then return end
        local fr = Traduire(texte)
        if fr and fr ~= texte then
            enCours = true
            self:SetText(fr)
            enCours = false
        end
    end)
end

local function AccrocherCadre(cadre, profondeur)
    if not cadre or (profondeur or 0) > 8 then return end
    if type(cadre.GetRegions) == "function" then
        local regions = { cadre:GetRegions() }
        for i = 1, #regions do
            local r = regions[i]
            if r and r.GetObjectType and r:GetObjectType() == "FontString" then
                AccrocherSetText(r)
                AppliquerZone(r)
            end
        end
    end
    if type(cadre.GetChildren) == "function" then
        local kids = { cadre:GetChildren() }
        for i = 1, #kids do
            AccrocherCadre(kids[i], (profondeur or 0) + 1)
        end
    end
end

local CIBLES = {
    "CharacterFrame",
    "PaperDollFrame",
    "CharacterStatsPane",
    "InspectFrame",
    "ItemSocketingFrame",
    "ContainerFrame1",
    "MerchantFrame",
    "AuctionFrame",
    "TradeSkillFrame",
}

local function AccrocherCibles()
    for _, nom in ipairs(CIBLES) do
        local f = _G[nom]
        if f then AccrocherCadre(f, 0) end
    end
end

local balayage = CreateFrame("Frame")
local ecoule, tours = 0, 0
balayage:RegisterEvent("PLAYER_LOGIN")
balayage:RegisterEvent("ADDON_LOADED")
balayage:SetScript("OnEvent", function(_, evt, nom)
    if evt == "ADDON_LOADED" then
        AccrocherCibles()
        return
    end
    if evt == "PLAYER_LOGIN" then
        AccrocherCibles()
        balayage:SetScript("OnUpdate", function(self, delta)
            ecoule = ecoule + delta
            if ecoule < 2 then return end
            ecoule = 0
            tours = tours + 1
            AccrocherCibles()
            if tours > 15 then
                self:SetScript("OnUpdate", function(_, d)
                    ecoule = ecoule + d
                    if ecoule < 10 then return end
                    ecoule = 0
                    AccrocherCibles()
                end)
            end
        end)
    end
end)

AFRP.Traduire = Traduire
AFRP.AccrocherCibles = AccrocherCibles
