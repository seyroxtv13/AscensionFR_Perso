-- ============================================================================
-- AscensionFR - Métiers et grimoire
--
-- Ascension livre ses fenêtres compilées (Blizzard_TradeSkillUI.pub) : leurs
-- noms de cadres sont inconnus et peuvent changer. On ne suppose donc rien de
-- la structure.
--
-- Méthode : les fonctions de données (GetTradeSkillInfo, GetTradeSkillRecipeLink...)
-- sont côté client et restent fiables. On les interroge pour construire une
-- table « texte anglais -> texte français », puis on parcourt la fenêtre et on
-- remplace le texte de chaque zone de texte reconnue. Aucun nom de cadre en dur.
-- ============================================================================
local AFR = AscensionFR

local Correspondances = {}   -- texte anglais -> texte français (fenêtre en cours)
local aTraduire = false

local function Ajouter(en, fr)
    if en and fr and en ~= "" and fr ~= "" and en ~= fr then
        Correspondances[en] = fr
        aTraduire = true
    end
end

-- Un libellé venu des DBC (« Crossbows », « Blacksmithing »...) ou appris.
local function Libelle(texte)
    if not texte or texte == "" then return nil end
    return AFR.DB.Libelles[texte] or AFR.DB.Divers[texte]
end

-- ----------------------------------------------------------------------------
-- Métiers
-- ----------------------------------------------------------------------------
-- Une recette (ou un en-tête) de la liste : correspondances + récolte.
-- Sorti de la boucle pour pouvoir être appelé PAR TRANCHES (voir cadence).
local function ConstruireRecette(i)
    local nomEN, genre = GetTradeSkillInfo(i)
    if not nomEN then return end
    if genre == "header" or genre == "subheader" then
        -- En-tête de catégorie : sous-classe d'objet le plus souvent
        Ajouter(nomEN, Libelle(nomEN))
        return
    end
    -- Recette : le lien donne l'identifiant du sort
    local lien = GetTradeSkillRecipeLink and GetTradeSkillRecipeLink(i)
    local id = lien and string.match(lien, "enchant:(%d+)")
    local s = id and AFR.DB.Sorts[tonumber(id)]
    if s and s.N then
        Ajouter(nomEN, s.N)
    else
        -- Repli : le nom de l'objet fabriqué porte souvent le
        -- même nom que la recette.
        local lienObjet = GetTradeSkillItemLink and GetTradeSkillItemLink(i)
        local idObjet = AFR.IdDepuisLienObjet(lienObjet)
        local o = idObjet and AFR.DB.Objets[idObjet]
        if o and o.N then
            Ajouter(nomEN, o.N)
        elseif id then
            -- L'identifiant du sort est connu : récolte par ID,
            -- pour le traitement complet (officiel frFR ou file
            -- de traduction) au lieu d'un texte anonyme.
            AFR.Recolter("Sorts", tonumber(id), { N = nomEN })
        else
            AFR.Recolter("Divers", nomEN, true)
        end
    end

    -- Composants
    if type(GetTradeSkillNumReagents) == "function" then
        for j = 1, (GetTradeSkillNumReagents(i) or 0) do
            local nomComposant = GetTradeSkillReagentInfo(i, j)
            local lienComposant = GetTradeSkillReagentItemLink
                and GetTradeSkillReagentItemLink(i, j)
            local idComposant = AFR.IdDepuisLienObjet(lienComposant)
            local oc = idComposant and AFR.DB.Objets[idComposant]
            if oc and oc.N then
                Ajouter(nomComposant, oc.N)
            elseif nomComposant then
                AFR.Recolter("Divers", nomComposant, true)
            end
        end
    end
end

-- GEL DES GROS MÉTIERS (22/07/2026, diagnostiqué par un joueur — merci) :
-- TRADE_SKILL_UPDATE arrive en RAFALES, et chaque événement re-parcourait
-- TOUTES les recettes (des milliers sur Ascension) avec récolte des
-- inconnues — le client gelait à l'ouverture. Deux remèdes :
--  1. SIGNATURE (métier + nombre de recettes) : tant qu'elle n'a pas
--     changé, on ne reconstruit rien — les rafales deviennent gratuites ;
--  2. TRANCHES : au-delà de 400 recettes, le parcours se fait par paquets
--     de 250 par image (cadence, plus bas) — le client respire, la fenêtre
--     se francise progressivement sous les yeux du joueur.
local signature_metier
local chantier
local cadence = CreateFrame("Frame")
cadence:Hide()
local TRANCHE = 250

local function ConstruireMetiers()
    if type(GetNumTradeSkills) ~= "function" then return end
    local nb = GetNumTradeSkills() or 0
    local ligne
    if type(GetTradeSkillLine) == "function" then
        ligne = GetTradeSkillLine()
    end
    local signature = tostring(ligne or "?") .. ":" .. tostring(nb)
    if signature == signature_metier then return end
    signature_metier = signature
    chantier = nil
    cadence:Hide()
    Correspondances = {}
    aTraduire = false

    -- Nom du métier (« Woodworking », « Blacksmithing »...)
    Ajouter(ligne, Libelle(ligne))

    -- Les libellés FIXES de la fenêtre : boutons, filtres, « Composants : ».
    -- Leur texte est posé par le XML à la construction, donc avant nous — on
    -- les rattrape par correspondance de texte, comme le reste. Les globales
    -- elles-mêmes ne sont jamais touchées (taint), et « SEARCH » n'est PAS
    -- dans la liste : le contenu de la case de recherche sert de repère au
    -- filtre de la fenêtre — le traduire vide la liste des recettes (vécu et
    -- prouvé le 20/07/2026, voir Epreuves.lua).
    for _, cle in ipairs({"CREATE", "CREATE_ALL", "EXIT", "REQUIRES_LABEL",
                          "SPELL_REAGENTS", "ALL_SUBCLASSES",
                          "ALL_INVENTORY_SLOTS", "CRAFT_IS_MAKEABLE"}) do
        local anglais, francais = _G[cle], AFR.DB.UI[cle]
        if type(anglais) == "string" and type(francais) == "string" then
            Ajouter(anglais, francais)
        end
    end

    if nb <= 400 then
        -- Petit métier : d'un seul geste, comme avant.
        for i = 1, nb do ConstruireRecette(i) end
    else
        -- Gros métier d'Ascension : par tranches, une par image.
        chantier = { i = 1, nb = nb }
        cadence:Show()
    end
end

-- La LISTE des recettes résiste au parcours générique (capture de Dan du
-- 17/07 : le détail à droite était en français, la liste à gauche non).
-- Ascension a restylé la fenêtre standard sans la remplacer : ses boutons
-- gardent les noms de Blizzard. On les traite donc nommément, comme les
-- boutons de marchand et de butin — plus sûr que d'espérer qu'un parcours
-- les atteigne.
--
-- Le rang du bouton n'est PAS le rang de la recette : la liste défile. Le
-- décalage se demande au jeu, il ne se devine pas.
local function TraduireListeRecettes()
    if type(GetTradeSkillInfo) ~= "function" then return end
    local decalage = 0
    if type(FauxScrollFrame_GetOffset) == "function"
        and TradeSkillListScrollFrame then
        local ok, v = pcall(FauxScrollFrame_GetOffset, TradeSkillListScrollFrame)
        if ok and type(v) == "number" then decalage = v end
    end
    for i = 1, (TRADE_SKILLS_DISPLAYED or 8) do
        local bouton = _G["TradeSkillSkill" .. i]
        if bouton and bouton.GetText and not AFR.EstProtege(bouton) then
            local affiche = bouton:GetText()
            local nomEN = GetTradeSkillInfo(i + decalage)
            if affiche and nomEN and Correspondances[nomEN] then
                -- Les RECETTES sont indentées d'une espace par le client
                -- (« ␣Wool Bandage », Blizzard_TradeSkillUI lignes 181/190),
                -- les EN-TÊTES non. L'ancienne égalité en préfixe strict ne
                -- voyait donc QUE les en-têtes — « Autre » passait en
                -- français, « Wool Bandage » jamais (élucidé le 20/07/2026).
                -- On cherche le nom où qu'il soit et on préserve ce qui
                -- l'entoure (indentation, mode daltonien, suffixes).
                local debut, fin = string.find(affiche, nomEN, 1, true)
                if debut then
                    bouton:SetText(string.sub(affiche, 1, debut - 1)
                        .. Correspondances[nomEN]
                        .. string.sub(affiche, fin + 1))
                end
            end
        end
    end
end

local function TraduireMetiers()
    if not AFR.Actif() then return end
    if not TradeSkillFrame or not TradeSkillFrame:IsShown() then return end
    ConstruireMetiers()
    if aTraduire then
        AFR.Parcourir(TradeSkillFrame, Correspondances)
        TraduireListeRecettes()
    end
end

-- Le moteur des tranches : chaque image, un paquet de recettes, puis une
-- repeinture — la fenêtre se francise progressivement, sans jamais geler.
cadence:SetScript("OnUpdate", function()
    if not chantier or not TradeSkillFrame
        or not TradeSkillFrame:IsShown() then
        chantier = nil
        cadence:Hide()
        return
    end
    local nb = GetNumTradeSkills and GetNumTradeSkills() or 0
    if nb ~= chantier.nb then
        -- La liste a bougé en cours de route (filtre, en-tête replié) :
        -- on abandonne proprement, le prochain TRADE_SKILL_UPDATE
        -- repartira sur une signature neuve.
        chantier = nil
        signature_metier = nil
        cadence:Hide()
        return
    end
    local fin = chantier.i + TRANCHE - 1
    if fin > nb then fin = nb end
    for i = chantier.i, fin do
        ConstruireRecette(i)
    end
    chantier.i = fin + 1
    if aTraduire then
        AFR.Parcourir(TradeSkillFrame, Correspondances)
        TraduireListeRecettes()
    end
    if chantier.i > nb then
        chantier = nil
        cadence:Hide()
    end
end)

-- ----------------------------------------------------------------------------
-- Grimoire (livre de sorts)
-- ----------------------------------------------------------------------------
local function ConstruireGrimoire()
    Correspondances = {}
    aTraduire = false
    local typeLivre = (SpellBookFrame and SpellBookFrame.bookType) or "spell"
    if type(GetSpellName) ~= "function" then return end

    for i = 1, 1024 do
        local nomEN, rangEN = GetSpellName(i, typeLivre)
        if not nomEN then break end
        local lien = GetSpellLink and GetSpellLink(i, typeLivre)
        local id = lien and string.match(lien, "spell:(%d+)")
        local s = id and AFR.DB.Sorts[tonumber(id)]
        if s then
            if s.N then Ajouter(nomEN, s.N) end
            if s.R and rangEN then Ajouter(rangEN, s.R) end
        elseif id then
            AFR.Recolter("Sorts", tonumber(id), { N = nomEN })
        end
    end

    -- Onglets du grimoire : noms de métiers et de compétences
    for i = 1, (MAX_SKILLLINE_TABS or 8) do
        local nomOnglet = GetSpellTabInfo and GetSpellTabInfo(i)
        if nomOnglet then Ajouter(nomOnglet, Libelle(nomOnglet)) end
    end
end

local function TraduireGrimoire()
    if not AFR.Actif() then return end
    if not SpellBookFrame or not SpellBookFrame:IsShown() then return end
    ConstruireGrimoire()
    if aTraduire then AFR.Parcourir(SpellBookFrame, Correspondances) end
end

-- ----------------------------------------------------------------------------
-- Branchements — tous conditionnels : ces fenêtres sont chargées à la demande
-- et Ascension peut les avoir remplacées.
-- ----------------------------------------------------------------------------
local frame = CreateFrame("Frame")
frame:RegisterEvent("TRADE_SKILL_SHOW")
frame:RegisterEvent("TRADE_SKILL_UPDATE")
frame:RegisterEvent("SPELLS_CHANGED")
frame:RegisterEvent("LEARNED_SPELL_IN_TAB")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, event, arg1)
    if event == "TRADE_SKILL_SHOW" or event == "TRADE_SKILL_UPDATE" then
        TraduireMetiers()
    elseif event == "SPELLS_CHANGED" or event == "LEARNED_SPELL_IN_TAB" then
        TraduireGrimoire()
    elseif event == "ADDON_LOADED" then
        if arg1 == "Blizzard_TradeSkillUI"
            and type(TradeSkillFrame_Update) == "function" then
            hooksecurefunc("TradeSkillFrame_Update", TraduireMetiers)
        end
    end
end)

if type(SpellBookFrame_Update) == "function" then
    hooksecurefunc("SpellBookFrame_Update", TraduireGrimoire)
end
if type(SpellBookFrame_UpdateSpells) == "function" then
    hooksecurefunc("SpellBookFrame_UpdateSpells", TraduireGrimoire)
end
if type(TradeSkillFrame_Update) == "function" then
    hooksecurefunc("TradeSkillFrame_Update", TraduireMetiers)
end

-- Filet de sécurité : si la fenêtre est repeinte par du code qu'on ne connaît
-- pas (interface compilée d'Ascension), on repasse peu après son ouverture.
local minuteur = CreateFrame("Frame")
minuteur:Hide()
local ecoule = 0
minuteur:SetScript("OnUpdate", function(self, delta)
    ecoule = ecoule + delta
    if ecoule > 0.25 then
        self:Hide()
        ecoule = 0
        TraduireMetiers()
        TraduireGrimoire()
    end
end)
frame:HookScript("OnEvent", function(self, event)
    if event == "TRADE_SKILL_SHOW" or event == "SPELLS_CHANGED" then
        ecoule = 0
        minuteur:Show()
    end
end)
