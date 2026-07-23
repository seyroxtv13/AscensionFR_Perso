-- ============================================================================
-- AscensionFR - Dialogues de PNJ (gossip et accueil de quêtes)
-- ============================================================================
local AFR = AscensionFR

local function Sub(t) return AFR.Substituer(t) end

-- Traduit le texte d'un bouton de dialogue : option de gossip, ou titre de
-- quête proposé par le PNJ.
--
-- PIÈGE (résolu 21/07/2026, 417 titres récupérés d'un coup) : Ascension
-- colore les titres de quête des menus (« |cff000000Titre|r » noir,
-- « |cffFFFF00Titre|r » jaune). GetText() rend la chaîne AVEC la couleur :
-- la table des titres, indexée par le titre NU, ne matchait jamais — les
-- joueurs voyaient l'anglais et l'addon re-récoltait sans fin.
local function SansCouleur(texte)
    local couleur, nu = string.match(texte, "^(|c%x%x%x%x%x%x%x%x)(.-)|r$")
    return couleur, nu
end

local function TraduireBouton(bouton)
    local texte = bouton:GetText()
    if not texte or texte == "" then return end
    -- Anti-bruit (232 faux positifs recensés le 21/07/2026) : si ce bouton
    -- affiche déjà ce que NOUS y avons écrit au passage précédent, ne rien
    -- refaire — et surtout ne pas RÉCOLTER notre propre français.
    if bouton.afrTexte == texte then return end
    -- Option de dialogue connue ?
    local fr = AFR.ChercherParTexte(AFR.DB.Gossip, texte)
    if fr then
        bouton:SetText(Sub(fr))
        bouton.afrTexte = bouton:GetText()
        return
    end
    -- Titre de quête ?
    local q = AFR.QueteParTitreEN(texte)
    if q and q.T then
        bouton:SetText(Sub(q.T))
        bouton.afrTexte = bouton:GetText()
        return
    end
    -- Titre (ou option) sous habillage couleur : retenter à nu, rhabiller.
    local couleur, nu = SansCouleur(texte)
    if nu and nu ~= "" then
        local q2 = AFR.QueteParTitreEN(nu)
        if q2 and q2.T then
            bouton:SetText(couleur .. Sub(q2.T) .. "|r")
            bouton.afrTexte = bouton:GetText()
            return
        end
        local fr2 = AFR.ChercherParTexte(AFR.DB.Gossip, nu)
        if fr2 then
            bouton:SetText(couleur .. Sub(fr2) .. "|r")
            bouton.afrTexte = bouton:GetText()
            return
        end
        -- Récolter le titre NU : la clé reste exploitable par l'usine.
        AFR.Recolter("Gossip", nu, true)
        bouton.afrTexte = texte
        return
    end
    -- Inconnu : récolte pour traduction ultérieure.
    AFR.Recolter("Gossip", texte, true)
    bouton.afrTexte = texte
end

local function TraduireGossip()
    if not AFR.Actif() then return end
    -- Texte d'accueil du PNJ
    local accueil = GetGossipText()
    if accueil and accueil ~= "" and GossipGreetingText then
        local fr = AFR.ChercherParTexte(AFR.DB.TextesPNJ, accueil)
        if fr then
            GossipGreetingText:SetText(Sub(fr))
        else
            AFR.Recolter("TextesPNJ", accueil, true)
        end
    end
    -- Boutons (options + quêtes)
    for i = 1, 32 do
        local bouton = _G["GossipTitleButton" .. i]
        if bouton and bouton:IsShown() then
            TraduireBouton(bouton)
        end
    end
end

-- Panneau d'accueil des donneurs de quêtes multiples (QUEST_GREETING)
local function TraduireAccueilQuetes()
    if not AFR.Actif() then return end
    local accueil = GetGreetingText and GetGreetingText()
    if accueil and accueil ~= "" and GreetingText then
        local fr = AFR.ChercherParTexte(AFR.DB.TextesPNJ, accueil)
        if fr then
            GreetingText:SetText(Sub(fr))
        else
            AFR.Recolter("TextesPNJ", accueil, true)
        end
    end
    for i = 1, 32 do
        local bouton = _G["QuestTitleButton" .. i]
        if bouton and bouton:IsShown() then
            local texte = bouton:GetText()
            if texte and texte ~= "" then
                local q = AFR.QueteParTitreEN(texte)
                if q and q.T then bouton:SetText(Sub(q.T)) end
            end
        end
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("GOSSIP_SHOW")
frame:RegisterEvent("QUEST_GREETING")
frame:SetScript("OnEvent", function(self, event)
    if event == "GOSSIP_SHOW" then
        TraduireGossip()
    elseif event == "QUEST_GREETING" then
        TraduireAccueilQuetes()
    end
end)

-- Certains addons ou le jeu lui-même rafraîchissent la fenêtre après coup.
if type(GossipFrameUpdate) == "function" then
    hooksecurefunc("GossipFrameUpdate", TraduireGossip)
end
