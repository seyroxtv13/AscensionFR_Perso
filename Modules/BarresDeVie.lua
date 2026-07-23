-- ============================================================================
-- AscensionFR - Barres de vie flottantes (nameplates)
--
-- Le nom affiché au-dessus d'une créature n'est pas une info-bulle ni un cadre
-- d'unité : c'est une « barre de vie flottante », que WoW 3.3.5 n'expose par
-- aucune API. Elles n'ont pas de nom, ne sont pas listables, et le jeu les
-- recycle d'une créature à l'autre.
--
-- Seule méthode possible : repérer ces cadres parmi les enfants de WorldFrame
-- à leur structure (deux enfants dont une barre de statut), puis remplacer le
-- texte du nom. Comme le jeu recycle les cadres, on revérifie régulièrement.
--
-- Contrairement à la cible, on n'a pas l'identifiant de la créature ici : on ne
-- dispose que du nom affiché. La traduction se fait donc par correspondance de
-- texte, via l'index des noms anglais des créatures.
-- ============================================================================
local AFR = AscensionFR

local INTERVALLE = 0.3   -- s. Assez réactif à l'œil, négligeable pour le jeu.

local barres = {}        -- cadres déjà identifiés
local connues = 0        -- nombre d'enfants de WorldFrame au dernier examen
local ecoule = 0

-- ----------------------------------------------------------------------------
-- DÉSACTIVÉ PAR DÉFAUT — le joueur doit cocher la case dans /afr.
--
-- Renommer une barre de vie flottante, c'est écrire sur la surface que TOUS
-- les addons de nameplates se disputent. Vécu deux fois (Trey, puis Trøg) :
-- nous changeons le texte -> Kui_Nameplates le détecte et appelle Hide() ->
-- PlateBuffs écoute Hide() et rappelle Kui_Nameplates -> boucle infinie,
-- « C stack overflow », mémoire saturée, jeu figé.
--
-- Pourquoi une option et pas seulement une détection : on ne peut PAS tester
-- ce cas (ni Dan ni personne ici n'a ces addons), et aucune liste ne peut
-- couvrir les addons de nameplates à venir. Une détection qui rate coûte au
-- joueur sa session ; la fonction désactivée ne coûte que des noms de
-- créatures en anglais. L'échange n'est pas discutable.
--
-- Pour la réactiver : /afr -> « Traduire les noms au-dessus des monstres ».
-- ----------------------------------------------------------------------------

-- Filet pour ceux qui l'activent quand même : on refuse de tourner si un
-- addon de nameplates est là. On vise la BIBLIOTHÈQUE et pas des noms
-- d'addons — c'est LibNameplate-1.0 qui provoque la boucle, et tout addon
-- qui l'utilise déclenchera le même plantage, connu de nous ou non. La liste
-- de noms ne reste qu'en second rideau, pour les rares qui ne passent pas
-- par LibStub.
local ADDONS_CONFLICTUELS = {
    "PlateBuffs",
    "Kui_Nameplates",
    "TidyPlates",
    "Aloft",
    "ElvUI",
}

-- Le résultat ne change pas en cours de partie : on le calcule une fois.
local conflit

local function ConflitNameplate()
    local opt = AscensionFRSaved and AscensionFRSaved.Options
    -- Non cochée = on ne tourne pas. C'est le cas par défaut.
    if not (opt and opt.barresDeVie) then return true end
    if conflit ~= nil then return conflit end

    conflit = false
    if LibStub and type(LibStub.GetLibrary) == "function" then
        local ok, lib = pcall(LibStub.GetLibrary, LibStub,
                              "LibNameplate-1.0", true)
        if ok and lib then conflit = true end
    end
    if not conflit then
        for _, nom in ipairs(ADDONS_CONFLICTUELS) do
            if IsAddOnLoaded(nom) then conflit = true break end
        end
    end
    if conflit then
        AFR.Debug("barres de vie : addon de nameplates détecté, on n'y touche pas.")
    end
    return conflit
end

-- Une barre de vie flottante : cadre sans nom, deux enfants, dont le second
-- est une barre de statut (la barre de conjuration).
local function EstBarreDeVie(cadre)
    if cadre:GetName() then return false end
    if cadre:GetNumChildren() ~= 2 then return false end
    local _, second = cadre:GetChildren()
    if not second or type(second.GetObjectType) ~= "function" then
        return false
    end
    return second:GetObjectType() == "StatusBar"
end

-- Retrouve la zone de texte du nom parmi les régions du cadre.
local function ZoneDuNom(cadre)
    local regions = { cadre:GetRegions() }
    for _, region in ipairs(regions) do
        if region and region.GetObjectType
            and region:GetObjectType() == "FontString" then
            local texte = region:GetText()
            -- Le premier texte non numérique est le nom ; le niveau est un
            -- nombre, on l'écarte.
            if texte and texte ~= "" and not tonumber(texte) then
                return region
            end
        end
    end
    return nil
end

local function TraduireBarre(cadre)
    if AFR.EstProtege(cadre) then return end
    local zone = cadre.AscensionFR_nom
    if not zone then
        zone = ZoneDuNom(cadre)
        if not zone then return end
        cadre.AscensionFR_nom = zone
    end
    local texte = zone:GetText()
    if not texte or texte == "" then return end
    -- Déjà traduit ? On évite de retraduire à chaque passage.
    if texte == cadre.AscensionFR_dernier then return end

    local c = AFR.CreatureParNomEN(texte)
    local fr = c and c.N
    if not fr then
        fr = AFR.DB.Divers[texte]
    end
    if fr and fr ~= texte then
        zone:SetText(fr)
        cadre.AscensionFR_dernier = fr
    else
        cadre.AscensionFR_dernier = texte
    end
end

local function Examiner()
    -- WorldFrame gagne un enfant à chaque nouvelle barre affichée : tant que
    -- le compte ne bouge pas, inutile de tout reparcourir.
    local nb = WorldFrame:GetNumChildren()
    if nb ~= connues then
        connues = nb
        local enfants = { WorldFrame:GetChildren() }
        for _, enfant in ipairs(enfants) do
            if not barres[enfant] and EstBarreDeVie(enfant) then
                barres[enfant] = true
            end
        end
    end
    for cadre in pairs(barres) do
        if cadre:IsShown() then TraduireBarre(cadre) end
    end
end

local frame = CreateFrame("Frame")
frame:SetScript("OnUpdate", function(self, delta)
    if not AFR.Actif() or ConflitNameplate() then return end
    ecoule = ecoule + delta
    if ecoule < INTERVALLE then return end
    ecoule = 0
    local ok, err = pcall(Examiner)
    if not ok then
        AFR.Debug("barres de vie :", err)
        self:SetScript("OnUpdate", nil)   -- ne jamais spammer une erreur
    end
end)
