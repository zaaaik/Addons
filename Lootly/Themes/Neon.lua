local ADDON, NS = ...
local WHITE = "Interface\\Buttons\\WHITE8X8"
local BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"

-- Borde de color de la calidad con resplandor.
NS:RegisterTheme("Neon", {
  label = "Neon",
  Apply = function(row, s, c, highlight)
    row.bg:SetBackdrop({ bgFile = WHITE, edgeFile = BORDER, edgeSize = 10,
      insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    row.bg:SetBackdropColor(0.03, 0.04, 0.1, 0.5 + 0.45 * s.opacity)
    row.bg:SetBackdropBorderColor(c.r, c.g, c.b, 1)
    row.shine:Hide()
    row.accent:Hide()
    row.glow:Show()
    row.glow:ClearAllPoints()
    row.glow:SetPoint("TOPLEFT", 3, -3)
    row.glow:SetPoint("BOTTOMRIGHT", -3, 3)
    local a = (highlight and 0.55 or 0.3) * s.glow
    NS.Gradient(row.glow, "VERTICAL", c.r, c.g, c.b, a, c.r, c.g, c.b, 0)
  end,
})
