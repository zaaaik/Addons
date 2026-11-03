local ADDON, NS = ...
local WHITE = "Interface\\Buttons\\WHITE8X8"
local BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"

-- Tema principal: cristal translúcido flotante.
NS:RegisterTheme("Glass", {
  label = "Glass",
  Apply = function(row, s, c, highlight)
    local bg = row.bg
    bg:SetBackdrop({ bgFile = WHITE, edgeFile = BORDER, edgeSize = 10,
      insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    bg:SetBackdropColor(0.55, 0.65, 0.8, s.opacity * 0.4)
    bg:SetBackdropBorderColor(1, 1, 1, 0.25 + 0.5 * s.glow)

    row.shine:Show()
    row.shine:ClearAllPoints()
    row.shine:SetPoint("TOPLEFT", 3, -3)
    row.shine:SetPoint("TOPRIGHT", -3, -3)
    row.shine:SetHeight(row:GetHeight() * 0.5)
    NS.Gradient(row.shine, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.22 * s.glow)

    row.glow:Show()
    row.glow:ClearAllPoints()
    row.glow:SetPoint("TOPLEFT", 3, -3)
    row.glow:SetPoint("BOTTOMRIGHT", -3, 3)
    local a = (highlight and 0.6 or 0.3) * s.glow
    NS.Gradient(row.glow, "HORIZONTAL", c.r, c.g, c.b, a, c.r, c.g, c.b, 0)

    row.accent:Hide()
  end,
})
