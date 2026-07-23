-- Traduction française des addons des AUTRES (DragonUI est le premier).
--
-- POURQUOI PAS LEUR PROPRE FICHIER frFR.lua
-- ----------------------------------------
-- Ces addons ont souvent un fichier français, mais AceLocale ne charge une
-- langue que si le CLIENT est dans cette langue :
--     if locale ~= gameLocale and not isDefault then return end
-- Le client d'Ascension est anglais : leur frFR.lua ne sera JAMAIS lu, quel
-- que soit son contenu. On écrit donc dans leur table VIVANTE. Aucun de leurs
-- fichiers n'est modifié : leurs mises à jour n'effacent rien.
--
-- POURQUOI C'EST SANS DANGER
-- --------------------------
-- Aucune variable globale n'est écrite ici. C'est l'écriture de globales qui
-- a bloqué les sorts en combat pendant cinq versions (voir InterfaceUI.lua).
-- On n'écrit que dans une table appartenant à AceLocale, que le code sécurisé
-- de Blizzard ne lit jamais. Tout passe par pcall : si l'addon visé change ou
-- disparaît, il ne se passe simplement rien.
--
-- POUR AJOUTER UN AUTRE ADDON : rien à coder. Il suffit qu'une table de plus
-- apparaisse dans AFR.DB.AddonsTiers, nommée comme son application AceLocale.

local AFR = AscensionFR

-- Traduire l'addon d'un autre auteur ne doit jamais être imposé : le joueur
-- peut refuser depuis /afr. La clé n'existe que s'il a DÉCOCHÉ — absence =
-- activé, donc rien à cocher pour en profiter.
local REGLAGE = {
    DragonUI = "dragonTradOff",
    DragonUI_Options = "dragonTradOff",
}

local function Refuse(app)
    local cle = REGLAGE[app]
    if not cle then return false end
    local options = AscensionFRSaved and AscensionFRSaved.Options
    return (options and options[cle]) and true or false
end

local traites = {}

local function AceLocale()
    if not LibStub or type(LibStub.GetLibrary) ~= "function" then return end
    local ok, lib = pcall(LibStub.GetLibrary, LibStub, "AceLocale-3.0", true)
    if ok then return lib end
end

-- Injecte une application, si son addon est chargé et pas déjà fait.
local function Injecter(app)
    if traites[app] or Refuse(app) then return end
    local textes = AFR.DB.AddonsTiers[app]
    if type(textes) ~= "table" or not next(textes) then return end

    local lib = AceLocale()
    if not lib then return end

    -- NewLocale(app, "enUS") SANS le drapeau isDefault : on obtient le proxy
    -- d'écriture, qui REMPLACE les valeurs déjà posées. Avec isDefault=true,
    -- AceLocale refuserait d'écraser l'anglais — c'est exactement pour cette
    -- raison qu'on ne le passe pas.
    local ok, L = pcall(lib.NewLocale, lib, app, "enUS")
    if not ok or not L then return end

    local n = 0
    for anglais, francais in pairs(textes) do
        L[anglais] = francais
        n = n + 1
    end

    traites[app] = true
    if AFR.Debug then AFR.Debug(app, ":", n, "textes en français") end
end

local function Tenter()
    for app in pairs(AFR.DB.AddonsTiers) do
        if IsAddOnLoaded and IsAddOnLoaded(app) then Injecter(app) end
    end
end

local cadre = CreateFrame("Frame")
cadre:RegisterEvent("ADDON_LOADED")
cadre:SetScript("OnEvent", function(self, event, nom)
    if nom and AFR.DB.AddonsTiers[nom] then Injecter(nom) end
end)

-- Les addons chargés AVANT nous ont déjà passé leur ADDON_LOADED : on les
-- rattrape tout de suite. Les deux ordres de chargement sont donc couverts.
Tenter()
