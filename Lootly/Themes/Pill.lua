local ADDON, NS = ...
local WHITE = "Interface\\Buttons\\WHITE8X8"
local BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"

-- Pastilla minimalista, fondo negro semitransparente.
NS:RegisterTheme("Pill", {
  label = "Pill",
  heightMul = 0.85,
  Apply = function(row, s, c)
    row.bg:SetBackdrop({ bgFile = WHITE, edgeFile = BORDER, edgeSize = 14,
      insets = { left = 4, right = 4, top = 4, bottom = 4 } })
    row.bg:SetBackdropColor(0, 0, 0, 0.3 + 0.5 * s.opacity)
    row.bg:SetBackdropBorderColor(0, 0, 0, 0.6)
    row.shine:Hide()
    row.accent:Hide()
    row.glow:Hide()
  end,
})
