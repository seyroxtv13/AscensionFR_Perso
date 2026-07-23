-- Traduction d'interface CIBLÉE, surface par surface.
--
-- LA RÈGLE, ET POURQUOI
-- ---------------------
-- L'ancien module écrivait `_G[clé] = français` pour 13 000 chaînes d'un coup.
-- Le code sécurisé de Blizzard lit ces globales, les trouvait souillées, et
-- refusait les sorts en combat : cinq versions pour en sortir (voir
-- InterfaceUI.lua, désactivé depuis la 1.7.0).
--
-- Ici on n'écrit JAMAIS de globale. On remplace le texte AU MOMENT où il
-- s'affiche, comme le font déjà Chat.lua, Tooltips.lua et Quetes.lua. Chaque
-- surface est indépendante : si l'une pose problème, on la retire seule.

local AFR = AscensionFR

local function Actif()
    return not (AFR.Actif and not AFR.Actif())
end

-- ==========================================================================
-- 1. INFO-BULLES DU MICRO-MENU
-- ==========================================================================
-- Les globales elles-mêmes restent ANGLAISES : `GetBindingText` et le code des
-- raccourcis les lisent, et les toucher est précisément ce qui bloquait les
-- sorts. On ne réécrit que la ligne affichée dans l'info-bulle.
--
-- Le texte affiché est « <globale> (C) » : le libellé suivi de la touche. On
-- compare donc par DÉBUT de ligne, et on garde la fin telle quelle — sinon on
-- effacerait le raccourci, la seule information vraiment utile ici.
local MICRO_MENU = {
    "CHARACTER_BUTTON", "SPELLBOOK_ABILITIES_BUTTON", "TALENTS_BUTTON",
    "ACHIEVEMENT_BUTTON", "QUESTLOG_BUTTON", "SOCIAL_BUTTON",
    "HELP_BUTTON", "MAINMENU_BUTTON", "PLAYER_V_PLAYER",
    "NEWBIE_TOOLTIP_CHARACTER", "NEWBIE_TOOLTIP_SPELLBOOK",
    "NEWBIE_TOOLTIP_TALENTS", "NEWBIE_TOOLTIP_ACHIEVEMENT",
    "NEWBIE_TOOLTIP_QUESTLOG", "NEWBIE_TOOLTIP_SOCIAL",
    "NEWBIE_TOOLTIP_LFGPARENT", "NEWBIE_TOOLTIP_PVP",
    "NEWBIE_TOOLTIP_HELP", "NEWBIE_TOOLTIP_MAINMENU",
    "NEWBIE_TOOLTIP_CHARACTERINFO", "NEWBIE_TOOLTIP_SPELLBOOKABILITIES",
    -- Boutons MAISON d'Ascension. Introuvables dans les .lua et .xml du
    -- client : leur texte vit dans GlobalStrings.dbc, que l'usine lit déjà.
    -- Ils étaient donc traduits depuis le début — il ne manquait que leur nom
    -- dans cette liste.
    "NEWBIE_TOOLTIP_TRIALS", "NEWBIE_TOOLTIP_PATH_TO_ASCENSION",
    "TRIALS", "PATH_TO_ASCENSION",
}

-- Construit une fois : { anglais actuel -> français }. On lit la globale
-- plutôt que d'écrire dedans ; l'anglais du client fait foi, y compris si
-- Ascension l'a modifié de son côté.
local paires
local function Paires()
    if paires then return paires end
    paires = {}
    for _, cle in ipairs(MICRO_MENU) do
        local anglais = _G[cle]
        local francais = AFR.DB.UI and AFR.DB.UI[cle]
        if type(anglais) == "string" and anglais ~= ""
            and type(francais) == "string" and francais ~= ""
            and francais ~= anglais then
            table.insert(paires, { en = anglais, fr = francais,
                                   n = string.len(anglais) })
        end
    end
    -- Du plus long au plus court : « Character Info » ne doit pas être coiffé
    -- par une entrée plus courte qui commencerait pareil.
    table.sort(paires, function(a, b) return a.n > b.n end)
    return paires
end

local dedans = false

local function TraduireInfoBulle(bulle)
    if dedans or not Actif() or type(bulle) ~= "table" then return end
    local liste = Paires()
    if #liste == 0 then return end
    local nom = bulle.GetName and bulle:GetName()
    if not nom then return end
    local change = false
    for i = 1, bulle:NumLines() do
        local zone = _G[nom .. "TextLeft" .. i]
        local texte = zone and zone:GetText()
        if texte and texte ~= "" then
            for _, p in ipairs(liste) do
                if string.sub(texte, 1, p.n) == p.en then
                    zone:SetText(p.fr .. string.sub(texte, p.n + 1))
                    change = true
                    break
                end
            end
        end
    end
    -- Le français est plus long que l'anglais : sans ce rappel, la bulle garde
    -- la largeur calculée pour le texte anglais et la phrase déborde.
    if change then
        dedans = true
        bulle:Show()
        dedans = false
    end
end

-- DEUX accroches, et il en faut deux. OnShow ne voit que le TITRE : le client
-- affiche la bulle, PUIS y ajoute la description (GameTooltip_AddNewbieTip).
-- Show() est rappelé après cet ajout — c'est là qu'on attrape la description.
if GameTooltip then
    if GameTooltip.HookScript then
        GameTooltip:HookScript("OnShow", TraduireInfoBulle)
    end
    hooksecurefunc(GameTooltip, "Show", TraduireInfoBulle)
end

-- ==========================================================================
-- 2. COMPTE À REBOURS DE DÉCONNEXION
-- ==========================================================================
-- Le client affiche « 17 %d sec. until logout » : un %d parasite, EN ANGLAIS
-- comme en français. La cause est chez Ascension : `CAMP_TIMER` vaut
-- « %d %s until logout » et ils passent `SECONDS_ABBR` en second argument —
-- or SECONDS_ABBR contient déjà un %d, qui ressort tel quel.
--
-- On ne peut pas corriger la globale : StaticPopup en fait une COPIE FIGÉE au
-- chargement (`StaticPopupDialogs["CAMP"].text = CAMP_TIMER`). On réécrit donc
-- la ligne après coup, avec UN SEUL %d et l'unité en clair — l'argument en
-- trop est alors ignoré par format().
local COMPTEURS = {
    CAMP = "Déconnexion dans %d sec",
    QUIT = "Sortie dans %d sec",
}

-- Les boutons de ces fenêtres viennent aussi d'une copie figée : « Exit now »
-- restait anglais à côté d'un texte français. On les repeint au même moment,
-- toujours sans toucher aux globales.
local BOUTONS = {
    CAMP = { "CANCEL" },
    QUIT = { "QUIT_NOW", "CANCEL" },
}

local function TraduireBoutons(fenetre, nom)
    local cles = BOUTONS[fenetre.which]
    if not cles then return end
    for i, cle in ipairs(cles) do
        local francais = AFR.DB.UI and AFR.DB.UI[cle]
        local bouton = _G[nom .. "Button" .. i]
        if type(francais) == "string" and francais ~= "" and bouton
            and bouton:IsShown() and bouton:GetText() ~= francais then
            bouton:SetText(francais)
        end
    end
end

if type(StaticPopup_OnUpdate) == "function" then
    hooksecurefunc("StaticPopup_OnUpdate", function(fenetre)
        if not Actif() or type(fenetre) ~= "table" then return end
        local modele = fenetre.which and COMPTEURS[fenetre.which]
        if not modele then return end
        local reste = fenetre.timeleft
        if type(reste) ~= "number" or reste <= 0 then return end
        local nom = fenetre.GetName and fenetre:GetName()
        if not nom then return end
        local zone = _G[nom .. "Text"]
        if zone then
            zone:SetFormattedText(modele, math.ceil(reste))
        end
        TraduireBoutons(fenetre, nom)
    end)
end

-- ==========================================================================
-- 3. MENU ÉCHAP (menu de jeu)
-- ==========================================================================
-- Les boutons sont écrits par le XML à la construction, avant nous. On les
-- repeint à l'OUVERTURE du menu, par correspondance de texte. L'anglais
-- LITTÉRAL sert de clé — les étiquettes de la table de données ne sont pas
-- toutes exposées au Lua (leçon des Épreuves) — et le français vient de
-- DB.UI par son étiquette. Si Ascension reformule un bouton, il reste
-- simplement anglais. Les boutons déjà français (ceux de DragonUI) ne
-- correspondent à aucune clé et ne sont pas touchés.
local MENU = {
    { en = "Help / Report Bug", cle = "GM_HELP_LABEL" },
    { en = "Join Discord",      cle = "JOIN_DISCORD" },
    { en = "Sound",             cle = "SOUND_LABEL" },
    { en = "Interface",         cle = "UIOPTIONS_MENU" },
    { en = "Key Bindings",      cle = "KEY_BINDINGS" },
    { en = "Quick Binding",     cle = "QUICK_KEYBINDING" },
    { en = "Macros",            cle = "MACROS" },
    { en = "AddOns",            cle = "ADDONS" },
    { en = "Logout",            cle = "LOGOUT" },
    { en = "Options",           cle = "GAMEOPTIONS_MENU" },
    { en = "Return to Game",    cle = "RETURN_TO_GAME" },
    { en = "Video",             cle = "VIDEOOPTIONS_MENU" },
    { en = "Exit Game",         cle = "EXIT_GAME" },
}

local function PoserMenu(zone)
    local lu, texte = pcall(zone.GetText, zone)
    if not lu or type(texte) ~= "string" then return end
    for _, m in ipairs(MENU) do
        if texte == m.en then
            local fr = AFR.DB.UI and AFR.DB.UI[m.cle]
            if type(fr) == "string" and fr ~= "" then
                pcall(zone.SetText, zone, fr)
            end
            return
        end
    end
end

local function TraduireMenu(cadre, profondeur)
    if profondeur > 3 or type(cadre) ~= "table" then return end
    -- le texte porté par le cadre lui-même (boutons)…
    if type(cadre.GetObjectType) == "function"
        and type(cadre.GetText) == "function"
        and type(cadre.SetText) == "function" then
        local ok, genre = pcall(cadre.GetObjectType, cadre)
        if ok and genre ~= "EditBox" then PoserMenu(cadre) end
    end
    -- …ses zones de texte (le titre « Options »)…
    if type(cadre.GetRegions) == "function" then
        local ok, zones = pcall(function() return {cadre:GetRegions()} end)
        if ok then
            for _, zone in ipairs(zones) do
                if type(zone) == "table" and zone.GetText and zone.SetText then
                    PoserMenu(zone)
                end
            end
        end
    end
    -- …et ses enfants.
    if type(cadre.GetChildren) == "function" then
        local ok, enfants = pcall(function() return {cadre:GetChildren()} end)
        if ok then
            for _, enfant in ipairs(enfants) do
                TraduireMenu(enfant, profondeur + 1)
            end
        end
    end
end

-- Le menu Échap d'Ascension est le cadre « EscapeMenu » (SharedXML,
-- escapemenu.xml), PAS le GameMenuFrame de Blizzard — découvert le
-- 20/07/2026 après une accroche posée dans le vide. Ses boutons sont écrits
-- une seule fois à la construction du client, avant tout addon : d'où le
-- repeint à chaque ouverture. GameMenuFrame reste en secours.
for _, nomCadre in ipairs({"EscapeMenu", "GameMenuFrame"}) do
    local cadreMenu = _G[nomCadre]
    if cadreMenu and cadreMenu.HookScript then
        cadreMenu:HookScript("OnShow", function(self)
            if not Actif() then return end
            pcall(TraduireMenu, self, 1)
        end)
    end
end

-- ==========================================================================
-- 4. FENÊTRES D'OPTIONS (Interface, Raccourcis, Macros, Vidéo, Son)
-- ==========================================================================
-- C'est LA zone qui a causé le désastre de la 1.6 : le code sécurisé lit les
-- globales de raccourcis et d'options, les écrire bloquait les sorts en
-- combat. Ici, AUCUNE globale n'est touchée — on repeint le texte affiché,
-- à l'ouverture de chaque fenêtre, et jamais dans une zone de saisie (le
-- contenu des macros du joueur est sacré).
--
-- Le dictionnaire est un index INVERSE construit une seule fois : pour
-- chaque étiquette traduite de DB.UI, l'anglais actuel se lit dans _G — ce
-- que le client affiche fait foi. Tout texte de ces fenêtres qui correspond
-- exactement à une chaîne officielle passe en français ; le reste ne bouge
-- pas. L'index ne sert QUE dans ces fenêtres : pas de traduction sauvage
-- ailleurs.
local inverse
local function Inverse(texte)
    if not inverse then
        inverse = {}
        for cle, francais in pairs(AFR.DB.UI) do
            local anglais = _G[cle]
            if type(anglais) == "string" and anglais ~= ""
                and type(francais) == "string" and francais ~= ""
                and anglais ~= francais then
                inverse[anglais] = francais
            end
        end
    end
    return inverse[texte]
end

local function PoserOptions(zone)
    local lu, texte = pcall(zone.GetText, zone)
    if not lu or type(texte) ~= "string" or texte == "" then return end
    local fr = Inverse(texte)
    if fr then pcall(zone.SetText, zone, fr) end
end

local function TraduireFenetre(cadre, profondeur)
    if profondeur > 8 or type(cadre) ~= "table" then return end
    if type(cadre.GetObjectType) == "function"
        and type(cadre.GetText) == "function"
        and type(cadre.SetText) == "function" then
        local ok, genre = pcall(cadre.GetObjectType, cadre)
        if ok and genre ~= "EditBox" then PoserOptions(cadre) end
    end
    if type(cadre.GetRegions) == "function" then
        local ok, zones = pcall(function() return {cadre:GetRegions()} end)
        if ok then
            for _, zone in ipairs(zones) do
                if type(zone) == "table" and zone.GetText and zone.SetText then
                    PoserOptions(zone)
                end
            end
        end
    end
    if type(cadre.GetChildren) == "function" then
        local ok, enfants = pcall(function() return {cadre:GetChildren()} end)
        if ok then
            for _, enfant in ipairs(enfants) do
                TraduireFenetre(enfant, profondeur + 1)
            end
        end
    end
end

local accrochees = {}
local function AccrocherFenetre(nom)
    local cadre = _G[nom]
    if not cadre or accrochees[cadre] or not cadre.HookScript then return end
    accrochees[cadre] = true
    cadre:HookScript("OnShow", function(self)
        if not Actif() then return end
        pcall(TraduireFenetre, self, 1)
    end)
    if cadre.IsShown and cadre:IsShown() then
        pcall(TraduireFenetre, cadre, 1)
    end
end

-- Présentes dès la connexion.
for _, nom in ipairs({"InterfaceOptionsFrame", "VideoOptionsFrame",
                      "AudioOptionsFrame"}) do
    AccrocherFenetre(nom)
end

-- Chargées à la demande : on guette leur arrivée. La liste des raccourcis
-- DÉFILE (les lignes se réécrivent à chaque coup de molette) : le simple
-- repeint à l'ouverture ne suffit pas, on suit aussi sa fonction de mise à
-- jour.
local chargeur = CreateFrame("Frame")
chargeur:RegisterEvent("ADDON_LOADED")
chargeur:SetScript("OnEvent", function(self, event, nom)
    if nom == "Blizzard_BindingUI" then
        AccrocherFenetre("KeyBindingFrame")
        if type(KeyBindingFrame_Update) == "function" then
            hooksecurefunc("KeyBindingFrame_Update", function()
                if Actif() and KeyBindingFrame then
                    pcall(TraduireFenetre, KeyBindingFrame, 1)
                end
            end)
        end
    elseif nom == "Blizzard_MacroUI" then
        AccrocherFenetre("MacroFrame")
    end
end)

-- ==========================================================================
-- 5. INFO-BULLES DES FENÊTRES D'OPTIONS
-- ==========================================================================
-- « Display your character's name in the game world. » : les descriptions
-- d'options s'affichent dans la bulle du jeu, pas dans la fenêtre. On les
-- traduit avec le même index inverse, mais SEULEMENT si le propriétaire de
-- la bulle est dans une de nos fenêtres d'options : ce dictionnaire de
-- 14 000 chaînes ne doit jamais toucher une bulle d'objet ou de sort — les
-- lignes d'objets sont un terrain piégé (le client en cache certaines par
-- leur texte anglais, voir Tooltips.lua).
local function ProprietaireDansNosFenetres(bulle)
    if type(bulle.GetOwner) ~= "function" then return false end
    local ok, cadre = pcall(bulle.GetOwner, bulle)
    if not ok then return false end
    local profondeur = 0
    while type(cadre) == "table" and profondeur < 12 do
        if accrochees[cadre] or cadre == _G.EscapeMenu then return true end
        if type(cadre.GetParent) ~= "function" then return false end
        local monte, parent = pcall(cadre.GetParent, cadre)
        if not monte then return false end
        cadre = parent
        profondeur = profondeur + 1
    end
    return false
end

local bulle_options = false
local function TraduireBulleOptions(bulle)
    if bulle_options or not Actif() or type(bulle) ~= "table" then return end
    if not ProprietaireDansNosFenetres(bulle) then return end
    local nom = bulle.GetName and bulle:GetName()
    if not nom or type(bulle.NumLines) ~= "function" then return end
    local change = false
    for i = 1, bulle:NumLines() do
        local zone = _G[nom .. "TextLeft" .. i]
        local texte = zone and zone:GetText()
        if texte and texte ~= "" then
            local fr = Inverse(texte)
            if fr and fr ~= texte then
                zone:SetText(fr)
                change = true
            end
        end
    end
    -- Recalcule la taille (le français est plus long) ; le verrou empêche
    -- notre propre Show() de nous rappeler.
    if change then
        bulle_options = true
        pcall(bulle.Show, bulle)
        bulle_options = false
    end
end

if GameTooltip then
    if GameTooltip.HookScript then
        GameTooltip:HookScript("OnShow", TraduireBulleOptions)
    end
    hooksecurefunc(GameTooltip, "Show", TraduireBulleOptions)
end

-- ==========================================================================
-- 6. FENÊTRES DE CONFIRMATION (invitation de groupe, duel, résurrection…)
-- ==========================================================================
-- « Omegagypsy invites you to a group. » : le texte est COMPOSÉ à
-- l'affichage — gabarit anglais + nom du joueur. On convertit le gabarit en
-- motif (« ^(.+) invites you to a group%.$ ») et on reforme la phrase
-- française officielle autour du nom capturé. Les globales, comme toujours,
-- ne sont pas touchées.
local POPUPS = {
    "INVITATION", "GUILD_INVITATION", "DUEL_REQUESTED",
    "RESURRECT_REQUEST", "RESURRECT_REQUEST_NO_SICKNESS",
    "RESURRECT_REQUEST_TIMER", "CONFIRM_SUMMON", "ARENA_TEAM_INVITATION",
    -- Objets : destruction et confirmation de liage. GOOD_ITEM avant ITEM :
    -- les règles sont essayées dans l'ordre et la première qui mord gagne.
    "DELETE_GOOD_ITEM", "DELETE_ITEM", "EQUIP_NO_DROP", "USE_NO_DROP",
    "LOOT_NO_DROP",
}

local regles

local function EnMotifPopup(gabarit)
    local motif = string.gsub(gabarit,
        "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    motif = string.gsub(motif, "%%%%s", function() return "(.+)" end)
    motif = string.gsub(motif, "%%%%d", function() return "(%-?%d+)" end)
    return "^" .. motif .. "$"
end

local function EnRemplacementPopup(gabarit)
    local rang = 0
    local sortie = string.gsub(gabarit, "%%", "%%%%")
    sortie = string.gsub(sortie, "%%%%[ds]", function()
        rang = rang + 1
        return "%" .. rang
    end)
    return sortie
end

local function ConstruireRegles()
    regles = {}
    for _, cle in ipairs(POPUPS) do
        local anglais, francais = _G[cle], AFR.DB.UI[cle]
        if type(anglais) == "string" and anglais ~= ""
            and type(francais) == "string" and francais ~= ""
            and anglais ~= francais then
            -- Le client anglais vérifie le mot tapé contre sa globale jamais
            -- écrite : il attend « DELETE ». La consigne officielle française
            -- (« Tapez "EFFACER" ») ferait taper le mauvais mot et le bouton
            -- resterait gris — on montre donc DELETE dans la phrase française.
            if cle == "DELETE_GOOD_ITEM" then
                francais = string.gsub(francais, "EFFACER", "DELETE")
            end
            table.insert(regles, { motif = EnMotifPopup(anglais),
                                   rempl = EnRemplacementPopup(francais) })
        end
    end
end

local function TraduirePopups()
    if not Actif() then return end
    if not regles then ConstruireRegles() end
    for i = 1, 4 do
        local cadre = _G["StaticPopup" .. i]
        local zone = _G["StaticPopup" .. i .. "Text"]
        if cadre and zone and cadre:IsShown() then
            local texte = zone:GetText()
            if type(texte) == "string" and texte ~= "" then
                for _, r in ipairs(regles) do
                    local nouveau, n = string.gsub(texte, r.motif, r.rempl)
                    if n > 0 then
                        -- Nom d'objet dans « Voulez-vous détruire X ? » :
                        -- traduit par le pont DB.ObjetsNoms quand connu.
                        local noms = AFR.DB.ObjetsNoms
                        if noms then
                            nouveau = string.gsub(nouveau,
                                "^(Voulez%-vous détruire )(.-)( %?)",
                                function(a, nom, b)
                                    return a .. (noms[nom] or nom) .. b
                                end)
                            nouveau = string.gsub(nouveau,
                                "^(.-)( sera lié à vous si vous le "
                                .. "prenez%.)$",
                                function(nom, fin)
                                    return (noms[nom] or nom) .. fin
                                end)
                        end
                        zone:SetText(nouveau)
                        -- La fenêtre se redimensionne sur son texte.
                        if type(StaticPopup_Resize) == "function" then
                            pcall(StaticPopup_Resize, cadre, cadre.which)
                        end
                        break
                    end
                end
            end
        end
    end
end

if type(StaticPopup_Show) == "function" then
    hooksecurefunc("StaticPopup_Show", TraduirePopups)
end
