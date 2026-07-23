-- ============================================================================
-- AscensionFR - Maître d'entraînement (Blizzard_TrainerUI : équitation,
-- métiers...). Le client compose tout en anglais depuis ses DBC et ses
-- globales : on repeint À L'AFFICHAGE après chaque mise à jour de la fenêtre.
-- Le pont vers le français : la DESCRIPTION anglaise du service
-- (GetTrainerServiceDescription) retrouvée telle quelle dans DB.Sorts (champ
-- DE) -> nom (N), rang (R) et description (D) français. Comme partout :
-- aucune globale écrite, aucune EditBox touchée.
-- ============================================================================
local AFR = AscensionFR

local function Actif()
    return AFR.Actif and AFR.Actif()
end

-- ----------------------------------------------------------------------------
-- Index [description anglaise normalisée] = entrée de DB.Sorts. Construit au
-- premier passage seulement (la fenêtre s'ouvre rarement ; un parcours unique
-- de la base). Les descriptions en doublon sont neutralisées (false) : mieux
-- vaut laisser l'anglais que risquer la traduction d'un autre sort.
-- ----------------------------------------------------------------------------
local index_desc

-- Normalisation FORTE, pour la CLÉ seulement : le texte brut du client et
-- notre copie (db.ascension.gg) divergent par des broutilles — casse des
-- codes couleurs (|cff vs |cFF), espaces en fin de ligne INTERNE, marquage
-- @...@ d'Ascension. On écrase tout ça des deux côtés ; les formules
-- restent, elles, bien distinctives.
local function Normale(texte)
    texte = string.gsub(texte, "|c%x%x%x%x%x%x%x%x", "")
    texte = string.gsub(texte, "|r", "")
    texte = string.gsub(texte, "@", "")
    texte = string.gsub(texte, "%s+", " ")
    return (string.match(texte, "^%s*(.-)%s*$"))
end

-- Clé FLOUE : le client fournit le texte CALCULÉ (« dealing 22 Fire
-- damage ») alors que la base garde le MODÈLE (« dealing ${$cond(...)}
-- Fire damage ») — jamais égaux octet à octet (prouvé par /afrmaitre le
-- 20/07). On remplace formules ET nombres par « # » des deux côtés : la
-- structure de la phrase suffit à identifier le sort.
local function CleFloue(texte)
    texte = Normale(texte)
    texte = string.gsub(texte, "%$%b{}", "#")      -- ${$cond(...)}
    texte = string.gsub(texte, "%$[%w/;%.<>]+", "#") -- $805966s1, $/10;S3, $d
    texte = string.gsub(texte, "%d+%.?%d*", "#")   -- nombres calculés
    -- unités de durée : « $d » côté modèle devient « 12 sec » côté écran —
    -- on absorbe l'unité derrière le # (audit : 33 % des modèles ont un $d)
    texte = string.gsub(texte, "#%s*sec%.?o?n?d?s?", "#")
    texte = string.gsub(texte, "#%s*min%.?u?t?e?s?", "#")
    texte = string.gsub(texte, "#%s*hours?", "#")
    texte = string.gsub(texte, "#%s*days?", "#")
    texte = string.gsub(texte, "#[%s#]*#", "#")
    return texte
end

-- Les conditions « $?s92088[texte si talent][sinon] » sont RÉSOLUES dans le
-- texte affiché : on indexe chaque modèle sous ses deux issues (plafond de
-- variantes pour rester borné).
local function Variantes(gabarit)
    local sorties = { gabarit }
    for _ = 1, 3 do
        local suivantes, change = {}, false
        for _, g in ipairs(sorties) do
            local debut, fin, a, b = string.find(g, "%$%?%w+(%b[])(%b[])")
            if debut and #suivantes < 8 then
                change = true
                local avant, apres = string.sub(g, 1, debut - 1),
                    string.sub(g, fin + 1)
                table.insert(suivantes,
                    avant .. string.sub(a, 2, -2) .. apres)
                table.insert(suivantes,
                    avant .. string.sub(b, 2, -2) .. apres)
            else
                table.insert(suivantes, g)
            end
        end
        sorties = suivantes
        if not change then break end
    end
    return sorties
end

local function ConstruireIndex()
    index_desc = {}
    for _, s in pairs(AFR.DB.Sorts) do
        if type(s) == "table" and s.DE and s.N then
            for _, variante in ipairs(Variantes(s.DE)) do
                local cle = CleFloue(variante)
                local deja = index_desc[cle]
                if deja == nil then
                    index_desc[cle] = s
                elseif deja and deja.N ~= s.N then
                    -- doublons au nom DIVERGENT : neutralisés. Les RANGS
                    -- d'un même sort partagent nom et modèle : le premier
                    -- fait foi.
                    index_desc[cle] = false
                end
            end
        end
    end
end

local function ParDescription(texte)
    if type(texte) ~= "string" or texte == "" then return end
    if not index_desc then ConstruireIndex() end
    local s = index_desc[CleFloue(texte)]
    if s then return s end
end

-- Exposé pour les fenêtres de talents CoA (Epreuves.lua, 22/07/2026) :
-- leurs cartes affichent les mêmes descriptions calculées que le dresseur.
AFR.SortParDescription = ParDescription

-- Le PLUS GROS index de l'addon : 40 000 sorts x jusqu'à 8 variantes de
-- description. Construit d'un coup à la première fenêtre de dresseur =
-- LE plus gros mini-blocage en pleine partie. Préchauffé pendant l'écran
-- de chargement (Core, 2.0.2).
if AFR.Prechauffages then
    table.insert(AFR.Prechauffages, function()
        if not index_desc then ConstruireIndex() end
    end)
end

-- Rangs de compétence : le champ R de DB.Sorts est parfois resté anglais
-- (« Apprentice » sur 33388)... et parfois N'EST PAS un rang du tout (noms de
-- plats, « Deprecated », ids — 284 valeurs distinctes mesurées par l'audit).
-- LISTE BLANCHE stricte : on ne réécrit la sous-ligne du client QUE si R est
-- un rang connu ; sinon on laisse l'affichage du client tel quel.
local RANGS = {
    ["Apprentice"] = "Apprenti", ["Novice"] = "Novice",
    ["Journeyman"] = "Compagnon", ["Expert"] = "Expert",
    ["Artisan"] = "Artisan", ["Master"] = "Maître",
    ["Grand Master"] = "Grand maître",
    ["Passive"] = "Passif", ["Specialization"] = "Spécialisation",
    ["Spec Passive"] = "Passif de spécialisation",
}

-- En-têtes de catégorie absents de DB_Libelles (customs Ascension inclus).
local ENTETES = {
    ["Beast Training"] = "Dressage de bête",
    ["Weapon Skills"] = "Compétences d'armes",
    ["Armor Proficiencies"] = "Maniement des armures",
    ["Mysticism"] = "Mysticisme",
    ["Mystic Enchanting"] = "Enchantement mystique",
    ["Archaeology"] = "Archéologie",
    -- écoles de sorts des maîtres de classe CoA, au fil des observations
    ["Fel Rifts"] = "Failles gangrenées",
}

-- « (Rank 1) » sur les sorts de classe : générique, indépendant du pont —
-- même quand le sort est inconnu de la base, son rang parle français.
local function TraduireRang(fs)
    if not (fs and fs.GetText and fs:IsShown()) then return end
    local texte = fs:GetText()
    if type(texte) ~= "string" then return end
    local nouveau, n = string.gsub(texte, "^%(Rank (%d+)%)$", "(Rang %1)")
    if n > 0 then fs:SetText(nouveau) end
end

-- ----------------------------------------------------------------------------
-- Habillage de la fenêtre (boutons, étiquettes, accueil)
-- ----------------------------------------------------------------------------
-- L'accueil vient du SERVEUR (GetTrainerGreetingText) : on ne traduit que les
-- phrases connues, littéralement. À compléter au fil des observations.
local SALUTS = {
    ["Hello! Ready for some training?"] =
        "Bonjour ! Prêt pour un peu d'entraînement ?",
}

local BOUTONS = {
    "ClassTrainerTrainButton", "ClassTrainerCancelButton",
    "ClassTrainerExitButton",
}

local mots

local function Mots()
    if not mots then
        mots = {
            ["Train"] = AFR.DB.UI["TRAIN"],
            ["Exit"] = AFR.DB.UI["EXIT"],
            ["Cancel"] = AFR.DB.UI["CANCEL"],
            ["Cost:"] = AFR.DB.UI["COSTS_LABEL"],
        }
    end
    return mots
end

local function RepeindreChrome()
    local m = Mots()
    for _, nom in ipairs(BOUTONS) do
        local bouton = _G[nom]
        if bouton and bouton.GetText then
            local fr = m[bouton:GetText() or ""]
            if fr then bouton:SetText(fr) end
        end
    end
    if ClassTrainerCostLabel and ClassTrainerCostLabel.GetText then
        local fr = m[ClassTrainerCostLabel:GetText() or ""]
        if fr then ClassTrainerCostLabel:SetText(fr) end
    end
    if ClassTrainerGreetingText then
        local accueil = ClassTrainerGreetingText:GetText()
        if accueil and SALUTS[accueil] then
            ClassTrainerGreetingText:SetText(SALUTS[accueil])
        end
    end
end

-- ----------------------------------------------------------------------------
-- Liste des services : en-têtes de compétence (« Riding » -> DB_Libelles) et
-- lignes de service (nom N + rang R par le pont des descriptions)
-- ----------------------------------------------------------------------------
local function RepeindreListe()
    local i = 1
    while true do
        local bouton = _G["ClassTrainerSkill" .. i]
        if not bouton then break end
        if bouton:IsShown() and bouton.GetID then
            local skillIndex = bouton:GetID()
            local serviceName, _, serviceType =
                GetTrainerServiceInfo(skillIndex)
            if serviceType == "header" then
                local fr = serviceName and (AFR.DB.Libelles[serviceName]
                    or ENTETES[serviceName])
                if fr then bouton:SetText(fr) end
            elseif serviceName then
                local s = ParDescription(
                    GetTrainerServiceDescription(skillIndex))
                if s then
                    -- deux espaces : le retrait du client (voir son Update)
                    if s.N then bouton:SetText("  " .. s.N) end
                    local sous = _G["ClassTrainerSkill" .. i .. "SubText"]
                    local rang = s.R and RANGS[s.R]
                    if rang and sous and sous:IsShown() then
                        sous:SetText("(" .. rang .. ")")
                    end
                end
            end
        end
        TraduireRang(_G["ClassTrainerSkill" .. i .. "SubText"])
        i = i + 1
    end
end

-- ----------------------------------------------------------------------------
-- Panneau de détail : nom, rang, description, et la ligne « Requires: ... »
-- composée par le client avec des nombres TEINTÉS (« Level |cffff2020 30|r,
-- Riding (|cffffffff100|r) ») — on découpe sur les virgules et on traduit
-- chaque morceau en gardant l'habillage.
-- ----------------------------------------------------------------------------
local function TraduireSegment(seg)
    local nombre = string.match(seg, "^Level (|c%x%x%x%x%x%x%x%x%d+|r)$")
        or string.match(seg, "^Level (%d+)$")
    if nombre then return "Niveau " .. nombre end
    -- « Riding (|cffffffff100|r) » : nom de compétence + rang entre parenthèses
    local nom, parens = string.match(seg, "^(.-)%s*(%(.+%))$")
    if nom and AFR.DB.Libelles[nom] then
        return AFR.DB.Libelles[nom] .. " " .. parens
    end
    -- Aptitude/étape prérequise : le nom arrive ENROBÉ de codes couleur
    -- (TRAINER_REQ_ABILITY = « |cffffffff%s|r ») — on déshabille, on
    -- cherche le cœur, on rhabille.
    local avant, coeur, apres = string.match(seg,
        "^(|c%x%x%x%x%x%x%x%x)(.-)(|r)$")
    if coeur then
        return avant .. (AFR.DB.Libelles[coeur] or coeur) .. apres
    end
    -- nom nu : dictionnaire ou anglais gardé
    return AFR.DB.Libelles[seg] or seg
end

local function TraduireExigences()
    local zone = ClassTrainerSkillRequirements
    local texte = zone and zone:GetText()
    if type(texte) ~= "string" or texte == "" then return end
    local reste = string.match(texte, "^Requires:%s*(.+)$")
    if not reste then return end
    local sortie = {}
    for seg in string.gmatch(reste, "[^,]+") do
        table.insert(sortie,
            TraduireSegment(string.match(seg, "^%s*(.-)%s*$")))
    end
    zone:SetText((AFR.DB.UI["REQUIRES_LABEL"] or "Requiert :") .. " "
        .. table.concat(sortie, ", "))
end

local function RepeindreDetail()
    local id = ClassTrainerFrame and ClassTrainerFrame.selectedService
    if id then
        local s = ParDescription(GetTrainerServiceDescription(id))
        if s then
            if s.N and ClassTrainerSkillName then
                ClassTrainerSkillName:SetText(s.N)
            end
            local rang = s.R and RANGS[s.R]
            if rang and ClassTrainerSubSkillName
                and ClassTrainerSubSkillName:IsShown() then
                ClassTrainerSubSkillName:SetText("(" .. rang .. ")")
            end
            if s.D and ClassTrainerSkillDescription then
                -- Le client affiche le texte CALCULÉ ; notre D est un
                -- MODÈLE à formules. Le moteur d'alignement des sorts
                -- (info-bulles) sait marier les deux : il reprend les
                -- nombres affichés et les replace dans le français.
                local brut = GetTrainerServiceDescription(id)
                local fr
                if type(brut) == "string" and brut ~= ""
                    and s.DE and AFR.TraduireTexteSort then
                    local ok, resultat =
                        pcall(AFR.TraduireTexteSort, s.D, s.DE, brut)
                    if ok then fr = resultat end
                end
                -- Repli : moteur de calcul du client sur le modèle français.
                if not fr and C_Format
                    and type(C_Format.Format) == "function" then
                    local ok, calcule = pcall(C_Format.Format, s.D, true)
                    if ok and type(calcule) == "string"
                        and calcule ~= "" then
                        fr = calcule
                    end
                end
                -- Jamais de formule brute à l'écran.
                if fr and not string.find(fr, "${", 1, true) then
                    ClassTrainerSkillDescription:SetText(fr)
                end
            end
        end
    end
    TraduireRang(ClassTrainerSubSkillName)
    TraduireExigences()
end

local function Repeindre()
    if not Actif() then return end
    RepeindreChrome()
    RepeindreListe()
    RepeindreDetail()
end

-- ----------------------------------------------------------------------------
-- Branchement. Blizzard_TrainerUI se charge À LA DEMANDE (première visite
-- chez un maître) : on guette son chargement si besoin. Les greffes sont des
-- hooksecurefunc APRÈS la mise à jour du client : il écrit l'anglais, on
-- repasse en français, à chaque rafraîchissement (défilement, filtre, achat).
-- ----------------------------------------------------------------------------
local function Brancher()
    if type(ClassTrainerFrame_Update) == "function" then
        hooksecurefunc("ClassTrainerFrame_Update", Repeindre)
    end
    if type(ClassTrainer_SetSelection) == "function" then
        hooksecurefunc("ClassTrainer_SetSelection", function()
            if Actif() then RepeindreDetail() end
        end)
    end
end

-- Info-bulle au SURVOL d'un service (GameTooltip:SetTrainerService) : nom
-- par le pont, description alignée par le moteur des sorts.
if GameTooltip and type(GameTooltip.SetTrainerService) == "function" then
    hooksecurefunc(GameTooltip, "SetTrainerService", function(tooltip, id)
        if not Actif() or not id then return end
        local brut = GetTrainerServiceDescription(id)
        local s = ParDescription(brut)
        if not s then return end
        local modifie = false
        local l1 = GameTooltipTextLeft1
        if s.N and l1 and l1:GetText() and l1:GetText() ~= "" then
            l1:SetText(s.N)
            modifie = true
        end
        if s.D and s.DE and AFR.TraduireTexteSort then
            for i = 2, tooltip:NumLines() do
                local zone = _G["GameTooltipTextLeft" .. i]
                local texte = zone and zone:GetText()
                if texte and string.len(texte) > 12 then
                    local ok, fr = pcall(AFR.TraduireTexteSort,
                        s.D, s.DE, texte)
                    if ok and fr
                        and not string.find(fr, "${", 1, true) then
                        zone:SetText(fr)
                        modifie = true
                    end
                end
            end
        end
        if modifie and tooltip:IsShown() then tooltip:Show() end
    end)
end

-- Diagnostic : /afrmaitre — montre la description BRUTE (normalisée, codes
-- échappés, par tronçons) du service sélectionné et dit si le pont trouve.
SLASH_AFRMAITRE1 = "/afrmaitre"
SlashCmdList["AFRMAITRE"] = function()
    local id = ClassTrainerFrame and ClassTrainerFrame.selectedService
    if not id then
        print("AFR : sélectionne d'abord un service chez le maître.")
        return
    end
    local brut = GetTrainerServiceDescription(id)
    if type(brut) ~= "string" or brut == "" then
        print("AFR : ce service n'a pas de description.")
        return
    end
    local s = ParDescription(brut)
    print("AFR maître : pont = "
        .. (s and (s.N or "?") or "INTROUVABLE") .. " | brut = " .. #brut)
    local visible = string.gsub(Normale(brut), "|", "||")
    for debut = 1, #visible, 220 do
        print(string.sub(visible, debut, debut + 219))
    end
end

if type(ClassTrainerFrame_Update) == "function" then
    Brancher()
else
    local veilleur = CreateFrame("Frame")
    veilleur:RegisterEvent("ADDON_LOADED")
    veilleur:SetScript("OnEvent", function(self, _, nom)
        if nom == "Blizzard_TrainerUI" then
            self:UnregisterEvent("ADDON_LOADED")
            Brancher()
        end
    end)
end
