local ADDON, NS = ...
local WHITE = "Interface\\Buttons\\WHITE8X8"
local BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"

-- Negro sólido, más compacto.
NS:RegisterTheme("Black", {
  label = "Black",
  widthMul = 0.9,
  heightMul = 0.85,
  Apply = function(row, s, c, highlight)
    local bg = row.bg
    bg:SetBackdrop({ bgFile = WHITE, edgeFile = BORDER, edgeSize = 8,
      insets = { left = 2, right = 2, top = 2, bottom = 2 } })
    bg:SetBackdropColor(0.03, 0.03, 0.04, 0.5 + 0.5 * s.opacity)
    bg:SetBackdropBorderColor(c.r, c.g, c.b, 0.9)

    row.shine:Hide()

    row.accent:Show()
    row.accent:ClearAllPoints()
    row.accent:SetPoint("TOPLEFT", 3, -3)
    row.accent:SetPoint("BOTTOMLEFT", 3, 3)
    row.accent:SetWidth(3)
    row.accent:SetColorTexture(c.r, c.g, c.b, 1)

    if highlight then
      row.glow:Show()
      row.glow:ClearAllPoints()
      row.glow:SetPoint("TOPLEFT", 3, -3)
      row.glow:SetPoint("BOTTOMRIGHT", -3, 3)
      NS.Gradient(row.glow, "HORIZONTAL", c.r, c.g, c.b, 0.35 * s.glow, c.r, c.g, c.b, 0)
    else
      row.glow:Hide()
    end
  end,
})
