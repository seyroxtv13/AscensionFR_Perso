-- ============================================================================
-- AscensionFR - Info-bulles (objets, sorts, créatures)
-- Les lignes de statistiques (« +5 Stamina », « Requires Level 10 »...) sont
-- déjà francisées par les GlobalStrings frFR : ce module traduit ce qui vient
-- des données serveur (noms, descriptions) via les bases par ID.
-- ============================================================================
local AFR = AscensionFR

local function Sub(t) return AFR.Substituer(t) end

local function LigneGauche(tooltip, i)
    return _G[tooltip:GetName() .. "TextLeft" .. i]
end

-- ----------------------------------------------------------------------------
-- Objets
-- ----------------------------------------------------------------------------

-- Lignes émises par le client compilé d'Ascension : elles n'existent ni dans
-- les GlobalStrings ni dans les données serveur, seul un remplacement
-- littéral peut les traduire. À compléter au fil des observations.
local LignesClient = {
    ["You don't own this vanity item"] =
        "Vous ne possédez pas cet objet d'apparat",
    ["Hold Shift to Compare"] = "Maintenez Maj pour comparer",
}

-- ----------------------------------------------------------------------------
-- Lignes STATIQUES (« Binds when picked up », « Wrist », « Cloth »,
-- « Requires Level 10 », « Durability 12 / 20 »...)
-- ----------------------------------------------------------------------------
-- Jusqu'à la 1.6 elles étaient françaises parce qu'on écrivait les
-- GlobalStrings — la méthode qui bloquait les sorts en combat. Depuis la
-- coupure (1.7.0), elles étaient retombées en anglais. Les revoici, par
-- remplacement à l'affichage, au sein des SEULES info-bulles d'objets :
-- aucune globale n'est écrite, et les lignes que le client cache lui-même
-- (voir le pavé au-dessus de CorpsStatique) ne sont jamais touchées.
local exactes, formats, stats_noms, corps_formats

local function SansCouleurs(t)
    t = string.gsub(t, "|c%x%x%x%x%x%x%x%x", "")
    return (string.gsub(t, "|r", ""))
end

local ETIQUETTES_EXACTES = {
    "ITEM_BIND_ON_PICKUP", "ITEM_BIND_ON_EQUIP", "ITEM_BIND_ON_USE",
    "ITEM_BIND_QUEST", "ITEM_BIND_TO_ACCOUNT", "ITEM_SOULBOUND",
    "ITEM_ACCOUNTBOUND", "ITEM_CONJURED", "ITEM_UNIQUE",
    "ITEM_UNIQUE_EQUIPPABLE", "CURRENTLY_EQUIPPED",
    "TRANSMOGRIFY_TOOLTIP_APPEARANCE_UNKNOWN",
    "TRANSMOGRIFY_TOOLTIP_APPEARANCE_KNOWN",
    "ITEM_DELTA_DESCRIPTION",
}

-- Gabarits à nombres. « %.1f » est volontairement absent : son échappement
-- est un nid à erreurs pour deux lignes cosmétiques.
local ETIQUETTES_FORMATS = {
    "ITEM_MIN_LEVEL", "ITEM_LEVEL", "DURABILITY_TEMPLATE",
    "ARMOR_TEMPLATE", "SHIELD_BLOCK_TEMPLATE", "DAMAGE_TEMPLATE",
}

-- « Requires Level %d » -> motif ancré « ^Requires Level (%-?%d+)$ ».
local function EnMotif(gabarit)
    local motif = string.gsub(gabarit,
        "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    motif = string.gsub(motif, "%%%%d", function() return "(%-?%d+)" end)
    motif = string.gsub(motif, "%%%%s", function() return "(.+)" end)
    return "^" .. motif .. "$"
end

-- « Niveau %d requis » -> remplacement « Niveau %1 requis » (captures dans
-- l'ordre — l'anglais et le français gardent le même ordre d'arguments).
local function EnRemplacement(gabarit)
    local rang = 0
    local sortie = string.gsub(gabarit, "%%", "%%%%")
    sortie = string.gsub(sortie, "%%%%[ds]", function()
        rang = rang + 1
        return "%" .. rang
    end)
    return sortie
end

local function ConstruireStatiques()
    exactes, formats = {}, {}
    -- Littéraux du client compilé, sans étiquette nulle part.
    exactes["Auction"] = "Enchères"
    exactes["unknown"] = "inconnu"
    for _, cle in ipairs(ETIQUETTES_EXACTES) do
        local anglais, francais = _G[cle], AFR.DB.UI[cle]
        if type(anglais) == "string" and anglais ~= ""
            and type(francais) == "string" and francais ~= ""
            and anglais ~= francais then
            exactes[anglais] = francais
        end
    end
    -- Emplacements (« Wrist » -> « Poignets ») : toutes les INVTYPE_*.
    for cle, francais in pairs(AFR.DB.UI) do
        if string.sub(cle, 1, 8) == "INVTYPE_" then
            local anglais = _G[cle]
            if type(anglais) == "string" and anglais ~= ""
                and type(francais) == "string" and francais ~= ""
                and anglais ~= francais then
                exactes[anglais] = francais
            end
        end
    end
    -- Sous-classes et types d'armes (« Cloth » -> « Tissu ») : DB_Libelles
    -- est déjà une table [anglais] = français.
    for anglais, francais in pairs(AFR.DB.Libelles) do
        if type(anglais) == "string" and type(francais) == "string"
            and anglais ~= francais then
            exactes[anglais] = francais
        end
    end
    for _, cle in ipairs(ETIQUETTES_FORMATS) do
        local anglais, francais = _G[cle], AFR.DB.UI[cle]
        if type(anglais) == "string" and anglais ~= ""
            and type(francais) == "string" and francais ~= ""
            and anglais ~= francais then
            table.insert(formats,
                { motif = EnMotif(anglais), rempl = EnRemplacement(francais) })
        end
    end
    -- Ligne d'enchère avec quantité (« Auction x1 ») : littéral du client
    -- compilé, sans étiquette nulle part.
    -- Le « x1 » arrive parfois teinté (codes couleurs incrustés) : c'est le
    -- dernier recours dé-coloré de LigneStatique qui le rattrape alors.
    table.insert(formats, { motif = "^Auction x(%d+)%s*$",
                            rempl = "Enchères x%1" })
    -- « (21.4 damage per second) » : DPS_TEMPLATE utilise %.1f, exclu du
    -- convertisseur générique — motif dédié, nombre décimal capturé.
    table.insert(formats, { motif = "^%((%d+%.?%d*) damage per second%)$",
                            rempl = "(%1 dégâts par seconde)" })

    -- Lignes de STATS (« +1 Stamina », « -2 Critical Strike Rating ») :
    -- signe + nombre + nom de stat. Les noms officiels sont dans DB.UI, le
    -- signe et le nombre se gardent tels quels.
    local STATS = {
        "SPELL_STAT1_NAME", "SPELL_STAT2_NAME", "SPELL_STAT3_NAME",
        "SPELL_STAT4_NAME", "SPELL_STAT5_NAME", "ARMOR", "BLOCK",
        "ITEM_MOD_CRIT_RATING_SHORT", "ITEM_MOD_HIT_RATING_SHORT",
        "ITEM_MOD_HASTE_RATING_SHORT", "ITEM_MOD_EXPERTISE_RATING_SHORT",
        "ITEM_MOD_ATTACK_POWER_SHORT", "ITEM_MOD_SPELL_POWER_SHORT",
        "ITEM_MOD_DEFENSE_SKILL_RATING_SHORT", "ITEM_MOD_DODGE_RATING_SHORT",
        "ITEM_MOD_PARRY_RATING_SHORT", "ITEM_MOD_BLOCK_RATING_SHORT",
        "ITEM_MOD_RESILIENCE_RATING_SHORT",
        "ITEM_MOD_MANA_REGENERATION_SHORT",
        "ITEM_MOD_HEALTH_REGENERATION_SHORT",
        "ITEM_MOD_SPELL_PENETRATION_SHORT",
        "ITEM_MOD_ARMOR_PENETRATION_RATING_SHORT",
        -- ajouts de l'audit du 20/07 : « +30 Health », « +20 Mana »,
        -- « +15 Frost Resistance »... (RESISTANCE0 = doublon d'ARMOR, exclu)
        "ITEM_MOD_HEALTH_SHORT", "ITEM_MOD_MANA_SHORT",
        "RESISTANCE1_NAME", "RESISTANCE2_NAME", "RESISTANCE3_NAME",
        "RESISTANCE4_NAME", "RESISTANCE5_NAME", "RESISTANCE6_NAME",
    }
    stats_noms = {}
    for _, cle in ipairs(STATS) do
        local anglais, francais = _G[cle], AFR.DB.UI[cle]
        if type(anglais) == "string" and anglais ~= ""
            and type(francais) == "string" and francais ~= ""
            and anglais ~= francais then
            stats_noms[anglais] = francais
        end
    end

    -- CORPS des lignes d'effet (« Equip: Improves critical strike rating
    -- by 12. ») : le préfixe est posé par la boucle des préfixes, le corps
    -- se traduit ici quand il suit un gabarit officiel ITEM_MOD_* (forme
    -- longue). Même mécanique EnMotif/EnRemplacement que les formats.
    corps_formats = {}
    local ETIQUETTES_CORPS = {
        "ITEM_MOD_CRIT_RATING", "ITEM_MOD_HIT_RATING",
        "ITEM_MOD_HASTE_RATING", "ITEM_MOD_EXPERTISE_RATING",
        "ITEM_MOD_ATTACK_POWER", "ITEM_MOD_SPELL_POWER",
        "ITEM_MOD_DEFENSE_SKILL_RATING", "ITEM_MOD_DODGE_RATING",
        "ITEM_MOD_PARRY_RATING", "ITEM_MOD_BLOCK_RATING",
        "ITEM_MOD_RESILIENCE_RATING", "ITEM_MOD_MANA_REGENERATION",
        "ITEM_MOD_HEALTH_REGENERATION", "ITEM_MOD_SPELL_PENETRATION",
        "ITEM_MOD_ARMOR_PENETRATION_RATING",
    }
    for _, cle in ipairs(ETIQUETTES_CORPS) do
        local anglais, francais = _G[cle], AFR.DB.UI[cle]
        if type(anglais) == "string" and anglais ~= ""
            and type(francais) == "string" and francais ~= ""
            and anglais ~= francais then
            table.insert(corps_formats,
                { motif = EnMotif(anglais), rempl = EnRemplacement(francais) })
        end
    end
    -- Les stats de puissance d'Ascension (texte de sort, aucune globale) :
    -- gabarits posés main, mêmes tournures que DB_Sorts.
    table.insert(corps_formats,
        { motif = "^Increases PvE Power by (%-?%d+) and PvP Power by"
            .. " (%-?%d+)%.$",
          rempl = "Augmente la puissance PvE de %1 et la puissance PvP"
            .. " de %2." })
    table.insert(corps_formats,
        { motif = "^Increases PvE Power by (%-?%d+)%.$",
          rempl = "Augmente la puissance PvE de %1." })
    table.insert(corps_formats,
        { motif = "^Increases PvP Power by (%-?%d+)%.$",
          rempl = "Augmente la puissance PvP de %1." })

    -- « Sell Price: » : la globale n'a pas les deux-points, l'affichage si.
    local vente = AFR.DB.UI["SELL_PRICE"]
    if type(vente) == "string" and vente ~= "" then
        -- la traduction officielle traîne une espace finale, et l'affichage
        -- peut en coller une aussi : motif tolérant plutôt qu'exact.
        vente = string.gsub(vente, "%s+$", "") .. " :"
        exactes["Sell Price:"] = vente
        table.insert(formats, { motif = "^Sell Price:%s*$",
                                rempl = string.gsub(vente, "%%", "%%%%") })
    end
end

-- Lignes de stats (« +54 Armor », « |cffff2020-21|r Armor »...) : le client
-- habille le nombre différemment selon la stat — l'armure est un cas à part
-- du code compilé, sa couleur est incrustée dans le texte, d'une manière qui
-- a déjà déjoué deux motifs « sur mesure » (20/07/2026). Course perdue : on
-- DÉCORTIQUE la ligne (nombre habillé + séparateur + nom de stat) et on ne
-- remplace que le nom, l'habillage est conservé tel quel. L'espace insécable
-- (\194\160) compte comme séparateur : le client s'en sert parfois.
local SEP = "[%s\194\160]"
local HABILLAGES = {
    "^(|c%x%x%x%x%x%x%x%x[%+%-]?%d+|r)" .. SEP .. "+(.+)$", -- nombre coloré
    "^(|c%x%x%x%x%x%x%x%x[%+%-]?%d+)" .. SEP .. "+(.+)$",   -- couleur ouverte
    "^([%+%-]%d+)" .. SEP .. "+(.+)$",                       -- nombre nu
}
local function DecortiquerStat(texte)
    for _, m in ipairs(HABILLAGES) do
        local nombre, nom = string.match(texte, m)
        if nombre then
            nom = string.gsub(nom, SEP .. "+$", "")
            -- ligne entière colorée : le |r final appartient à l'habillage,
            -- pas au nom (« |cff...-21 Armor|r »)
            local ferme = ""
            local coeur = string.match(nom, "^(.-)|r$")
            if coeur and stats_noms[coeur] then nom, ferme = coeur, "|r" end
            local francais = stats_noms[nom]
            if francais then return nombre .. " " .. francais .. ferme end
            return -- nombre reconnu mais stat inconnue : rien à faire
        end
    end
end

local function LigneStatique(texte)
    if not exactes then ConstruireStatiques() end
    local francais = exactes[texte]
    if francais then return francais end
    for _, f in ipairs(formats) do
        local nouveau, n = string.gsub(texte, f.motif, f.rempl)
        if n > 0 then return nouveau end
    end
    francais = DecortiquerStat(texte)
    if francais then return francais end
    -- Dernier recours : la même ligne SANS ses codes couleurs incrustés
    -- (« Auction |cff8080ffx1|r »). On perd la teinte, on gagne le français.
    local nu = SansCouleurs(texte)
    if nu ~= texte then
        francais = exactes[nu]
        if francais then return francais end
        for _, f in ipairs(formats) do
            local nouveau, n = string.gsub(nu, f.motif, f.rempl)
            if n > 0 then return nouveau end
        end
    end
end

-- Préfixes des lignes d'effet. m = ce qu'on peut RENCONTRER à l'écran (globale
-- actuelle, puis anglais de secours) ; f = ce qu'on AFFICHE en français.
-- Distinction obligatoire depuis le piège ITEM_SPELL_TRIGGER_ONEQUIP : le
-- client cache certaines lignes (« Equip: Increases PvE Power ») en les
-- reconnaissant à leur texte ANGLAIS. La globale doit donc rester anglaise
-- (liste TAINT_EXACT), et c'est ICI, sur les seules lignes visibles, que le
-- préfixe devient français.
local PREFIXES = {
    { nom = "ITEM_SPELL_TRIGGER_ONUSE",   en = "Use:" },
    { nom = "ITEM_SPELL_TRIGGER_ONEQUIP", en = "Equip:" },
    { nom = "ITEM_SPELL_TRIGGER_ONPROC",  en = "Chance on hit:" },
}

local function Prefixes()
    local p = {}
    for _, d in ipairs(PREFIXES) do
        local fr = AFR.DB.UI[d.nom]
        if type(fr) ~= "string" or fr == "" then fr = nil end
        local g = _G[d.nom]
        if type(g) == "string" and g ~= "" and g ~= d.en then
            table.insert(p, { m = g .. " ", f = (fr or g) .. " " })
        end
        table.insert(p, { m = d.en .. " ", f = (fr or d.en) .. " " })
    end
    return p
end

-- Corps d'une ligne d'effet (après le préfixe) : gabarits ITEM_MOD_* longs
-- et stats de puissance d'Ascension. Motifs ancrés — un corps libre (texte
-- de sort custom) ne matche pas et suit la voie normale.
local function CorpsStatique(corps)
    if not corps_formats then ConstruireStatiques() end
    for _, f in ipairs(corps_formats) do
        local nouveau, n = string.gsub(corps, f.motif, f.rempl)
        if n > 0 then return nouveau end
    end
end

-- LIGNES CACHÉES PAR LE CLIENT. Sur les objets mis à l'échelle (leveling),
-- le client compilé CACHE certaines lignes de stat (« Equip: Increases PvE
-- Power by 38. ») en les reconnaissant à leur texte ANGLAIS — d'où la
-- globale ONEQUIP laissée anglaise (TAINT_EXACT). Notre remise en page
-- (Show) faisait resurgir ces lignes : de 18/07 au 22/07 on effaçait TOUT
-- ce qui ressemblait à une stat de puissance… y compris sur les objets de
-- niveau maximum, où le client AFFICHE ces lignes car la stat est réelle
-- (signalement du 22/07/2026 : la puissance PvE/PvP disparaissait des
-- objets 60). Depuis : on relève l'ÉTAT réel de chaque ligne à l'entrée du
-- crochet (avant toute retouche) — cachée par le client -> on l'efface pour
-- qu'elle ne resurgisse pas ; visible -> elle vit sa vie normale,
-- traduction comprise.

-- Un échec O ne mérite le journal que si la ligne affichée est bien le TEXTE
-- ANGLAIS d'un des sorts de l'objet (modèle périmé -> correction à faire).
-- Les lignes de stats composées par le client, DÉJÀ françaises (« Equip:
-- Augmente la puissance d'attaque de 3. »), échouent normalement : ce n'est
-- que du bruit dans les rapports. Test : les 12 premiers caractères du corps
-- coïncident avec un modèle anglais (DE/DE2) de l'objet.
-- (SansCouleurs est défini plus haut, près de LigneStatique.)

local function CorpsAuModele(corps, sorts)
    corps = string.match(SansCouleurs(corps), "^%s*(.-)%s*$")
    local debut = string.sub(corps, 1, 12)
    if debut == "" then return false end
    for _, sid in ipairs(sorts) do
        local s = AFR.DB.Sorts[tonumber(sid)]
        if s then
            if s.DE and string.sub(SansCouleurs(s.DE), 1, 12) == debut then
                return true
            end
            if s.DE2 and string.sub(SansCouleurs(s.DE2), 1, 12) == debut then
                return true
            end
        end
    end
    return false
end

-- Le client colle parfois un temps de recharge à la fin de la ligne d'effet
-- (« ...by 100%! (1 sec de recharge) ») : il n'est pas dans le modèle du
-- sort et ferait échouer l'alignement, qui est ancré aux deux bouts. On le
-- met de côté et on le restitue après.
local function DetacherRecharge(texte)
    local corps, suffixe =
        string.match(texte, "^(.-)(%s*%([^()]*recharge[^()]*%))%s*$")
    if not corps then
        corps, suffixe =
            string.match(texte, "^(.-)(%s*%([^()]*[Cc]ooldown[^()]*%))%s*$")
    end
    if corps then return corps, suffixe end
    return texte, ""
end

-- Ligne d'effet (« Utiliser : Restores 126 health... ») : la description du
-- sort attaché, résolue par le client. On retire le préfixe, on aligne le
-- modèle anglais du sort et on replace les valeurs dans le français —
-- exactement la mécanique des info-bulles de sorts.
-- Paragraphes d'un modèle : séparés par une ligne vide (\n\n). L'info-bulle
-- d'OBJET affiche chaque paragraphe du sort sur SA PROPRE ligne, alors que
-- le modèle les porte tous — aligner le tout contre une seule ligne échouait
-- toujours (vécu : « Parchemin du gardien », test de Dan du 22/07/2026).
local function Paragraphes(texte)
    texte = string.gsub(texte or "", "\r\n", "\n")
    texte = string.gsub(texte, "\r", "\n")
    local sortie = {}
    for brut in string.gmatch(texte .. "\n\n", "(.-)\n\n+") do
        local morceau = string.match(brut, "^%s*(.-)%s*$")
        if morceau ~= "" then table.insert(sortie, morceau) end
    end
    return sortie
end

local function TraduireLigneEffet(ligne, texte, sorts, prefixes)
    local prefixe, reste = "", texte
    for _, p in ipairs(prefixes) do
        if string.sub(texte, 1, string.len(p.m)) == p.m then
            -- on reconnaît p.m (affiché), on écrira p.f (français)
            prefixe, reste = p.f, string.sub(texte, string.len(p.m) + 1)
            break
        end
    end
    local corps, recharge = DetacherRecharge(reste)
    for _, sid in ipairs(sorts) do
        local s = AFR.DB.Sorts[tonumber(sid)]
        if s and s.D then
            local fr = AFR.TraduireTexteSort(s.D, s.DE, corps)
            -- Modèle multi-paragraphes contre ligne unique : chaque
            -- paragraphe du couple D/DE est un sous-modèle candidat.
            if not fr and s.DE and string.find(s.DE, "\n") then
                local p_fr = Paragraphes(s.D)
                local p_en = Paragraphes(s.DE)
                if #p_fr == #p_en and #p_en > 1 then
                    for i = 1, #p_en do
                        fr = AFR.TraduireTexteSort(p_fr[i], p_en[i], corps)
                        if fr then break end
                    end
                end
            end
            if fr then
                ligne:SetText(prefixe .. fr .. recharge)
                return true
            end
        end
    end
    return false
end

-- Nom de compétence dans les prérequis (« First Aid (20) requis ») : la
-- structure de la ligne est déjà francisée par les GlobalStrings, mais le nom
-- vient des DBC. La paire EN->FR est dans DB_Libelles. Reconstruction par
-- découpe de chaîne, pas par gsub : un nom comme « Two-Handed Axes » contient
-- des caractères magiques des motifs Lua.
local function TraduireLigneCompetence(ligne, texte)
    local nom = string.match(texte, "^(.-) %(%d+%) requis$")
    if nom then
        local fr = AFR.DB.Libelles[nom]
        if fr then
            ligne:SetText(fr .. string.sub(texte, string.len(nom) + 1))
            return true
        end
        return false
    end
    nom = string.match(texte, "^Requires (.-) %(%d+%)$")
    if nom then
        local fr = AFR.DB.Libelles[nom]
        if fr then
            ligne:SetText("Requires " .. fr
                .. string.sub(texte, 9 + string.len(nom) + 1))
            return true
        end
    end
    return false
end

local function SurObjet(tooltip)
    if not AFR.Actif() then return end
    local nomEN, lien = tooltip:GetItem()
    local id = AFR.IdDepuisLienObjet(lien)
    local o = id and AFR.DB.Objets[id]
    if not o then return end
    -- État des lignes AVANT toute retouche : celles que le client a cachées
    -- lui-même (stats internes des objets mis à l'échelle — voir le pavé
    -- au-dessus de CorpsStatique).
    local internes_cachees = {}
    for i = 2, tooltip:NumLines() do
        local ligne = LigneGauche(tooltip, i)
        if ligne and ligne:GetText() and ligne:GetText() ~= ""
            and not ligne:IsShown() then
            internes_cachees[i] = true
        end
    end
    local modifie = false
    -- Vrai dès qu'une ligne de CE passage mérite vraiment d'être signalée.
    -- Sert à effacer les échecs devenus obsolètes (voir la fin de la fonction).
    local echec_vu = false
    if o.N then
        local l1 = LigneGauche(tooltip, 1)
        if l1 and l1:GetText() and l1:GetText() ~= "" then
            l1:SetText(o.N)
            modifie = true
        end
    end
    local prefixes = Prefixes()
    for i = 2, tooltip:NumLines() do
        local ligne = LigneGauche(tooltip, i)
        local texte = ligne and ligne:GetText()
        if texte and texte ~= "" and internes_cachees[i] then
            -- Ligne que le client avait cachée : notre remise en page (Show)
            -- la ferait resurgir — on l'efface, même résultat visuel que le
            -- jeu anglais (l'emplacement vide existe aussi chez lui).
            ligne:SetText("")
            modifie = true
        elseif texte and texte ~= "" then
            if o.D and string.sub(texte, 1, 1) == "\"" then
                -- La description « d'ambiance » est la ligne entre guillemets.
                ligne:SetText("\"" .. o.D .. "\"")
                modifie = true
            elseif LignesClient[texte] then
                ligne:SetText(LignesClient[texte])
                modifie = true
            elseif LigneStatique(texte) then
                ligne:SetText(LigneStatique(texte))
                modifie = true
            elseif TraduireLigneCompetence(ligne, texte) then
                modifie = true
            elseif o.S and string.len(texte) > 12
                and TraduireLigneEffet(ligne, texte, o.S, prefixes) then
                modifie = true
                if AFR.OublierEchec then AFR.OublierEchec("O", id) end
            else
                -- Ligne non alignée. Si elle commence par un préfixe d'effet :
                -- journal d'échec (une « Utiliser : » aurait dû s'aligner), puis
                -- au moins le préfixe passe en français — nécessaire depuis que
                -- la globale ONEQUIP reste anglaise (piège des lignes cachées) :
                -- le client compose « Equip: » même quand le corps est déjà
                -- français (stats ITEM_MOD_*).
                for _, p in ipairs(prefixes) do
                    if string.sub(texte, 1, string.len(p.m)) == p.m then
                        local corps = string.sub(texte,
                            string.len(p.m) + 1)
                        -- Corps sur gabarit officiel (« Improves critical
                        -- strike rating by 12. ») ou stat de puissance
                        -- d'Ascension : traduit ici, pas d'échec à noter.
                        local corps_fr = CorpsStatique(corps)
                        if corps_fr then
                            ligne:SetText(p.f .. corps_fr)
                            modifie = true
                            break
                        end
                        if o.S and string.len(texte) > 12
                            and AFR.JournaliserEchec
                            and CorpsAuModele(corps, o.S) then
                            AFR.JournaliserEchec("O", id, texte)
                            echec_vu = true
                        end
                        if p.f ~= p.m then
                            ligne:SetText(p.f .. corps)
                            modifie = true
                        end
                        break
                    end
                end
            end
        end
    end
    -- Colonne de DROITE (« Cloth », « Mail », « unknown ») : mêmes lignes
    -- statiques, autre colonne — la boucle principale ne lit que la gauche.
    for i = 1, tooltip:NumLines() do
        local droite = _G[tooltip:GetName() .. "TextRight" .. i]
        local texte = droite and droite:GetText()
        if texte and texte ~= "" and not internes_cachees[i] then
            local francais = LigneStatique(texte)
            if francais then
                droite:SetText(francais)
                modifie = true
            end
        end
    end
    -- Rien d'anormal sur cet objet cette fois-ci : on efface l'échec qui
    -- pourrait rester en mémoire. Sans ce ménage, une entrée notée AVANT une
    -- correction y restait à vie et repartait dans chaque rapport (6 fausses
    -- alertes constatées le 18/07/2026, toutes déjà traduites depuis).
    if not echec_vu and AFR.OublierEchec then
        AFR.OublierEchec("O", id)
    end
    if modifie then
        if tooltip:IsShown() then tooltip:Show() end
        -- La remise en page (Show) peut faire resurgir une ligne que le
        -- client avait cachée : on repasse derrière et on efface.
        for i in pairs(internes_cachees) do
            local ligne = LigneGauche(tooltip, i)
            local texte = ligne and ligne:GetText()
            if texte and texte ~= "" then
                ligne:SetText("")
            end
        end
    end
end

-- ----------------------------------------------------------------------------
-- Sorts (voir Modules\Sorts.lua pour la résolution des variables $s1, $d...)
-- ----------------------------------------------------------------------------
-- id connu de la base -> traduction ; sinon -> récolte. Partagé entre les
-- info-bulles de sort (GetSpell) et celles de buff/débuff (UnitAura).
local function TraiterSort(tooltip, id, nomEN)
    if not id then return end
    local s = AFR.DB.Sorts[id]
    if s then
        AFR.TraduireInfobulleSort(tooltip, id)
        -- ANGLE MORT bouché le 20/07 (constat de Dan) : une entrée
        -- INCOMPLÈTE — nom français, description absente (« Cheval
        -- squelette bai » + corps anglais) — n'était NI récoltée (id
        -- connu) NI journalisée (rien à aligner). On la complète ici.
        if not s.D and nomEN then
            local nb = tooltip:NumLines()
            local desc = nb > 1 and LigneGauche(tooltip, nb)
            local texte = desc and desc:GetText()
            if texte and string.len(texte) > 12 then
                AFR.Recolter("Sorts", id, { N = nomEN, D = texte })
            end
        end
    elseif nomEN then
        -- Sort inconnu de la base : on le récolte pour traduction.
        local nb = tooltip:NumLines()
        local desc = nb > 1 and LigneGauche(tooltip, nb)
        AFR.Recolter("Sorts", id,
            { N = nomEN, D = desc and desc:GetText() or nil })
    end
end

-- ----------------------------------------------------------------------------
-- Lignes STATIQUES des bulles de sorts (« 45 Energy », « Instant »,
-- « Melee Range », « 2 min cooldown », « Requires Melee Weapon »...).
-- Composées par le client depuis des gabarits à étiquettes : le français
-- officiel est dans DB.UI, on remplace à l'affichage — les deux colonnes.
-- ----------------------------------------------------------------------------
local sorts_exactes, sorts_formats

local CLES_SORT_EXACTES = {
    "MELEE_RANGE", "SPELL_CAST_CHANNELED", "SPELL_CAST_TIME_INSTANT",
    "SPELL_CAST_TIME_INSTANT_NO_MANA", "SPELL_ON_NEXT_SWING",
    "SPELL_PASSIVE", "SPELL_RANGE_AREA", "SPELL_RANGE_UNLIMITED",
    "SPELL_RECAST_TIME_INSTANT",
}
-- Gabarits : %d (coûts), %s (portée) et %.3g (temps à décimales).
local CLES_SORT_FORMATS = {
    "ENERGY_COST", "FOCUS_COST", "HEALTH_COST", "MANA_COST", "RAGE_COST",
    "RUNIC_POWER_COST", "SPELL_CAST_TIME_MIN", "SPELL_CAST_TIME_SEC",
    "SPELL_CAST_TIME_RANGED", "SPELL_RANGE",
    "SPELL_RECAST_TIME_MIN", "SPELL_RECAST_TIME_SEC",
}

-- « %.3g min cooldown » -> « ^([%d%.,]+) min cooldown$ ». Jetons \1\2\3
-- posés AVANT l'échappement des magiques (le « % » des gabarits en fait
-- partie), remplacés après.
local function EnMotifSort(gabarit)
    gabarit = string.gsub(gabarit, "%%%.3g", "\1")
    gabarit = string.gsub(gabarit, "%%d", "\2")
    gabarit = string.gsub(gabarit, "%%s", "\3")
    local motif = string.gsub(gabarit,
        "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")
    motif = string.gsub(motif, "\1", "([%%d%%.,]+)")
    motif = string.gsub(motif, "\2", "(%%-?%%d+)")
    motif = string.gsub(motif, "\3", "(.+)")
    return "^" .. motif .. "$"
end

local function EnRemplacementSort(gabarit)
    local sortie = string.gsub(gabarit, "%%%.3g", "\1")
    sortie = string.gsub(sortie, "%%d", "\1")
    sortie = string.gsub(sortie, "%%s", "\1")
    sortie = string.gsub(sortie, "%%", "%%%%")
    local rang = 0
    sortie = string.gsub(sortie, "\1", function()
        rang = rang + 1
        return "%" .. rang
    end)
    return sortie
end

-- « Requires Melee Weapon » : le reste de la ligne est un type d'équipement
-- (parfois une forme, un objet...). On ne traduit que si on SAIT — un
-- « Nécessite Cat Form » à moitié anglais serait pire que l'original.
local ARMES_REQUISES = {
    ["Melee Weapon"] = "Arme de mêlée",
    ["Ranged Weapon"] = "Arme à distance",
    ["Shield"] = "Bouclier", ["Shields"] = "Boucliers",
}

local function ConstruireStatiquesSort()
    sorts_exactes, sorts_formats = {}, {}
    for _, cle in ipairs(CLES_SORT_EXACTES) do
        local anglais, francais = _G[cle], AFR.DB.UI[cle]
        if type(anglais) == "string" and anglais ~= ""
            and type(francais) == "string" and francais ~= ""
            and anglais ~= francais then
            sorts_exactes[anglais] = francais
        end
    end
    for _, cle in ipairs(CLES_SORT_FORMATS) do
        local anglais, francais = _G[cle], AFR.DB.UI[cle]
        if type(anglais) == "string" and anglais ~= ""
            and type(francais) == "string" and francais ~= ""
            and anglais ~= francais then
            table.insert(sorts_formats,
                { motif = EnMotifSort(anglais),
                  rempl = EnRemplacementSort(francais) })
        end
    end
end

local function LigneSortStatique(texte)
    if not sorts_exactes then ConstruireStatiquesSort() end
    local francais = sorts_exactes[texte]
    if francais then return francais end
    for _, f in ipairs(sorts_formats) do
        local nouveau, n = string.gsub(texte, f.motif, f.rempl)
        if n > 0 then return nouveau end
    end
    local exige = string.match(texte, "^Requires (.+)$")
    if exige then
        local fr = ARMES_REQUISES[exige] or AFR.DB.Libelles[exige]
        if fr then return "Nécessite " .. fr end
    end
end

local function StatiquesSort(tooltip)
    local modifie = false
    for i = 1, tooltip:NumLines() do
        for _, cote in ipairs({ "TextLeft", "TextRight" }) do
            local zone = _G[tooltip:GetName() .. cote .. i]
            local texte = zone and zone:GetText()
            if texte and texte ~= "" then
                local francais = LigneSortStatique(texte)
                if francais then
                    zone:SetText(francais)
                    modifie = true
                end
            end
        end
    end
    if modifie and tooltip:IsShown() then tooltip:Show() end
end

local function SurSort(tooltip)
    if not AFR.Actif() then return end
    local nomEN, rang, id = tooltip:GetSpell()
    TraiterSort(tooltip, id, nomEN)
    StatiquesSort(tooltip)
end

-- Info-bulles de buff/débuff : elles ne déclenchent PAS OnTooltipSetSpell
-- (elles proviennent de SetUnitAura/SetUnitBuff/SetUnitDebuff). On retrouve
-- l'ID du sort de l'aura et on traduit exactement comme un sort. En 3.3.5,
-- UnitAura renvoie le spellId en 11e position.
-- Ligne de durée des buffs (« 6 minutes remaining ») : composée par le
-- client depuis des gabarits pluralisés. Traduite par motif — le nombre est
-- gardé, le pluriel français est décidé ici.
local DUREES = {
    { motif = "^(%d+) seconds? remaining$",
      un = "seconde restante", plusieurs = "secondes restantes" },
    { motif = "^(%d+) minutes? remaining$",
      un = "minute restante", plusieurs = "minutes restantes" },
    { motif = "^(%d+) hours? remaining$",
      un = "heure restante", plusieurs = "heures restantes" },
    { motif = "^(%d+) days? remaining$",
      un = "jour restant", plusieurs = "jours restants" },
}

local function TraduireDuree(tooltip)
    local modifie = false
    for i = 2, tooltip:NumLines() do
        local ligne = LigneGauche(tooltip, i)
        local texte = ligne and ligne:GetText()
        if texte and texte ~= "" then
            for _, d in ipairs(DUREES) do
                local nombre = string.match(texte, d.motif)
                if nombre then
                    ligne:SetText(nombre .. " " .. (tonumber(nombre) == 1
                        and d.un or d.plusieurs))
                    modifie = true
                    break
                end
            end
        end
    end
    if modifie and tooltip:IsShown() then tooltip:Show() end
end

local function SurAura(tooltip, unite, index, filtre)
    if not AFR.Actif() or not unite or not index then return end
    local aura = { UnitAura(unite, index, filtre) }
    TraiterSort(tooltip, aura[11], aura[1])
    TraduireDuree(tooltip)
    StatiquesSort(tooltip)
end

-- ----------------------------------------------------------------------------
-- Créatures / PNJ
-- ----------------------------------------------------------------------------
-- « Level 20 Dwarf Templar » : le client compose cette ligne lui-même, et il
-- tire la race et la classe de ses DBC — ni le serveur ni les GlobalStrings
-- ne les portent. La structure de la phrase est déjà française (nos
-- GlobalStrings), restent les deux noms. On ne devine pas où ils sont : le
-- jeu nous les donne (UnitRace / UnitClass), on les cherche tels quels dans
-- la ligne. Découpe de chaîne, jamais gsub : « Death Knight » et les noms à
-- tiret contiennent des caractères magiques des motifs Lua.
local function RemplacerMot(texte, mot, remplacement)
    local debut = string.find(texte, mot, 1, true)   -- true = texte brut
    if not debut then return texte, false end
    return string.sub(texte, 1, debut - 1) .. remplacement
        .. string.sub(texte, debut + string.len(mot)), true
end

local function TraduireRaceClasse(tooltip, unite)
    local raceEN = UnitRace(unite)
    local classeEN = UnitClass(unite)
    local raceFR = raceEN and AFR.DB.Libelles[raceEN]
    local classeFR = classeEN and AFR.DB.Libelles[classeEN]
    if not raceFR and not classeFR then return false end
    local modifie = false
    for i = 2, tooltip:NumLines() do
        local ligne = LigneGauche(tooltip, i)
        local texte = ligne and ligne:GetText()
        if texte and texte ~= "" then
            local nouveau, a, b = texte, false, false
            if raceFR then nouveau, a = RemplacerMot(nouveau, raceEN, raceFR) end
            if classeFR then
                nouveau, b = RemplacerMot(nouveau, classeEN, classeFR)
            end
            if a or b then
                ligne:SetText(nouveau)
                modifie = true
            end
        end
    end
    return modifie
end

-- Lignes composées des bulles de créatures : « Level 1 Beast », le TITRE de
-- la quête à laquelle le monstre appartient, l'objectif « X slain: n/m ».
local TYPES_CREATURES = {
    ["Beast"] = "Bête", ["Humanoid"] = "Humanoïde", ["Demon"] = "Démon",
    ["Dragonkin"] = "Draconien", ["Giant"] = "Géant",
    ["Mechanical"] = "Mécanique", ["Critter"] = "Bestiole",
    ["Aberration"] = "Aberration", ["Totem"] = "Totem",
    ["Non-combat Pet"] = "Familier pacifique",
    ["Not specified"] = "Non spécifié",
    ["Elemental"] = "Élémentaire", ["Undead"] = "Mort-vivant",
    ["Corpse"] = "Cadavre",
}

-- Lignes de dépouille sur les cadavres (métiers de récolte)
local LIGNES_CADAVRE = {
    ["Skinnable"] = "Dépeçable",
}

local index_titres_quetes

local function TitreQuete(texte)
    if not index_titres_quetes then
        index_titres_quetes = {}
        for _, q in pairs(AFR.DB.Quetes) do
            if type(q) == "table" and q.TE and q.T and q.TE ~= q.T then
                local deja = index_titres_quetes[q.TE]
                if deja == nil then
                    index_titres_quetes[q.TE] = q.T
                elseif deja ~= q.T then
                    -- quêtes HOMONYMES aux français divergents : mieux vaut
                    -- l'anglais que le titre d'une autre quête (audit 20/07)
                    index_titres_quetes[q.TE] = false
                end
            end
        end
    end
    local fr = index_titres_quetes[texte]
    if fr then return fr end
end

-- Partagé : l'intercepteur global traduit aussi les titres de quêtes
-- affichés seuls (fenêtre « Détails de la quête », liens...).
AFR.TitreQueteFrancais = TitreQuete

local function LigneUnite(texte)
    -- « Level 1 Beast », « Level ?? Boss », « Level 10 Elite Bête »...
    local niveau, reste = string.match(texte, "^Level ([%d?]+)%s*(.*)$")
    if niveau then
        local sortie = "Niveau " .. niveau
        if reste ~= "" then
            local elite, corps = string.match(reste, "^(Elite)%s*(.*)$")
            if not elite then corps = reste end
            if elite then sortie = sortie .. " Élite" end
            if corps ~= "" then
                sortie = sortie .. " " .. (TYPES_CREATURES[corps]
                    or AFR.DB.Libelles[corps] or corps)
            end
        end
        return sortie
    end
    -- « Skinnable » et famille (dépouille des cadavres)
    if LIGNES_CADAVRE[texte] then return LIGNES_CADAVRE[texte] end
    -- « Requires Mining/Herbalism » sur un cadavre : métier via Libelles
    local metier = string.match(texte, "^Requires (.+)$")
    if metier and AFR.DB.Libelles[metier] then
        return "Nécessite " .. AFR.DB.Libelles[metier]
    end
    -- Titre de quête (la bulle liste les quêtes auxquelles le monstre sert)
    local titre = TitreQuete(texte)
    if titre then return titre end
    -- Objectif « - Young Nightsaber slain: 4/4 »
    local avant, nom, fait, total =
        string.match(texte, "^([%-%s]*)(.-) slain: (%d+)/(%d+)$")
    if nom and AFR.NomCreatureFrancais then
        local fr = AFR.NomCreatureFrancais(nom)
        if fr then
            return avant .. fr .. " tué(s) : " .. fait .. "/" .. total
        end
        return
    end
    -- Objectif de COLLECTE (« Thistle: 2/4 ») via le pont des noms d'objets
    local avant2, nomObj, fait2, total2 =
        string.match(texte, "^([%-%s]*)(.-): (%d+)/(%d+)$")
    if nomObj and AFR.DB.ObjetsNoms then
        local fr = AFR.DB.ObjetsNoms[nomObj]
        if fr then
            return avant2 .. fr .. " : " .. fait2 .. "/" .. total2
        end
    end
end

-- Indépendant de la connaissance de la créature : même un monstre absent de
-- la base garde son niveau, son type et ses lignes de quête en français.
local function LignesUnite(tooltip)
    local modifie = false
    for i = 2, tooltip:NumLines() do
        local ligne = LigneGauche(tooltip, i)
        local texte = ligne and ligne:GetText()
        if texte and texte ~= "" then
            local fr = LigneUnite(texte)
            if fr then
                ligne:SetText(fr)
                modifie = true
            end
        end
    end
    return modifie
end

local function SurUnite(tooltip)
    if not AFR.Actif() then return end
    local _, unite = tooltip:GetUnit()
    if not unite then return end
    if UnitIsPlayer(unite) then
        -- Les joueurs n'ont ni nom ni sous-titre à traduire : seulement leur
        -- ligne de race et de classe.
        if TraduireRaceClasse(tooltip, unite) then
            if tooltip:IsShown() then tooltip:Show() end
        end
        return
    end
    local modifie = LignesUnite(tooltip)
    local c
    local id = AFR.IdCreatureDepuisGUID(UnitGUID(unite))
    if id then c = AFR.DB.Creatures[id] end
    if not c then
        local nomEN = UnitName(unite)
        c = nomEN and AFR.CreatureParNomEN(nomEN)
    end
    if not c then
        if modifie and tooltip:IsShown() then tooltip:Show() end
        return
    end
    if c.N then
        local l1 = LigneGauche(tooltip, 1)
        if l1 then l1:SetText(c.N); modifie = true end
    end
    if c.S then
        -- Le sous-titre (« Maître de l'hôtellerie ») est en ligne 2 quand
        -- il correspond au sous-titre anglais connu.
        local l2 = LigneGauche(tooltip, 2)
        local texte = l2 and l2:GetText()
        if texte and (texte == c.SE or not string.match(texte, "^" .. (LEVEL or "Level"))) then
            if texte == c.SE then
                l2:SetText(c.S)
                modifie = true
            end
        end
    end
    if modifie and tooltip:IsShown() then tooltip:Show() end
end

-- ----------------------------------------------------------------------------
-- Cadres cible / focus
-- ----------------------------------------------------------------------------
-- Les cadres d'unité (cible, focus) sont protégés : y écrire contaminerait le
-- chemin d'exécution et bloquerait les actions du joueur. IsProtected() nous
-- évite de deviner.
local function EstProtege(cadre)
    if not cadre or type(cadre.IsProtected) ~= "function" then return false end
    local ok, protege = pcall(cadre.IsProtected, cadre)
    return ok and protege
end

local function TraduireNomCadre(unite, fontString)
    if not AFR.Actif() or not fontString then return end
    if EstProtege(fontString) then return end
    if not UnitExists(unite) or UnitIsPlayer(unite) then return end
    local c
    local id = AFR.IdCreatureDepuisGUID(UnitGUID(unite))
    if id then c = AFR.DB.Creatures[id] end
    if not c then
        local nomEN = UnitName(unite)
        c = nomEN and AFR.CreatureParNomEN(nomEN)
    end
    if c and c.N then fontString:SetText(c.N) end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("PLAYER_FOCUS_CHANGED")
frame:SetScript("OnEvent", function(self, event)
    if event == "PLAYER_TARGET_CHANGED" then
        TraduireNomCadre("target", TargetFrameTextureFrameName)
    elseif event == "PLAYER_FOCUS_CHANGED" then
        TraduireNomCadre("focus", FocusFrameTextureFrameName)
    end
end)

-- ----------------------------------------------------------------------------
-- Boutons de marchands, butin et récompenses de quête (noms d'objets)
-- ----------------------------------------------------------------------------
-- Habillage de la fenêtre de marchand : étiquettes officielles (onglets
-- « Merchant »/« Buyback », « Repair Items ») + littéraux du client custom
-- d'Ascension (case camelote, menu de réparation automatique). Deux canaux :
--  - les littéraux sont AUSSI greffés dans AFR.DB.Epreuves (notre table, pas
--    une globale du jeu) : l'intercepteur global de Modules/Epreuves.lua
--    traduit alors le menu déroulant, reposé par SetText à chaque ouverture ;
--  - les textes posés par le XML avant nos greffes (case à cocher, étiquette
--    de réparation, onglets) ne passent jamais par SetText : on les repeint
--    ici, par une marche sur les régions de MerchantFrame.
-- Tout est À ÉTIQUETTES (audit du 20/07 : les customs d'Ascension sont bien
-- dans SON GlobalStrings.dbc, donc dans DB.UI) : anglais = _G[cle], français
-- = DB.UI[cle]. Une seule source de vérité, wording poli dans DB_Interface.
local MARCHAND_CLES = {
    -- fenêtre : onglets, réparation, titre de la page rachat
    "MERCHANT", "BUYBACK", "REPAIR_ITEMS", "MERCHANT_BUYBACK",
    -- customs : case camelote + menu de réparation automatique
    "MERCHANT_AUTO_SELL_TEXT", "MERCHANT_AUTO_REPAIR_SETTING",
    "MERCHANT_AUTO_REPAIR_USE_GOLD", "MERCHANT_AUTO_REPAIR_USE_GUILD_BANK",
    "MERCHANT_AUTO_REPAIR_USE_BOTH",
    -- corps des info-bulles du menu (la passe GameTooltip d'Epreuves les
    -- voit dès qu'ils sont dans son dictionnaire)
    "MERCHANT_AUTO_REPAIR_NONE_TOOLTIP",
    "MERCHANT_AUTO_REPAIR_USE_GOLD_TOOLTIP",
    "MERCHANT_AUTO_REPAIR_USE_GUILD_BANK_TOOLTIP",
    "MERCHANT_AUTO_REPAIR_USE_BOTH_TOOLTIP",
}

local marchand_mots
local function MarchandMots()
    if not marchand_mots then
        marchand_mots = {}
        for _, cle in ipairs(MARCHAND_CLES) do
            local en, fr = _G[cle], AFR.DB.UI[cle]
            if type(en) == "string" and en ~= ""
                and type(fr) == "string" and fr ~= "" and en ~= fr then
                marchand_mots[en] = fr
                -- greffe dans le dictionnaire de l'intercepteur global :
                -- menu déroulant (SetText à chaque ouverture), titre de la
                -- page rachat, corps des info-bulles.
                if AFR.DB.Epreuves and AFR.DB.Epreuves[en] == nil then
                    AFR.DB.Epreuves[en] = fr
                end
            end
        end
    end
    return marchand_mots
end

local function RepeindreRegions(cadre, mots, profondeur)
    if profondeur <= 0 then return end
    for _, r in ipairs({ cadre:GetRegions() }) do
        if r.GetObjectType and r:GetObjectType() == "FontString"
            and r.GetText and r.SetText then
            local fr = mots[r:GetText() or ""]
            if fr then r:SetText(fr) end
        end
    end
    for _, enfant in ipairs({ cadre:GetChildren() }) do
        local genre = enfant.GetObjectType and enfant:GetObjectType()
        if genre ~= "EditBox" then
            if (genre == "Button" or genre == "CheckButton")
                and enfant.GetText then
                local fr = mots[enfant:GetText() or ""]
                if fr then enfant:SetText(fr) end
            end
            RepeindreRegions(enfant, mots, profondeur - 1)
        end
    end
end

local function TraduireMarchand()
    if not AFR.Actif() then return end
    for i = 1, MERCHANT_ITEMS_PER_PAGE or 10 do
        local nomFS = _G["MerchantItem" .. i .. "Name"]
        local bouton = _G["MerchantItem" .. i .. "ItemButton"]
        if nomFS and bouton and bouton:IsShown() then
            local lien = GetMerchantItemLink(bouton:GetID())
            local id = AFR.IdDepuisLienObjet(lien)
            local o = id and AFR.DB.Objets[id]
            if o and o.N then nomFS:SetText(o.N) end
        end
    end
    -- L'objet de RACHAT affiché en bas de la page marchand (dernier vendu).
    local nb = GetNumBuybackItems and GetNumBuybackItems()
    if nb and nb > 0 and MerchantBuyBackItemName then
        local id = AFR.IdDepuisLienObjet(GetBuybackItemLink(nb))
        local o = id and AFR.DB.Objets[id]
        if o and o.N then MerchantBuyBackItemName:SetText(o.N) end
    end
    if MerchantFrame then
        RepeindreRegions(MerchantFrame, MarchandMots(), 4)
    end
end

-- Onglet « Rachat » : mêmes boutons, autre source (GetBuybackItemLink).
local function TraduireRachat()
    if not AFR.Actif() then return end
    for i = 1, BUYBACK_ITEMS_PER_PAGE or 12 do
        local nomFS = _G["MerchantItem" .. i .. "Name"]
        local bouton = _G["MerchantItem" .. i .. "ItemButton"]
        if nomFS and bouton and bouton:IsShown() then
            local lien = GetBuybackItemLink(bouton:GetID())
            local id = AFR.IdDepuisLienObjet(lien)
            local o = id and AFR.DB.Objets[id]
            if o and o.N then nomFS:SetText(o.N) end
        end
    end
    if MerchantFrame then
        RepeindreRegions(MerchantFrame, MarchandMots(), 4)
    end
end

local function TraduireButin()
    if not AFR.Actif() then return end
    for i = 1, LOOTFRAME_NUMBUTTONS or 4 do
        local bouton = _G["LootButton" .. i]
        local texteFS = _G["LootButton" .. i .. "Text"]
        if bouton and bouton:IsShown() and texteFS then
            local lien = GetLootSlotLink(bouton.slot or bouton:GetID())
            local id = AFR.IdDepuisLienObjet(lien)
            local o = id and AFR.DB.Objets[id]
            if o and o.N then texteFS:SetText(o.N) end
        end
    end
end

-- ----------------------------------------------------------------------------
-- Branchements
-- ----------------------------------------------------------------------------
GameTooltip:HookScript("OnTooltipSetItem", SurObjet)
GameTooltip:HookScript("OnTooltipSetSpell", SurSort)
GameTooltip:HookScript("OnTooltipSetUnit", SurUnite)
if ItemRefTooltip then
    ItemRefTooltip:HookScript("OnTooltipSetItem", SurObjet)
    ItemRefTooltip:HookScript("OnTooltipSetSpell", SurSort)
end
-- Les bulles de COMPARAISON (« Actuellement équipé », l'objet porté à côté
-- de l'objet survolé) sont des cadres séparés, jamais couverts jusqu'ici.
for _, comparateur in ipairs({ShoppingTooltip1, ShoppingTooltip2}) do
    if comparateur and comparateur.HookScript then
        comparateur:HookScript("OnTooltipSetItem", SurObjet)
    end
end

-- REPASSE tardive : le client AJOUTE des lignes après notre passage —
-- la ligne d'enchère (« Auction x1 » / « unknown ») arrive d'un module qui
-- écrit derrière OnTooltipSetItem, puis redessine. On repasse sur les
-- lignes statiques à chaque redessin de la bulle d'un objet. Le verrou
-- empêche notre propre Show() de nous rappeler.
local repasse_en_cours = false
local function RepasseStatique(tooltip)
    if repasse_en_cours or not AFR.Actif() then return end
    if type(tooltip.GetItem) ~= "function" then return end
    local ok, _, lien = pcall(tooltip.GetItem, tooltip)
    if not ok or not lien then return end
    local modifie = false
    for i = 1, tooltip:NumLines() do
        for _, cote in ipairs({"TextLeft", "TextRight"}) do
            local zone = _G[tooltip:GetName() .. cote .. i]
            local texte = zone and zone:GetText()
            -- zone:IsShown() : les lignes cachées par le client (stats
            -- internes) ne sont jamais touchées — même régime que SurObjet.
            if texte and texte ~= "" and zone:IsShown() then
                local francais = LigneStatique(texte)
                if francais and francais ~= texte then
                    zone:SetText(francais)
                    modifie = true
                end
            end
        end
    end
    -- Ligne d'argent (« Sell Price: ») : son libellé vit dans une police à
    -- part du cadre d'argent, pas dans les TextLeft — les boucles ne le
    -- voient jamais. Les pièces sont ancrées au bord droit du libellé, elles
    -- suivent d'elles-mêmes quand le texte s'allonge. Pas de Show() pour ça.
    for i = 1, tooltip.shownMoneyFrames or 0 do
        local prefixe = _G[tooltip:GetName() .. "MoneyFrame" .. i
            .. "PrefixText"]
        local texte = prefixe and prefixe:GetText()
        if texte and texte ~= "" then
            local francais = LigneStatique(texte)
            if francais and francais ~= texte then
                prefixe:SetText(francais)
            end
        end
    end
    if modifie then
        repasse_en_cours = true
        pcall(tooltip.Show, tooltip)
        repasse_en_cours = false
    end
end
hooksecurefunc(GameTooltip, "Show", RepasseStatique)
if ItemRefTooltip then
    hooksecurefunc(ItemRefTooltip, "Show", RepasseStatique)
end
-- Les bulles de comparaison aussi : leur section « Si vous remplacez cet
-- objet… » est ajoutée APRÈS OnTooltipSetItem, seule la repasse la voit.
for _, comparateur in ipairs({ShoppingTooltip1, ShoppingTooltip2}) do
    if comparateur then
        hooksecurefunc(comparateur, "Show", RepasseStatique)
    end
end

-- Buffs / débuffs : greffe sûre (hooksecurefunc, lecture seule + SetText sur
-- nos lignes ajoutées ne déclenche pas le Taint... SAUF SI Ascension vérifie).
-- Rétabli en 1.7.5. Ces greffes avaient été coupées pendant la recherche du
-- blocage des sorts, par précaution — pas parce qu'elles étaient en cause.
-- Vérification faite : SurAura ne lit que UnitAura et n'écrit QUE dans
-- GameTooltip, un cadre non protégé, exactement comme les info-bulles
-- d'objets, de marchands et de butin restées actives sans jamais poser de
-- problème. Elle ne touche jamais aux BuffButton. Le vrai coupable était le
-- remplacement des variables globales, désormais désactivé.
if type(GameTooltip.SetUnitBuff) == "function" then
    hooksecurefunc(GameTooltip, "SetUnitBuff", function(self, unite, index)
        SurAura(self, unite, index, "HELPFUL")
    end)
    hooksecurefunc(GameTooltip, "SetUnitDebuff", function(self, unite, index)
        SurAura(self, unite, index, "HARMFUL")
    end)
    hooksecurefunc(GameTooltip, "SetUnitAura",
        function(self, unite, index, filtre)
            SurAura(self, unite, index, filtre)
        end)
end
if type(MerchantFrame_UpdateMerchantInfo) == "function" then
    hooksecurefunc("MerchantFrame_UpdateMerchantInfo", TraduireMarchand)
end
if type(MerchantFrame_UpdateBuybackInfo) == "function" then
    hooksecurefunc("MerchantFrame_UpdateBuybackInfo", TraduireRachat)
end
if type(LootFrame_Update) == "function" then
    hooksecurefunc("LootFrame_Update", TraduireButin)
end
