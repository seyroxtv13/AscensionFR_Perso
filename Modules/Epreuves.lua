-- Fenêtre des Épreuves d'Ascension (« Trials ») en français.
--
-- DEUX SOURCES DE TEXTE, DEUX BASES
-- --------------------------------
--   * le CONTENU (noms et descriptions des 297 épreuves) vient de
--     Challenge.dbc -> AFR.DB.Epreuves, indexé par le texte anglais ;
--   * les LIBELLÉS de la fenêtre (About, Activate, Leaderboard…) sont des
--     GlobalStrings -> AFR.DB.UI, indexé par le NOM de la globale. Il faut
--     donc un index inverse pour les retrouver depuis leur texte anglais.
--
-- AUCUNE GLOBALE N'EST ÉCRITE. On s'accroche aux mixins de la fenêtre avec
-- hooksecurefunc : notre code passe APRÈS le leur et repose simplement le
-- texte. Si Ascension change sa fenêtre, l'accroche ne trouve rien et
-- l'anglais revient — dégradation propre, jamais de casse.

local AFR = AscensionFR

-- Déclaré tout en haut : `Balayer` est APPELÉ dans Brancher() bien avant
-- d'être défini plus bas. Sans cette réservation, l'appel visait une variable
-- globale inexistante et le balayage ne tournait jamais — en silence, car il
-- est enveloppé dans un pcall.
local Balayer

-- Même raison pour ces deux-là : Brancher les lit aussi. Déclarés plus bas,
-- Brancher lisait la GLOBALE `remplaces` (nil) et « remplaces - avant »
-- levait une erreur — avalée par pcall, donc le branchement échouait pour
-- toujours et le rebalayage ne tournait JAMAIS. Trouvé par l'audit
-- adversarial du 20/07/2026, invisible autrement.
local remplaces = 0        -- diagnostic : combien de textes changés
-- Fenêtres À REBALAYER au prochain tick de la veilleuse (2.0.1 : on ne
-- balaie plus JAMAIS UIParent entier — chaque texte traduit re-déclenchait
-- un parcours de TOUTE l'interface, une fois par seconde en jeu actif :
-- c'étaient les mini-blocages du jour de sortie, chez Ruxar comme chez
-- Dan). Clé = le cadre RACINE concerné, valeur = true (dédoublonne).
local a_balayer = {}
local a_balayer_nb = 0

-- La racine d'une zone de texte : la fenêtre de premier niveau qui la
-- contient. C'est ELLE qu'on rebalaie — elle est ouverte et vivante.
local function RacineDe(zone)
    local cadre = zone
    for _ = 1, 12 do
        if type(cadre) ~= "table" or type(cadre.GetParent) ~= "function" then
            return nil
        end
        local parent = cadre:GetParent()
        if not parent or parent == UIParent or parent == WorldFrame then
            return cadre ~= zone and cadre or nil
        end
        cadre = parent
    end
    return nil
end

local function DemanderBalayage(cadre)
    if cadre and not a_balayer[cadre] and a_balayer_nb < 8 then
        a_balayer[cadre] = true
        a_balayer_nb = a_balayer_nb + 1
    end
end

local function Actif()
    return not (AFR.Actif and not AFR.Actif())
end

-- Interrupteur d'enquête, sans /reload :
--   /run AscensionFRSaved.Options.sansInterception = true    (couper)
--   /run AscensionFRSaved.Options.sansInterception = nil     (rétablir)
-- Neutralise TOUTE l'interception d'affichage (Épreuves, hauts faits,
-- bulles, balayage). Sert à départager « c'est notre addon » de « c'est le
-- jeu » quand une fenêtre se comporte bizarrement.
local function Coupee()
    local options = AscensionFRSaved and AscensionFRSaved.Options
    return options and options.sansInterception
end

-- Index inverse des GlobalStrings, construit à la PREMIÈRE ouverture de la
-- fenêtre seulement : inutile de le payer pour les joueurs qui n'y vont pas.
local libelles
local function Libelle(texte)
    if not libelles then
        libelles = {}
        for cle, francais in pairs(AFR.DB.UI or {}) do
            local anglais = _G[cle]
            if type(anglais) == "string" and anglais ~= ""
                and type(francais) == "string" and francais ~= ""
                and anglais ~= francais then
                libelles[anglais] = francais
            end
        end
    end
    return libelles[texte]
end

local function Francais(texte)
    if type(texte) ~= "string" or texte == "" then return nil end
    local t = AFR.DB.Epreuves and AFR.DB.Epreuves[texte]
    if type(t) == "string" and t ~= "" then return t end
    -- PONT DES NOMS DE SORTS (21/07) : le grimoire et les fenêtres balayées
    -- passent par CE chemin-ci, pas par FrancaisLigne — les deux doivent
    -- connaître le pont (« Passif » se traduisait, « Dodge » non : c'était
    -- exactement cette ligne qui manquait).
    local noms = AFR.DB.SortsNoms
    local n = noms and noms[texte]
    if type(n) == "string" and n ~= "" then return n end
    -- PONT DES NOMS D'OBJETS (22/07) : la collection Vanity, la garde-robe
    -- et la forge affichent des noms d'objets par leur TEXTE seul.
    local objets = AFR.DB.ObjetsNoms
    local o = objets and objets[texte]
    if type(o) == "string" and o ~= "" then return o end
    -- « Rank 1 » sous les noms du grimoire.
    local rang = string.match(texte, "^Rank (%d+)$")
    if rang then return "Rang " .. rang end
    -- Descriptions de sorts à nombres calculés (cartes CoA) — en dernier :
    -- l'index flou ne sert que si rien d'exact n'a répondu.
    return Libelle(texte)
        or (AFR.DescriptionSort and AFR.DescriptionSort(texte))
end

-- Repose le texte en français sur la zone visée. On compare avant d'écrire :
-- réécrire la même chaîne à chaque rafraîchissement ferait clignoter le cadre.
local function Poser(zone, texte)
    if not Actif() or type(zone) ~= "table" then return end
    local fr = Francais(texte)
    if fr and zone.GetText and zone:GetText() ~= fr then
        zone:SetText(fr)
    end
end

-- LE VRAI POINT D'ACCROCHE : l'API qui FOURNIT les données.
--
-- Accrocher les mixins ne marche pas : `Mixin(cadre, …)` COPIE les fonctions
-- dans chaque cadre à sa construction, qui a lieu avant qu'on puisse
-- intervenir. Modifier la table du mixin après coup ne touche donc aucun
-- cadre existant (constaté en jeu le 20/07/2026 : rien n'était traduit alors
-- que tout compilait).
--
-- On enveloppe donc `C_Challenge`, en amont de tout affichage. Chaque texte
-- rendu passe par notre dictionnaire ; tout le reste — nombres, booléens,
-- tables — ressort intact. Si un texte est inconnu, l'anglais passe tel quel.
-- Les fonctions sont nommées EXPLICITEMENT, pas énumérées par pairs().
-- Première tentative en jeu : pairs(C_Challenge) n'a rien rendu, donc rien
-- n'a été enveloppé alors que la table existait bien — signe que ses
-- fonctions vivent derrière une métatable, invisibles à l'énumération.
-- La liste vient des appels réellement présents dans le client.
local API = {
    C_Challenge = {
        "GetChallengeInfo", "GetChallengeInfoByLevel", "GetChallengeAtIndex",
        "GetChallengesWithGroupID", "GetPendingChallenges",
        -- Les onglets Restrictions / Prérequis passent par celles-ci.
        "GetModifierLocalization", "GetConditionLocalization",
        "GetRuleLocalization", "GetRequirementLocalization",
    },
    C_TrialCreator = {
        "GetTrialInfo", "GetTrialAtIndex", "GetActiveTrial",
    },
}

local function Traduire(...)
    -- select("#", …) et unpack(1, n), PAS table.getn : un nil au MILIEU des
    -- retours de l'API tronquerait tout ce qui suit — la fenêtre des
    -- Épreuves perdrait des données sans erreur (audit du 20/07/2026).
    local n = select("#", ...)
    local retours = {...}
    for i = 1, n do
        if type(retours[i]) == "string" then
            local ok, fr = pcall(Francais, retours[i])
            if ok and fr then retours[i] = fr end
        end
    end
    return unpack(retours, 1, n)
end

-- Marque les fonctions déjà traitées. Sans ce garde-fou, une seconde passe
-- enveloppe l'enveloppe : les couches s'empilent et le jeu ralentit à chaque
-- appel (vécu le 20/07/2026 — la surveillance ne s'arrêtait pas et
-- réenveloppait une fois par seconde).
local posees = {}

local function EnvelopperAPI()
    local n = 0
    for espace, fonctions in pairs(API) do
        local table_api = _G[espace]
        if type(table_api) == "table" then
            for _, nom in ipairs(fonctions) do
                local ancienne = table_api[nom]
                if type(ancienne) == "function" and not posees[ancienne] then
                    local nouvelle = function(...)
                        return Traduire(ancienne(...))
                    end
                    posees[ancienne] = true
                    posees[nouvelle] = true
                    table_api[nom] = nouvelle
                    n = n + 1
                end
            end
        end
    end
    if n > 0 and AFR.Debug then
        AFR.Debug("Épreuves :", n, "fonctions enveloppées")
    end
    return n > 0
end

-- Rend VRAI si l'enveloppe est posée : c'est ce que la veilleuse attend pour
-- s'arrêter. Sans cette valeur de retour, elle tournait indéfiniment.
local mixins_poses = false

local function Brancher()
    local pose = EnvelopperAPI()

    -- Les accroches de mixin ne se posent QU'UNE FOIS : hooksecurefunc empile
    -- sans jamais remplacer, donc une seconde passe doublerait le travail à
    -- chaque appel.
    if mixins_poses then return pose end
    mixins_poses = true

    -- Filet de sécurité : si un cadre est construit APRÈS nous, il prendra la
    -- version accrochée du mixin. Sans effet sur les cadres déjà bâtis — d'où
    -- l'enveloppe de l'API ci-dessus, qui est le vrai mécanisme.
    if type(ChallengeItemMixin) == "table"
        and type(ChallengeItemMixin.SetName) == "function" then
        hooksecurefunc(ChallengeItemMixin, "SetName", function(self, nom)
            Poser(self and self.Text, nom)
        end)
    end

    -- Le panneau de détail : titre, sous-titre, description.
    local M = ChallengeExtendedInfoMixin
    if type(M) ~= "table" then return pose end
    if type(M.SetTitle) == "function" then
        hooksecurefunc(M, "SetTitle", function(self, texte)
            Poser(self and self.Title, texte)
        end)
    end
    if type(M.SetSubText) == "function" then
        hooksecurefunc(M, "SetSubText", function(self, texte)
            Poser(self and self.SubText, texte)
        end)
    end
    if type(M.ShowAboutTab) == "function" then
        hooksecurefunc(M, "ShowAboutTab", function(self, propos)
            Poser(self and self.Description, propos)
        end)
    end

    -- Rattrape ce qui était déjà à l'écran avant notre arrivée.
    local avant = remplaces
    pcall(Balayer, UIParent, 1)
    if AFR.Debug then
        AFR.Debug("Épreuves : balayage,", remplaces - avant, "textes rattrapés")
    end
    return pose
end

-- ==========================================================================
-- L'INTERCEPTION À L'AFFICHAGE — le mécanisme qui marche
-- ==========================================================================
-- Après trois échecs (mixins copiés, pairs() aveugle, API arrivant trop tard
-- et surtout non empruntée par l'affichage), on cesse de chercher D'OÙ vient
-- le texte : on le prend AU MOMENT où il est posé à l'écran.
--
-- Toutes les zones de texte du jeu partagent une même table de méthodes. En
-- s'y accrochant une seule fois, on voit passer chaque texte affiché, quel
-- que soit le chemin qu'il a emprunté.
--
-- CE QUI REND LA CHOSE SÛRE :
--   * on ne consulte QUE le dictionnaire des Épreuves (471 entrées) — un
--     texte inconnu ressort intact, donc aucun risque de traduire par erreur
--     un texte d'un autre addon ;
--   * une seule recherche dans une table par changement de texte : le coût
--     est négligeable ;
--   * un verrou empêche notre propre écriture de nous rappeler en boucle ;
--   * aucune globale n'est écrite.
-- Les LIBELLÉS du cadre (About, Activate, Leaderboard…) sont des
-- GlobalStrings, déjà traduites dans DB.UI. On les nomme UNE PAR UNE plutôt
-- que d'ouvrir le dictionnaire entier : c'est ce qui garantit qu'aucun texte
-- d'un autre addon ne sera traduit par accident.
local CHROME = {
    "CHALLENGES_ABOUT", "CHALLENGES_EDITOR_LABEL_ABOUT",
    "CHALLENGES_LEADERBOARD", "CHALLENGES_AURAS",
    "CHALLENGES_RESTRICTIONS", "CHALLENGES_EDITOR_LABEL_RESTRICTIONS",
    "CHALLENGES_REQUIREMENTS",
    "CHALLENGES_EDITOR_LABEL_ACTIVATION_REQUIREMENTS",
    "CURRENT_LEVEL_COLON", "ACTIVATE", "DEACTIVATE",
    "CHALLENGES", "CHALLENGES_STORE", "CUSTOM_TRIALS", "TRIAL_BUILDER",
    "GAMEMODES", "TRIALS", "PATH_TO_ASCENSION",
    -- bulle de performance du menu de jeu (paragraphes explicatifs)
    "NEWBIE_TOOLTIP_LATENCY", "NEWBIE_TOOLTIP_FRAMERATE",
    "NEWBIE_TOOLTIP_MEMORY",
}

-- Construit à la première interception : { anglais du client -> français }.
local chrome
local function Chrome(texte)
    if not chrome then
        chrome = {}
        for _, cle in ipairs(CHROME) do
            local anglais, francais = _G[cle], AFR.DB.UI and AFR.DB.UI[cle]
            if type(anglais) == "string" and anglais ~= ""
                and type(francais) == "string" and francais ~= ""
                and anglais ~= francais then
                chrome[anglais] = francais
            end
        end
    end
    return chrome[texte]
end

-- Un libellé peut être affiché SUIVI de sa valeur : « Current Level: 1 ».
-- L'égalité exacte échoue alors, alors que le libellé est bien connu. On
-- réessaie sur le DÉBUT du texte, mais seulement pour les libellés qui se
-- terminent par « : » — un préfixe aussi caractéristique ne peut pas se
-- confondre avec une phrase ordinaire.
local prefixes
local function Prefixe(texte)
    if not prefixes then
        prefixes = {}
        for anglais, francais in pairs(AFR.DB.Epreuves or {}) do
            if string.sub(anglais, -1) == ":" then
                table.insert(prefixes, {en = anglais, fr = francais,
                                        n = string.len(anglais)})
            end
        end
    end
    for _, p in ipairs(prefixes) do
        if string.sub(texte, 1, p.n) == p.en then
            return p.fr .. string.sub(texte, p.n + 1)
        end
    end
end

-- Correspondance TOLÉRANTE aux fins de ligne — le dernier recours.
--
-- Le fichier de données contient « \r\n » ; ce que la fenêtre affiche n'est
-- pas toujours identique octet pour octet (le client réécrit parfois les
-- sauts de ligne). Résultat observé : une description d'UN paragraphe
-- passait, la même à TROIS paragraphes échouait — seule différence, les
-- sauts de ligne. On indexe donc aussi chaque texte sous une forme
-- normalisée (sauts unifiés, bords rognés) et on cherche l'arrivée sous la
-- même forme. Le français est posé avec des \n simples, ce que les zones de
-- texte affichent proprement.
local normalise

-- Nettoyage LÉGER, pour les VALEURS françaises : fins de ligne unifiées,
-- bords rognés — rien qui abîme le texte affiché.
local function Normaliser(texte)
    texte = string.gsub(texte, "\r\n", "\n")
    texte = string.gsub(texte, "\r", "\n")
    texte = string.gsub(texte, "^%s+", "")
    texte = string.gsub(texte, "%s+$", "")
    return texte
end

-- Nettoyage FORT, pour les CLÉS de comparaison seulement. Le client
-- transforme les MOTS-CLÉS à la volée avant affichage : « experience » du
-- fichier de données devient « |Hkeyword:…|hExperience|h » coloré à l'écran
-- (système du Keyword Appendix — élucidé le 20/07/2026 sur les pages de la
-- Voie : celles SANS mot-clé passaient, les autres jamais). On compare donc
-- sans les habillages de lien/couleur et sans la casse. Jamais appliqué aux
-- valeurs : le joueur verrait du texte en minuscules.
local function NormaliserCle(texte)
    texte = Normaliser(texte)
    texte = string.gsub(texte, "|H[^|]*|h", "")          -- ouverture de lien
    texte = string.gsub(texte, "|h", "")                 -- fermeture de lien
    texte = string.gsub(texte, "|c%x%x%x%x%x%x%x%x", "") -- couleur
    texte = string.gsub(texte, "|r", "")
    return string.lower(texte)
end

local function Normalisee(texte)
    if not normalise then
        normalise = {}
        for _, table_db in ipairs({AFR.DB.Epreuves, AFR.DB.HautsFaits}) do
            for anglais, francais in pairs(table_db or {}) do
                normalise[NormaliserCle(anglais)] = Normaliser(francais)
            end
        end
    end
    return normalise[NormaliserCle(texte)]
end

-- 35 000 entrées normalisées d'un coup à la PREMIÈRE info-bulle : un
-- mini-blocage en pleine partie. Préchauffé pendant l'écran de chargement
-- (Core, 2.0.2).
if AFR.Prechauffages then
    table.insert(AFR.Prechauffages,
                 function() Normalisee("préchauffage") end)
end

-- Textes COMPOSÉS : un libellé connu suivi d'un compteur — « Getting
-- Started 20 / 21 » (barre de la Voie), « Page 1 of 4 ». Le libellé se
-- traduit, le compte se garde tel quel.
local function Composee(texte)
    local corps, compte = string.match(texte, "^(.-)%s+(%d+%s*/%s*%d+)$")
    if corps and corps ~= "" then
        local base = AFR.DB.Epreuves
        local fr = (base and base[corps]) or Normalisee(corps)
        if fr then return fr .. " " .. compte end
    end
    local page, total = string.match(texte, "^Page (%d+) of (%d+)$")
    if page then return "Page " .. page .. " sur " .. total end
    -- « Realm First! X » : des milliers de hauts faits qui n'existent qu'en
    -- copie « premier du royaume ». Le cœur X est traduit, l'habillage se
    -- compose ici — l'outil ne traduit plus ces copies une à une.
    local exploit = string.match(texte, "^Realm First! (.+)$")
    if exploit then
        local base, hauts = AFR.DB.Epreuves, AFR.DB.HautsFaits
        local fr = (base and base[exploit]) or (hauts and hauts[exploit])
            or Normalisee(exploit)
        if fr then return "Premier du royaume ! " .. fr end
    end
    -- « Battlegear of Might (0/8) » : nom d'ensemble d'objets suivi du
    -- compteur de pièces, dans la même ligne d'info-bulle (22/07,
    -- chantier complétude — paires ItemSet officielles en base).
    local ensemble, compte = string.match(texte,
                                          "^(.-)%s*(%(%d+/%d+%))$")
    if ensemble and ensemble ~= "" then
        local base = AFR.DB.Epreuves
        local fr = base and base[ensemble]
        if fr then return fr .. " " .. compte end
    end
end

-- Objectifs de quête, sous leurs DEUX habits : « 4/10 Webwood Venom Sac »
-- (ordre inversé des suivis — WatchFrame comme DragonUI) et « Webwood Venom
-- Sac: 4/10 » (format serveur). Objets via le pont DB.ObjetsNoms, tués via
-- l'index des créatures. Dans l'intercepteur : TOUS les suivis en profitent.
local function Objectif(texte)
    -- habillage couleur autour du compteur (« |cff…- 0/1|r Webwood Egg ») :
    -- on retente sur la version nue — perte de teinte assumée.
    if string.find(texte, "|c", 1, true) then
        local nu = string.gsub(texte, "|c%x%x%x%x%x%x%x%x", "")
        nu = string.gsub(nu, "|r", "")
        if nu ~= texte then return Objectif(nu) end
    end
    -- objectif-PHRASE (« Speak to Dirania Silvershine in Shadowglen. ») :
    -- pont TDB LogDescription -> locale officielle, tiret toléré.
    local ponts = AFR.DB.QuetesObjectifs
    if ponts then
        local fr = ponts[texte]
        if fr then return fr end
        local tiret, corps = string.match(texte, "^([%-%s]+)(.+)$")
        if corps and ponts[corps] then return tiret .. ponts[corps] end
    end
    -- tiret toléré PARTOUT : DragonUI le met dans la même chaîne
    local avant, fait, total, nom =
        string.match(texte, "^([%-%s]*)(%d+)/(%d+)%s+(.-)%s*$")
    if nom and nom ~= "" then
        local noms = AFR.DB.ObjetsNoms
        local fr = noms and noms[nom]
        if not fr then
            local coeur = string.match(nom, "^(.-) slain$")
            if coeur and AFR.NomCreatureFrancais then
                local c = AFR.NomCreatureFrancais(coeur)
                if c then fr = c .. " tué(s)" end
            end
        end
        -- fragment d'objectif custom (« Carrion Path traversed ») : le
        -- dictionnaire des objectifs le portera dès qu'il sera récolté
        -- et traduit — le canal est prêt.
        if not fr and ponts then
            fr = ponts[nom]
        end
        if fr then
            return avant .. fait .. "/" .. total .. " " .. fr
        end
        return
    end
    local avant2, nom2, fait2, total2 =
        string.match(texte, "^([%-%s]*)(.-): (%d+)/(%d+)%s*$")
    if nom2 and nom2 ~= "" then
        local noms = AFR.DB.ObjetsNoms
        local fr = noms and noms[nom2]
        if fr then
            return avant2 .. fr .. " : " .. fait2 .. "/" .. total2
        end
    end
end

-- « Level 4 Night Elf Felsworn » (fiche de personnage, bulles de joueurs) :
-- niveau + race + classe, chacun via Libelles — la race peut faire deux
-- mots, la classe arrive parfois TEINTÉE (couleur préservée). On ne touche
-- rien si ni race ni classe ne sont reconnues.
local function NiveauRaceClasse(texte)
    -- Niveau teinté (|cff...22|r) : code couleur EXACT à 8 chiffres hexa.
    -- JAMAIS « %x* » devant le niveau : les chiffres décimaux sont aussi
    -- de l'hexa, « Level 22 » perdait son premier 2 et la fiche affichait
    -- « Niveau 2 » (vécu : signalement de Veb, 21/07 au soir).
    local niveau, reste = string.match(texte,
        "^Level%s+|c%x%x%x%x%x%x%x%x(%d+)|r%s+(.+)$")
    if not niveau then
        niveau, reste = string.match(texte, "^Level%s+(%d+)%s+(.+)$")
    end
    if not niveau then return end
    local libelles = AFR.DB.Libelles
    if not libelles then return end
    local couleur = string.match(reste, "(|c%x%x%x%x%x%x%x%x)")
    local nu = string.gsub(reste, "|c%x%x%x%x%x%x%x%x", "")
    nu = string.gsub(nu, "|r", "")
    local morceaux = {}
    for mot in string.gmatch(nu, "%S+") do
        table.insert(morceaux, mot)
    end
    if #morceaux < 2 then return end
    -- DEUX passes : d'abord la coupe où race ET classe sont reconnues
    -- (sinon « Undead Witch Hunter » devenait race « Undead Witch » +
    -- classe « Hunter », alors que la classe CoA est « Witch Hunter » —
    -- vécu sur le même signalement). Ensuite seulement, la coupe où une
    -- seule des deux moitiés est connue.
    for exiger_les_deux = 1, 0, -1 do
        for coupe = #morceaux - 1, 1, -1 do
            local race = table.concat(morceaux, " ", 1, coupe)
            local classe = table.concat(morceaux, " ", coupe + 1)
            local raceFR = libelles[race]
            local classeFR = libelles[classe]
            local retenu
            if exiger_les_deux == 1 then
                retenu = raceFR and classeFR
            else
                retenu = raceFR or classeFR
            end
            if retenu then
                classeFR = classeFR or classe
                if couleur then
                    classeFR = couleur .. classeFR .. "|r"
                end
                return "Niveau " .. niveau .. " " .. (raceFR or race)
                    .. " " .. classeFR
            end
        end
    end
end

-- Pierre tombale Ironman de la carte + coordonnées : gabarits composés du
-- client custom. Le PSEUDO du mort n'est jamais traduit ; le tueur passe
-- par l'index des créatures ; dates et durées sont francisées.
local MOIS = {
    January = "janvier", February = "février", March = "mars",
    April = "avril", May = "mai", June = "juin", July = "juillet",
    August = "août", September = "septembre", October = "octobre",
    November = "novembre", December = "décembre",
}
local MORT_MOTS = {
    ["Died."] = "Mort.",
    ["[Melee Attack]"] = "[Attaque en mêlée]",
}

local function Unites(t)
    t = string.gsub(t, "(%d+) Hours?", "%1 h")
    t = string.gsub(t, "(%d+) Minutes?", "%1 min")
    t = string.gsub(t, "(%d+) Seconds?", "%1 s")
    return t
end

local function Carte(texte)
    local reste = string.match(texte, "^Failure Reason: (.+)$")
    if reste then
        return "Cause de l'échec : " .. (MORT_MOTS[reste] or reste)
    end
    local qui, niveau = string.match(texte, "^Killer: (.+) %(Level (%d+)%)$")
    if qui then
        local fr = AFR.NomCreatureFrancais and AFR.NomCreatureFrancais(qui)
        return "Tueur : " .. (fr or qui) .. " (niveau " .. niveau .. ")"
    end
    local degats, source = string.match(texte,
        "^Killing Blow: (%d+) Damage from (.+)$")
    if degats then
        return "Coup fatal : " .. degats .. " dégâts de "
            .. (MORT_MOTS[source] or source)
    end
    reste = string.match(texte, "^Duration: (.+)$")
    if reste then return "Durée : " .. Unites(reste) end
    local mois, jour, heure = string.match(texte, "^(%a+) (%d+) at (.+)$")
    if mois and MOIS[mois] then
        return jour .. " " .. MOIS[mois] .. " à " .. heure
    end
    reste = string.match(texte, "^(.+) ago$")
    if reste then return "il y a " .. Unites(reste) end
    reste = string.match(texte, "^Player: (.+)$")
    if reste then return "Joueur : " .. reste end
    reste = string.match(texte, "^Cursor: (.+)$")
    if reste then return "Curseur : " .. reste end
    -- « Hibliaty Level 1 Stormbringer » : pseudo (intact) + niveau + classe
    -- reconnue — la classe arrive parfois teintée, couleur préservée.
    local nu = string.gsub(texte, "|c%x%x%x%x%x%x%x%x", "")
    nu = string.gsub(nu, "|r", "")
    local nom, niv, classe = string.match(nu, "^(%S+) Level (%d+) (.+)$")
    if nom and classe and AFR.DB.Libelles then
        local c = AFR.DB.Libelles[classe]
        if c then
            local couleur = string.match(texte, "(|c%x%x%x%x%x%x%x%x)%s*"
                .. classe:gsub("(%W)", "%%%1"))
            if couleur then c = couleur .. c .. "|r" end
            return nom .. " niveau " .. niv .. " " .. c
        end
    end
    -- « Ironman - Resolute 1x Experience (1) » : au moins Experience
    if string.find(texte, "x Experience", 1, true) then
        return (string.gsub(texte, "x Experience", "x Expérience"))
    end
end

local en_cours = false
-- (`remplaces` et la file `a_balayer` sont déclarés tout en haut :
--  les redéclarer ici créerait une DEUXIÈME variable du même nom, et Brancher
--  et Intercepter ne parleraient plus du même compteur.)

-- Mémoire du verdict de la chaîne de recherche (2.0.1). L'interception
-- voit passer TOUS les textes de l'interface, en boucle : les mêmes
-- reviennent des centaines de fois. Sans mémoire, chaque passage refaisait
-- toute la chaîne (dictionnaires + motifs + normalisation à 4 gsub) — du
-- travail et des déchets mémoire en continu, que le ménage du jeu paie en
-- à-coups. `false` mémorise « aucune traduction ». Vidée au-delà de 8 192.
local memoireVerdict, memoireVerdictNb = {}, 0

-- DESCRIPTIONS de sorts sur les cartes de talents CoA (22/07/2026, phase 2
-- du chantier) : le texte affiché porte des nombres CALCULÉS — le pont des
-- descriptions du dresseur (index flou) retrouve le sort, et l'aligneur
-- replace les nombres de l'écran dans le français. Réservé aux textes
-- longs : une description fait toujours plus de 40 caractères, et les
-- textes courts inonderaient l'index pour rien.
local function DescriptionSort(texte)
    if string.len(texte) <= 40 or not AFR.SortParDescription then return end
    local s = AFR.SortParDescription(texte)
    if not (s and s.D and s.DE) then return end
    return AFR.TraduireTexteSort(s.D, s.DE, texte)
end
AFR.DescriptionSort = DescriptionSort   -- consulté aussi par Francais()

local function Intercepter(zone, texte)
    if en_cours or Coupee() then return end
    if type(texte) ~= "string" or texte == "" then return end
    -- Nombres, pourcentages, « 12/20 », dégâts qui défilent : jamais rien
    -- à traduire, et c'est l'écrasante majorité du trafic en combat. On
    -- sort AVANT la chaîne et sans encombrer la mémoire des verdicts.
    if not string.find(texte, "%a") then return end
    local base = AFR.DB and AFR.DB.Epreuves
    if not base then return end
    local fr
    local connu = memoireVerdict[texte]
    if connu ~= nil then
        if connu == false then return end
        fr = connu
    else
        local hauts = AFR.DB.HautsFaits
        local zones, libelles = AFR.DB.Zones, AFR.DB.Libelles
        local objets_noms = AFR.DB.ObjetsNoms
        fr = base[texte] or (hauts and hauts[texte])
            or (zones and zones[texte]) or (libelles and libelles[texte])
            or (objets_noms and objets_noms[texte])
            or Chrome(texte)
            or Prefixe(texte) or Normalisee(texte) or Composee(texte)
            or Objectif(texte) or NiveauRaceClasse(texte) or Carte(texte)
            or (AFR.TitreQueteFrancais and AFR.TitreQueteFrancais(texte))
            or DescriptionSort(texte)
        if memoireVerdictNb >= 8192 then
            memoireVerdict, memoireVerdictNb = {}, 0
        end
        memoireVerdict[texte] = fr or false
        memoireVerdictNb = memoireVerdictNb + 1
    end
    if not fr or not Actif() then return end
    -- IDENTITÉ = ne rien faire (audit du 20/07 au soir) : une entrée dont le
    -- français égale l'anglais (« Incarnations ») ou ne diffère que par la
    -- casse via Normalisee re-demandait un balayage à CHAQUE balayage →
    -- boucle perpétuelle, une fois par seconde, pour toute la session.
    -- (Depuis la 2.0.1 le balayage est CIBLÉ sur la fenêtre racine — mais
    -- la garde d'identité reste indispensable, même raison.)
    if fr == texte then return end
    -- PARE-TEMPÊTE (22/07/2026, crash de la Forge mystique signalé par un
    -- joueur) : la forge re-pose son texte À CHAQUE IMAGE
    -- (SetText(GetText()) dans son OnUpdate), et un autre addon accroché au
    -- même bouton peut re-poser SON texte en réponse au nôtre — un
    -- ping-pong anglais/français à 60 Hz dont chaque échange gonfle la file
    -- de balayage, jusqu'à étouffer le client 32 bits. Une même zone ne se
    -- retraduit donc pas plus de deux fois par seconde : l'œil ne voit
    -- rien, la tempête meurt de faim.
    local maintenant = GetTime()
    if zone.AFR_dernier == texte
        and maintenant - (zone.AFR_quand or 0) < 0.5 then
        return
    end
    zone.AFR_dernier, zone.AFR_quand = texte, maintenant
    -- pcall : si l'écriture échoue, le verrou doit être relâché quand même —
    -- sinon `en_cours` reste coincé à vrai et TOUTE l'interception meurt en
    -- silence pour la session (audit du 20/07/2026).
    en_cours = true
    local ecrit = pcall(zone.SetText, zone, fr)
    en_cours = false
    if not ecrit then return end
    remplaces = remplaces + 1
    -- Un texte de NOTRE dictionnaire vient de s'afficher : SA fenêtre est
    -- donc ouverte et vivante. On rebalaie CETTE fenêtre (éléments fixes :
    -- onglets, boutons — qui ne repassent jamais par ici), et elle seule.
    -- Balayer UIParent entier ici, c'était l'origine des mini-blocages.
    DemanderBalayage(RacineDe(zone))
end

-- /afr epreuves — dit ce que le module voit réellement. Sans ce compteur,
-- « ce n'est pas traduit » ne distingue pas « le texte n'est pas dans la
-- base », « le balayage n'atteint pas la fenêtre » et « l'accroche manque ».
SLASH_AFREPREUVES1 = "/afrepreuves"
SlashCmdList["AFREPREUVES"] = function()
    local base = AFR.DB and AFR.DB.Epreuves or {}
    local n = 0
    for _ in pairs(base) do n = n + 1 end
    local avant = remplaces
    if Balayer then pcall(Balayer, UIParent, 1) end
    print("|cff0099ffAscensionFR|r — Épreuves")
    print("  textes en base       : " .. n)
    print("  rattrapés à l'instant: " .. (remplaces - avant))
    print("  remplacements totaux : " .. remplaces)
    print("  « About » connu      : " .. tostring(base["About"] or "NON"))
end

-- Il ne suffit PAS d'accrocher les simples zones de texte. Constaté en jeu le
-- 20/07/2026 : les NOMS passaient en français, pas les descriptions. Le pavé
-- de description a une barre de défilement — c'est un composant d'un autre
-- type, avec sa propre table de méthodes, invisible depuis la première.
-- On accroche donc chaque famille de composants susceptible d'afficher du
-- texte, en dédoublonnant celles qui partagent la même table.
local function Familles()
    local essais = {}

    local ok, zone = pcall(function()
        return UIParent:CreateFontString(nil, "BACKGROUND", "GameFontNormal")
    end)
    if ok and zone then table.insert(essais, zone) end

    -- « Button » est indispensable : un ONGLET n'est pas une zone de texte,
    -- c'est un bouton, et il porte sa propre méthode SetText. Sans lui, les
    -- onglets restaient anglais alors que tout le reste passait (constaté en
    -- jeu : 41 remplacements réussis, zéro onglet touché).
    --
    -- « EditBox » est INTERDITE, et ce n'est pas un oubli. Le texte d'une
    -- zone de saisie appartient au joueur — ou sert de repère au code : la
    -- fenêtre de métier compare le contenu de sa case à « Search » pour
    -- savoir si un filtre est actif. L'avoir réécrit en « Recherche » rendait
    -- le filtre actif en permanence : la fenêtre cherchait des recettes
    -- contenant « Recherche » et s'ouvrait VIDE (vécu le 20/07/2026 —
    -- prouvé par l'interrupteur sansInterception).
    for _, genre in ipairs({"SimpleHTML", "ScrollingMessageFrame",
                            "MessageFrame", "Button", "CheckButton"}) do
        local fait, cadre = pcall(CreateFrame, genre)
        if fait and cadre then
            -- IMPÉRATIF : une EditBox capte le CLAVIER dès sa création
            -- (autoFocus vaut vrai par défaut). Laissée telle quelle, cette
            -- boîte invisible avale toutes les touches du joueur : les
            -- raccourcis semblent intacts mais plus rien n'atteint le jeu.
            -- Vécu le 20/07/2026 — clavier mort en jeu, même après relance.
            pcall(function()
                if cadre.SetAutoFocus then cadre:SetAutoFocus(false) end
                if cadre.ClearFocus then cadre:ClearFocus() end
                if cadre.EnableKeyboard then cadre:EnableKeyboard(false) end
                if cadre.EnableMouse then cadre:EnableMouse(false) end
                cadre:Hide()
            end)
            table.insert(essais, cadre)
        end
    end
    return essais
end

-- BALAYAGE UNIQUE du texte DÉJÀ affiché.
--
-- L'interception ne voit que les textes posés APRÈS elle. Or les onglets
-- (« About », « Leaderboard »…) sont écrits une seule fois à la construction
-- de la fenêtre et plus jamais retouchés : ils resteraient anglais pour
-- toujours. Les restrictions, elles, sont réécrites à chaque sélection, d'où
-- la différence constatée en jeu le 20/07/2026.
-- On parcourt donc une fois ce qui est déjà là. Chaque zone passe par le même
-- filtre : un texte hors dictionnaire reste intact.
function Balayer(cadre, profondeur)
    -- Profondeur 10 : la fenêtre des Épreuves empile cadre > liste défilante
    -- > contenu > élément > bouton. Six niveaux n'y suffisaient pas.
    if Coupee() or profondeur > 10 or type(cadre) ~= "table" then return end
    -- Un bouton porte son texte lui-même, pas seulement dans ses régions.
    -- Mais JAMAIS une zone de saisie : son contenu appartient au joueur ou
    -- sert de repère au code (voir le commentaire de Familles()).
    if type(cadre.GetText) == "function" and type(cadre.SetText) == "function"
        and type(cadre.GetRegions) == "function" then
        local ok_genre, genre = pcall(cadre.GetObjectType, cadre)
        if not (ok_genre and genre == "EditBox") then
            local lu, texte = pcall(cadre.GetText, cadre)
            if lu then Intercepter(cadre, texte) end
        end
    end
    if type(cadre.GetRegions) == "function" then
        local ok, zones = pcall(function() return {cadre:GetRegions()} end)
        if ok then
            for _, zone in ipairs(zones) do
                if type(zone) == "table" and zone.GetText and zone.SetText then
                    local lu, texte = pcall(zone.GetText, zone)
                    if lu then Intercepter(zone, texte) end
                end
            end
        end
    end
    if type(cadre.GetChildren) == "function" then
        local ok, enfants = pcall(function() return {cadre:GetChildren()} end)
        if ok then
            for _, enfant in ipairs(enfants) do
                Balayer(enfant, profondeur + 1)
            end
        end
    end
end

local function AccrocherAffichage()
    local vues, n = {}, 0
    for _, exemple in ipairs(Familles()) do
        local meta = getmetatable(exemple)
        local methodes = meta and meta.__index
        if type(methodes) == "table" and not vues[methodes] then
            vues[methodes] = true
            if type(methodes.SetText) == "function" then
                hooksecurefunc(methodes, "SetText", Intercepter)
                n = n + 1
            end
            -- Les textes composés (« Getting Started 20 / 21 », « Page 1
            -- of 4 ») passent par SetFormattedText, que le crochet SetText
            -- ne voit pas : on relit le résultat formaté et on le repasse
            -- au même filtre.
            if type(methodes.SetFormattedText) == "function" then
                hooksecurefunc(methodes, "SetFormattedText", function(zone)
                    if type(zone.GetText) == "function" then
                        local ok, formate = pcall(zone.GetText, zone)
                        if ok then Intercepter(zone, formate) end
                    end
                end)
            end
        end
    end
    if AFR.Debug then
        AFR.Debug("Épreuves :", n, "familles d'affichage interceptées")
    end
    return n > 0
end

pcall(AccrocherAffichage)

-- QUAND s'accrocher : c'est là qu'étaient les deux échecs précédents.
--
-- `C_Challenge` n'existe NI au chargement, NI à PLAYER_LOGIN : le client ne
-- la crée qu'à la première ouverture de la fenêtre, et aucun événement ne
-- l'annonce. Constaté en jeu le 20/07/2026 : la commande `/run print(type(
-- C_Challenge))` répondait « table » une fois la fenêtre ouverte, alors que
-- notre module n'avait rien trouvé au démarrage.
--
-- On surveille donc son apparition, une fois par seconde. C'est le seul
-- signal disponible. Dès qu'elle est là on enveloppe et on s'arrête : plus
-- rien ne tourne ensuite.
local depuis = 0

-- Fenêtres CoA (talents, garde-robe, vanité) : leurs textes sont posés à la
-- construction, avant nos crochets, et elles se chargent À LA DEMANDE sans
-- événement dédié. On rebalaie à chaque APPARITION de l'une d'elles.
-- (Noms relevés dans collections.lua du client : AddTab(...).)
local COA_FENETRES = {
    "CoATalentFrame", "CharacterAdvancement",
    "AppearanceWardrobeFrame", "StoreCollectionFrame",
    -- le relevé complet des onglets AddTab de Collections.lua (22/07) :
    -- la fenêtre mère, l'Architecte, les Cartes de compétence, la Forge
    -- mystique et la Collection saisonnière manquaient à l'appel.
    "Collections", "BuildCreatorFrame", "SkillCardsFrame",
    "EnchantCollection", "SeasonCollectionFrame",
    -- grimoire : la page « Professions » pose ses libellés à la construction
    "SpellBookFrame",
    -- feuille de personnage custom (stats, onglets)
    "CharacterFrame",
    -- carte du monde (titre, cases, coordonnées)
    "WorldMapFrame",
    -- fenêtre de détail de quête (clic sur le suivi)
    "QuestLogDetailFrame",
}
-- (l'ancien suivi coa_visibles a disparu : on re-balaie désormais les
--  fenêtres CoA visibles à chaque tic, pas seulement à l'apparition)

local veilleuse = CreateFrame("Frame")
veilleuse:SetScript("OnUpdate", function(self, ecoule)
    depuis = depuis + ecoule
    if depuis < 1 then return end
    depuis = 0

    -- AVANT la barrière `branche` : ces fenêtres vivent sans C_Challenge.
    for _, nom in ipairs(COA_FENETRES) do
        local cadre = _G[nom]
        if cadre and cadre.IsShown and cadre:IsShown() then
            -- Re-balayée à CHAQUE tic tant qu'elle est ouverte (1x/s,
            -- fenêtre seule — jamais tout l'écran) : les fenêtres CoA se
            -- redessinent en naviguant (onglets, arbres) sans le moindre
            -- événement, et le balayage unique à l'apparition laissait
            -- l'anglais revenir (vécu : cartes de talents, 22/07).
            DemanderBalayage(cadre)
        end
    end

    -- Brancher est idempotent (marques `posees`) : on le repasse tant que
    -- la fenêtre vit. L'ancien verrou « branche » figeait le PREMIER espace
    -- API arrivé — si C_TrialCreator apparaissait avant C_Challenge, l'autre
    -- restait anglais pour la session (audit du 20/07 au soir).
    if type(C_Challenge) == "table" or type(C_TrialCreator) == "table" then
        pcall(Brancher)
    end

    -- La veilleuse NE S'ARRÊTE PLUS après le branchement. Après un /reload,
    -- `C_Challenge` existe déjà — c'est une table du CLIENT, elle survit au
    -- rechargement du Lua. Le balayage se déclenchait donc aussitôt, sur un
    -- écran où la fenêtre n'était pas ouverte, ne trouvait rien, et ne
    -- revenait jamais : les onglets restaient anglais jusqu'à un /afrepreuves
    -- manuel. On rebalaie désormais chaque fois qu'une fenêtre s'anime.
    if a_balayer_nb > 0 then
        for cadre in pairs(a_balayer) do
            if cadre.IsShown and cadre:IsShown() then
                pcall(Balayer, cadre, 1)
            end
        end
        a_balayer = {}
        a_balayer_nb = 0
    end
end)

-- Au cas où l'API serait déjà là (rechargement en cours de partie).
-- SURTOUT ne pas éteindre la veilleuse ici. Après un /reload, C_Challenge
-- existe déjà (table du CLIENT, elle survit au rechargement du Lua) : ce bloc
-- s'exécute donc à chaque fois. L'ancienne ligne « SetScript(nil) » qui
-- traînait ici tuait le rebalayage au démarrage — les onglets restaient
-- anglais après chaque /reload alors que tout le reste passait (20/07/2026).
if type(C_Challenge) == "table" then
    pcall(Brancher)
end

-- ==========================================================================
-- INFO-BULLES (hauts faits des Épreuves, conditions, liens cliqués)
-- ==========================================================================
-- GameTooltip:SetText et AddLine sont des méthodes C du tooltip LUI-MÊME :
-- le crochet posé sur les zones de texte ne les voit jamais passer. On
-- repasse donc sur les lignes affichées à l'ouverture de la bulle — même
-- procédé que le micro-menu dans InterfaceCiblee.lua.

local FORMATS = {
    -- Textes composés avec un nom de joueur dedans. Le français est celui de
    -- DB_Interface (ACHIEVEMENT_TOOLTIP_IN_PROGRESS…). Si Ascension change
    -- sa formulation, le motif ne mord plus et l'anglais reste — sans casse.
    { motif = "^Achievement in progress by (.+)$",
      gabarit = "Haut fait en cours pour %s" },
    { motif = "^Achievement earned by (.+)$",
      gabarit = "Haut fait accompli par %s" },
    -- en-têtes de la bulle de performance du menu de jeu
    { motif = "^Latency: (%d+) ms$",
      gabarit = "Latence : %s ms" },
    { motif = "^Framerate: (%d+) fps$",
      gabarit = "Rafraîchissement : %s ips" },
    { motif = "^AddOn Memory: ([%d%.]+) MB$",
      gabarit = "Mémoire des addons : %s Mo" },
    -- « Rank N » du grimoire (le motif de Francais() ne couvre que le
    -- chemin du balayage ; celui-ci couvre le crochet SetText, 21/07).
    { motif = "^Rank (%d+)$", gabarit = "Rang %s" },
    -- Fenêtre des compagnons/montures : le même gabarit habille les
    -- 1 993 montures du jeu — un seul motif les couvre toutes (21/07).
    { motif = "^Summons and dismisses your (.+)%. This mount's speed "
        .. "changes depending on your Riding skill and location%.$",
      gabarit = "Invoque et renvoie votre %s. La vitesse de cette monture "
        .. "dépend de votre compétence de monte et de l'endroit où vous "
        .. "vous trouvez." },
}

local function FrancaisLigneCalcul(texte)
    local base, hauts = AFR.DB.Epreuves, AFR.DB.HautsFaits
    local zones = AFR.DB.Zones
    -- pont des noms de sorts (grimoire, barres — l'ID n'est pas accessible
    -- au moment où le nom s'affiche, on passe donc par le texte, 21/07)
    local noms_sorts = AFR.DB.SortsNoms
    local fr = (base and base[texte]) or (hauts and hauts[texte])
        or (zones and zones[texte])
        or (noms_sorts and noms_sorts[texte])
    -- Titres de quêtes du JOURNAL (la liste de gauche, 21/07) : le pont
    -- des titres existait, la liste n'y était pas branchée.
    if not fr and AFR.QueteParTitreEN then
        local q = AFR.QueteParTitreEN(texte)
        if q and q.T then fr = q.T end
    end
    fr = fr
        or Chrome(texte) or Prefixe(texte) or Normalisee(texte)
        or Objectif(texte) or NiveauRaceClasse(texte) or Carte(texte)
    if fr then return fr end
    -- « [Monk] Slow and Steady » : l'habillage [Classe] varie d'un haut fait
    -- à l'autre, mais le cœur est déjà dans les dictionnaires.
    local devant, coeur = string.match(texte, "^(%[.-%]%s*)(.+)$")
    if coeur then
        fr = (base and base[coeur]) or (hauts and hauts[coeur])
            or Normalisee(coeur)
        if fr then return devant .. fr end
    end
    -- « Realm First! X » : composé, comme dans Composee.
    local exploit = string.match(texte, "^Realm First! (.+)$")
    if exploit then
        fr = (base and base[exploit]) or (hauts and hauts[exploit])
            or Normalisee(exploit)
        if fr then return "Premier du royaume ! " .. fr end
    end
    -- Titre de zone de la carte du monde : « Stonetalon Mountains (15-60) ».
    -- La tranche de niveaux collée cassait le match exact ; on la détache,
    -- on traduit le nom via le pont de zones, on recolle (21/07).
    if zones then
        local nomZone, apres =
            string.match(texte, "^(.-)(%s*%(%d+%-%d+%))$")
        if nomZone and zones[nomZone] then
            return zones[nomZone] .. apres
        end
    end
    for _, f in ipairs(FORMATS) do
        local argument = string.match(texte, f.motif)
        if argument then
            -- si la capture (nom de monture, de joueur...) a sa propre
            -- traduction exacte, on l'utilise ; sinon elle passe telle
            -- quelle — jamais de texte cassé.
            local capture_fr = base and base[argument]
            return string.format(f.gabarit, capture_fr or argument)
        end
    end
end

-- MÉMOIRE DES RÉSULTATS. Une info-bulle survolée se redessine en continu :
-- chaque ligne repassait toute la chaîne (dictionnaires, motifs FORMATS...)
-- à chaque image — y compris les lignes SANS traduction, les plus
-- nombreuses. On mémorise donc aussi les échecs (`false` = « pas de
-- traduction, inutile de rechercher »). Les bases ne changent pas en cours
-- de session : la mémoire ne peut pas devenir fausse. Vidée au-delà de
-- 8 192 entrées (les textes à nombres dynamiques ne peuvent pas
-- l'engraisser sans fin).
local memoireLigne, memoireLigneNb = {}, 0

local function FrancaisLigne(texte)
    local connu = memoireLigne[texte]
    if connu ~= nil then
        if connu == false then return nil end
        return connu
    end
    local fr = FrancaisLigneCalcul(texte)
    if memoireLigneNb >= 8192 then
        memoireLigne, memoireLigneNb = {}, 0
    end
    memoireLigne[texte] = fr or false
    memoireLigneNb = memoireLigneNb + 1
    return fr
end

local bulle_en_cours = false

local function TraduireBulle(bulle)
    if bulle_en_cours or Coupee() or not Actif()
        or type(bulle) ~= "table" then return end
    local nom = bulle.GetName and bulle:GetName()
    if not nom or type(bulle.NumLines) ~= "function" then return end
    local change = false
    for i = 1, bulle:NumLines() do
        local zone = _G[nom .. "TextLeft" .. i]
        local texte = zone and zone:GetText()
        if texte and texte ~= "" then
            local fr = FrancaisLigne(texte)
            if fr and fr ~= texte then
                zone:SetText(fr)
                change = true
            end
        end
    end
    -- Le français est plus long que l'anglais : sans ce rappel, la bulle
    -- garde sa largeur anglaise et le texte déborde. Le verrou empêche notre
    -- propre Show() de nous rappeler en boucle.
    if change then
        bulle_en_cours = true
        pcall(bulle.Show, bulle)   -- le verrou doit survivre à une erreur
        bulle_en_cours = false
    end
end

-- GameTooltip = le survol ; ItemRefTooltip = la bulle qui s'ouvre quand on
-- CLIQUE un lien de haut fait dans le chat ; WorldMapTooltip = le survol
-- des points de quête sur la CARTE (titres + objectifs dynamiques).
for _, bulle in ipairs({GameTooltip, ItemRefTooltip, WorldMapTooltip}) do
    if bulle then
        if bulle.HookScript then
            bulle:HookScript("OnShow", TraduireBulle)
        end
        hooksecurefunc(bulle, "Show", TraduireBulle)
    end
end

-- ============================================================================
-- LE GRIMOIRE, EN DIRECT (21/07) : les noms des boutons passaient entre les
-- mailles des familles interceptées — crochet explicite sur la mise à jour
-- des boutons du grimoire, mécanique garantie et testable.
-- ============================================================================
if type(SpellButton_UpdateButton) == "function" then
    local SUFFIXES_GRIMOIRE = { "SpellName", "SubSpellName" }
    hooksecurefunc("SpellButton_UpdateButton", function(bouton)
        if Coupee() or not Actif() or not bouton then return end
        local nom = bouton.GetName and bouton:GetName()
        if not nom then return end
        for i = 1, 2 do
            local zone = _G[nom .. SUFFIXES_GRIMOIRE[i]]
            local texte = zone and zone.GetText and zone:GetText()
            if texte and texte ~= "" then
                local ok, fr = pcall(FrancaisLigne, texte)
                if ok and fr and fr ~= texte then
                    zone:SetText(fr)
                end
            end
        end
    end)
end

-- ============================================================================
-- MENUS DÉROULANTS, EN DIRECT (22/07) : les listes UIDropDownMenu (menu de
-- tchat, Emote vocale, clic droit...) ne passent PAS par les familles
-- interceptées — même leçon que le grimoire, même remède : crochet explicite
-- sur l'ajout de chaque entrée. Couvre « Say » -> « Dire », « /hello » ->
-- « /salut » (paires posées par le module Émotes), et tout texte connu de
-- FrancaisLigne.
-- ============================================================================
if type(UIDropDownMenu_AddButton) == "function" then
    hooksecurefunc("UIDropDownMenu_AddButton", function(info, niveau)
        if Coupee() or not Actif() then return end
        niveau = niveau or UIDROPDOWNMENU_MENU_LEVEL or 1
        local liste = _G["DropDownList" .. niveau]
        local n = liste and liste.numButtons
        if not n then return end
        local bouton = _G["DropDownList" .. niveau .. "Button" .. n]
        if not bouton or AFR.EstProtege(bouton) then return end
        local texte = bouton.GetText and bouton:GetText()
        if not texte or texte == "" then return end
        local ok, fr = pcall(FrancaisLigne, texte)
        if ok and fr and fr ~= texte then
            bouton:SetText(fr)
        end
    end)
end
