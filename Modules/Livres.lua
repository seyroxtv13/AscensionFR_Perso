-- ============================================================================
-- AscensionFR - Livres et pages (ItemTextFrame)
-- ============================================================================
local AFR = AscensionFR

local frame = CreateFrame("Frame")
frame:RegisterEvent("ITEM_TEXT_READY")
frame:SetScript("OnEvent", function()
    if not AFR.Actif() then return end
    local texte = ItemTextGetText()
    if not texte or texte == "" then return end
    local fr = AFR.ChercherParTexte(AFR.DB.Pages, texte)
    if fr and ItemTextPageText then
        ItemTextPageText:SetText(AFR.Substituer(fr))
    elseif not fr then
        AFR.Recolter("Pages", texte, true)
    end
end)
