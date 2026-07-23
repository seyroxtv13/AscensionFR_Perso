-- ============================================================================
-- AscensionFR - Émotes françaises (2.1)
--
-- 1. COMMANDES : /bonjour, /danser, /rire... — les commandes OFFICIELLES du
--    client français de Blizzard, enregistrées par le mécanisme sanctionné
--    des addons (SlashCmdList). Aucune écriture dans les tables du client :
--    zéro risque de taint. Chaque commande retrouve le JETON de son émote
--    via hash_EmoteTokenList, la table publique que le client construit au
--    chargement (« /HELLO » -> « HELLO ») — on la LIT seulement.
-- 2. MENUS : une fois « /danser » réellement tapable, on affiche les
--    commandes françaises dans les menus d'émotes (paires versées dans le
--    dictionnaire d'affichage — interception SetText habituelle).
-- 3. TCHAT : « You flirt. » -> « Vous draguez. » (phrases officielles
--    d'EmotesTextData, gabarits %s compris), par filtre de message.
-- ============================================================================
local AFR = AscensionFR

local function Actif()
    return not (AFR.Actif and not AFR.Actif())
end

-- ----------------------------------------------------------------------------
-- 1 + 2. Commandes et affichage des menus
-- ----------------------------------------------------------------------------
local enregistrees = 0
local correspondances = {}      -- fr (minuscules) -> en, pour /afremotes
AFR.EmotesCorrespondances = correspondances

local function EnregistrerCommandes()
    if enregistrees > 0 then return enregistrees end
    local cmds = AFR.DB.EmotesCommandes
    local jetons = AFR.DB.EmotesJetons
    if not cmds or not jetons or type(DoEmote) ~= "function" then
        return 0
    end
    -- hash_EmoteTokenList (table publique du client d'origine) sert de
    -- garde anti-conflit quand elle existe — mais Ascension l'a remaniée :
    -- le JETON vient de NOTRE base (EmotesText.dbc), jamais du client.
    local internes = type(hash_EmoteTokenList) == "table"
        and hash_EmoteTokenList or {}
    local vues = {}
    local affichage = AFR.DB.Epreuves     -- dictionnaire d'affichage
    for cle, fr in pairs(cmds) do
        local en = _G[cle]
        if type(en) ~= "string" then en = nil end
        local frMaj = string.upper(fr)
        -- Jamais deux fois la même, et JAMAIS par-dessus une commande
        -- anglaise existante (« /train » vaut dans les deux langues).
        if not vues[frMaj] and not internes[frMaj] then
            -- LE jeton exact : la globale EMOTE<n>_TOKEN, définie par le
            -- ChatFrame.lua du client lui-même — c'est ELLE que leur code
            -- consulte quand on tape une commande (lu dans leur source,
            -- patch-B). Notre base ne sert que de repli. (Vécu : la
            -- déduction par nom rendait les émotes vocales muettes —
            -- /attacktarget a pour jeton ATTACKMYTARGET, etc.)
            local numero = tonumber(string.match(cle, "^EMOTE(%d+)_"))
            local jeton = numero and _G["EMOTE" .. numero .. "_TOKEN"]
            if type(jeton) ~= "string" or jeton == "" then
                jeton = jetons[cle]
            end
            if jeton and jeton ~= "" then
                vues[frMaj] = true
                enregistrees = enregistrees + 1
                correspondances[string.lower(fr)] = en or ("jeton " .. jeton)
                local nom = "AFREMOTE" .. enregistrees
                _G["SLASH_" .. nom .. "1"] = fr
                SlashCmdList[nom] = function(cible)
                    if cible == "" then cible = nil end
                    DoEmote(jeton, cible)
                end
                -- Menus : « /hello » s'affiche « /bonjour ». Uniquement si
                -- la globale anglaise existe chez ce client ET que personne
                -- d'autre ne revendique déjà ce texte.
                if en and affichage and affichage[en] == nil then
                    affichage[en] = fr
                end
            end
        end
    end
    if AFR.Debug then
        AFR.Debug("émotes :", enregistrees, "commandes françaises actives")
    end
    return enregistrees
end

-- hash_EmoteTokenList est rempli par le client à son chargement, avant les
-- addons — mais au cas où (client remanié), on retente à l'entrée en jeu.
if EnregistrerCommandes() == 0 then
    local attente = CreateFrame("Frame")
    attente:RegisterEvent("PLAYER_LOGIN")
    attente:SetScript("OnEvent", function(self)
        self:UnregisterEvent("PLAYER_LOGIN")
        EnregistrerCommandes()
    end)
end

-- ----------------------------------------------------------------------------
-- 2 bis. Les MENUS du bouton de tchat (Say/Emote/Voice Emote/Language)
-- ne sont PAS des UIDropDownMenu : le client les construit à part
-- (OnMenuLoad dans SON ChatFrame.lua — lu dans patch-B). On repeint leurs
-- boutons à CHAQUE ouverture, par correspondance exacte (dictionnaire
-- d'affichage : « Say » -> « Dire », « /flee » -> sa commande française).
-- ----------------------------------------------------------------------------
local function TraduireMenuTchat(menu)
    if not Actif() then return end
    local nom = menu.GetName and menu:GetName()
    if not nom then return end
    local affichage = AFR.DB.Epreuves
    if not affichage then return end
    for i = 1, 40 do
        local bouton = _G[nom .. "Button" .. i]
        if not bouton then break end
        local texte = bouton.GetText and bouton:GetText()
        if texte and texte ~= "" then
            local fr = affichage[texte]
            if fr and fr ~= texte then
                bouton:SetText(fr)
            end
        end
    end
end

for _, nom in ipairs({ "ChatMenu", "EmoteMenu", "LanguageMenu",
                       "VoiceMacroMenu" }) do
    local menu = _G[nom]
    if menu and menu.HookScript then
        pcall(menu.HookScript, menu, "OnShow", TraduireMenuTchat)
    end
end

-- ----------------------------------------------------------------------------
-- /afremotes — diagnostic : combien de commandes, et « /afremotes fuyez »
-- dit si « /fuyez » existe et à quelle commande anglaise elle répond.
-- (`correspondances` est déclarée tout en haut, remplie à l'enregistrement.)
-- ----------------------------------------------------------------------------
SLASH_AFREMOTES1 = "/afremotes"
SlashCmdList["AFREMOTES"] = function(arg)
    local sortie = DEFAULT_CHAT_FRAME
    if not sortie then return end
    arg = arg and string.gsub(arg, "^%s*/?", "") or ""
    if arg == "" then
        sortie:AddMessage("|cff0099ffAscensionFR|r : "
            .. enregistrees .. " commandes d'émotes françaises actives. "
            .. "« /afremotes fuyez » pour en vérifier une.")
        return
    end
    local fr = "/" .. string.lower(arg)
    local en = correspondances[fr]
    if en then
        sortie:AddMessage("|cff0099ffAscensionFR|r : " .. fr
            .. " = " .. en .. " — active.")
    else
        sortie:AddMessage("|cff0099ffAscensionFR|r : " .. fr
            .. " n'est pas enregistrée (pas dans le français officiel, "
            .. "ou en conflit avec une commande existante).")
    end
end

-- ----------------------------------------------------------------------------
-- 3. Phrases d'émotes du tchat
-- ----------------------------------------------------------------------------
local gabarits    -- construits à la première émote reçue, pas avant

local function ConstruireGabarits()
    gabarits = {}
    for en, fr in pairs(AFR.DB.EmotesTchat or {}) do
        if string.find(en, "%%s") then
            local motif = string.gsub(en,
                "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
            motif = "^" .. string.gsub(motif, "%%%%s", "(.+)") .. "$"
            table.insert(gabarits, { motif = motif, fr = fr, l = #en })
        end
    end
    -- Les plus longs d'abord : « %s flirts with %s » doit passer avant
    -- « %s flirts. » quand les deux pourraient mordre.
    table.sort(gabarits, function(a, b) return a.l > b.l end)
end

local function TraduireEmote(texte)
    local t = AFR.DB.EmotesTchat
    if not t then return end
    local fr = t[texte]
    if fr then return fr end
    if not gabarits then ConstruireGabarits() end
    for i = 1, #gabarits do
        local g = gabarits[i]
        local a, b = string.match(texte, g.motif)
        if a then
            -- Remplacement par fonction : un nom contenant un caractère
            -- spécial ne peut pas casser le gabarit français.
            local resultat = string.gsub(g.fr, "%%s",
                                         function() return a end, 1)
            if b then
                resultat = string.gsub(resultat, "%%s",
                                       function() return b end, 1)
            end
            return resultat
        end
    end
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_TEXT_EMOTE",
    function(self, event, message, ...)
        if Actif() and type(message) == "string" then
            local fr = TraduireEmote(message)
            if fr then return false, fr, ... end
        end
        return false, message, ...
    end)
