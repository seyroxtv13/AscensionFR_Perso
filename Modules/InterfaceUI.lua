-- ============================================================================
-- AscensionFR - Interface (GlobalStrings)
-- Applique les chaînes d'interface frFR officielles : tout ce que le client
-- formate lui-même (stats d'objets, messages système, boutons...) passe en
-- français automatiquement.
-- ============================================================================
local AFR = AscensionFR

-- Clés à ne jamais remplacer, en plus de DB.ListeNoire (générée depuis le
-- code du jeu) : valeurs comparées par le code, ou analysées par d'autres
-- addons.
local ListeNoireManuelle = {
    -- Le joueur doit taper ce mot pour détruire un objet. Ce n'est pas un
    -- texte affiché mais une valeur COMPARÉE par le code. La fenêtre, elle,
    -- est construite au chargement de FrameXML (avant les addons) et affiche
    -- donc toujours « DELETE » : traduire la valeur attendue en « EFFACER »
    -- rendait la confirmation impossible. Les deux doivent rester anglais.
    ["DELETE_ITEM_CONFIRM_STRING"] = true,
    -- Motifs de combat parsés par DBM / bibliothèques de scan
    ["UNITNAME_SUMMON_TITLE1"] = true,
    -- Format de dates/nombres système
    ["LARGE_NUMBER_SEPERATOR"] = true,
    ["DECIMAL_SEPERATOR"] = true,
}

-- Globales lues par du code SÉCURISÉ. Les traduire (donc les « souiller » via
-- _G[clé]=…) fait BLOQUER des actions du joueur en combat : GetBindingText lit
-- RALT_KEY_TEXT & co pour afficher les raccourcis sur chaque bouton d'action,
-- ce qui souille ShapeshiftBar_UpdateState puis bloque ShapeshiftButton:Hide()
-- — et, de proche en proche, les sorts du joueur (vécu, taint.log du 17/07).
-- On les laisse donc en anglais : ce ne sont que de petites étiquettes.
local MOTIFS_TAINT = {
    "KEY_TEXT$",                    -- LSHIFT_KEY_TEXT, RALT_KEY_TEXT… (modificateurs)
    "^KEY_",                        -- KEY_ESCAPE, KEY_ABBR_*… (noms de touches, GetBindingText)
    "^COMPACT_UNIT_FRAME_PROFILE",  -- options des profils de raid (code sécurisé)
    "^SLASH_",                      -- commandes /slash : lues par les macros sécurisées
                                    -- (bloquantes en combat) ET à ne jamais traduire.
    "^VOICE",                       -- VOICECHAT_*, VOICE_* : lues par le chat vocal
                                    -- (blocage de VoiceChatTalkers:Hide() en combat).
}
local TAINT_EXACT = {
    -- boutons du micro-menu, lus par le code sécurisé du menu principal
    ["CHARACTER_BUTTON"] = true, ["TALENTS_BUTTON"] = true,
    ["ACHIEVEMENT_BUTTON"] = true, ["QUESTLOG_BUTTON"] = true,
    ["DUNGEONS_BUTTON"] = true, ["MAINMENU_BUTTON"] = true,
    ["WORLDMAP_BUTTON"] = true,
    -- suivi de quêtes : WatchFrame_Update lit OBJECTIVES_TRACKER_LABEL, ce qui
    -- souille tout le système de POI et bloque WorldMapBlobFrame:Show() (carte).
    ["OBJECTIVES_TRACKER_LABEL"] = true, ["WATCHFRAME_NUM_POPUPS"] = true,
    -- divers, lus en contexte sécurisé (vus dans le taint.log)
    ["CHANNEL_ROSTER"] = true, ["NO_VOICE_SESSIONS"] = true,
    ["BATTLEFIELD_MINIMAP_SHOW_NEVER"] = true, ["PLAYER_V_PLAYER"] = true,
    -- PAS du taint, mais même famille de piège : le client d'Ascension CACHE
    -- certaines lignes d'objet (« Equip: Increases PvE Power by N. ») en les
    -- reconnaissant à leur TEXTE anglais. Traduire ce préfixe l'empêchait de
    -- les reconnaître -> lignes fantômes sur des tas d'objets (bissection du
    -- 18/07/2026, objet-témoin 500662). Le préfixe français est posé par
    -- Tooltips.lua sur les lignes visibles uniquement.
    ["ITEM_SPELL_TRIGGER_ONEQUIP"] = true,
}

-- Étiquette d'un RÉGLAGE d'interface : « SHOW_TARGET_OF_TARGET_TEXT » est le
-- libellé de la case à cocher, « SHOW_TARGET_OF_TARGET » est le réglage.
-- Blizzard LIT le libellé et ÉCRIT le réglage dans la même fonction : traduire
-- le libellé souille donc le réglage, qui souille TargetFrame, qui souille
-- UseAction() — le joueur ne peut plus lancer ses sorts.
--
-- Chaîne complète relevée dans taint.log (19/07/2026, signalée par Trey) :
--   SHOW_TARGET_OF_TARGET_TEXT (nous)
--     -> SHOW_TARGET_OF_TARGET
--     -> TargetFrame.lua:782 TargetofTarget_Update()
--     -> UseAction() BLOQUÉ
-- 173 721 souillures sur SHOW_BUFF_DURATIONS, 17 351 sur SHOW_TARGET_OF_TARGET.
--
-- La règle se déduit toute seule : si la clé finit par _TEXT et qu'il existe
-- une variable du même nom SANS _TEXT dont la valeur est une valeur simple
-- (un réglage vaut « 0 », « 1 », un nombre…), c'est une étiquette de réglage.
-- Une dizaine de libellés restent en anglais dans le menu Options : c'est peu
-- cher payé pour ne pas bloquer les sorts en plein combat.
-- Deux correctifs (1.6.1, 1.6.2) ont tenté de RECONNAÎTRE un réglage par
-- déduction. Les deux ont échoué, et de la pire façon : une déduction fausse
-- ne se déclenche jamais et ne dit rien. La 1.6.2 laissait encore passer dix
-- réglages (CHAT_STYLE, VERTICAL_SYNC, TIMESTAMPS_LABEL…).
--
-- On ne déduit donc plus. DB.Reglages est la liste des noms que le CLIENT
-- lui-même a écrits dans son taint.log au site de lecture du réglage
-- (OptionsPanelTemplates.lua:379) — 191 à ce jour, relevés par
-- outils/extraire_reglages.py. Aucun test à l'exécution qui puisse échouer
-- en silence : soit le nom est dans la liste, soit il n'y est pas.
--
-- L'ancienne heuristique reste en filet, pour les options qu'aucun journal
-- n'a encore vues (un joueur qui n'ouvre jamais un panneau ne le journalise
-- pas). Elle ne peut que protéger DAVANTAGE, jamais moins.
local function EtiquetteDeReglage(cle)
    -- L'infobulle de l'option, lue ligne 375.
    if string.find(cle, "^OPTION_TOOLTIP_") then return true end
    -- Le réglage lui-même, lu ligne 379, sous ses deux formes : nom nu
    -- (STOP_AUTO_ATTACK) ou « <NOM>_TEXT » (SHOW_TARGET_OF_TARGET_TEXT).
    local base = string.match(cle, "^(.+)_TEXT$") or cle
    if AFR.DB.Reglages[cle] or AFR.DB.Reglages[base] then return true end
    -- Filet : une option possède presque toujours une infobulle, et celle-ci
    -- existe dès le chargement — contrairement au réglage, créé APRÈS sa
    -- propre lecture. Ne jamais tester _G[<NOM>].
    return _G["OPTION_TOOLTIP_" .. base] ~= nil
end

local function TaintSensible(cle)
    if TAINT_EXACT[cle] then return true end
    if EtiquetteDeReglage(cle) then return true end
    for _, motif in ipairs(MOTIFS_TAINT) do
        if string.find(cle, motif) then return true end
    end
    return false
end

-- La règle de fond, depuis la 1.6.4. Les listes ci-dessus (réglages,
-- micro-menu, touches…) sont désormais des sous-ensembles de celle-ci ; on
-- les garde parce qu'elles documentent DES CAS VÉCUS et leur chaîne exacte.
--
-- Mesure du 19/07/2026 : sur 13 552 chaînes d'interface, le code du client en
-- LIT 2 208, dans 172 de ses fichiers. Écrire l'une d'elles la souille, et si
-- du code protégé la relit, l'action du joueur est refusée. Lister les
-- coupables au fil des signalements ne pouvait donc pas converger — trois
-- versions l'ont prouvé. On ne traduit plus que ce que le client se contente
-- d'AFFICHER, soit 84 % des chaînes.
local function Interdite(cle)
    return ListeNoireManuelle[cle] or AFR.DB.ListeNoire[cle]
        or AFR.DB.LuesClient[cle] or TaintSensible(cle)
end

-- Arguments attendus par une chaîne de format : table [position] = type.
-- Les « %% » littéraux sont ignorés (ils n'attendent pas d'argument).
--
-- WoW accepte deux écritures :
--   « Level %s %s %s »              -> arguments pris dans l'ordre
--   « %2$s %3$s de niveau %1$s »    -> arguments désignés par leur rang
-- La seconde est la façon dont le français réordonne une phrase. C'est la
-- POSITION qui compte, pas l'ordre d'apparition : comparer les séquences
-- rejetait à tort toute traduction réordonnée — dont les info-bulles de
-- race et de classe. Le client d'Ascension écrit lui-même 239 chaînes
-- positionnelles : il les gère.
--
-- Renvoie nil si la chaîne se contredit (même rang, deux types).
local function Arguments(texte)
    local nettoye = string.gsub(texte, "%%%%", "")
    local args, suivant = {}, 0
    -- PIÈGE (résolu 21/07/2026, 19 chaînes réhabilitées) : l'espace était
    -- accepté comme drapeau de format, donc le français « % de menace » se
    -- lisait « %d » et l'anglais « 100% focus » se lisait « %f » — 25
    -- chaînes écartées à tort. Aucune vraie chaîne du jeu n'utilise
    -- l'espace-drapeau : on le retire de la classe.
    for rang, dollar, _, genre in string.gmatch(nettoye,
        "%%(%d*)(%$?)([%-%+#0]*%d*%.?%d*)([dfsuxXeEgGqc])") do
        local position
        if dollar == "$" and rang ~= "" then
            position = tonumber(rang)
        else
            -- Sans « $ », d'éventuels chiffres sont une largeur, pas un rang.
            suivant = suivant + 1
            position = suivant
        end
        if args[position] and args[position] ~= genre then return nil end
        args[position] = genre
    end
    return args
end

-- Une traduction n'est sûre que si elle consomme exactement les mêmes
-- arguments, aux mêmes rangs, que la chaîne d'origine. Ascension a modifié
-- une partie de son interface : ses chaînes anglaises ne correspondent plus
-- toujours aux chaînes frFR officielles, et un format() incompatible fait
-- planter le jeu.
local function SignatureCompatible(origine, traduction)
    local a, b = Arguments(origine), Arguments(traduction)
    if not a or not b then return false end
    local maxi = 0
    for position in pairs(a) do
        if position > maxi then maxi = position end
    end
    for position in pairs(b) do
        if position > maxi then maxi = position end
    end
    for i = 1, maxi do
        if a[i] ~= b[i] then return false end
    end
    return true
end

-- Ce qu'on a effectivement remplacé : texte anglais -> texte français. Sert
-- à rattraper les copies figées (voir RafraichirFenetresContextuelles).
local Remplacees = {}

-- Chaînes fragiles FORCÉES, hors contrôle de signature. Le client injecte une
-- abréviation de format (« %d … », ex. SECONDS_ABBR) dans un %s de texte, ce
-- qui laisse un « %d » parasite (« Déconnexion dans 14 %d sec »). En ne gardant
-- qu'UN %d (le nombre) et l'unité en clair, format() ignore l'argument en trop.
-- Réservé aux cas où l'unité est INVARIABLE (compte à rebours de sortie, ~20 s).
-- On les force AUSSI dans Remplacees : sinon la COPIE FIGÉE du StaticPopup,
-- réappliquée depuis Remplacees, garderait le « %d %s » frFR cassé (vécu).
local FORCEES = {
    ["CAMP_TIMER"] = "Déconnexion dans %d sec",
    ["QUIT_TIMER"] = "Sortie dans %d sec",
}

local function AppliquerGlobalStrings()
    local n, ignorees, protegees = 0, 0, 0
    for cle, valeur in pairs(AFR.DB.UI) do
        local origine = _G[cle]
        -- Une globale VIDE n'est pas une chaîne « pas encore traduite » : c'est
        -- ainsi qu'Ascension MASQUE un élément d'interface. La remplir par du
        -- français le fait apparaître — le client reconstruit alors l'info-bulle
        -- avec une ligne de plus (vécu : « Équipé : Augmente la puissance PvE »
        -- surgissant sur des objets qui ne l'ont pas en anglais). On n'y touche
        -- jamais : traduire, ce n'est pas ajouter du texte là où il n'y en a pas.
        if type(origine) == "string" and origine ~= "" and origine ~= valeur then
            if FORCEES[cle] then
                _G[cle] = FORCEES[cle]
                Remplacees[origine] = FORCEES[cle]
                n = n + 1
            elseif Interdite(cle) then
                protegees = protegees + 1
            elseif SignatureCompatible(origine, valeur) then
                _G[cle] = valeur
                Remplacees[origine] = valeur
                n = n + 1
            else
                ignorees = ignorees + 1
                -- Une par une, ces lignes noieraient le journal (119 au
                -- démarrage) : rubrique à part, jointe au partage.
                AFR.Detailler("Chaînes d'interface écartées "
                    .. "(format incompatible avec Ascension)", cle)
            end
        end
    end
    return n, ignorees, protegees
end

-- ----------------------------------------------------------------------------
-- Les fenêtres contextuelles (« Voulez-vous vraiment... »)
--
-- StaticPopupDialogs est construit au chargement de FrameXML, AVANT les
-- addons : chaque entrée garde une COPIE du texte anglais
--     StaticPopupDialogs["QUIT"] = { text = QUIT_TIMER, button1 = QUIT_NOW }
-- Remplacer la globale plus tard ne change donc rien à la copie — la fenêtre
-- de sortie du jeu restait en anglais alors que QUIT_TIMER était traduit.
--
-- On ne devine pas quelle clé va dans quel champ : on rapproche par la
-- VALEUR, à partir de ce qu'on a réellement remplacé. Une chaîne écartée
-- (format incompatible) ou en liste noire n'est pas dans `Remplacees` : sa
-- fenêtre reste donc anglaise, cohérente avec le code qui la lit. C'est ce
-- qui protège « DELETE_ITEM_CONFIRM_STRING » : la fenêtre continue de
-- demander le mot que le code attend.
-- ----------------------------------------------------------------------------
local CHAMPS_TEXTE = { "text", "text1", "text2", "button1", "button2",
                       "button3", "button4" }

local function RafraichirFenetresContextuelles()
    if type(StaticPopupDialogs) ~= "table" then return 0 end
    local n = 0
    for _, fenetre in pairs(StaticPopupDialogs) do
        if type(fenetre) == "table" then
            for _, champ in ipairs(CHAMPS_TEXTE) do
                local fr = Remplacees[fenetre[champ]]
                if fr then
                    fenetre[champ] = fr
                    n = n + 1
                end
            end
        end
    end
    return n
end

-- Les cadres statiques créés avant le chargement des addons ont déjà lu les
-- chaînes anglaises : on rafraîchit les plus visibles à la main.
local function RafraichirCadresStatiques()
    local majBouton = function(bouton, cle)
        local v = _G[cle]
        if bouton and type(v) == "string" then bouton:SetText(v) end
    end
    -- Menu Échap
    majBouton(GameMenuButtonOptions, "GAMEOPTIONS_MENU")
    majBouton(GameMenuButtonUIOptions, "UIOPTIONS_MENU")
    majBouton(GameMenuButtonKeybindings, "KEY_BINDINGS")
    majBouton(GameMenuButtonMacros, "MACROS")
    majBouton(GameMenuButtonLogout, "LOGOUT")
    majBouton(GameMenuButtonQuit, "EXIT_GAME")
    majBouton(GameMenuButtonContinue, "RETURN_TO_GAME")
    majBouton(GameMenuButtonAddOns, "ADDONS")
    -- Onglets du bas de l'écran de personnage
    if CharacterFrameTab1 then
        majBouton(CharacterFrameTab1, "CHARACTER")
        majBouton(CharacterFrameTab2, "PET")
        majBouton(CharacterFrameTab3, "REPUTATION")
        majBouton(CharacterFrameTab4, "SKILLS")
        majBouton(CharacterFrameTab5, "CURRENCY")
    end
    -- Fenêtre sociale / journal
    majBouton(QuestLogFrameAbandonButton, "ABANDON_QUEST_ABBREV")
    majBouton(QuestFrameAcceptButton, "ACCEPT")
    majBouton(QuestFrameDeclineButton, "DECLINE")
    majBouton(QuestFrameCompleteButton, "COMPLETE_QUEST")
    majBouton(QuestFrameCompleteQuestButton, "COMPLETE_QUEST")
    majBouton(QuestFrameGoodbyeButton, "GOODBYE")
    majBouton(GossipFrameGreetingGoodbyeButton, "GOODBYE")
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
-- ----------------------------------------------------------------------------
-- DÉSACTIVÉ DEPUIS LA 1.7.0 — ne pas remettre à `true` sans avoir lu ceci.
--
-- Traduire l'interface oblige à écrire des variables globales du jeu. Le jeu
-- surveille ces écritures (protection anti-triche) : dès qu'un morceau de son
-- code protégé relit une variable modifiée, il REFUSE l'action en cours. Les
-- joueurs ne pouvaient plus lancer leurs sorts en combat, et la barre du
-- familier disparaissait.
--
-- Cinq versions (1.6.1 à 1.6.5) ont tenté de s'en sortir en listant les
-- variables à ne pas toucher. La liste est passée de 191 à 3 548 sans jamais
-- suffire : le code du client en lit trop, et parfois de façon dynamique. La
-- traduction de l'interface est tombée de 100 % à 74 % pour rien.
--
-- Depuis qu'on a coupé cette partie, plus aucun signalement de blocage.
--
-- Tout le reste de l'addon — quêtes, objets, sorts, créatures, dialogues,
-- livres, info-bulles — ne touche à aucune globale et continue normalement.
-- C'est l'essentiel de la traduction : plus de 250 000 entrées.
--
-- La voie propre pour récupérer l'interface est de livrer le français comme
-- des DONNÉES du jeu (archive MPQ) plutôt que par un addon. Piste bloquée
-- pour l'instant : le launcher supprime les archives qu'il ne connaît pas.
-- Voir POUR_LES_DEVS.md.
local TRADUIRE_INTERFACE = false

frame:SetScript("OnEvent", function(self, event, arg1)
    if not TRADUIRE_INTERFACE then return end
    if event == "ADDON_LOADED" and arg1 == "AscensionFR_Perso" then
        if AFR.Actif() then
            local n, ignorees, protegees = AppliquerGlobalStrings()
            AFR.Debug("GlobalStrings appliquées :", n,
                "| format incompatible :", ignorees,
                "| laissées en anglais pour ne pas bloquer le jeu :", protegees)
            AFR.Debug("fenêtres contextuelles rafraîchies :",
                RafraichirFenetresContextuelles())
        end
    elseif event == "PLAYER_LOGIN" then
        if AFR.Actif() then
            RafraichirCadresStatiques()
        end
    end
end)
