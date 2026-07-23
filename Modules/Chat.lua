-- ============================================================================
-- AscensionFR - Chat
-- Traduit les noms d'objets dans les liens de chat, les paroles des PNJ
-- (say/yell/emote/whisper) et le nom du PNJ qui parle. Les paroles viennent
-- de la base DB.Repliques, livrée par l'annexe AscensionFR_Repliques
-- (69 477 entrées) ; DB.Divers accueille en secours ce qui y manque.
-- ============================================================================
local AFR = AscensionFR

-- Remplace le texte affiché des liens d'objets |Hitem:1234...|h[Nom]|h
local function TraduireLiensObjets(message)
    local modifie = false
    message = string.gsub(message, "(|Hitem:(%d+)[^|]*|h%[)([^%]]+)(%]|h)",
        function(avant, id, nom, apres)
            local o = AFR.DB.Objets[tonumber(id)]
            if o and o.N then
                modifie = true
                return avant .. o.N .. apres
            end
            return avant .. nom .. apres
        end)
    -- Liens de quêtes |Hquest:456:60|h[Titre]|h
    message = string.gsub(message, "(|Hquest:(%d+)[^|]*|h%[)([^%]]+)(%]|h)",
        function(avant, id, titre, apres)
            local q = AFR.DB.Quetes[tonumber(id)]
            if q and q.T then
                modifie = true
                return avant .. q.T .. apres
            end
            return avant .. titre .. apres
        end)
    return message, modifie
end

local function FiltreLiens(self, event, message, ...)
    if not AFR.Actif() or not message then return false end
    local nouveau = TraduireLiensObjets(message)
    if nouveau ~= message then
        return false, nouveau, ...
    end
    return false
end

-- Répliques des PNJ : traduit le nom de l'émetteur + le texte si connu.
local function FiltrePNJ(self, event, message, emetteur, ...)
    if not AFR.Actif() then return false end
    local nouveauMessage = message
    local nouvelEmetteur = emetteur
    if message then
        local fr = AFR.ChercherParTexte(AFR.DB.Repliques, message)
            or AFR.ChercherParTexte(AFR.DB.Divers, message)
        if fr then nouveauMessage = AFR.Substituer(fr) end
    end
    if emetteur then
        local c = AFR.CreatureParNomEN(emetteur)
        if c and c.N then nouvelEmetteur = c.N end
    end
    if nouveauMessage ~= message or nouvelEmetteur ~= emetteur then
        return false, nouveauMessage, nouvelEmetteur, ...
    end
    return false
end

for _, ev in ipairs({
    "CHAT_MSG_LOOT", "CHAT_MSG_SYSTEM", "CHAT_MSG_CHANNEL",
    "CHAT_MSG_SAY", "CHAT_MSG_YELL", "CHAT_MSG_GUILD", "CHAT_MSG_PARTY",
    "CHAT_MSG_RAID", "CHAT_MSG_WHISPER",
}) do
    ChatFrame_AddMessageEventFilter(ev, FiltreLiens)
end

for _, ev in ipairs({
    "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL",
    "CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_MONSTER_WHISPER",
}) do
    ChatFrame_AddMessageEventFilter(ev, FiltrePNJ)
end

-- ----------------------------------------------------------------------------
-- Libellé de la zone de saisie : « Say: » -> « Dire : »
--
-- PREMIÈRE APPLICATION DE LA MÉTHODE SÛRE (1.7.5).
--
-- Traduire l'interface en remplaçant les variables globales
-- (_G["CHAT_SAY_SEND"] = "Dire : ") souille le jeu et bloquait les sorts des
-- joueurs : c'est désactivé depuis la 1.7.0. On procède donc autrement — on
-- laisse la variable tranquille et on réécrit le texte APRÈS que le client
-- l'a affiché. Seul le cadre concerné est touché, et la zone de chat n'est
-- pas un cadre protégé.
--
-- Le client compose ce libellé dans ChatEdit_UpdateHeader : cas simples via
-- _G["CHAT_<TYPE>_SEND"], cas à paramètre (chuchotement, emote, canal) via
-- SetFormattedText.
--
-- Piège à ne pas oublier : juste après, le client règle la marge de saisie
-- sur la LARGEUR du libellé. « Dire : » n'a pas la largeur de « Say: » —
-- sans recalcul, le texte tapé chevaucherait l'étiquette.
-- ----------------------------------------------------------------------------
if type(ChatEdit_UpdateHeader) == "function" then
    hooksecurefunc("ChatEdit_UpdateHeader", function(editBox)
        if not AFR.Actif() or not editBox then return end
        local genre = editBox:GetAttribute("chatType")
        if not genre then return end
        local entete = _G[editBox:GetName() .. "Header"]
        if not entete then return end

        local fr = AFR.DB.UI["CHAT_" .. genre .. "_SEND"]
        if not fr then return end

        if genre == "WHISPER" or genre == "BN_WHISPER" then
            entete:SetFormattedText(fr,
                editBox:GetAttribute("tellTarget") or "")
        elseif genre == "EMOTE" then
            entete:SetFormattedText(fr, UnitName("player") or "")
        elseif genre == "CHANNEL" or genre == "BN_CONVERSATION" then
            -- Deux paramètres et un numéro de canal résolu par le client :
            -- on n'y touche pas, le risque d'afficher n'importe quoi dépasse
            -- le bénéfice.
            return
        else
            entete:SetText(fr)
        end
        editBox:SetTextInsets(15 + entete:GetWidth(), 13, 0, 0)
    end)
end
