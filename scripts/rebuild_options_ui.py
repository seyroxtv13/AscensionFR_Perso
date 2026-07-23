# -*- coding: utf-8 -*-
"""Replace Options.lua panel layout with left-rail Perso UI."""
from pathlib import Path

p = Path(__file__).resolve().parents[1] / "Modules" / "Options.lua"
t = p.read_text(encoding="utf-8")

start = t.index("-- ----------------------------------------------------------------------------\n-- Construction du panneau")
end = t.index("-- ----------------------------------------------------------------------------\n-- Partage du journal")

NEW = r'''-- ----------------------------------------------------------------------------
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
    total:SetText(string.format("|cffffd100%s|r",
        tostring(somme):reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")))

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

'''

# Fix number formatting - Lua doesn't have reverse gsub like that easily for French
# Use simpler total format instead
NEW = NEW.replace(
    '''total:SetText(string.format("|cffffd100%s|r",
        tostring(somme):reverse():gsub("(%d%d%d)", "%1 "):reverse():gsub("^ ", "")))''',
    'total:SetText(string.format("|cffffd100%d|r", somme))',
)

out = t[:start] + NEW + t[end:]
# Fix report header branding
out = out.replace(
    'local blocs = { "Signalement Ascension FR — à coller sur " .. DISCORD, "" }',
    'local blocs = { "Signalement AscensionFR Perso — " .. DISCORD, "" }',
)

p.write_text(out, encoding="utf-8", newline="\n")
print("OK", p, "bytes", len(out))
# Sanity: no CharacterFrame tabs, has rail
for needle in ("CharacterFrameTabButtonTemplate", "local rail =", "entrées en mémoire", "SOUTIEN_URL", "AscensionFR_Perso"):
    print(needle, out.count(needle))
