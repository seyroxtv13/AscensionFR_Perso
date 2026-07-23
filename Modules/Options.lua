-- ============================================================================
-- AscensionFR Perso - Panneau d'options (layout rail gauche)
--
-- Échap -> Interface -> AddOns. /afrp l'ouvre.
-- Structure volontairement différente d'AscensionFR :
--   bandeau marque + menu vertical (État / Réglages / Compat. / Journal)
--   + zone contenu. Pas d'onglets CharacterFrame ni encart don.
-- ============================================================================
local AFR = AscensionFR_Perso

-- ----------------------------------------------------------------------------
local SOUTIEN_URL = "https://github.com/seyroxtv13/AscensionFR_Perso"

-- Le salon où centraliser les retours. Un lien copiable dans l'addon évite
-- de recevoir les signalements « de partout » (MP, salons divers...).
local DISCORD = SOUTIEN_URL
AFR.DISCORD = DISCORD

-- Boutons bas de la fenêtre Interface (partagés) : Accepter / Quitter
-- uniquement tant que le panneau Perso est affiché.
local _okTxt, _cancelTxt
local function _PersoBoutonsBas(actif)
    local ok = _G.InterfaceOptionsFrameOkay
    local cancel = _G.InterfaceOptionsFrameCancel
    if not ok or not cancel then return end
    if actif then
        if not _okTxt then
            _okTxt = ok:GetText()
            _cancelTxt = cancel:GetText()
        end
        ok:SetText("Accepter")
        cancel:SetText("Quitter")
    elseif _okTxt then
        ok:SetText(_okTxt)
        cancel:SetText(_cancelTxt)
    end
end

-- Libellés lisibles des bases, dans l'ordre où on veut les montrer.
local CATEGORIES = {
    { "Quetes", "Quêtes" },
    { "Sorts", "Sorts" },
    { "Objets", "Objets" },
    { "Creatures", "Créatures" },
    { "ObjetsMonde", "Objets du monde" },
    { "Repliques", "Répliques des PNJ" },
    { "UI", "Interface" },
    { "Gossip", "Options de dialogue" },
    { "TextesPNJ", "Dialogues" },
    { "Pages", "Livres" },
    { "Libelles", "Libellés" },
    { "Divers", "Divers" },
}

local function Compter(nomTable)
    local n = 0
    for _ in pairs(AFR.DB[nomTable] or {}) do n = n + 1 end
    return n
end

local function TotalRecolte()
    local n = 0
    local r = AscensionFRSaved and AscensionFRSaved.Recolte
    if r then
        for _, cat in pairs(r) do
            for _ in pairs(cat) do n = n + 1 end
        end
    end
    return n
end

local function OptionsSauvees()
    AscensionFRSaved = AscensionFRSaved or {}
    AscensionFRSaved.Options = AscensionFRSaved.Options or {}
    return AscensionFRSaved.Options
end

-- Déclarés d'avance : des poignées de clic construites plus haut dans le
-- fichier s'y réfèrent avant leur définition (même piège que `Balayer` dans
-- Epreuves.lua — sans cette réservation, elles viseraient une globale nil).
local Rafraichir
local AfficherOnglet

-- ----------------------------------------------------------------------------
-- Registre des addons TIERS pris en charge (onglet « Addons tiers »).
--
-- Une entrée = une section à l'écran : le nom, un badge installé/absent, et
-- ses cases. Pour prendre en charge un nouvel addon, il suffit d'ajouter une
-- entrée ici — l'onglet se construit tout seul.
--
-- Les clés `inversee = true` sont ENREGISTRÉES À L'ENVERS : la clé n'existe
-- que si l'on a décoché. Absence = activé. C'est ce qui permet d'ajouter la
-- fonction sans que personne n'ait à aller la cocher.
-- ----------------------------------------------------------------------------
local ADDONS_TIERS = {
    {
        nom = "DragonUI",
        estLa = function()
            return (IsAddOnLoaded and IsAddOnLoaded("DragonUI"))
                and true or false
        end,
        cases = {
            {
                nomGlobal = "AscensionFROptionsDragonTrad",
                cle = "dragonTradOff",
                inversee = true,
                texte = "Traduire l'addon DragonUI",
                info = "Les 1 752 textes de DragonUI et de son panneau "
                    .. "d'options. Décocher demande un /reload pour revenir "
                    .. "à l'anglais.",
                tooltip = "Met en français les 1 752 textes de DragonUI "
                    .. "et de son panneau d'options.\n\nAucun fichier de "
                    .. "DragonUI n'est modifié : ses mises à jour n'effacent "
                    .. "rien.\n\nDécocher demande un /reload pour revenir à "
                    .. "l'anglais.",
                auClic = function(coche)
                    -- Les textes déjà écrits chez DragonUI ne se reprennent
                    -- pas : il faut relancer l'interface pour repartir de
                    -- ses fichiers d'origine.
                    print("|cffc47030Perso|r : DragonUI "
                        .. (coche and "sera traduit" or "repassera en anglais")
                        .. " au prochain /reload.")
                end,
            },
            {
                nomGlobal = "AscensionFROptionsDragonGrille",
                cle = "dragonGrilleOff",
                inversee = true,
                texte = "DragonUI : grille et aimantation",
                info = "En mode édition : une ligne verte tous les 5 "
                    .. "carreaux, et les cadres se collent à la grille.",
                tooltip = "Dans le mode édition de DragonUI : une ligne "
                    .. "verte tous les 5 carreaux, et les cadres se collent "
                    .. "à la grille quand vous les lâchez.\n\nUn coin du "
                    .. "cadre tombe alors toujours pile sur une "
                    .. "intersection.\n\nDécocher rend la main "
                    .. "immédiatement ; les lignes vertes, elles, "
                    .. "disparaissent au prochain /reload.",
            },
        },
    },
}

-- ----------------------------------------------------------------------------
-- Construction du panneau — layout Perso (rail gauche, pas d'onglets AFR)
-- ----------------------------------------------------------------------------
local panneau = CreateFrame("Frame", "AscensionFROptions")
panneau.name = "AscensionFR Perso"

-- Bandeau marque
local bandeau = CreateFrame("Frame", nil, panneau)
bandeau:SetPoint("TOPLEFT", 10, -10)
bandeau:SetPoint("TOPRIGHT", -14, -10)
bandeau:SetHeight(42)
bandeau:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
bandeau:SetBackdropColor(0.05, 0.07, 0.09, 0.95)
bandeau:SetBackdropBorderColor(0.77, 0.44, 0.19)

local titre = bandeau:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
titre:SetPoint("TOPLEFT", 12, -8)
titre:SetText("|cffc47030AscensionFR Perso|r")

local sousTitre = bandeau:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
sousTitre:SetPoint("TOPLEFT", titre, "BOTTOMLEFT", 0, -2)
sousTitre:SetPoint("RIGHT", bandeau, "RIGHT", -10, 0)
sousTitre:SetJustifyH("LEFT")
sousTitre:SetText("Traduction FR indépendante · Seyrox · /afrp")

-- Rail de navigation (vertical) — structure volontairement différente d'AFR
local rail = CreateFrame("Frame", nil, panneau)
rail:SetPoint("TOPLEFT", bandeau, "BOTTOMLEFT", 0, -8)
rail:SetPoint("BOTTOMLEFT", panneau, "BOTTOMLEFT", 10, 12)
rail:SetWidth(118)
rail:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
rail:SetBackdropColor(0.04, 0.05, 0.07, 0.92)
rail:SetBackdropBorderColor(0.35, 0.32, 0.28)

local NOMS_ONGLETS = { "État", "Réglages", "Compat.", "Journal" }
local onglets = {}

local function StyleNav(bouton, actif)
    if actif then
        bouton:SetBackdropColor(0.18, 0.10, 0.04, 0.95)
        bouton:SetBackdropBorderColor(0.85, 0.52, 0.22)
        bouton.label:SetTextColor(1, 0.88, 0.55)
    else
        bouton:SetBackdropColor(0.08, 0.09, 0.11, 0.85)
        bouton:SetBackdropBorderColor(0.28, 0.28, 0.30)
        bouton.label:SetTextColor(0.72, 0.72, 0.74)
    end
end

for i, nomOnglet in ipairs(NOMS_ONGLETS) do
    local bouton = CreateFrame("Button", "AscensionFROptionsTab" .. i, rail)
    bouton:SetHeight(28)
    bouton:SetPoint("TOPLEFT", 6, -8 - (i - 1) * 34)
    bouton:SetPoint("TOPRIGHT", -6, -8 - (i - 1) * 34)
    bouton:SetBackdrop({
        bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
        tile = true, tileSize = 8, edgeSize = 10,
        insets = { left = 2, right = 2, top = 2, bottom = 2 },
    })
    bouton.label = bouton:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    bouton.label:SetPoint("CENTER")
    bouton.label:SetText(nomOnglet)
    bouton:SetScript("OnClick", function() AfficherOnglet(i) end)
    StyleNav(bouton, i == 1)
    onglets[i] = bouton
end

-- Lien GitHub en bas du rail (Ctrl+C copie l'URL complète)
local lienRailLbl = rail:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
lienRailLbl:SetPoint("BOTTOMLEFT", 6, 28)
lienRailLbl:SetPoint("BOTTOMRIGHT", -6, 28)
lienRailLbl:SetJustifyH("CENTER")
lienRailLbl:SetText("|cffc47030…/AscensionFR_Perso|r")

local lienRail = CreateFrame("EditBox", "AscensionFRSoutienLien", rail, "InputBoxTemplate")
lienRail:SetHeight(18)
lienRail:SetPoint("BOTTOMLEFT", 6, 8)
lienRail:SetPoint("BOTTOMRIGHT", -6, 8)
lienRail:SetAutoFocus(false)
lienRail:SetText(SOUTIEN_URL)
lienRail:SetCursorPosition(0)
lienRail:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
lienRail:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
lienRail:SetScript("OnMouseUp", function(self)
    self:SetFocus(); self:HighlightText()
end)
lienRail:SetScript("OnTextChanged", function(self)
    if self:GetText() ~= SOUTIEN_URL then
        self:SetText(SOUTIEN_URL); self:SetCursorPosition(0)
    end
end)
lienRail:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
    GameTooltip:SetText(SOUTIEN_URL, 1, 1, 1)
    GameTooltip:Show()
end)
lienRail:SetScript("OnLeave", function() GameTooltip:Hide() end)

-- Zone de contenu à droite du rail
local contenu = CreateFrame("Frame", nil, panneau)
contenu:SetPoint("TOPLEFT", rail, "TOPRIGHT", 8, 0)
contenu:SetPoint("BOTTOMRIGHT", panneau, "BOTTOMRIGHT", -14, 12)
contenu:SetBackdrop({
    bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
    edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
    tile = true, tileSize = 16, edgeSize = 12,
    insets = { left = 3, right = 3, top = 3, bottom = 3 },
})
contenu:SetBackdropColor(0.03, 0.04, 0.05, 0.55)
contenu:SetBackdropBorderColor(0.40, 0.36, 0.30)

local NOMS_PAGES = {
    "AscensionFROptionsAccueil",
    "AscensionFROptionsReglages",
    "AscensionFROptionsAddonsTiers",
    "AscensionFRJournal",
}
local pages = {}
for i = 1, #NOMS_ONGLETS do
    local page = CreateFrame("Frame", NOMS_PAGES[i], contenu)
    page:SetPoint("TOPLEFT", 10, -10)
    page:SetPoint("BOTTOMRIGHT", -10, 10)
    page:Hide()
    pages[i] = page
end
local pageAccueil, pageReglages, pageAddons, pageJournal =
    pages[1], pages[2], pages[3], pages[4]

-- ============================================================================
-- Page 1 — ÉTAT (accueil refondu)
-- ============================================================================
local caseActif = CreateFrame("CheckButton", "AscensionFROptionsActif",
    pageAccueil, "InterfaceOptionsCheckButtonTemplate")
caseActif:SetPoint("TOPLEFT", pageAccueil, "TOPLEFT", 0, 0)
_G[caseActif:GetName() .. "Text"]:SetText("Activer la traduction")
caseActif.tooltipText = "Décochez pour retrouver le jeu en anglais. "
    .. "Un /reload est nécessaire pour tout rétablir."

-- Total hero (au lieu de la grille AFR + titre « Traductions chargées »)
local total = pageAccueil:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
total:SetPoint("TOPLEFT", caseActif, "BOTTOMLEFT", 4, -10)
total:SetJustifyH("LEFT")

local totalLbl = pageAccueil:CreateFontString(nil, "ARTWORK", "GameFontDisable")
totalLbl:SetPoint("TOPLEFT", total, "BOTTOMLEFT", 0, -2)
totalLbl:SetText("entrées en mémoire")

-- Grille compacte 3 colonnes
local lignes = {}
for i = 1, #CATEGORIES do
    local ligne = pageAccueil:CreateFontString(nil, "ARTWORK",
        "GameFontHighlightSmall")
    local colonne = (i - 1) % 3
    local rangee = math.floor((i - 1) / 3)
    ligne:SetPoint("TOPLEFT", totalLbl, "BOTTOMLEFT",
        colonne * 145, -14 - rangee * 14)
    ligne:SetJustifyH("LEFT")
    lignes[i] = ligne
end

local etat = pageAccueil:CreateFontString(nil, "ARTWORK", "GameFontNormal")
etat:SetPoint("TOPLEFT", lignes[#CATEGORIES - 2], "BOTTOMLEFT", 0, -16)
etat:SetPoint("RIGHT", pageAccueil, "RIGHT", -4, 0)
etat:SetJustifyH("LEFT")

local etatDetail = pageAccueil:CreateFontString(nil, "ARTWORK",
    "GameFontHighlightSmall")
etatDetail:SetPoint("TOPLEFT", etat, "BOTTOMLEFT", 0, -4)
etatDetail:SetPoint("RIGHT", pageAccueil, "RIGHT", -4, 0)
etatDetail:SetJustifyH("LEFT")
etatDetail:SetJustifyV("TOP")
etatDetail:SetHeight(28)

local signalements = pageAccueil:CreateFontString(nil, "ARTWORK",
    "GameFontHighlightSmall")
signalements:SetPoint("TOPLEFT", etatDetail, "BOTTOMLEFT", 0, -4)
signalements:SetPoint("RIGHT", pageAccueil, "RIGHT", -4, 0)
signalements:SetJustifyH("LEFT")

local boutonAider = CreateFrame("Button", nil, pageAccueil, "UIPanelButtonTemplate")
boutonAider:SetHeight(28)
boutonAider:SetPoint("TOPLEFT", signalements, "BOTTOMLEFT", 0, -12)
boutonAider:SetPoint("TOPRIGHT", pageAccueil, "TOPRIGHT", -4, 0)
boutonAider:SetText("Préparer un rapport")
boutonAider:SetScript("OnClick", function()
    if AFR.PartagerJournal then AFR.PartagerJournal() end
end)

local aide = pageAccueil:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
aide:SetPoint("TOPLEFT", boutonAider, "BOTTOMLEFT", 0, -8)
aide:SetPoint("RIGHT", pageAccueil, "RIGHT", -4, 0)
aide:SetJustifyH("LEFT")
aide:SetJustifyV("TOP")
aide:SetHeight(40)
aide:SetText("Anglais restant : survolez puis |cffffff00/afrp signaler|r. "
    .. "Envoi rapide : |cffffd100Compagnon Perso|r.")

-- ============================================================================
-- Page 2 — RÉGLAGES
-- ============================================================================
local function CaseReglage(nomGlobal, ancre, texte, explication, tooltip)
    local case = CreateFrame("CheckButton", nomGlobal, pageReglages,
        "InterfaceOptionsCheckButtonTemplate")
    if ancre then
        case:SetPoint("TOPLEFT", ancre, "BOTTOMLEFT", -26, -8)
    else
        case:SetPoint("TOPLEFT", pageReglages, "TOPLEFT", 0, -4)
    end
    _G[nomGlobal .. "Text"]:SetText(texte)
    case.tooltipText = tooltip
    local ligne = pageReglages:CreateFontString(nil, "ARTWORK",
        "GameFontDisableSmall")
    ligne:SetPoint("TOPLEFT", case, "BOTTOMLEFT", 26, 4)
    ligne:SetPoint("RIGHT", pageReglages, "RIGHT", -8, 0)
    ligne:SetJustifyH("LEFT")
    ligne:SetJustifyV("TOP")
    ligne:SetHeight(24)
    ligne:SetText(explication)
    case.explication = ligne
    return case
end

local caseInterface = CaseReglage("AscensionFROptionsInterface", nil,
    "Traduire l'interface",
    "Fenêtres Ascension : Épreuves, hauts faits, collections, menus… "
        .. "Effet immédiat.",
    "Décochez pour laisser l'interface d'Ascension en anglais, sans toucher "
        .. "au reste (quêtes, sorts, objets...).")

local casePlaques = CaseReglage("AscensionFROptionsPlaques",
    caseInterface.explication,
    "Traduire les plaques de nom des monstres",
    "Noms au-dessus des créatures. Décocher agit sur les nouvelles plaques.",
    "Remplace le nom anglais des plaques par le français.")

local caseBarresDeVie = CaseReglage("AscensionFROptionsBarresDeVie",
    casePlaques.explication,
    "Traduire les noms au-dessus des monstres",
    "Ancienne méthode, coupée par défaut. À laisser décochée avec un addon "
        .. "de barres de vie.",
    "Désactivé par défaut. À n'activer que sans addon de nameplates.")

local caseMinimap = CaseReglage("AscensionFROptionsMinimap",
    caseBarresDeVie.explication,
    "Bouton près de la minimap",
    "Petit livre : état au survol, ce panneau au clic. Déplaçable.",
    "Faites-le glisser autour de la minimap.")

local caseDebug = CaseReglage("AscensionFROptionsDebug",
    caseMinimap.explication,
    "Messages de débogage",
    "Recopie le journal dans le chat. Sinon : page Journal.",
    "Sans cocher, tout se lit déjà dans Journal.")

-- ============================================================================
-- Page 3 — COMPAT.
-- ============================================================================
local introAddons = pageAddons:CreateFontString(nil, "ARTWORK",
    "GameFontHighlightSmall")
introAddons:SetPoint("TOPLEFT", pageAddons, "TOPLEFT", 0, -4)
introAddons:SetPoint("RIGHT", pageAddons, "RIGHT", -8, 0)
introAddons:SetJustifyH("LEFT")
introAddons:SetJustifyV("TOP")
introAddons:SetHeight(26)
introAddons:SetText("Addons d'autres auteurs : Perso les francise "
    .. "sans modifier leurs fichiers.")

local sectionsAddons = {}
do
    local ancre, decalX = introAddons, 0
    for _, defAddon in ipairs(ADDONS_TIERS) do
        local entete = pageAddons:CreateFontString(nil, "ARTWORK",
            "GameFontNormal")
        entete:SetPoint("TOPLEFT", ancre, "BOTTOMLEFT", decalX, -14)
        entete:SetText(defAddon.nom)
        local badge = pageAddons:CreateFontString(nil, "ARTWORK",
            "GameFontHighlightSmall")
        badge:SetPoint("LEFT", entete, "RIGHT", 8, 0)
        local section = { def = defAddon, badge = badge, cases = {} }
        ancre, decalX = entete, 0
        for _, defCase in ipairs(defAddon.cases) do
            local case = CreateFrame("CheckButton", defCase.nomGlobal,
                pageAddons, "InterfaceOptionsCheckButtonTemplate")
            case:SetPoint("TOPLEFT", ancre, "BOTTOMLEFT", decalX, -6)
            _G[defCase.nomGlobal .. "Text"]:SetText(defCase.texte)
            case.tooltipText = defCase.tooltip
            local info = pageAddons:CreateFontString(nil, "ARTWORK",
                "GameFontDisableSmall")
            info:SetPoint("TOPLEFT", case, "BOTTOMLEFT", 26, 4)
            info:SetPoint("RIGHT", pageAddons, "RIGHT", -8, 0)
            info:SetJustifyH("LEFT")
            info:SetJustifyV("TOP")
            info:SetHeight(24)
            info:SetText(defCase.info)
            case:SetScript("OnClick", function(self)
                local opt = OptionsSauvees()
                if defCase.inversee then
                    opt[defCase.cle] = (not self:GetChecked()) or nil
                else
                    opt[defCase.cle] = self:GetChecked() and true or nil
                end
                if defCase.auClic then
                    defCase.auClic(self:GetChecked() and true or false)
                end
                Rafraichir()
            end)
            table.insert(section.cases, { case = case, def = defCase })
            ancre, decalX = info, -26
        end
        table.insert(sectionsAddons, section)
    end
end

-- ============================================================================
-- Page 4 — JOURNAL
-- ============================================================================
local introJournal = pageJournal:CreateFontString(nil, "ARTWORK",
    "GameFontHighlightSmall")
introJournal:SetPoint("TOPLEFT", pageJournal, "TOPLEFT", 0, -4)
introJournal:SetPoint("RIGHT", pageJournal, "RIGHT", -8, 0)
introJournal:SetJustifyH("LEFT")
introJournal:SetText("Journal live de l'addon. Molette pour défiler.")

local console = CreateFrame("ScrollingMessageFrame", nil, pageJournal)
console:SetPoint("TOPLEFT", introJournal, "BOTTOMLEFT", 0, -8)
console:SetPoint("BOTTOMRIGHT", pageJournal, "BOTTOMRIGHT", -8, 38)
if GameFontHighlightSmall then
    console:SetFontObject(GameFontHighlightSmall)
end
console:SetJustifyH("LEFT")
console:SetFading(false)
console:SetMaxLines(300)
console:EnableMouseWheel(true)
console:SetScript("OnMouseWheel", function(self, delta)
    if delta > 0 then self:ScrollUp() else self:ScrollDown() end
end)

pageJournal:SetScript("OnShow", function()
    console:Clear()
    for _, message in ipairs(AFR.Journal) do
        console:AddMessage(message)
    end
end)

AFR.JournalEcoute = function(message)
    if console:IsVisible() then console:AddMessage(message) end
end

local boutonRapport = CreateFrame("Button", nil, pageJournal,
    "UIPanelButtonTemplate")
boutonRapport:SetSize(190, 24)
boutonRapport:SetPoint("BOTTOMLEFT", pageJournal, "BOTTOMLEFT", 0, 6)
boutonRapport:SetText("Préparer le rapport")
boutonRapport:SetScript("OnClick", function()
    if AFR.PartagerJournal then AFR.PartagerJournal() end
end)

local infoRapport = pageJournal:CreateFontString(nil, "ARTWORK",
    "GameFontDisableSmall")
infoRapport:SetPoint("LEFT", boutonRapport, "RIGHT", 10, 0)
infoRapport:SetPoint("RIGHT", pageJournal, "RIGHT", -8, 0)
infoRapport:SetJustifyH("LEFT")
infoRapport:SetHeight(28)
infoRapport:SetText("Ctrl+C dans la fenêtre qui s'ouvre.")

-- ----------------------------------------------------------------------------
Rafraichir = function()
    local opt = OptionsSauvees()

    caseActif:SetChecked(AFR.Actif())

    caseInterface:SetChecked(not opt.sansInterception)
    casePlaques:SetChecked(not opt.sansPlaques)
    caseBarresDeVie:SetChecked(opt.barresDeVie and true or false)
    caseMinimap:SetChecked(not opt.minimapCache)
    caseDebug:SetChecked(opt.debug and true or false)

    for _, section in ipairs(sectionsAddons) do
        local installe = section.def.estLa()
        section.badge:SetText(installe and "|cff00ff00installé|r"
            or "|cff808080absent|r")
        for _, c in ipairs(section.cases) do
            if c.def.inversee then
                c.case:SetChecked(not opt[c.def.cle])
            else
                c.case:SetChecked(opt[c.def.cle] and true or false)
            end
            if installe then c.case:Enable() else c.case:Disable() end
            c.case:SetAlpha(installe and 1 or 0.45)
            local etiquette = _G[c.def.nomGlobal .. "Text"]
            local police = installe and GameFontHighlightLeft
                or GameFontDisableLeft
            if etiquette and police then
                etiquette:SetFontObject(police)
            end
        end
    end

    local somme = 0
    for i, categorie in ipairs(CATEGORIES) do
        local n = Compter(categorie[1])
        somme = somme + n
        if n > 0 then
            lignes[i]:SetText(string.format("%s |cffffffff%d|r",
                categorie[2], n))
        else
            lignes[i]:SetText("|cff808080" .. categorie[2] .. " —|r")
        end
    end
    total:SetText(string.format("|cffffd100%d|r", somme))

    local attente = TotalRecolte()
    if attente > 0 then
        etat:SetText(string.format(
            "|cffff9900%d|r textes pas encore traduits chez vous", attente))
        etatDetail:SetText("Notés automatiquement — partiront avec le "
            .. "prochain rapport.")
    else
        etat:SetText("|cff00ff00Tout ce que vous avez croisé est traduit.|r")
        etatDetail:SetText("Explorez pour découvrir du contenu inédit.")
    end

    local n = AFR.NombreSignalements and AFR.NombreSignalements() or 0
    if n > 0 then
        signalements:SetText(string.format(
            "|cffff9900%d|r souci(s) signalé(s) à partager.", n))
    else
        signalements:SetText("")
    end
end

AfficherOnglet = function(i)
    panneau.selectedTab = i
    for k, bouton in ipairs(onglets) do
        StyleNav(bouton, k == i)
    end
    for k, page in ipairs(pages) do
        if k == i then page:Show() else page:Hide() end
    end
    Rafraichir()
end

-- ----------------------------------------------------------------------------
caseActif:SetScript("OnClick", function(self)
    local opt = OptionsSauvees()
    opt.desactive = not self:GetChecked() or nil
    if self:GetChecked() then
        print("|cffc47030Perso|r : traduction activée (/reload conseillé).")
    else
        print("|cffc47030Perso|r : traduction désactivée "
            .. "(/reload pour tout rétablir en anglais).")
    end
    Rafraichir()
end)

caseInterface:SetScript("OnClick", function(self)
    local opt = OptionsSauvees()
    opt.sansInterception = (not self:GetChecked()) or nil
    print("|cffc47030Perso|r : interface d'Ascension "
        .. (self:GetChecked() and "traduite." or "laissée en anglais."))
    Rafraichir()
end)

casePlaques:SetScript("OnClick", function(self)
    local opt = OptionsSauvees()
    opt.sansPlaques = (not self:GetChecked()) or nil
    print("|cffc47030Perso|r : plaques de nom "
        .. (self:GetChecked() and "traduites."
            or "laissées en anglais (/reload pour les déjà traduites)."))
    Rafraichir()
end)

caseBarresDeVie:SetScript("OnClick", function(self)
    local opt = OptionsSauvees()
    opt.barresDeVie = self:GetChecked() and true or nil
    Rafraichir()
end)

caseMinimap:SetScript("OnClick", function(self)
    if AFR.MinimapVisible then
        AFR.MinimapVisible(self:GetChecked() and true or false)
    end
end)

caseDebug:SetScript("OnClick", function(self)
    local opt = OptionsSauvees()
    opt.debug = self:GetChecked() and true or nil
    Rafraichir()
end)

panneau.refresh = Rafraichir
panneau:SetScript("OnShow", function()
    AfficherOnglet(panneau.selectedTab or 1)
    _PersoBoutonsBas(true)
end)
panneau:HookScript("OnHide", function()
    _PersoBoutonsBas(false)
end)

panneau.selectedTab = 1
pageAccueil:Show()

if type(InterfaceOptions_AddCategory) == "function" then
    InterfaceOptions_AddCategory(panneau)
end

AFR.PanneauAide = panneau

-- ----------------------------------------------------------------------------
-- Partage du journal — la fenêtre « Signaler un souci »
--
-- Un addon 3.3.5 ne peut pas écrire dans le presse-papiers : le seul chemin
-- est une zone de saisie dont le texte est présélectionné, que le joueur
-- copie avec Ctrl+C. On y joint le contexte (version, client, comptes) et
-- les rubriques de détail, pour que le rapport se suffise à lui-même.
-- ----------------------------------------------------------------------------
local fenetreCopie = CreateFrame("Frame", "AscensionFRCopie", UIParent)
fenetreCopie:SetSize(620, 440)
fenetreCopie:SetPoint("CENTER")
fenetreCopie:SetFrameStrata("FULLSCREEN_DIALOG")
fenetreCopie:SetBackdrop({
    bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background",
    edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
    tile = true, tileSize = 32, edgeSize = 32,
    insets = { left = 11, right = 12, top = 12, bottom = 11 },
})
fenetreCopie:EnableMouse(true)
fenetreCopie:SetMovable(true)
fenetreCopie:RegisterForDrag("LeftButton")
fenetreCopie:SetScript("OnDragStart", fenetreCopie.StartMoving)
fenetreCopie:SetScript("OnDragStop", fenetreCopie.StopMovingOrSizing)
fenetreCopie:Hide()
-- Échap ferme la fenêtre, comme toute fenêtre du jeu.
if type(UISpecialFrames) == "table" then
    table.insert(UISpecialFrames, "AscensionFRCopie")
end

local titreCopie = fenetreCopie:CreateFontString(nil, "ARTWORK",
    "GameFontNormal")
titreCopie:SetPoint("TOP", 0, -16)
titreCopie:SetText("Signaler un souci — AscensionFR Perso")

local aideCopie = fenetreCopie:CreateFontString(nil, "ARTWORK",
    "GameFontHighlightSmall")
aideCopie:SetPoint("TOP", titreCopie, "BOTTOM", 0, -6)
-- bornée à la fenêtre : ancre centrale seule = largeur illimitée (vécu)
aideCopie:SetPoint("LEFT", fenetreCopie, "LEFT", 16, 0)
aideCopie:SetPoint("RIGHT", fenetreCopie, "RIGHT", -16, 0)
aideCopie:SetJustifyH("CENTER")
aideCopie:SetHeight(42)
aideCopie:SetText("Rapport prêt. |cffffff00Ctrl+C|r pour copier, puis collez-le où vous voulez.\n"
    .. "(Plus simple : Compagnon Perso.) |cffffff00Échap|r ferme.")

-- Le lien du Discord, copiable (Ctrl+C) : un addon ne peut ni ouvrir un
-- navigateur ni écrire dans le presse-papiers ; une zone de saisie
-- présélectionnée est le seul chemin.
local etiquetteDiscord = fenetreCopie:CreateFontString(nil, "ARTWORK",
    "GameFontNormalSmall")
etiquetteDiscord:SetPoint("TOPLEFT", 20, -56)
etiquetteDiscord:SetText("GitHub (Ctrl+C) :")

local lienDiscord = CreateFrame("EditBox", "AscensionFRLienDiscord",
    fenetreCopie, "InputBoxTemplate")
lienDiscord:SetSize(340, 20)
lienDiscord:SetPoint("LEFT", etiquetteDiscord, "RIGHT", 10, 0)
lienDiscord:SetAutoFocus(false)
lienDiscord:SetText(DISCORD)
lienDiscord:SetCursorPosition(0)
lienDiscord:SetScript("OnEscapePressed", function(self) self:ClearFocus() end)
lienDiscord:SetScript("OnEditFocusGained", function(self) self:HighlightText() end)
lienDiscord:SetScript("OnMouseUp", function(self)
    self:SetFocus(); self:HighlightText()
end)
-- Lecture seule de fait : toute frappe est annulée, le lien reste intact.
lienDiscord:SetScript("OnTextChanged", function(self)
    if self:GetText() ~= DISCORD then
        self:SetText(DISCORD); self:SetCursorPosition(0)
    end
end)

local defilementCopie = CreateFrame("ScrollFrame", "AscensionFRCopieScroll",
    fenetreCopie, "UIPanelScrollFrameTemplate")
defilementCopie:SetPoint("TOPLEFT", 18, -88)
defilementCopie:SetPoint("BOTTOMRIGHT", -38, 44)

local zoneCopie = CreateFrame("EditBox", "AscensionFRCopieZone",
    defilementCopie)
zoneCopie:SetMultiLine(true)
zoneCopie:SetAutoFocus(false)
zoneCopie:SetWidth(560)
zoneCopie:SetHeight(4000)
if ChatFontNormal then zoneCopie:SetFontObject(ChatFontNormal) end
zoneCopie:SetScript("OnEscapePressed", function() fenetreCopie:Hide() end)
defilementCopie:SetScrollChild(zoneCopie)

local fermerCopie = CreateFrame("Button", nil, fenetreCopie,
    "UIPanelButtonTemplate")
fermerCopie:SetSize(100, 22)
fermerCopie:SetPoint("BOTTOM", 95, 16)
fermerCopie:SetText("Fermer")
fermerCopie:SetScript("OnClick", function() fenetreCopie:Hide() end)

-- Vider les signalements en attente, une fois le rapport copié. Le compteur du
-- panneau ne se remet plus à zéro tout seul (on ne purge plus au /reload, pour
-- ne pas effacer les retours d'un ami non encore transmis) : ce bouton rend la
-- main à l'utilisateur.
local viderCopie = CreateFrame("Button", nil, fenetreCopie,
    "UIPanelButtonTemplate")
viderCopie:SetSize(190, 22)
viderCopie:SetPoint("RIGHT", fermerCopie, "LEFT", -10, 0)
viderCopie:SetText("Vider les signalements")
viderCopie:SetScript("OnClick", function()
    if AFR.ViderSignalements then AFR.ViderSignalements() end
end)

-- Le contexte technique : sans lui, un journal partagé est une énigme.
local function Contexte()
    local lignesContexte = {}
    local version = type(GetAddOnMetadata) == "function"
        and GetAddOnMetadata("AscensionFR_Perso", "Version") or "?"
    table.insert(lignesContexte, "AscensionFR Perso " .. tostring(version))
    if type(GetBuildInfo) == "function" then
        local jeu, build = GetBuildInfo()
        table.insert(lignesContexte, "Client : " .. tostring(jeu)
            .. " (" .. tostring(build) .. ")"
            .. (type(GetLocale) == "function"
                and " / " .. GetLocale() or ""))
    end
    local somme = 0
    for _, t in pairs(AFR.DB) do
        for _ in pairs(t) do somme = somme + 1 end
    end
    table.insert(lignesContexte, "Traductions chargées : " .. somme)
    table.insert(lignesContexte, "Traduction : "
        .. (AFR.Actif() and "activée" or "désactivée"))
    local attente = type(NombreRecoltes) == "function" and NombreRecoltes() or 0
    table.insert(lignesContexte, "En attente : " .. attente
        .. " texte(s) récolté(s), "
        .. (AFR.NombreSignalements and AFR.NombreSignalements() or 0)
        .. " signalement(s)")
    return lignesContexte
end

-- Le cœur du rapport : les données réellement exploitables. Elles vivent dans
-- AscensionFRSaved (disque), pas dans le journal de session — sans ce déballage
-- le rapport copié n'a que des compteurs. On les met EN TÊTE, avant le journal.
local PLAFOND_RECOLTE = 60

-- Chaque signalement : type + ID + toutes les lignes de l'info-bulle
-- photographiée (gauche, et droite entre crochets). C'est ce qui donne
-- « sort #48512 : <texte anglais> », directement traduisible.
local function AjouterSignalements(blocs)
    local liste = AscensionFRSaved and AscensionFRSaved.Signalements
    if not liste or #liste == 0 then return end
    table.insert(blocs, "")
    table.insert(blocs, "--- Signalements (" .. #liste .. ") ---")
    for _, s in ipairs(liste) do
        local entete = tostring(s.T or "?")
        if s.ID then entete = entete .. " #" .. tostring(s.ID) end
        if s.Q then entete = entete .. "  (" .. s.Q .. ")" end
        table.insert(blocs, entete)
        if s.N and s.N ~= "" then
            table.insert(blocs, "  note : " .. s.N)
        end
        if type(s.L) == "table" then
            for i = 1, #s.L do
                local g = s.L[i] or ""
                local d = (s.R and s.R[i]) or ""
                if g ~= "" and d ~= "" then
                    table.insert(blocs, "  " .. g .. "   [" .. d .. "]")
                elseif g ~= "" then
                    table.insert(blocs, "  " .. g)
                elseif d ~= "" then
                    table.insert(blocs, "  [" .. d .. "]")
                end
            end
        end
    end
end

-- Les échecs d'alignement : un texte connu des bases qui refuse de se traduire
-- (format @...@, variables). ID + texte, par genre (S sorts, O objets).
local function AjouterEchecs(blocs)
    local j = AscensionFRSaved and AscensionFRSaved.EchecsAlignement
    if type(j) ~= "table" then return end
    for genre, entrees in pairs(j) do
        local ids = {}
        for id in pairs(entrees) do table.insert(ids, id) end
        if #ids > 0 then
            table.insert(blocs, "")
            table.insert(blocs, "--- Échecs d'alignement " .. tostring(genre)
                .. " (" .. #ids .. ") ---")
            for _, id in ipairs(ids) do
                local v = entrees[id]
                if type(v) == "table" then
                    table.insert(blocs, tostring(id) .. " :")
                    for _, ligne in ipairs(v) do
                        table.insert(blocs, "  " .. tostring(ligne))
                    end
                else
                    table.insert(blocs, tostring(id) .. " : " .. tostring(v))
                end
            end
        end
    end
end

-- La récolte : tous les textes rencontrés sans traduction. Plafonnée pour ne
-- pas produire un pavé impartageable ; au-delà, on renvoie vers le fichier.
local function AjouterRecolte(blocs)
    local r = AscensionFRSaved and AscensionFRSaved.Recolte
    if type(r) ~= "table" then return end
    local totalRecolte = 0
    for _, cat in pairs(r) do
        for _ in pairs(cat) do totalRecolte = totalRecolte + 1 end
    end
    if totalRecolte == 0 then return end
    table.insert(blocs, "")
    table.insert(blocs, "--- Récolte : rencontrés sans traduction ("
        .. totalRecolte .. ") ---")
    local montres = 0
    for categorie, entrees in pairs(r) do
        for cle, valeur in pairs(entrees) do
            if montres >= PLAFOND_RECOLTE then break end
            local ligne = "[" .. tostring(categorie) .. "] " .. tostring(cle)
            -- Le texte anglais récolté (quêtes surtout) part AVEC la ligne :
            -- sans lui, le rapport ne donnait que des numéros intraduisibles.
            if type(valeur) == "string" and valeur ~= "" then
                ligne = ligne .. " ==> " .. string.sub(valeur, 1, 900)
            end
            table.insert(blocs, ligne)
            montres = montres + 1
        end
        if montres >= PLAFOND_RECOLTE then break end
    end
    if totalRecolte > montres then
        table.insert(blocs, "... +" .. (totalRecolte - montres)
            .. " autres — pour tout, envoie le fichier "
            .. "WTF\\Account\\<compte>\\SavedVariables\\AscensionFRSaved.lua")
    end
end

local function TexteAPartager()
    local blocs = { "Signalement AscensionFR Perso — " .. DISCORD, "" }
    for _, ligne in ipairs(Contexte()) do table.insert(blocs, ligne) end
    -- D'abord l'exploitable (IDs + textes anglais), ensuite le journal.
    AjouterSignalements(blocs)
    AjouterEchecs(blocs)
    AjouterRecolte(blocs)
    table.insert(blocs, "")
    table.insert(blocs, "--- Journal (" .. #AFR.Journal .. " lignes) ---")
    for _, message in ipairs(AFR.Journal) do
        table.insert(blocs, message)
    end
    for rubrique, lignesRubrique in pairs(AFR.Details) do
        table.insert(blocs, "")
        table.insert(blocs, "--- " .. rubrique
            .. " (" .. #lignesRubrique .. ") ---")
        for _, ligne in ipairs(lignesRubrique) do
            table.insert(blocs, ligne)
        end
    end
    return table.concat(blocs, "\n")
end

function AFR.PartagerJournal()
    zoneCopie:SetText(TexteAPartager())
    zoneCopie:HighlightText()
    zoneCopie:SetFocus()
    fenetreCopie:Show()
end

-- Efface les signalements en attente et rafraîchit le panneau. Les échecs
-- d'alignement, eux, se soignent seuls (AFR.OublierEchec quand un texte se
-- remet à traduire) et n'affichent pas de compteur : on ne touche donc qu'aux
-- signalements, ce que montre le panneau.
function AFR.ViderSignalements()
    AscensionFRSaved = AscensionFRSaved or {}
    local n = AFR.NombreSignalements and AFR.NombreSignalements() or 0
    AscensionFRSaved.Signalements = {}
    print(string.format(
        "|cffc47030Perso|r : %d signalement(s) vidé(s).", n))
    Rafraichir()
    fenetreCopie:Hide()
end

-- Ouvre le panneau. InterfaceOptionsFrame_OpenToCategory de 3.3.5 n'ouvre pas
-- la bonne catégorie au premier appel : on l'appelle deux fois, comme le font
-- tous les addons de l'époque.
function AFR.OuvrirOptions()
    if type(InterfaceOptionsFrame_OpenToCategory) ~= "function" then
        print("|cffc47030Perso|r : panneau d'options indisponible ; "
            .. "utilisez /afrp on | off | debug.")
        return
    end
    InterfaceOptionsFrame_OpenToCategory(panneau)
    InterfaceOptionsFrame_OpenToCategory(panneau)
end
