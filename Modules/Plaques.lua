-- ============================================================================
-- AscensionFR - Plaques de nom (barres au-dessus des créatures) + suivi de
-- quêtes (WatchFrame) + messages jaunes de progression.
--
-- SÉCURITÉ : le désastre de la 1.6 venait de l'ÉCRITURE des globales relues
-- par le code de combat. Ici, comme partout depuis : lecture seule, puis
-- SetText sur ce qui est AFFICHÉ. Les plaques ne sont pas des cadres
-- protégés en 3.3.5 (Aloft/TidyPlates les réécrivent en plein combat).
-- Coupe-circuit dédié : AscensionFRSaved.Options.sansPlaques.
--
-- Le pont vers le français : DB.Creatures porte le nom anglais (NE) à côté
-- du français (N) -> index inversé, construit une seule fois.
-- ============================================================================
local AFR = AscensionFR

local function Options()
    return AscensionFRSaved and AscensionFRSaved.Options
end

local function Actif()
    return AFR.Actif and AFR.Actif()
        and not (Options() and Options().sansPlaques)
end

-- ----------------------------------------------------------------------------
-- Index [nom anglais] = nom français. Doublons DIVERGENTS neutralisés.
-- ----------------------------------------------------------------------------
local index_noms

local function ConstruireIndex()
    index_noms = {}
    for _, c in pairs(AFR.DB.Creatures) do
        if type(c) == "table" and c.NE and c.N and c.NE ~= c.N then
            local deja = index_noms[c.NE]
            if deja == nil then
                index_noms[c.NE] = c.N
            elseif deja ~= c.N then
                index_noms[c.NE] = false
            end
        end
    end
end

local function Francais(nom)
    if type(nom) ~= "string" or nom == "" then return end
    if not index_noms then ConstruireIndex() end
    local fr = index_noms[nom]
    if fr then return fr end
end

-- Partagé : d'autres modules traduisent des noms de PNJ affichés (titre des
-- fenêtres de quête/dialogue). Même index, même prudence.
AFR.NomCreatureFrancais = Francais

-- L'index se construit à la première demande : un pic en pleine partie.
-- Préchauffé pendant l'écran de chargement (Core, 2.0.2).
if AFR.Prechauffages then
    table.insert(AFR.Prechauffages,
                 function() Francais("préchauffage") end)
end

-- ----------------------------------------------------------------------------
-- PLAQUES. Détection sans hypothèse sur leur structure (le client d'Ascension
-- les a remaniées) : tout enfant de WorldFrame portant une FontString dont le
-- texte ENTIER est un nom anglais connu se fait repeindre. Autovalidant — un
-- niveau « 2 » ou un « 100% » ne matche jamais l'index.
-- ----------------------------------------------------------------------------
-- 2.0.2 : les zones de texte d'un cadre sont relevées UNE seule fois (les
-- plaques sont recyclées, leur structure ne bouge pas), et chaque zone
-- mémorise le dernier texte vu. Avant : deux tableaux alloués par cadre à
-- CHAQUE passage (4 par seconde par plaque visible) + une recherche par
-- zone — du déchet mémoire en continu, que le ménage du jeu paie en
-- à-coups.
local function ReleverZones(cadre, profondeur, zones)
    for _, r in ipairs({ cadre:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "FontString" then
            zones[#zones + 1] = r
        end
    end
    if profondeur > 1 then
        for _, enfant in ipairs({ cadre:GetChildren() }) do
            if not (enfant.GetObjectType
                and enfant:GetObjectType() == "EditBox") then
                ReleverZones(enfant, profondeur - 1, zones)
            end
        end
    end
    return zones
end

local function RepeindreCadre(cadre, profondeur)
    local zones = cadre.afrZones
    if not zones then
        zones = ReleverZones(cadre, profondeur, {})
        cadre.afrZones = zones
    end
    for i = 1, #zones do
        local r = zones[i]
        local texte = r:GetText()
        -- afrVu : dernier texte examiné (anglais resté tel quel, ou notre
        -- français posé). Tant qu'il ne bouge pas, zéro travail.
        if texte and texte ~= "" and texte ~= r.afrVu then
            local fr = Francais(texte)
            if fr then
                r:SetText(fr)
                r.afrVu = fr
            else
                r.afrVu = texte
            end
        end
    end
end

-- `connues` (clés faibles, parcourue par pairs — JAMAIS ipairs : une liste
-- à références faibles + ipairs est un piège en Lua 5.1, un trou après
-- ramassage et le parcours s'arrête) : tous les enfants de WorldFrame déjà
-- vus. 2.0.2 : la liste complète des enfants n'est plus ré-allouée à
-- chaque tick — WorldFrame gagne un enfant à chaque nouvelle plaque, donc
-- tant que le COMPTE ne bouge pas, il n'y a rien de nouveau à accrocher
-- (même garde que BarresDeVie.lua).
local connues = setmetatable({}, { __mode = "k" })
local nb_connus = -1
local depuis = 0

local veilleuse = CreateFrame("Frame")
veilleuse:SetScript("OnUpdate", function(self, ecoule)
    depuis = depuis + ecoule
    if depuis < 0.25 then return end
    depuis = 0
    if not Actif() then return end
    local n = WorldFrame:GetNumChildren()
    if n ~= nb_connus then
        nb_connus = n
        for _, cadre in ipairs({ WorldFrame:GetChildren() }) do
            if not connues[cadre] then
                connues[cadre] = true
                -- au recyclage, la plaque réapparaît avec un nouveau nom
                pcall(cadre.HookScript, cadre, "OnShow", function(c)
                    if Actif() then pcall(RepeindreCadre, c, 2) end
                end)
            end
        end
    end
    -- le client peut aussi reposer le nom sans Hide/Show : repasse légère
    -- sur les visibles (grâce à afrVu, de simples comparaisons de chaînes)
    for cadre in pairs(connues) do
        if cadre:IsShown() then
            pcall(RepeindreCadre, cadre, 2)
        end
    end
end)

-- ----------------------------------------------------------------------------
-- (Le SUIVI de quêtes est déjà couvert par TraduireSuivi dans Quetes.lua —
-- greffe WatchFrame_Update existante, preuve taint.log en commentaire.)
--
-- « - Young Thistle Boar slain: 3/4 » : nom de créature via l'index.
-- ----------------------------------------------------------------------------
local function LigneSuivi(texte)
    local avant, nom, fait, total =
        string.match(texte, "^([%-%s]*)(.-) slain: (%d+)/(%d+)$")
    if nom then
        local fr = Francais(nom)
        if fr then
            return avant .. fr .. " tué(s) : " .. fait .. "/" .. total
        end
        return
    end
    -- objectif de COLLECTE serveur (« Warsong Saw Blades: 0/1 ») : le nom
    -- d'objet passe par le pont DB.ObjetsNoms.
    local nomObj, fait2, total2 = string.match(texte, "^(.-): (%d+)/(%d+)$")
    if nomObj and AFR.DB.ObjetsNoms then
        local fr = AFR.DB.ObjetsNoms[nomObj]
        if fr then return fr .. " : " .. fait2 .. "/" .. total2 end
    end
end

-- ----------------------------------------------------------------------------
-- Messages ROUGES d'erreur (« Ability is not ready yet. ») : étiquettes
-- ERR_* / SPELL_FAILED_* — le français officiel est dans DB.UI. Seuls les
-- textes SANS variable (%s, %d) peuvent matcher exactement ; les autres
-- passent tels quels. (Retour du testeur, 20/07 au soir.)
-- ----------------------------------------------------------------------------
local erreurs, erreurs_formats

-- « Discovered: %s » -> motif « ^Discovered: (.+)$ » ; le français garde
-- ses captures dans l'ordre. Les gabarits à position explicite (%1$s) sont
-- écartés : trop risqués pour une conversion naïve.
local function EnMotifMessage(gabarit)
    gabarit = string.gsub(gabarit, "%%s", "\1")
    gabarit = string.gsub(gabarit, "%%d", "\2")
    local motif = string.gsub(gabarit,
        "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    motif = string.gsub(motif, "\1", "(.+)")
    motif = string.gsub(motif, "\2", "(%%-?%%d+)")
    return "^" .. motif .. "$"
end

local function EnRemplacementMessage(gabarit)
    local sortie = string.gsub(gabarit, "%%[sd]", "\1")
    sortie = string.gsub(sortie, "%%", "%%%%")
    local rang = 0
    sortie = string.gsub(sortie, "\1", function()
        rang = rang + 1
        return "%" .. rang
    end)
    return sortie
end

local function Erreur(texte)
    if not erreurs then
        erreurs, erreurs_formats = {}, {}
        for cle, fr in pairs(AFR.DB.UI) do
            if (string.sub(cle, 1, 4) == "ERR_"
                or string.sub(cle, 1, 13) == "SPELL_FAILED_")
                and type(fr) == "string" and fr ~= "" then
                local en = _G[cle]
                if type(en) == "string" and en ~= "" and en ~= fr then
                    if not string.find(en, "%%") then
                        erreurs[en] = fr
                    elseif not string.find(en, "%%%d+%$")
                        and not string.find(fr, "%%%d+%$")
                        and not string.find(en, "%%%.")
                        and not string.find(fr, "%%%.") then
                        -- gabarit simple (%s / %d) : « Découverte : X »
                        table.insert(erreurs_formats,
                            { motif = EnMotifMessage(en),
                              rempl = EnRemplacementMessage(fr) })
                    end
                end
            end
        end
    end
    local fr = erreurs[texte]
    if fr then return fr end
    for _, f in ipairs(erreurs_formats) do
        local nouveau, n = string.gsub(texte, f.motif, f.rempl)
        if n > 0 then return nouveau end
    end
end

-- Messages envoyés TELS QUELS par le serveur (aucune clé côté client — vus
-- en jeu, traduits à la main). S'étoffe au fil des captures de Dan et des
-- récoltes ci-dessous.
local MESSAGES_SERVEUR = {
    ["You need to learn Riding Skill first!"] =
        "Vous devez d'abord apprendre la compétence de monte !",
}

local function TraduireMessage(texte)
    local fr = MESSAGES_SERVEUR[texte] or Erreur(texte) or LigneSuivi(texte)
    -- Message rouge inconnu et visiblement anglais : on le RÉCOLTE, pour
    -- que le prochain « Riding Skill » remonte tout seul par les rapports.
    if not fr and #texte > 12
        and not string.find(texte, "[éèêàçûîôë]") then
        AFR.Recolter("Divers", texte, true)
    end
    -- « Découverte : Greenpaw Village » : le nom de zone capturé se traduit
    -- si on le connaît (DB.Zones — frFR officiel du jeu de base).
    local resultat = fr or texte
    local zones = AFR.DB.Zones
    if zones then
        local avant, nom, suite =
            string.match(resultat, "^(Découverte : )([^,]+)(.*)$")
        if nom and zones[nom] then
            return avant .. zones[nom] .. suite
        end
    end
    return fr
end

-- ----------------------------------------------------------------------------
-- Objets du MONDE (arbres à couper, minerais, herbes) : leur bulle n'a ni
-- objet, ni sort, ni unité — c'est son signalement. Nom via l'index NE->N de
-- DB.ObjetsMonde, ligne « Requires Woodcutting » via Libelles + métiers
-- custom d'Ascension. (Retour du testeur, 20/07 au soir.)
-- ----------------------------------------------------------------------------
local METIERS_RECOLTE = {
    ["Woodcutting"] = "Coupe de bois",
}

local index_monde

local function MondeFrancais(nom)
    if type(nom) ~= "string" or nom == "" then return end
    if not index_monde then
        index_monde = {}
        for _, o in pairs(AFR.DB.ObjetsMonde) do
            if type(o) == "table" and o.NE and o.N and o.NE ~= o.N then
                local deja = index_monde[o.NE]
                if deja == nil then
                    index_monde[o.NE] = o.N
                elseif deja ~= o.N then
                    index_monde[o.NE] = false
                end
            end
        end
    end
    local fr = index_monde[nom]
    if fr then return fr end
end

local monde_en_cours = false

local function SurMonde(tooltip)
    if monde_en_cours or not Actif() then return end
    if tooltip.GetItem then
        local ok, _, lien = pcall(tooltip.GetItem, tooltip)
        if ok and lien then return end
    end
    if tooltip.GetSpell then
        local ok, nomSort = pcall(tooltip.GetSpell, tooltip)
        if ok and nomSort then return end
    end
    if tooltip.GetUnit then
        local ok, _, unite = pcall(tooltip.GetUnit, tooltip)
        if ok and unite then return end
    end
    local modifie = false
    local l1 = _G[tooltip:GetName() .. "TextLeft1"]
    local texte = l1 and l1:GetText()
    local fr = texte and MondeFrancais(texte)
    if not fr and texte then
        -- « Corpse of X » : X peut être un PSEUDO de joueur — on ne
        -- traduit que le gabarit, et le nom seulement si c'est une
        -- créature connue.
        local nom = string.match(texte, "^Corpse of (.+)$")
        if nom then
            fr = "Cadavre de " .. (Francais(nom) or nom)
        end
    end
    if fr then
        l1:SetText(fr)
        modifie = true
    end
    local l2 = _G[tooltip:GetName() .. "TextLeft2"]
    local t2 = l2 and l2:GetText()
    if t2 then
        local metier = string.match(t2, "^Requires (.+)$")
        local mfr = metier and (METIERS_RECOLTE[metier]
            or AFR.DB.Libelles[metier])
        if mfr then
            l2:SetText("Nécessite " .. mfr)
            modifie = true
        end
    end
    if modifie and tooltip:IsShown() then
        monde_en_cours = true
        pcall(tooltip.Show, tooltip)
        monde_en_cours = false
    end
end

if GameTooltip then
    -- Les bulles d'objets du monde sont AFFICHÉES par le moteur C, qui ne
    -- passe pas par la méthode Show — seul le script OnShow se déclenche
    -- alors. On pose les deux, comme la passe des Épreuves.
    hooksecurefunc(GameTooltip, "Show", SurMonde)
    if GameTooltip.HookScript then
        GameTooltip:HookScript("OnShow", SurMonde)
    end
end

-- ----------------------------------------------------------------------------
-- Carte de VOL : la bulle d'un nœud dit « Zoram'gar Outpost, Ashenvale ».
-- La zone après la virgule se traduit via DB.Zones (le nom du nœud aussi,
-- quand on le connaît). Greffe sur l'entrée de souris des nœuds de taxi.
-- ----------------------------------------------------------------------------
if type(TaxiNodeOnButtonEnter) == "function" then
    hooksecurefunc("TaxiNodeOnButtonEnter", function()
        if not Actif() then return end
        local l1 = GameTooltipTextLeft1
        local texte = l1 and l1:GetText()
        if type(texte) ~= "string" or texte == "" then return end
        local zones = AFR.DB.Zones
        if not zones then return end
        local nom, zone = string.match(texte, "^(.+), ([^,]+)$")
        local modifie = false
        if zone and zones[zone] then
            texte = (zones[nom] or nom) .. ", " .. zones[zone]
            modifie = true
        elseif zones[texte] then
            texte = zones[texte]
            modifie = true
        end
        if modifie then
            l1:SetText(texte)
            if GameTooltip:IsShown() then GameTooltip:Show() end
        end
    end)
end

-- ----------------------------------------------------------------------------
-- Messages jaunes de progression (« Young Thistle Boar slain: 3/4 »).
-- UIErrorsFrame n'est ni une globale de textes ni un cadre protégé : on
-- enrobe SA méthode AddMessage (membre du cadre, façon ErrorFilter) et on
-- traduit au passage ce qu'on sait traduire — tout le reste passe tel quel.
-- ----------------------------------------------------------------------------
if UIErrorsFrame and not UIErrorsFrame.AFR_enrobe then
    UIErrorsFrame.AFR_enrobe = true
    local origine = UIErrorsFrame.AddMessage
    UIErrorsFrame.AddMessage = function(self, texte, ...)
        -- pcall OBLIGATOIRE (audit 20/07) : une erreur ici avalerait le
        -- message ORIGINAL (« Trop loin », « Interrompu »...) — le pire
        -- endroit pour perdre une information. L'original passe TOUJOURS.
        if Actif() and type(texte) == "string" then
            local ok, fr = pcall(TraduireMessage, texte)
            if ok and fr then texte = fr end
        end
        return origine(self, texte, ...)
    end
end

-- ============================================================================
-- Messages système du TCHAT : création d'objet, butin, montée de compétence,
-- expérience, argent, réputation (demande de Dan, 21/07/2026).
--
-- L'ANGLAIS est lu EN DIRECT dans les globales du client (_G[cle]) : le motif
-- colle toujours à ce qu'Ascension affiche vraiment, même s'il a été modifié.
-- Le FRANÇAIS vient des GlobalStrings frFR officielles, recopiées ici.
-- Accroche : ChatFrame_AddMessageEventFilter — l'API prévue pour transformer
-- les messages, AUCUNE globale écrite. En cas de pépin, l'original passe.
-- ============================================================================
local TCHAT_FR = {
    LOOT_ITEM_CREATED_SELF = "Vous créez : %s.",
    LOOT_ITEM_CREATED_SELF_MULTIPLE = "Vous créez : %sx%d.",
    LOOT_ITEM_SELF = "Vous recevez le butin : %s.",
    LOOT_ITEM_SELF_MULTIPLE = "Vous recevez le butin : %sx%d.",
    LOOT_ITEM_PUSHED_SELF = "Vous recevez l'objet : %s.",
    LOOT_ITEM_PUSHED_SELF_MULTIPLE = "Vous recevez l'objet : %sx%d.",
    SKILL_RANK_UP = "Votre compétence en %s est maintenant de %d.",
    ERR_SKILL_UP_SI = "Votre compétence en %s est maintenant de %d.",
    COMBATLOG_XPGAIN_FIRSTPERSON =
        "%s meurt, vous gagnez %d points d'expérience.",
    COMBATLOG_XPGAIN_FIRSTPERSON_UNNAMED =
        "Vous gagnez %d points d'expérience.",
    YOU_LOOT_MONEY = "Vous ramassez %s",
    FACTION_STANDING_INCREASED =
        "Votre réputation auprès de %s augmente de %d points.",
    ACHIEVEMENT_BROADCAST = "%s a accompli le haut fait %s !",
    GUILD_ACHIEVEMENT_BROADCAST = "%s (guilde) a accompli le haut fait %s !",
}

-- Motifs CUSTOM d'Ascension : pas de globale à lire, motif écrit à la main.
local TCHAT_MOTIFS = {
    { motif = "^You must be level (%d+) or higher to select a PvP ruleset!$",
      gabarit = "Vous devez être au moins niveau %s pour choisir un "
          .. "règlement JcJ !" },
    { motif = "^You must be level (%d+) or higher to select a "
          .. "PvE ruleset!$",
      gabarit = "Vous devez être au moins niveau %s pour choisir un "
          .. "règlement JcE !" },
}
-- Captures à retraduire, par clé : nom de métier (Libelles) ou de créature.
local TCHAT_CAPTURE = {
    SKILL_RANK_UP = "libelle", ERR_SKILL_UP_SI = "libelle",
    COMBATLOG_XPGAIN_FIRSTPERSON = "creature",
    FACTION_STANDING_INCREASED = "libelle",
    ACHIEVEMENT_BROADCAST = "hautfait",
    GUILD_ACHIEVEMENT_BROADCAST = "hautfait",
    YOU_LOOT_MONEY = "argent", LOOT_MONEY = "argent",
}

local motifs_tchat

local function ConstruireMotifsTchat()
    motifs_tchat = {}
    for cle, fr in pairs(TCHAT_FR) do
        local en = _G[cle]
        if type(en) == "string" and not string.find(en, "$", 1, true) then
            local motif = string.gsub(en,
                "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
            -- l'échappement vient de doubler les % de %s/%d : on les
            -- transforme maintenant en captures.
            motif = string.gsub(motif, "%%%%s", "(.-)")
            motif = string.gsub(motif, "%%%%d", "(%%d+)")
            motifs_tchat[#motifs_tchat + 1] =
                { motif = "^" .. motif .. "$", fr = fr, cle = cle }
        end
    end
    -- Les motifs longs d'abord : « ...x%d. » avant sa version simple.
    table.sort(motifs_tchat, function(a, b) return #a.motif > #b.motif end)
end

local function CaptureFrancaise(cle, valeur)
    local genre = TCHAT_CAPTURE[cle]
    if not genre or type(valeur) ~= "string" then return valeur end
    if genre == "libelle" then
        return AFR.DB.Libelles[valeur] or valeur
    end
    if genre == "hautfait" then
        -- le nom du haut fait vit ENTRE CROCHETS dans le lien : on ne
        -- touche qu'à lui, jamais aux données du lien (|Hachievement:...).
        return (string.gsub(valeur, "%[(.-)%]", function(nom)
            local fr = AFR.DB.HautsFaits and AFR.DB.HautsFaits[nom]
            return "[" .. (fr or nom) .. "]"
        end))
    end
    if genre == "argent" then
        valeur = string.gsub(valeur, "Copper", "cuivre")
        valeur = string.gsub(valeur, "Silver", "argent")
        valeur = string.gsub(valeur, "Gold", "or")
        return valeur
    end
    return Francais(valeur) or valeur
end

local function TraduireTchat(message)
    if not motifs_tchat then ConstruireMotifsTchat() end
    for i = 1, #motifs_tchat do
        local m = motifs_tchat[i]
        local a, b = string.match(message, m.motif)
        if a then
            local captures, rang = { a, b }, 0
            local fr = string.gsub(m.fr, "%%[sd]", function()
                rang = rang + 1
                local v = captures[rang]
                if v == nil then return "" end
                return CaptureFrancaise(m.cle, v)
            end)
            -- élision : « auprès de Orgrimmar » -> « auprès d'Orgrimmar »
            fr = string.gsub(fr, "auprès de ([AEIOUÉÈÀaeiouéèà])",
                             "auprès d'%1")
            return fr
        end
    end
    for i = 1, #TCHAT_MOTIFS do
        local m = TCHAT_MOTIFS[i]
        local capture = string.match(message, m.motif)
        if capture then return string.format(m.gabarit, capture) end
    end
end

local function FiltreTchat(self, event, message, ...)
    if Actif() and type(message) == "string" then
        local ok, fr = pcall(TraduireTchat, message)
        if ok and fr then
            return false, fr, ...
        end
    end
    -- rien renvoyé : le message original continue sa route, intact.
end

for _, evenement in ipairs({ "CHAT_MSG_SYSTEM", "CHAT_MSG_LOOT",
        "CHAT_MSG_SKILL", "CHAT_MSG_MONEY", "CHAT_MSG_COMBAT_XP_GAIN",
        "CHAT_MSG_COMBAT_FACTION_CHANGE", "CHAT_MSG_ACHIEVEMENT",
        "CHAT_MSG_GUILD_ACHIEVEMENT" }) do
    ChatFrame_AddMessageEventFilter(evenement, FiltreTchat)
end
