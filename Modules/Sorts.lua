-- ============================================================================
-- AscensionFR - Sorts
--
-- Les descriptions des sorts contiennent des variables ($s1 dégâts, $d durée,
-- $t1 intervalle...) que le CLIENT résout lui-même avant l'affichage. On ne
-- peut donc pas écrire bêtement la description française : « inflige $s1
-- dégâts » s'afficherait tel quel.
--
-- Méthode : la base fournit le modèle anglais (DE) en plus du texte français
-- (D). On aligne le modèle anglais sur l'info-bulle réellement affichée pour
-- récupérer les valeurs calculées par le client, puis on les replace dans le
-- modèle français.
--
--   modèle EN  : "Shock an enemy for $s1 Nature damage over $d."
--   affiché EN : "Shock an enemy for 15 Nature damage over 6 sec."
--                 -> $s1 = "15", $d = "6 sec"
--   modèle FR  : "Choque un ennemi, infligeant $s1 dégâts de Nature en $d."
--   résultat   : "Choque un ennemi, infligeant 15 dégâts de Nature en 6 sec."
-- ============================================================================
local AFR = AscensionFR

-- Échecs d'alignement déjà signalés dans le chat, par identifiant de sort.
-- Une info-bulle se redessine en continu tant qu'on la survole — et un buff
-- permanent la redessine sans arrêt. Sans cette mémoire, le même message
-- inonde le chat en mode débogage (vécu sur le sort 807729). Une ligne par
-- sort et par session suffit à diagnostiquer ; le journal détaillé destiné
-- au Compagnon, lui, continue d'être tenu à jour à chaque passage.
local echecsSignales = {}

-- Coupe-circuit des alignements : [id] = longueur totale du contenu de la
-- bulle au dernier ÉCHEC. Tant que le contenu ne change pas (mêmes
-- longueurs), on ne refait pas le calcul — il échouerait pareil. Un
-- contenu qui bouge (rang appris, valeurs recalculées) relance l'essai.
local echecsRecents = {}

-- Motifs des variables de sorts. Les motifs Lua ne connaissent pas
-- l'alternance : on les essaie un par un et on retient la correspondance la
-- plus précoce (la plus longue en cas d'égalité).
-- Recensées sur les 36 000 sorts réels du serveur (outils/auditer_sorts.py),
-- pas devinées : ne lister que les formes attendues laissait 5 % des modèles
-- inalignables, donc autant de descriptions bloquées en anglais.
local MOTIFS_VARIABLE = {
    "%$%b{}",                       -- ${ calcul }
    "%$%?[^%[]*%b[]%b[]",           -- $?condition[oui][non]
    "%$%?[^%[]*%b[]",               -- $?condition[texte]
    "%$[/%*%+%-]%d+;%d*%a%d*",      -- $/1000;s1 $*15;s1 $+100;s1 (opérations)
    "%$[GgLl][^;]*;",               -- $gm:f;  $lseconde:secondes;
    "%$@%a+",                       -- $@spellname
    "%$<%a+>",                      -- $<percent> $<mult>  (variable nommée)
    "%$%d+%a%d*",                   -- $64843s2  (valeur d'un autre sort)
    "%$%a%d*",                      -- $s1 $d $h $u $t $o $q $a $x $e $z $F...
    "%$%d+",                        -- $1

    -- Marquage maison d'Ascension, résolu par LEUR client avant affichage.
    -- On le traite comme des variables : la capture absorbe ce que le client
    -- a affiché à la place (rien pour @ext:, la description insérée pour
    -- @s:...), sans qu'on ait à imiter son rendu. 3 646 sorts traduits
    -- restaient en anglais parce que ces marqueurs cassaient l'alignement.
    "@ifknown:.-:ifknown@",         -- texte conditionnel (si sort connu)
    "@ifnotknown:.-:ifnotknown@",
    "@wflocation:[^@]*@",           -- indice de localisation Worldforge
    "@%a+:%d+:%-?%d+@",             -- @s:101087:0@  @re:81298:0@ (insertion)
    "@%a+:%d+:%a+@",                -- @req:1122520:req@
    "@%a+:%d+@",                    -- @req:8921@ @unlockby:635@ @learns:...
    "@ext:",                        -- ouverture de bloc d'info étendue
    ":ext@",                        -- fermeture
}

-- Échappe les caractères spéciaux des motifs Lua.
local function echapper(texte)
    return (string.gsub(texte, "([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1"))
end

-- Retire les codes couleur |cAARRGGBB...|r. Ils sont cosmétiques et le client
-- d'Ascension ne les affiche pas toujours sur ses sorts custom : les garder
-- dans le modèle EN alors que l'affiché en est dépourvu cassait l'alignement.
-- On les retire des deux côtés AVANT d'aligner ; le résultat français, lui,
-- vient du modèle FR NON dénudé, donc il garde ses propres couleurs.
local function retirer_couleurs(texte)
    if not texte then return texte end
    texte = string.gsub(texte, "|c%x%x%x%x%x%x%x%x", "")
    return (string.gsub(texte, "|r", ""))
end

-- Échappe un littéral en rendant SOUPLE son espace de tête et de queue (`%s*`).
-- Quand un bloc conditionnel (@ifknown, $?s...[..][..]) se résout à vide, le
-- client fait aussi disparaître les sauts de ligne qui l'entouraient ; un
-- espace rigide laissait alors toute la description en anglais (vécu :
-- « Flammes de Xoroth », bloc @ifknown final non appris). Le cœur du littéral
-- reste, lui, strict.
local function echapper_souple(litteral)
    if litteral == "" then return "" end
    -- Séparateur ENTIÈREMENT blanc entre deux variables : il doit rester
    -- EXIGÉ (%s+, pas %s*). Sinon, avec des captures paresseuses, « $s1 $s2 »
    -- sur « 15 20 » donne $s1="" et $s2="15 20" — un nombre dans le mauvais
    -- champ, qu'aucun garde-fou n'attrape. Le cas du bloc conditionnel rendu
    -- vide passe, lui, par le %s* de tête/queue d'un littéral PORTEUR de texte
    -- (voir plus bas), pas par un séparateur tout blanc.
    if string.find(litteral, "^%s*$") then return "%s+" end
    local coeur = string.match(litteral, "^%s*(.-)%s*$")
    local motif = echapper(coeur)
    if string.find(litteral, "^%s") then motif = "%s*" .. motif end
    if string.find(litteral, "%s$") then motif = motif .. "%s*" end
    return motif
end

-- Cherche la prochaine variable à partir de `position`.
local function prochaine_variable(modele, position)
    local meilleur_debut, meilleur_fin
    for _, motif in ipairs(MOTIFS_VARIABLE) do
        local debut, fin = string.find(modele, motif, position)
        if debut then
            if not meilleur_debut or debut < meilleur_debut
                or (debut == meilleur_debut and fin > meilleur_fin) then
                meilleur_debut, meilleur_fin = debut, fin
            end
        end
    end
    return meilleur_debut, meilleur_fin
end

-- Découpe un modèle en parties littérales et en variables.
-- Exposée sous AFR.DecouperModele pour que les tests puissent vérifier, sur
-- les vraies données du jeu, qu'aucune forme de variable ne nous échappe :
-- un « $ » restant dans une partie littérale condamne l'alignement.
local decouper
function decouper(modele)
    local litteraux, variables = {}, {}
    local position = 1
    while true do
        local debut, fin = prochaine_variable(modele, position)
        if not debut then break end
        table.insert(litteraux, string.sub(modele, position, debut - 1))
        table.insert(variables, string.sub(modele, debut, fin))
        position = fin + 1
    end
    table.insert(litteraux, string.sub(modele, position))
    return litteraux, variables
end

AFR.DecouperModele = decouper

-- Préfixe d'une variable conditionnelle : « $?s300512[oui][non] » ->
-- « $?s300512 ». C'est la seule partie IDENTIQUE entre le modèle anglais et
-- le modèle français : le texte entre crochets, lui, est TRADUIT côté FR —
-- chercher la valeur par la variable entière échouait donc toujours
-- (vécu : « Tempête juste », 805409, bloquée en anglais, 22/07/2026).
local function prefixe_conditionnel(variable)
    return string.match(variable, "^(%$%?[^%[]*)%[")
end

-- Extrait les valeurs substituées par le client.
-- Renvoie { ["$s1"] = "15", ["$d"] = "6 sec" } + une table séparée pour les
-- conditionnelles, indexée par PRÉFIXE (voir ci-dessus), portant la valeur
-- affichée ET la variable anglaise complète (ses crochets servent à traduire
-- une branche non vide). Ou nil si l'affiché ne correspond pas au modèle.
local function extraire_valeurs(modele_en, affiche_en)
    local litteraux, variables = decouper(modele_en)
    if #variables == 0 then return {} end

    -- Construit un motif de capture : littéral, (capture), littéral...
    -- Espace de tête/queue souple (echapper_souple) : un bloc conditionnel
    -- rendu vide fait disparaître les sauts de ligne qui l'entouraient.
    local motif = "^"
    for i, litteral in ipairs(litteraux) do
        motif = motif .. echapper_souple(litteral)
        if i <= #variables then motif = motif .. "(.-)" end
    end
    motif = motif .. "$"

    local captures = { string.match(affiche_en, motif) }
    if #captures ~= #variables then return nil end

    local valeurs, conditionnelles = {}, {}
    for i, variable in ipairs(variables) do
        local valeur = captures[i]
        if valeur == nil then return nil end
        -- Une même variable doit donner la même valeur partout
        if valeurs[variable] and valeurs[variable] ~= valeur then
            return nil
        end
        valeurs[variable] = valeur
        local prefixe = prefixe_conditionnel(variable)
        if prefixe then
            local existante = conditionnelles[prefixe]
            if existante and (existante.valeur ~= valeur
                or existante.var_en ~= variable) then
                -- Deux conditionnelles au même préfixe qui divergent : on ne
                -- saurait pas laquelle sert au modèle français — ambigu.
                conditionnelles[prefixe] = { ambigu = true }
            elseif not existante then
                conditionnelles[prefixe] =
                    { valeur = valeur, var_en = variable }
            end
        end
    end
    return valeurs, conditionnelles
end

-- L'intérieur du n-ième bloc [ ... ] d'une variable conditionnelle.
local function interieur_crochets(variable, rang)
    local compte = 0
    for bloc in string.gmatch(variable, "%b[]") do
        compte = compte + 1
        if compte == rang then
            return string.sub(bloc, 2, -2)
        end
    end
end

-- Le client étant anglais, les valeurs qu'il calcule contiennent ses propres
-- mots ($d -> « 1 hour 30 min »). On francise ces unités : chaque mot suivant
-- un nombre est remplacé une seule fois, via une table (des gsub en chaîne
-- se ré-appliqueraient à leur propre résultat : « seconds » -> « secondees »).
local UNITES = {
    ["hour"] = "heure",     ["hours"] = "heures",
    ["day"] = "jour",       ["days"] = "jours",
    ["yard"] = "mètre",     ["yards"] = "mètres",
    ["min"] = "min",        ["mins"] = "min",
    ["minute"] = "minute",  ["minutes"] = "minutes",
    ["sec"] = "sec",        ["secs"] = "sec",
    ["second"] = "seconde", ["seconds"] = "secondes",
}

local function franciser_unites(valeur)
    return (string.gsub(valeur, "(%d)(%s+)(%a+)", function(nombre, espace, mot)
        return nombre .. espace .. (UNITES[string.lower(mot)] or mot)
    end))
end

-- Replace les valeurs dans le modèle français.
local function appliquer_valeurs(modele_fr, valeurs, conditionnelles)
    local litteraux, variables = decouper(modele_fr)
    local morceaux = {}
    for i, litteral in ipairs(litteraux) do
        table.insert(morceaux, litteral)   -- littéral FR : couleurs conservées
        local variable = variables[i]
        if variable then
            -- Les valeurs sont indexées par la variable EN DÉNUDÉE (le modèle
            -- anglais a été dénudé avant l'alignement) : on cherche donc avec
            -- la variable FR elle aussi dénudée, sinon un bloc coloré des deux
            -- côtés (@ifknown avec |cff..|r) ne se retrouverait jamais.
            local nue = retirer_couleurs(variable)
            local valeur = valeurs[nue]
            if valeur == nil then
                -- Variable conditionnelle : son texte entre crochets est
                -- TRADUIT côté français, la recherche par variable entière
                -- ne peut pas aboutir — on passe par le PRÉFIXE, identique
                -- des deux côtés.
                local prefixe = prefixe_conditionnel(nue)
                local cond = prefixe and conditionnelles
                    and conditionnelles[prefixe]
                if cond and not cond.ambigu then
                    if cond.valeur == "" then
                        -- Branche résolue à vide : rien à afficher.
                        valeur = ""
                    else
                        -- Branche affichée (texte anglais, nombres résolus) :
                        -- on la traduit avec sa jumelle française — même
                        -- moteur, un cran plus bas. Crochet « oui » d'abord,
                        -- crochet « non » sinon.
                        for rang = 1, 2 do
                            local en_bloc = interieur_crochets(
                                cond.var_en, rang)
                            local fr_bloc = interieur_crochets(nue, rang)
                            if en_bloc and fr_bloc then
                                valeur = AFR.TraduireTexteSort(
                                    fr_bloc, en_bloc, cond.valeur)
                                if valeur then break end
                            end
                        end
                    end
                end
            end
            -- Variable toujours irrésolue : on ne sait pas faire.
            if valeur == nil then return nil end
            table.insert(morceaux, franciser_unites(valeur))
        end
    end
    return table.concat(morceaux)
end

-- Les fins de ligne diffèrent entre le modèle et l'affiché : les DBC écrivent
-- « \r\n », mais la chaîne peut avoir perdu son « \r » en chemin. Un caractère
-- invisible ne doit pas faire échouer tout l'alignement — c'est ce qui laissait
-- des descriptions entières en anglais (« modèle non aligné »).
local function normaliser_lignes(texte)
    if not texte then return nil end
    texte = string.gsub(texte, "\r\n", "\n")
    return (string.gsub(texte, "\r", "\n"))
end

-- Le client REPLIE les blocs @ext:...:ext@ : tant que MAJ n'est pas
-- enfoncée, il affiche « Hold SHIFT for more information » à la place du
-- contenu. Le modèle porte le contenu, l'écran porte l'indice : rien ne peut
-- s'aligner (vécu : « Libram de consécration », signalement du 17/07). On
-- retire alors le bloc des deux modèles et l'indice de l'affiché, on aligne
-- le reste, et on remet l'indice — en français.
local INDICE_MAJ = "Hold SHIFT for more information"
local INDICE_MAJ_FR = "|cff00DDFFMaintenez MAJ pour plus d'informations|r"

local function RetirerBlocsExt(texte)
    texte = string.gsub(texte, "%s*@ext:.-:ext@", "")
    return (string.gsub(texte, "%s+$", ""))
end

local function RetirerIndiceMaj(texte)
    texte = string.gsub(texte,
        "%s*|c%w%w%w%w%w%w%w%w" .. INDICE_MAJ .. "|r", "")
    texte = string.gsub(texte, "%s*" .. INDICE_MAJ, "")
    return (string.gsub(texte, "%s+$", ""))
end

-- ----------------------------------------------------------------------------
-- Tolérance aux nombres calculés par le client
-- ----------------------------------------------------------------------------
-- Ascension ne stocke pas toujours une variable ($s1) : pour beaucoup de ses
-- sorts maison, le serveur donne une FORMULE (« 24+Spi*0.25+AP*.2+SP*.58 ») et
-- le client affiche le résultat. Deux personnages voient donc deux nombres
-- différents, et un modèle relevé chez un joueur ne collera jamais au chiffre
-- près chez un autre (vécu : « Réparation Sanguine », 31 chez l'un, 34 chez
-- l'autre). Quand TOUT le reste est identique, on reporte simplement les
-- nombres affichés dans le texte français.
-- Bonus : un seul modèle couvre alors tous les rangs d'un même sort.
local NOMBRE = "%d+"

-- Littéral transformé en motif, avec les ESPACES SOUPLES : une espace en trop
-- avant un saut de ligne ne doit pas condamner tout l'alignement (vécu : le
-- client écrit « ...Intellect. \r\n », le modèle « ...Intellect.\n » — une
-- seule espace invisible laissait la description entière en anglais).
local function litteral_souple(litteral)
    local motif, position = "", 1
    while true do
        local debut, fin = string.find(litteral, "%s+", position)
        if not debut then break end
        motif = motif .. echapper(string.sub(litteral, position, debut - 1))
            .. "%s+"
        position = fin + 1
    end
    return motif .. echapper(string.sub(litteral, position))
end

-- Modèle où chaque nombre devient une capture, le reste restant littéral.
local function motif_nombres(modele)
    local motif, position = "^", 1
    while true do
        local debut, fin = string.find(modele, NOMBRE, position)
        if not debut then break end
        motif = motif .. litteral_souple(string.sub(modele, position,
                                                    debut - 1))
            .. "(" .. NOMBRE .. ")"
        position = fin + 1
    end
    return motif .. litteral_souple(string.sub(modele, position)) .. "$"
end

-- Remplace les nombres du français SANS toucher aux codes couleur et texture
-- (« |cff32cd32 », « |T...:0|t ») qui contiennent eux aussi des chiffres : on
-- les met à l'abri derrière des marqueurs qui, eux, n'en contiennent pas.
local function remplacer_nombres(texte, vers)
    local couleurs, textures = {}, {}
    texte = string.gsub(texte, "|c%x%x%x%x%x%x%x%x", function(code)
        table.insert(couleurs, code)
        return "\1"
    end)
    texte = string.gsub(texte, "|T.-|t", function(code)
        table.insert(textures, code)
        return "\2"
    end)
    texte = string.gsub(texte, NOMBRE, function(n) return vers[n] or n end)
    local i, j = 0, 0
    texte = string.gsub(texte, "\1", function()
        i = i + 1
        return couleurs[i]
    end)
    return (string.gsub(texte, "\2", function()
        j = j + 1
        return textures[j]
    end))
end

-- Rend le français avec les nombres de l'affiché, ou nil si ça ne colle pas.
local function aligner_nombres(modele_fr, modele_en, affiche_en)
    local attendus = {}
    for n in string.gmatch(modele_en, NOMBRE) do
        table.insert(attendus, n)
    end
    if #attendus == 0 then return nil end
    local trouves = { string.match(affiche_en, motif_nombres(modele_en)) }
    if #trouves ~= #attendus then return nil end
    -- Correspondance par VALEUR et non par position : l'ordre des nombres peut
    -- différer en français. Une même valeur qui devrait devenir deux choses
    -- différentes est ambiguë — on renonce plutôt que d'inventer.
    local vers = {}
    for i, ancien in ipairs(attendus) do
        if vers[ancien] and vers[ancien] ~= trouves[i] then return nil end
        vers[ancien] = trouves[i]
    end
    return remplacer_nombres(modele_fr, vers)
end

AFR.AlignerNombres = aligner_nombres      -- exposé pour les tests

-- Traduit un texte de sort en s'appuyant sur le texte anglais affiché.
-- Renvoie nil si la correspondance échoue : mieux vaut l'anglais qu'un texte
-- avec des « $s1 » visibles.
function AFR.TraduireTexteSort(modele_fr, modele_en, affiche_en)
    if not modele_fr then return nil end
    -- Bloc @ext replié ? On traduit la version repliée.
    local indice = ""
    if affiche_en and modele_en
        and string.find(affiche_en, INDICE_MAJ, 1, true)
        and string.find(modele_en, "@ext:", 1, true) then
        modele_en = RetirerBlocsExt(modele_en)
        modele_fr = RetirerBlocsExt(modele_fr)
        affiche_en = RetirerIndiceMaj(affiche_en)
        indice = "\n\n" .. INDICE_MAJ_FR
    end
    -- Codes couleur retirés pour TOUTE la phase d'alignement (modèle EN +
    -- affiché). Le résultat français vient de modele_fr NON dénudé : il garde
    -- donc ses propres couleurs.
    local modele_en_nu = retirer_couleurs(modele_en)
    local affiche_nu = retirer_couleurs(affiche_en)

    -- Pas de variable : le texte français s'utilise directement. Le critère
    -- est le découpeur lui-même, pas la seule présence d'un « $ » : un modèle
    -- sans dollar peut porter un marquage @s:...@ qui exige l'alignement
    -- (« Tempête juste » : le client insère toute une description à cet
    -- endroit).
    local a_variables = false
    if modele_en_nu then
        local _, vars_en = decouper(modele_en_nu)
        a_variables = #vars_en > 0
    end
    if not a_variables then
        local _, vars_fr = decouper(modele_fr)
        if #vars_fr > 0 or string.find(modele_fr, "%$") then
            return nil
        end
        -- Sans variable, on ne traduit que LA ligne qui EST le modèle
        -- anglais. Rendre le français sans vérifier remplaçait chaque ligne
        -- longue de l'info-bulle par la même phrase (vécu : hache aux
        -- enchantements multiples, « Livre des artisans » en triple).
        local function egaliser(texte)
            texte = normaliser_lignes(texte)
            return (string.gsub(texte, "^%s*(.-)%s*$", "%1"))
        end
        -- Comparaison indifférente aux espaces : le client sème parfois une
        -- espace de plus (« Intellect. \r\n » contre « Intellect.\n »). Le
        -- français rendu, lui, reste intact — on ne compare que pour décider.
        local function sans_espaces(texte)
            return (string.gsub(egaliser(texte), "%s+", " "))
        end
        if modele_en_nu and affiche_nu then
            local modele_nu = egaliser(modele_en_nu)
            local affiche = egaliser(affiche_nu)
            if sans_espaces(affiche) == sans_espaces(modele_nu) then
                return modele_fr .. indice
            end
            -- Seuls les NOMBRES diffèrent ? Le client les a calculés d'après
            -- le personnage : on reporte ceux de l'écran dans le français.
            local avec_nombres = aligner_nombres(modele_fr, modele_nu, affiche)
            if avec_nombres then return avec_nombres .. indice end
        end
        return nil
    end
    if not affiche_nu then return nil end
    affiche_nu = normaliser_lignes(affiche_nu)
    local valeurs, conditionnelles =
        extraire_valeurs(normaliser_lignes(modele_en_nu), affiche_nu)
    if not valeurs then return nil end
    local resultat = appliquer_valeurs(modele_fr, valeurs, conditionnelles)
    if not resultat then return nil end

    -- Garde-fou final : le joueur ne doit JAMAIS voir un « $ » à la place
    -- d'un chiffre. Si le texte français en contient plus que l'info-bulle
    -- anglaise (qui, elle, est déjà résolue), c'est qu'une variable a été
    -- abîmée en amont — typiquement par le traducteur automatique, dont la
    -- liste de codes à protéger avait divergé de celle-ci. On rend alors
    -- l'anglais, qui est correct.
    -- Ascension laisse quelques « $ » littéraux dans ses propres textes : ils
    -- apparaissent des deux côtés, d'où la comparaison par nombre plutôt que
    -- par présence.
    local _, dollars_fr = string.gsub(resultat, "%$", "")
    local _, dollars_en = string.gsub(affiche_nu, "%$", "")
    if dollars_fr > dollars_en then
        AFR.Debug("variable abîmée dans le texte français, anglais conservé")
        return nil
    end
    -- Un bloc conditionnel résolu à vide peut laisser un saut de ligne en fin
    -- de description : on le retire (l'indice @ext, lui, est rajouté après).
    resultat = (string.gsub(resultat, "%s+$", ""))
    return resultat .. indice
end

-- ----------------------------------------------------------------------------
-- Application aux info-bulles
-- ----------------------------------------------------------------------------
local function LigneGauche(tooltip, i)
    return _G[tooltip:GetName() .. "TextLeft" .. i]
end

-- Cherche, parmi toutes les lignes de l'info-bulle, celle que le modèle sait
-- aligner. Deviner « la dernière ligne longue » ne marche pas : Ascension
-- ajoute après la description d'autres lignes (« Applies Sacred Restraint »,
-- l'encadré du buff...), et on tentait alors d'aligner le modèle contre un
-- texte qui n'a rien à voir. L'alignement est lui-même le bon critère : la
-- description est la ligne qui correspond au modèle.
local function TraduireDescription(tooltip, modele_fr, modele_en)
    -- Toutes les lignes qui s'alignent, pas seulement la première : les
    -- objets de collection d'Ascension répètent le texte du sort (« Livre
    -- des artisans »), et s'arrêter au premier succès laissait le doublon
    -- en anglais.
    local traduit = false
    for i = 2, tooltip:NumLines() do
        local ligne = LigneGauche(tooltip, i)
        local texte = ligne and ligne:GetText()
        if texte and string.len(texte) > 10 then
            local fr = AFR.TraduireTexteSort(modele_fr, modele_en, texte)
            if fr then
                ligne:SetText(fr)
                traduit = true
            end
        end
    end
    return traduit
end

-- ----------------------------------------------------------------------------
-- BASE COMMUNAUTAIRE (don d'un joueur, 22/07/2026 — voir CONTEXTE) : lignes
-- de sorts CoA par MOTIF (nombres capturés -> gabarit {{n}}), relues main.
-- Consultée en PRIORITÉ pour les SpellID couverts ; les variantes génériques
-- partagées (« Level: %d »...) vivent dans SortsLignesCommunes et ne
-- s'essaient QUE sur les sorts couverts.
-- ----------------------------------------------------------------------------
local function AppliquerVariantes(liste, texte)
    if not liste then return end
    for i = 1, #liste do
        local captures = { string.match(texte, liste[i].p) }
        if captures[1] ~= nil then
            return (string.gsub(liste[i].t, "{{(%d+)}}", function(k)
                return captures[tonumber(k)] or ""
            end))
        end
    end
end

local function PasseCommunaute(tooltip, id)
    local fiche = id and AFR.DB.SortsLignes and AFR.DB.SortsLignes[id]
    if not fiche then return false end
    local fait = false
    local l1 = LigneGauche(tooltip, 1)
    if fiche.n and fiche.e and l1 and l1:GetText() == fiche.e then
        l1:SetText(fiche.n)
        fait = true
    end
    for i = 2, tooltip:NumLines() do
        local ligne = LigneGauche(tooltip, i)
        local texte = ligne and ligne:GetText()
        if texte and texte ~= "" then
            local fr = AppliquerVariantes(fiche.v, texte)
                or AppliquerVariantes(AFR.DB.SortsLignesCommunes, texte)
            if fr and fr ~= texte then
                ligne:SetText(fr)
                fait = true
            end
        end
    end
    return fait
end

function AFR.TraduireInfobulleSort(tooltip, id)
    local s = id and AFR.DB.Sorts[id]
    local communaute = PasseCommunaute(tooltip, id)
    -- Sort inconnu des bases, ou connu de NOM seulement : sans ce relevé,
    -- ces sorts n'entraient jamais dans le circuit de récolte — le journal
    -- ne notait que les échecs d'alignement, donc un sort sans description
    -- restait invisible de l'usine, même signalé cent fois par un joueur
    -- (vécu : Testament de ténacité). On relève dès la ligne 1 : le nom
    -- anglais fait partie de ce que l'usine doit apprendre.
    -- (Sauf si la base communautaire vient de le servir : rien à apprendre.)
    if id and (not s or not s.D) and not communaute
            and not echecsSignales[id]
            and AFR.JournaliserEchec then
        echecsSignales[id] = true
        local lignes = {}
        for i = 1, tooltip:NumLines() do
            local l = LigneGauche(tooltip, i)
            local t = l and l:GetText()
            if t and t ~= "" then table.insert(lignes, t) end
        end
        if #lignes > 0 then
            AFR.JournaliserEchec("S", id, lignes)
        end
    end
    if not s then
        if communaute and tooltip:IsShown() then tooltip:Show() end
        return communaute
    end
    local modifie = communaute

    if s.N then
        local l1 = LigneGauche(tooltip, 1)
        if l1 and l1:GetText() then
            -- Conserve les icônes/couleurs éventuelles autour du nom
            l1:SetText(s.N)
            modifie = true
        end
    end

    -- Rang (« Rank 2 » -> « Rang 2 ») : ligne 2 à droite en général
    if s.R then
        local r1 = _G[tooltip:GetName() .. "TextRight1"]
        if r1 and r1:GetText() and string.match(r1:GetText(), "^Rank %d") then
            r1:SetText(s.R)
            modifie = true
        end
    end

    if s.D then
        -- COUPE-CIRCUIT DU CHEMIN COÛTEUX : une bulle qui refuse de
        -- s'aligner se redessine en continu tant qu'on la survole, et
        -- chaque redessin refaisait TOUT le calcul (découpe du modèle,
        -- motifs, extraction) pour échouer pareil. On note la longueur du
        -- contenu au moment de l'échec : tant qu'elle n'a pas bougé,
        -- inutile de réessayer. C'était LA source de lag en survol des
        -- sorts d'époque décalée (vécu : Tempête juste, 805409).
        local signature = 0
        for i = 2, tooltip:NumLines() do
            local l = LigneGauche(tooltip, i)
            local t = l and l:GetText()
            if t then signature = signature + string.len(t) end
        end
        if echecsRecents[id] == signature then
            return modifie
        end
        -- Modèle principal (le lancement), puis modèle secondaire s'il existe.
        -- Un même sort affiche un texte DIFFÉRENT selon la vue : sa description
        -- de lancement, ou l'effet de son buff une fois appliqué. On essaie les
        -- deux (DE2/D2, ajoutés par les corrections). Ce 2e modèle sert aussi
        -- quand Ascension a changé le texte : le live devient le modèle qui
        -- s'aligne, sans toucher au modèle d'origine.
        local aligne = TraduireDescription(tooltip, s.D, s.DE)
        if not aligne and s.D2 then
            aligne = TraduireDescription(tooltip, s.D2, s.DE2)
        end
        if aligne then
            modifie = true
            echecsRecents[id] = nil
            if AFR.OublierEchec then AFR.OublierEchec("S", id) end
        else
            echecsRecents[id] = signature
            -- Servi par la base communautaire : l'échec d'alignement est
            -- NORMAL (les lignes sont déjà françaises) — ni bruit ni journal.
            if not communaute and not echecsSignales[id] then
                echecsSignales[id] = true
                AFR.Debug("sort", id, ": modèle non aligné, anglais conservé")
            end
            -- Journal silencieux pour le compagnon : quelles lignes étaient
            -- affichées quand l'alignement a échoué ?
            if AFR.JournaliserEchec and not communaute then
                local lignes = {}
                for i = 2, tooltip:NumLines() do
                    local l = LigneGauche(tooltip, i)
                    local t = l and l:GetText()
                    if t and t ~= "" then table.insert(lignes, t) end
                end
                if #lignes > 0 then
                    AFR.JournaliserEchec("S", id, lignes)
                end
            end
        end
    end

    if modifie and tooltip:IsShown() then tooltip:Show() end
    return modifie
end
