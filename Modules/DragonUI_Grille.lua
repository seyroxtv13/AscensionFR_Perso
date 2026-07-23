-- Confort d'édition pour l'addon tiers DragonUI :
--   1. une ligne VERTE tous les 5 carreaux, pour se repérer ;
--   2. l'AIMANTATION des cadres sur la grille, pour être sûr d'être aligné.
--
-- Comme pour la traduction ([[AddonsTiers.lua]]), aucun fichier de DragonUI
-- n'est modifié : ses mises à jour n'effacent donc rien. Tout est enveloppé
-- dans des pcall — si DragonUI change ou disparaît, il ne se passe rien.
--
-- POURQUOI CE N'EST PAS SI SIMPLE
-- -------------------------------
-- DragonUI a PLUSIEURS façons de déplacer un cadre (core/movers.lua, mais
-- surtout CreateUIFrame dans core/api.lua, plus des gestionnaires propres à
-- chaque module). Patcher un seul chemin ne suffit pas : on s'accroche donc
-- à son REGISTRE `EditableFrames`, qui les rassemble tous.

local AFR = AscensionFR
local CIBLE = "DragonUI"

local TOUS_LES = 5      -- une ligne verte tous les N carreaux
local CARREAU = 32      -- même valeur que DragonUI

-- Le joueur peut refuser cette fonction depuis /afr. La clé n'existe que s'il
-- a DÉCOCHÉ — absence = activé, donc rien à cocher pour en profiter. On relit
-- le réglage à CHAQUE lâcher plutôt qu'une fois au chargement : décocher rend
-- ainsi la main tout de suite, sans /reload.
local function Actif()
    local options = AscensionFRSaved and AscensionFRSaved.Options
    return not (options and options.dragonGrilleOff)
end

local branche = false
local enveloppes = {}

-- Pas EXACT entre deux lignes. Recopié du calcul de DragonUI : il étire les
-- carreaux pour que la grille reste symétrique (33,75 px de haut en 1080p,
-- pas 32). Aimanter sur 32 fixe poserait les cadres À CÔTÉ des lignes
-- affichées, avec un écart qui grandit vers les bords.
local function Pas()
    local largeur, hauteur = GetScreenWidth(), GetScreenHeight()
    if not largeur or not hauteur then return end
    local demiL = math.floor((largeur / 2) / CARREAU)
    local demiH = math.floor((hauteur / 2) / CARREAU)
    if demiL < 1 or demiH < 1 then return end
    return largeur / (demiL * 2), hauteur / (demiH * 2), demiL, demiH
end

-- Décalage à appliquer sur UN axe pour coller le bord le plus proche d'une
-- ligne. On mesure les deux bords et on garde la plus petite correction :
-- on peut ainsi aligner aussi bien un bord gauche qu'un bord droit, selon
-- celui qu'on a amené près de la ligne.
local function Correction(bordA, bordB, pas)
    local dA = math.floor(bordA / pas + 0.5) * pas - bordA
    local dB = math.floor(bordB / pas + 0.5) * pas - bordB
    if math.abs(dA) <= math.abs(dB) then return dA end
    return dB
end

-- Aimante sur les BORDS, pas sur le centre. Aimanter le centre paraissait
-- logique, mais un cadre dont la largeur n'est pas un multiple du carreau a
-- alors ses quatre coins entre deux lignes — donc jamais alignable sur la
-- grille. En collant le bord le plus proche de chaque axe, un COIN du cadre
-- tombe toujours pile sur une intersection.
--
-- ON NE TOUCHE JAMAIS À L'ANCRAGE, on décale seulement ses coordonnées.
-- La première version réancrait le cadre sur le coin bas-gauche d'UIParent.
-- DragonUI mesurait alors une coordonnée « depuis le coin » et l'enregistrait
-- dans un champ qui attend « depuis le centre » : au /reload, tout se
-- retrouvait décalé d'une demi-largeur d'écran, donc hors de l'écran.
-- En gardant l'ancrage d'origine, ce décalage devient impossible : DragonUI
-- relit exactement le type d'ancrage qu'il avait posé.
local function Aimanter(cadre)
    if not Actif() then return end
    local pasX, pasY = Pas()
    if not pasX or type(cadre) ~= "table" then return end
    if type(cadre.GetNumPoints) ~= "function" then return end

    -- Un cadre à PLUSIEURS ancrages tire sa TAILLE de ses points (TOPLEFT +
    -- BOTTOMRIGHT, par exemple). Y toucher le réduirait à rien — c'est ce qui
    -- faisait « disparaître » des cadres. On les laisse tranquilles.
    if cadre:GetNumPoints() ~= 1 then return end

    local point, relatif, pointRelatif, ox, oy = cadre:GetPoint(1)
    if not point or type(ox) ~= "number" or type(oy) ~= "number" then return end

    local gauche, droite = cadre:GetLeft(), cadre:GetRight()
    local bas, haut = cadre:GetBottom(), cadre:GetTop()
    if not (gauche and droite and bas and haut) then return end

    -- Le pas vient de GetScreenWidth(), donc exprimé dans l'échelle d'UIParent,
    -- alors que les bords et les décalages sont dans celle du cadre. DragonUI
    -- pose des échelles personnalisées : sans cette conversion, l'aimant
    -- viserait à côté sur tout cadre mis à l'échelle.
    local mienne = cadre:GetEffectiveScale() or 1
    local sienne = UIParent:GetEffectiveScale() or 1
    if mienne <= 0 or sienne <= 0 then return end
    local rapport = mienne / sienne

    local dx = Correction(gauche * rapport, droite * rapport, pasX)
    local dy = Correction(bas * rapport, haut * rapport, pasY)
    if dx == 0 and dy == 0 then return end

    cadre:SetPoint(point, relatif, pointRelatif,
                   ox + dx / rapport, oy + dy / rapport)
end

-- Enveloppe le lâcher d'un cadre. L'ORDRE est tout : on fige le déplacement,
-- on aimante, PUIS on rend la main à DragonUI. Il mesure alors la position
-- déjà aimantée et c'est celle-là qu'il enregistre. Aimanter APRÈS lui ferait
-- enregistrer l'ancienne : au /reload, tout aurait glissé.
local function Envelopper(cadre)
    if not Actif() then return end
    if type(cadre) ~= "table" or enveloppes[cadre] then return end
    if type(cadre.GetScript) ~= "function" then return end
    local ancien = cadre:GetScript("OnDragStop")
    if not ancien then return end
    enveloppes[cadre] = true
    cadre:SetScript("OnDragStop", function(self, ...)
        pcall(function()
            self:StopMovingOrSizing()
            Aimanter(self)
        end)
        return ancien(self, ...)
    end)
    return true
end

-- Repeint une ligne sur cinq en vert, comptées DEPUIS LE CENTRE pour que les
-- deux moitiés de l'écran se répondent — comme la ligne rouge centrale.
local function ColorerGrille()
    if not Actif() then return 0 end
    local grille = _G["DragonUIGridOverlay"]
    if not grille or type(grille.GetRegions) ~= "function" then return 0 end
    local _, _, demiL, demiH = Pas()
    if not demiL then return 0 end
    local n = 0
    for i = 1, select("#", grille:GetRegions()) do
        local zone = select(i, grille:GetRegions())
        local nom = zone and zone.GetName and zone:GetName()
        local axe, rang = nil, nil
        if nom then axe, rang = string.match(nom, "^DragonUIGrid([VH])(%d+)$") end
        if axe then
            rang = tonumber(rang)
            local centre = (axe == "V") and demiL or demiH
            -- La ligne centrale reste rouge : on ne touche qu'aux autres.
            if rang ~= centre and (rang - centre) % TOUS_LES == 0 then
                zone:SetTexture(0, 1, 0, 0.5)
                n = n + 1
            end
        end
    end
    return n
end

-- Les registres de DragonUI ne suffisent PAS : le jet de butin, le suivi de
-- quête, les boutons de minimap et les barres d'incantation ont chacun leur
-- propre gestionnaire de déplacement, hors de `EditableFrames`. Plutôt que de
-- courir après une dizaine de modules — et de rater ceux ajoutés demain — on
-- ramasse les cadres DÉPLAÇABLES pendant que le mode édition est ouvert :
-- c'est précisément l'ensemble qu'on vise, et rien d'autre ne l'est à ce
-- moment-là.
local function Parcourir(parent, profondeur)
    local n = 0
    if profondeur > 2 or type(parent.GetChildren) ~= "function" then
        return n
    end
    local ok, enfants = pcall(function() return {parent:GetChildren()} end)
    if not ok then return n end
    for _, enfant in ipairs(enfants) do
        if type(enfant) == "table" and type(enfant.IsMovable) == "function" then
            local peut, mobile = pcall(enfant.IsMovable, enfant)
            if peut and mobile and Envelopper(enfant) then
                n = n + 1
            end
            n = n + Parcourir(enfant, profondeur + 1)
        end
    end
    return n
end

-- Appelé à chaque ouverture du mode édition : la grille n'existe qu'à ce
-- moment-là, et de nouveaux cadres ont pu apparaître entre-temps.
local function Equiper()
    local D = _G[CIBLE]
    if type(D) ~= "table" then return end

    local lignes = ColorerGrille()
    local cadres = 0

    -- 1) Les registres connus — les plus sûrs, on commence par eux.
    if type(D.EditableFrames) == "table" then
        for _, donnees in pairs(D.EditableFrames) do
            if type(donnees) == "table" and Envelopper(donnees.frame) then
                cadres = cadres + 1
            end
        end
    end
    if type(D.Movers) == "table" and type(D.Movers.created) == "table" then
        for nom in pairs(D.Movers.created) do
            if Envelopper(_G["DragonUI_Mover_" .. tostring(nom)]) then
                cadres = cadres + 1
            end
        end
    end

    -- 2) Le ratissage, pour tout le reste. Envelopper() ignore les cadres
    --    déjà pris et ceux sans gestionnaire de lâcher : aucun doublon.
    cadres = cadres + Parcourir(UIParent, 1)

    if AFR.Debug then
        AFR.Debug("DragonUI grille :", lignes, "lignes vertes,", cadres,
                  "nouveaux cadres aimantés")
    end
end

local function Brancher()
    if branche then return end
    local D = _G[CIBLE]
    if type(D) ~= "table" or type(D.EditorMode) ~= "table" then return end
    if type(D.EditorMode.Show) ~= "function" then return end
    branche = true
    -- hooksecurefunc : on s'ajoute APRÈS sa fonction sans la remplacer.
    hooksecurefunc(D.EditorMode, "Show", Equiper)
    -- Si le mode édition est déjà ouvert, on ne l'attend pas.
    if type(D.EditorMode.IsActive) == "function" and D.EditorMode:IsActive() then
        Equiper()
    end
end

local cadre = CreateFrame("Frame")
cadre:RegisterEvent("ADDON_LOADED")
cadre:SetScript("OnEvent", function(self, event, nom)
    if nom == CIBLE then
        pcall(Brancher)
        if branche then self:UnregisterEvent("ADDON_LOADED") end
    end
end)

if IsAddOnLoaded and IsAddOnLoaded(CIBLE) then
    pcall(Brancher)
end
