-- ============================================================================
-- AscensionFR - Récolte
-- Enregistre les textes rencontrés en jeu qui manquent aux bases : le
-- compagnon Python les traduit et régénère les fichiers DB.
-- Commande : /afr  (statut, activation, débogage)
-- ============================================================================
local AFR = AscensionFR

local function Sauvegarde()
    AscensionFRSaved = AscensionFRSaved or {}
    AscensionFRSaved.Options = AscensionFRSaved.Options or {}
    AscensionFRSaved.Recolte = AscensionFRSaved.Recolte or {}
    return AscensionFRSaved.Recolte
end

-- categorie : "Gossip", "TextesPNJ", "Pages", "Sorts", "QuetesProgres",
--             "QuetesRendu", "Divers"
-- cle       : texte anglais ou identifiant numérique
-- valeur    : true (le texte est la clé) ou une table de détails
function AFR.Recolter(categorie, cle, valeur)
    if not cle or cle == "" or valeur == nil then return end
    if type(cle) == "string" then
        cle = string.gsub(strtrim(cle), "\r\n", "\n")
        if cle == "" or not string.match(cle, "%a") then return end
        -- Normalisation : on remet $n à la place du nom du joueur pour que
        -- la traduction serve à tous les personnages.
        local nom = UnitName("player")
        if nom and nom ~= "" then
            cle = string.gsub(cle, nom, "$n")
        end
    end
    local r = Sauvegarde()
    r[categorie] = r[categorie] or {}
    if r[categorie][cle] == nil then
        r[categorie][cle] = valeur
        AFR.Debug("récolté [" .. categorie .. "]",
            type(cle) == "string" and string.sub(cle, 1, 40) or cle)
    end
end

function NombreRecoltes()
    local total = 0
    local r = AscensionFRSaved and AscensionFRSaved.Recolte
    if r then
        for _, cat in pairs(r) do
            for _ in pairs(cat) do total = total + 1 end
        end
    end
    return total
end

-- ----------------------------------------------------------------------------
-- Commande /afr
-- ----------------------------------------------------------------------------
SLASH_ASCENSIONFR1 = "/afrp"
SLASH_ASCENSIONFR2 = "/afr"
SlashCmdList["ASCENSIONFR"] = function(msg)
    -- La casse d'origine est gardée pour la note libre de « signaler ».
    msg = strtrim(msg or "")
    local commande = string.lower(msg)
    AscensionFRSaved = AscensionFRSaved or {}
    AscensionFRSaved.Options = AscensionFRSaved.Options or {}
    local opt = AscensionFRSaved.Options
    if commande == "off" then
        opt.desactive = true
        print("|cff0099ffAscensionFR|r : traduction désactivée (/reload pour appliquer partout).")
    elseif commande == "on" then
        opt.desactive = nil
        print("|cff0099ffAscensionFR|r : traduction activée (/reload conseillé).")
    elseif commande == "debug" then
        opt.debug = not opt.debug
        print("|cff0099ffAscensionFR|r : débogage " .. (opt.debug and "activé" or "désactivé") .. ".")
    -- « /afr interface » a existé de la 1.6.5 à la 1.7.2 : elle coupait la
    -- traduction de l'interface pour débloquer un joueur. Depuis la 1.7.0
    -- cette partie est désactivée pour tout le monde (voir InterfaceUI.lua),
    -- la commande n'avait donc plus aucun effet. On la retire plutôt que de
    -- laisser croire qu'elle agit encore.
    elseif commande == "signaler"
        or string.sub(commande, 1, 9) == "signaler " then
        if AFR.Signaler then AFR.Signaler(string.sub(msg, 10)) end
    elseif commande == "copier" or commande == "journal" then
        if AFR.PartagerJournal then AFR.PartagerJournal() end
    else
        -- Tout le détail est dans le panneau : /afr l'ouvre.
        if AFR.OuvrirOptions then
            AFR.OuvrirOptions()
        else
            print("|cff0099ffAscensionFR|r : "
                .. "/afr on | off | debug | signaler | copier")
        end
    end
end

-- ----------------------------------------------------------------------------
-- Suivi en jeu
--
-- Le jeu n'écrit ses caches et la récolte sur le disque qu'au /reload ou à la
-- déconnexion : le compagnon ne peut rien traduire avant. Et une fois qu'il a
-- traduit, aucun moyen ne lui permet de prévenir le jeu en cours — un addon
-- 3.3.5 ne peut pas lire de fichier en cours de partie.
--
-- On informe donc le joueur aux deux bouts du cycle, au seul moment où l'addon
-- peut le faire : au chargement.
--   1. « +N traductions depuis la dernière fois » -> le /reload a servi.
--   2. « N textes inconnus rencontrés, /reload » -> un /reload servirait.
-- ----------------------------------------------------------------------------
local SEUIL_RAPPEL = 15      -- textes inconnus avant de proposer un /reload
local DELAI_RAPPEL = 300     -- s. entre deux rappels : ne jamais harceler

local function TotalTraductions()
    local total = 0
    for _, t in pairs(AFR.DB) do
        for _ in pairs(t) do total = total + 1 end
    end
    return total
end

local dernierRappel = 0
local dejaSignales = 0

local function ProposerReload()
    if not AFR.Actif() then return end
    local n = NombreRecoltes()
    if n < SEUIL_RAPPEL or n <= dejaSignales then return end
    local maintenant = GetTime()
    if maintenant - dernierRappel < DELAI_RAPPEL then return end
    dernierRappel = maintenant
    dejaSignales = n
    -- Formulation revue le 22/07/2026 (malentendu d'un joueur) : l'ancien
    -- texte disait « envoie ton rapport », donc un rapport DÉJÀ envoyé
    -- semblait perdu — alors que ce compteur ne peut pas savoir ce que le
    -- Compagnon a transmis (l'addon ne lit pas le disque en jeu) : il se
    -- vide quand une MISE À JOUR traduit ces textes.
    print(string.format(
        "|cff0099ffAscensionFR|r : %d textes croisés encore sans "
        .. "traduction. Le |cffffff00Compagnon AscensionFR|r peut les "
        .. "envoyer à l'usine en un clic (ou /afr → « Signaler un "
        .. "souci »). Déjà envoyés ? Rien de perdu : ils reviendront "
        .. "traduits, et ce compteur se videra à la mise à jour qui les "
        .. "traduit.", n))
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:SetScript("OnEvent", function()
    AscensionFRSaved = AscensionFRSaved or {}
    local total = TotalTraductions()
    local avant = AscensionFRSaved.DernierTotal

    print(string.format(
        "|cff0099ffAscensionFR|r chargé : %d traductions. Tapez /afr pour le statut.",
        total))

    -- Le compagnon a-t-il enrichi les bases depuis la dernière session ?
    if avant and total > avant then
        print(string.format(
            "|cff0099ffAscensionFR|r : |cff00ff00+%d nouvelles traductions|r "
            .. "depuis votre dernière session.", total - avant))
        -- Ce qui vient d'être traduit n'est plus à récolter : on vide la
        -- récolte (elle se re-remplira du seul contenu encore manquant).
        -- MAIS on garde les signalements et les échecs : chez un ami sans
        -- compagnon, « +N traductions » signifie juste qu'il a installé la
        -- mise à jour — les effacer ici lui ferait perdre des retours jamais
        -- transmis. Ils sont bornés et se soignent seuls (un échec qui se
        -- remet à traduire s'efface via AFR.OublierEchec).
        AscensionFRSaved.Recolte = {}
        dejaSignales = 0
    end
    AscensionFRSaved.DernierTotal = total
end)

-- Rappel discret : seulement quand il y a vraiment de quoi faire.
local minuteur = CreateFrame("Frame")
local ecoule = 0
minuteur:SetScript("OnUpdate", function(self, delta)
    ecoule = ecoule + delta
    if ecoule < 20 then return end
    ecoule = 0
    ProposerReload()
end)


-- Reliquat du diagnostic « ligne fantôme » (juillet 2026) : efface l'état de
-- bissection resté dans les sauvegardes des testeurs. À garder une version.
local nettoyage = CreateFrame("Frame")
nettoyage:RegisterEvent("PLAYER_ENTERING_WORLD")
nettoyage:SetScript("OnEvent", function(self)
    if AscensionFRSaved then AscensionFRSaved.bisect = nil end
    self:UnregisterAllEvents()
end)

-- ============================================================================
-- Alerte de mise à jour.
-- Un addon 3.3.5 n'a AUCUN accès réseau : impossible de vérifier GitHub ou de
-- se mettre à jour tout seul (il faudrait un programme externe — refusé par
-- les joueurs). La seule voie est le canal inter-addons ENTRE joueurs : chacun
-- annonce sa version (groupe, raid, guilde) ; qui entend plus récent que soi
-- est invité à télécharger. Plus il y a de joueurs à jour, plus l'info circule.
-- ============================================================================
local PREFIXE_VERSION = "AFRVER"
local URL_MAJ = "github.com/LePetitDan/AscensionFR/releases"

local function MaVersion()
    local v = type(GetAddOnMetadata) == "function"
        and GetAddOnMetadata("AscensionFR", "Version")
    -- « 2.3 » -> 2.3. Discipline : UN chiffre après le point (2.9 -> 3.0),
    -- sinon la comparaison numérique mentirait (2.10 vaudrait 2.1).
    return tonumber(v) or 0
end

local function AnnoncerVersion()
    local v = tostring(MaVersion())
    if GetNumRaidMembers() > 0 then
        SendAddonMessage(PREFIXE_VERSION, v, "RAID")
    elseif GetNumPartyMembers() > 0 then
        SendAddonMessage(PREFIXE_VERSION, v, "PARTY")
    end
    if IsInGuild() then
        SendAddonMessage(PREFIXE_VERSION, v, "GUILD")
    end
end

local dejaRelaye = false
local cadreVersion = CreateFrame("Frame")
cadreVersion:RegisterEvent("PLAYER_ENTERING_WORLD")
cadreVersion:RegisterEvent("CHAT_MSG_ADDON")
cadreVersion:SetScript("OnEvent", function(self, evt, prefixe, message, _, expediteur)
    if evt == "PLAYER_ENTERING_WORLD" then
        -- On annonce une fois, un peu après l'entrée en monde (le temps que
        -- guilde et groupe soient connus du client).
        self:UnregisterEvent("PLAYER_ENTERING_WORLD")
        local attente = 0
        self:SetScript("OnUpdate", function(cadre, delta)
            attente = attente + delta
            if attente < 15 then return end
            cadre:SetScript("OnUpdate", nil)
            AnnoncerVersion()
        end)
        return
    end
    -- CHAT_MSG_ADDON
    if prefixe ~= PREFIXE_VERSION or expediteur == UnitName("player") then
        return
    end
    local distante = tonumber(message)
    if not distante then return end
    if distante > MaVersion() then
        -- Plus récent que nous : on prévient le joueur, une fois par version.
        AscensionFRSaved = AscensionFRSaved or {}
        if (AscensionFRSaved.VersionVue or 0) < distante then
            AscensionFRSaved.VersionVue = distante
            print("|cff0099ffAscension FR :|r une nouvelle version est"
                .. " disponible ! Ouvre le |cffffff00Compagnon AscensionFR|r :"
                .. " il l'installe en un clic. (Sans le Compagnon : zip sur"
                .. " |cffffff00" .. URL_MAJ .. "|r à extraire sur ton jeu.)")
        end
    elseif distante < MaVersion() and not dejaRelaye then
        -- Lui est en retard : on fait circuler notre version (une fois).
        dejaRelaye = true
        AnnoncerVersion()
    end
end)
