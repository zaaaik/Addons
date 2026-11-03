local ADDON, NS = ...

-- Motor de temas. Cada tema solo define lo visual; las opciones son comunes.
-- def = { label, widthMul, heightMul, Apply(row, s, color, highlight) }
NS.Themes = {}
NS.ThemeOrder = {}

function NS:RegisterTheme(name, def)
  def.widthMul = def.widthMul or 1
  def.heightMul = def.heightMul or 1
  self.Themes[name] = def
  table.insert(self.ThemeOrder, name)
end

function NS:GetTheme()
  return self.Themes[self.db.theme] or self.Themes[self.ThemeOrder[1]]
end

-- Degradado compatible con Retail y Classic.
function NS.Gradient(tex, orientation, r1, g1, b1, a1, r2, g2, b2, a2)
  if tex.SetGradientAlpha then
    tex:SetGradientAlpha(orientation, r1, g1, b1, a1, r2, g2, b2, a2)
  else
    tex:SetGradient(orientation, CreateColor(r1, g1, b1, a1), CreateColor(r2, g2, b2, a2))
  end
end

-- Tema con anillo ornamentado: icono circular dentro del anillo, barra a la derecha
-- y cantidad en un círculo pequeño del anillo.
-- o = { label, texture, circleX, circleY, circleD, textX, bar={r,g,b}, border={r,g,b} }
function NS:RegisterRingTheme(name, o)
  local WHITE = "Interface\\Buttons\\WHITE8X8"
  local BORDER = "Interface\\Tooltips\\UI-Tooltip-Border"
  local function ringSize(s) return s.iconSize / o.circleD end
  self:RegisterTheme(name, {
    label = o.label,
    RowHeight = function(s) return ringSize(s) * 0.85 end,
    Apply = function(row, s, c, highlight)
      local R = ringSize(s)
      local w, h = row:GetSize()
      local barX, barH = R * 0.6, s.iconSize + 10
      local textX = R * (o.textX or 0.28)

      row.bg:ClearAllPoints()
      row.bg:SetPoint("TOPLEFT", row, "TOPLEFT", barX, -(h - barH) / 2)
      row.bg:SetPoint("BOTTOMRIGHT", row, "BOTTOMRIGHT", 0, (h - barH) / 2)
      row.bg:SetBackdrop({ bgFile = WHITE, edgeFile = BORDER, edgeSize = 8,
        insets = { left = 2, right = 2, top = 2, bottom = 2 } })
      row.bg:SetBackdropColor(o.bar[1], o.bar[2], o.bar[3], 0.75 + 0.25 * s.opacity)
      row.bg:SetBackdropBorderColor(o.border[1], o.border[2], o.border[3], 1)

      row.shine:Show()
      row.shine:ClearAllPoints()
      row.shine:SetPoint("TOPLEFT", row.bg, "TOPLEFT", 3, -3)
      row.shine:SetPoint("TOPRIGHT", row.bg, "TOPRIGHT", -3, -3)
      row.shine:SetHeight(barH * 0.5)
      NS.Gradient(row.shine, "VERTICAL", 1, 1, 1, 0, 1, 1, 1, 0.14)

      row.accent:Show()
      row.accent:ClearAllPoints()
      row.accent:SetPoint("BOTTOMLEFT", row.bg, "BOTTOMLEFT", 3, 3)
      row.accent:SetPoint("BOTTOMRIGHT", row.bg, "BOTTOMRIGHT", -3, 3)
      row.accent:SetHeight(3)
      row.accent:SetColorTexture(c.r, c.g, c.b, 1)

      if highlight then
        row.glow:Show()
        row.glow:ClearAllPoints()
        row.glow:SetPoint("TOPLEFT", row.bg, "TOPLEFT", 3, -3)
        row.glow:SetPoint("BOTTOMRIGHT", row.bg, "BOTTOMRIGHT", -3, 3)
        NS.Gradient(row.glow, "HORIZONTAL", c.r, c.g, c.b, 0.35 * s.glow, c.r, c.g, c.b, 0)
      else
        row.glow:Hide()
      end

      row.icon:ClearAllPoints()
      row.icon:SetPoint("CENTER", row, "LEFT", R * o.circleX, 0)
      NS.SetCircleIcon(row, true)

      row.ring:SetTexture(o.texture)
      row.ring:SetSize(R, R)
      row.ring:ClearAllPoints()
      row.ring:SetPoint("TOPLEFT", row.icon, "CENTER", -R * o.circleX, R * o.circleY)
      row.ring:Show()

      row.name:ClearAllPoints()
      row.name:SetPoint("TOPLEFT", row.bg, "TOPLEFT", textX, -5)
      row.name:SetWidth(w - barX - textX - 50)
      row.value:ClearAllPoints()
      row.value:SetPoint("BOTTOMLEFT", row.bg, "BOTTOMLEFT", textX, 7)
      row.value:SetJustifyH("LEFT")

    end,
  })
end
