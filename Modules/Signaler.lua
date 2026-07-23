-- ============================================================================
-- AscensionFR - Signalements
-- « /afr signaler » (ou une touche, Échap -> Raccourcis clavier) pendant
-- qu'une info-bulle fautive est affichée : l'addon photographie son contenu
-- dans les SavedVariables. Au /reload suivant, le compagnon la diagnostique
-- tout seul (absent des bases ? échec d'alignement ? chaîne du client ?) et
-- écrit son verdict dans traduction\traductions\rapport_signalements.txt.
-- Une capture d'écran devient une touche.
-- ============================================================================
local AFR = AscensionFR

-- Libellés du raccourci clavier (voir Bindings.xml)
BINDING_HEADER_ASCENSIONFR = "Ascension FR"
BINDING_NAME_ASCENSIONFR_SIGNALER = "Signaler le texte survolé"

local MAX_SIGNALEMENTS = 100   -- protège les SavedVariables
local MAX_ECHECS = 200

local function Liste()
    AscensionFRSaved = AscensionFRSaved or {}
    AscensionFRSaved.Signalements = AscensionFRSaved.Signalements or {}
    return AscensionFRSaved.Signalements
end

function AFR.NombreSignalements()
    local l = AscensionFRSaved and AscensionFRSaved.Signalements
    return l and #l or 0
end

local function InfobulleVisible()
    if GameTooltip:IsShown() and GameTooltip:NumLines() > 0 then
        return GameTooltip
    end
    if ItemRefTooltip and ItemRefTooltip:IsShown()
        and ItemRefTooltip:NumLines() > 0 then
        return ItemRefTooltip
    end
end

-- Photographie du cadre sous la souris : chaîne des parents (nom +
-- protection), textes visibles, état du module métiers. C'est l'outil
-- d'enquête pour les fenêtres réécrites par Ascension (vécu : la cuisine,
-- restée anglaise sans que la récolte ne voie rien passer).
local function DecrireCadre()
    if type(GetMouseFocus) ~= "function" then return nil end
    local cadre = GetMouseFocus()
    if not cadre or cadre == WorldFrame then return nil end
    local lignes = {}
    local chaine, c = {}, cadre
    for _ = 1, 8 do
        if not c then break end
        local nom = (c.GetName and c:GetName()) or "(anonyme)"
        if AFR.EstProtege(c) then nom = nom .. " (protégé)" end
        table.insert(chaine, nom)
        c = c.GetParent and c:GetParent()
    end
    table.insert(lignes, "cadre : " .. table.concat(chaine, " < "))
    if cadre.GetRegions then
        for _, r in ipairs({ cadre:GetRegions() }) do
            if r.GetObjectType and r:GetObjectType() == "FontString"
                and r.GetText and r:GetText() and r:GetText() ~= "" then
                table.insert(lignes, "texte : " .. r:GetText())
            end
        end
    end
    table.insert(lignes, "TradeSkillFrame : "
        .. (TradeSkillFrame
            and (TradeSkillFrame:IsShown() and "visible" or "caché")
            or "absent"))
    table.insert(lignes, "GetNumTradeSkills : "
        .. (type(GetNumTradeSkills) == "function"
            and tostring(GetNumTradeSkills() or 0) or "absent"))
    return lignes
end

-- Deux signalements décrivent le même problème s'ils portent sur le même
-- élément : inutile d'encombrer la file.
local function Signature(s)
    return (s.T or "?") .. ":"
        .. tostring(s.ID or (s.L and s.L[1]) or s.N or "")
end

function AFR.Signaler(note)
    local liste = Liste()
    local s = { Q = date("%d/%m/%y %H:%M") }
    if note and strtrim(note) ~= "" then
        s.T, s.N = "note", strtrim(note)
    else
        local tip = InfobulleVisible()
        if tip then
            -- Photographie complète : toutes les lignes, gauche et droite.
            s.L, s.R = {}, {}
            local nomTip = tip:GetName()
            for i = 1, tip:NumLines() do
                local g = _G[nomTip .. "TextLeft" .. i]
                local d = _G[nomTip .. "TextRight" .. i]
                s.L[i] = g and g:GetText() or ""
                s.R[i] = d and d:GetText() or ""
            end
            -- De quoi parle l'info-bulle ? L'ID vaut mieux que le texte.
            if tip.GetItem then
                local _, lien = tip:GetItem()
                local id = AFR.IdDepuisLienObjet(lien)
                if id then s.T, s.ID = "objet", id end
            end
            if not s.T and tip.GetSpell then
                local _, _, id = tip:GetSpell()
                if id then s.T, s.ID = "sort", id end
            end
            if not s.T and tip.GetUnit then
                local _, unite = tip:GetUnit()
                local guid = unite and UnitGUID(unite)
                local id = guid and AFR.IdCreatureDepuisGUID(guid)
                if id then s.T, s.ID = "pnj", id end
            end
            s.T = s.T or "texte"
        else
            -- Pas d'info-bulle : photographie du cadre sous la souris.
            s.L = DecrireCadre()
            if not s.L then
                print("|cff0099ffAscensionFR|r : survolez l'élément fautif "
                    .. "puis utilisez la touche ou /afr signaler. Sans rien "
                    .. "sous la souris : /afr signaler votre remarque.")
                return
            end
            s.T = "cadre"
        end
    end
    local signature = Signature(s)
    for _, existant in ipairs(liste) do
        if Signature(existant) == signature then
            print("|cff0099ffAscensionFR|r : déjà signalé — le compagnon "
                .. "s'en occupera au prochain /reload.")
            return
        end
    end
    if #liste >= MAX_SIGNALEMENTS then
        print("|cff0099ffAscensionFR|r : la file des signalements est "
            .. "pleine ; faites un /reload pour la transmettre au compagnon.")
        return
    end
    table.insert(liste, s)
    if s.T == "cadre" then
        print(string.format(
            "|cff0099ffAscensionFR|r : fenêtre photographiée (%d en "
            .. "attente). Le compagnon l'analysera au prochain /reload.",
            #liste))
    else
        print(string.format(
            "|cff0099ffAscensionFR|r : signalé (%d en attente). Le compagnon "
            .. "diagnostiquera au prochain /reload.", #liste))
    end
end

-- ----------------------------------------------------------------------------
-- Journal des échecs d'alignement
-- Quand un texte connu des bases refuse de se traduire (modèle non aligné),
-- on note l'ID et le texte affiché : le compagnon verra les ratés
-- systématiques sans attendre qu'un joueur les remarque. Silencieux, borné,
-- dédoublonné par ID — un filet, pas un espion.
-- genre : "S" (description de sort) ou "O" (ligne d'effet d'objet)
-- ----------------------------------------------------------------------------
-- texte : une chaîne, ou une table de lignes — les descriptions contiennent
-- elles-mêmes des sauts de ligne, les joindre perdrait la structure et
-- fausserait le rejeu hors-jeu (vécu sur le Libram : bloc @ext replié).
function AFR.JournaliserEchec(genre, id, texte)
    if not id or not texte or texte == "" then return end
    AscensionFRSaved = AscensionFRSaved or {}
    local j = AscensionFRSaved.EchecsAlignement or {}
    AscensionFRSaved.EchecsAlignement = j
    j[genre] = j[genre] or {}
    if j[genre][id] ~= nil then return end
    local n = 0
    for _ in pairs(j[genre]) do n = n + 1 end
    if n >= MAX_ECHECS then return end
    if type(texte) == "table" then
        local copie = {}
        for i = 1, math.min(#texte, 12) do
            copie[i] = string.sub(texte[i], 1, 600)
        end
        j[genre][id] = copie
    else
        j[genre][id] = string.sub(texte, 1, 600)
    end
end

-- Un échec journalisé qui se remet à traduire (bases enrichies, addon
-- corrigé...) s'efface : le journal se soigne tout seul.
function AFR.OublierEchec(genre, id)
    local j = AscensionFRSaved and AscensionFRSaved.EchecsAlignement
    if j and j[genre] then j[genre][id] = nil end
end
