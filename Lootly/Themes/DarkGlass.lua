local ADDON, NS = ...
local WHITE = "Interface\\Buttons\\WHITE8X8"
local BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"

-- Cristal oscuro translúcido.
NS:RegisterTheme("DarkGlass", {
  label = "Dark Glass",
  Apply = function(row, s, c, highlight)
    row.bg:SetBackdrop({ bgFile = WHITE, edgeFile = BORDER, edgeSize = 10,
      insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    row.bg:SetBackdropColor(0.07, 0.09, 0.13, 0.3 + 0.6 * s.opacity)
    row.bg:SetBackdropBorderColor(1, 1, 1, 0.2 + 0.4 * s.glow)

    row.shine:Show()
    row.shine:ClearAllPoints()
    row.shine:SetPoint("TOPLEFT", 3, -3)
    row.shine:SetPoint("TOPRIGHT", -3, -3)
    row.shine:SetHeight(row:GetHeight() * 0.45)
    NS.Gradient(row.shine, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.12 * s.glow)

    row.glow:Show()
    row.glow:ClearAllPoints()
    row.glow:SetPoint("TOPLEFT", 3, -3)
    row.glow:SetPoint("BOTTOMRIGHT", -3, 3)
    NS.Gradient(row.glow, "HORIZONTAL", c.r, c.g, c.b, (highlight and 0.5 or 0.2) * s.glow, c.r, c.g, c.b, 0)
    row.accent:Hide()
  end,
})
