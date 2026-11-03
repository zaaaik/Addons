local ADDON, NS = ...
local L = NS.L
local D = {}
NS.Display = D

local WHITE = "Interface\\Buttons\\WHITE8X8"
local SLIDE, FADE, FAST_FADE, GAP, TRAVEL, EXIT_TRAVEL = 0.3, 0.8, 0.4, 4, 70, 40

local anchor
local pool, active, previews = {}, {}, {}

local function outBack(p)
  local c1 = 1.70158
  local c3 = c1 + 1
  return 1 + c3 * (p - 1) ^ 3 + c1 * (p - 1) ^ 2
end

local function coinString(c)
  local g, s, k = floor(c / 10000), floor(c / 100) % 100, c % 100
  local t = ""
  if g > 0 then t = g .. "|cffffd700g|r " end
  if g > 0 or s > 0 then t = t .. s .. "|cffc7c7cfs|r " end
  return t .. k .. "|cffeda55fc|r"
end

local function rowSize()
  local s, theme = NS.db, NS:GetTheme()
  local h = theme.RowHeight and theme.RowHeight(s) or (s.iconSize + 8) * theme.heightMul
  return s.rowWidth * theme.widthMul, h
end

local function anchorPoint()
  return (NS.db.growUp and "BOTTOM" or "TOP") .. NS.db.side
end

local function layout()
  local _, h = rowSize()
  local sign = NS.db.growUp and 1 or -1
  local n = #active
  for i, row in ipairs(active) do
    row.ty = sign * (n - i) * (h + GAP)
  end
end

local function release(row)
  for i, r in ipairs(active) do
    if r == row then table.remove(active, i) break end
  end
  row:SetScript("OnUpdate", nil)
  row:Hide()
  pool[#pool + 1] = row
  layout()
end

local function fillText(row)
  local s, d = NS.db, row.data
  row.name:SetText(d.name)
  row.name:SetTextColor(d.color.r, d.color.g, d.color.b)
  row.value:SetText((s.showValue and d.value and d.value > 0) and coinString(d.value) or "")
  if s.showCount and not d.money then
    row.count:SetText(tostring(d.count))
    local bh = math.max(18, s.fontSize + 4)
    row.countBox:SetSize(math.max(bh, row.count:GetStringWidth() + 10), bh)
    row.countBox:Show()
  else
    row.countBox:Hide()
  end
end

local function resetLayout(row, s, w)
  row.bg:ClearAllPoints()
  row.bg:SetAllPoints(row)
  row.icon:ClearAllPoints()
  row.icon:SetPoint("LEFT", 8, 0)
  row.icon:SetSize(s.iconSize, s.iconSize)
  row.name:ClearAllPoints()
  row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
  row.name:SetWidth(w - s.iconSize - 70)
  row.value:ClearAllPoints()
  row.value:SetPoint("BOTTOMLEFT", row.icon, "BOTTOMRIGHT", 8, 1)
  row.value:SetJustifyH("LEFT")
  row.countBox:ClearAllPoints()
  row.countBox:SetPoint("RIGHT", row.bg, "RIGHT", -8, 0)
  row.ring:Hide()
  NS.SetCircleIcon(row, false)
end

-- Recorta el icono en círculo (para temas con marco redondo).
function NS.SetCircleIcon(row, on)
  if not row.mask then return end
  if on and not row.circled then
    row.icon:AddMaskTexture(row.mask)
    row.mask:SetAllPoints(row.icon)
    row.icon:SetTexCoord(0, 1, 0, 1)
    row.circled = true
  elseif not on and row.circled then
    row.icon:RemoveMaskTexture(row.mask)
    row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
    row.circled = false
  end
end

local function style(row)
  local s, theme = NS.db, NS:GetTheme()
  local w, h = rowSize()
  row:SetSize(w, h)
  row.name:SetFont(s.font, s.fontSize, "OUTLINE")
  row.count:SetFont(s.font, math.max(8, s.fontSize - 1), "OUTLINE")
  row.value:SetFont(s.font, s.valueFontSize, "OUTLINE")
  resetLayout(row, s, w)
  if row.data then
    local d = row.data
    local highlight = s.highlight and d.quality and d.quality >= 4
    theme.Apply(row, s, d.color, highlight)
    fillText(row)
  end
end

local function onUpdate(row, dt)
  row.t = row.t + dt
  local t, dur = row.t, NS.db.duration
  local e = outBack(math.min(1, t / SLIDE))
  local dir = (NS.db.side == "LEFT") and -1 or 1
  local dx = (1 - e) * TRAVEL * dir
  row.y = row.y + (row.ty - row.y) * math.min(1, dt * 12)
  local a = math.min(1, t / (SLIDE * 0.6))
  if t > dur then
    -- Salida suave: se desvanece y se desliza de vuelta hacia su lado.
    local f = (t - dur) / (row.fadeTime or FADE)
    if f >= 1 then return release(row) end
    local ease = f * f * (3 - 2 * f)
    a = a * (1 - ease)
    dx = dx + dir * ease * EXIT_TRAVEL
  end
  row:ClearAllPoints()
  row:SetPoint(anchorPoint(), anchor, anchorPoint(), dx, row.y)
  row:SetAlpha(a)
end

local function buildRow(parent)
  local row = CreateFrame("Frame", nil, parent)
  row:SetFrameStrata("HIGH")
  row:EnableMouse(true)
  -- Clic: cierra solo esta ventana (desvanecimiento rápido).
  row:SetScript("OnMouseUp", function(self)
    if self.t < NS.db.duration then self.t = NS.db.duration end
    self.fadeTime = FAST_FADE
  end)
  local bg = CreateFrame("Frame", nil, row, BackdropTemplateMixin and "BackdropTemplate" or nil)
  bg:SetAllPoints(row)
  row.bg = bg
  row.glow = bg:CreateTexture(nil, "ARTWORK", nil, 0)
  row.glow:SetTexture(WHITE)
  row.shine = bg:CreateTexture(nil, "ARTWORK", nil, 1)
  row.shine:SetTexture(WHITE)
  row.accent = bg:CreateTexture(nil, "ARTWORK", nil, 2)
  row.accent:SetTexture(WHITE)
  row.icon = bg:CreateTexture(nil, "ARTWORK", nil, 3)
  row.icon:SetPoint("LEFT", 8, 0)
  row.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  if bg.CreateMaskTexture then
    row.mask = bg:CreateMaskTexture()
    row.mask:SetTexture("Interface\\CharacterFrame\\TempPortraitAlphaMask", "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
  end
  row.ring = bg:CreateTexture(nil, "ARTWORK", nil, 5)
  row.name = bg:CreateFontString(nil, "OVERLAY")
  row.name:SetPoint("TOPLEFT", row.icon, "TOPRIGHT", 8, -1)
  row.name:SetJustifyH("LEFT")
  row.name:SetWordWrap(false)
  row.countBox = CreateFrame("Frame", nil, bg, BackdropTemplateMixin and "BackdropTemplate" or nil)
  row.countBox:SetBackdrop({ bgFile = WHITE, edgeFile = WHITE, edgeSize = 1 })
  row.countBox:SetBackdropColor(0, 0, 0, 0.55)
  row.countBox:SetBackdropBorderColor(1, 1, 1, 0.3)
  row.count = row.countBox:CreateFontString(nil, "OVERLAY")
  row.count:SetPoint("CENTER", 0, 0)
  row.count:SetTextColor(1, 1, 1)
  row.value = bg:CreateFontString(nil, "OVERLAY")
  row.value:SetPoint("BOTTOMRIGHT", -10, 6)
  return row
end

local function newRow()
  return table.remove(pool) or buildRow(UIParent)
end

-- data = { icon, name, color={r,g,b}, quality, count, value, key, money }
function D:Push(data)
  local s = NS.db
  if not s.enabled then return end
  if data.money and not s.showMoney then return end
  if data.quality and data.quality < s.minQuality then return end

  if s.merge and data.key then
    for _, row in ipairs(active) do
      if row.data.key == data.key and not row.fadeTime then
        row.data.count = row.data.count + data.count
        row.data.value = (row.data.value or 0) + (data.value or 0)
        row.t = SLIDE
        fillText(row)
        return
      end
    end
  end

  while #active >= s.maxRows do release(active[1]) end

  local row = newRow()
  row.data = data
  row.icon:SetTexture(data.icon)
  row.t, row.y, row.fadeTime = 0, 0, nil
  active[#active + 1] = row
  style(row)
  layout()
  row.y = row.ty
  row:SetAlpha(0)
  row:Show()
  row:SetScript("OnUpdate", onUpdate)

  if s.sound and data.quality and data.quality >= 3 and SOUNDKIT and SOUNDKIT.UI_EPICLOOT_TOAST then
    PlaySound(SOUNDKIT.UI_EPICLOOT_TOAST)
  end
end

function D:Refresh()
  if not anchor then return end
  local w, h = rowSize()
  anchor:SetSize(w, h)
  for _, row in ipairs(active) do style(row) end
  for _, row in ipairs(pool) do style(row) end
  for _, row in ipairs(previews) do style(row) end
  if NS.Config then NS.Config:LayoutPreviews() end
  layout()
end

-- Fila estática para la vista previa de la ventana de configuración.
function D:CreatePreview(parent, data)
  local row = buildRow(parent)
  row:SetScript("OnMouseUp", nil)
  row:EnableMouse(false)
  row:SetFrameStrata(parent:GetFrameStrata())
  row:SetFrameLevel(parent:GetFrameLevel() + 5)
  row.data = data
  row.icon:SetTexture(data.icon)
  style(row)
  row:SetAlpha(1)
  row:Show()
  previews[#previews + 1] = row
  return row
end

function D:GetPreviews() return previews end

function D:SetLocked(locked)
  NS.db.locked = locked
  anchor:EnableMouse(not locked)
  anchor.bg:SetShown(not locked)
  anchor.label:SetShown(not locked)
  NS:Print(locked and L["locked"] or (L["unlocked"] .. " - " .. L["Drag to move"]))
  if NS.Config then NS.Config:Sync() end
end

function D:Init()
  anchor = CreateFrame("Frame", "LootlyAnchor", UIParent)
  anchor:SetMovable(true)
  anchor:SetClampedToScreen(true)
  anchor:RegisterForDrag("LeftButton")
  anchor:SetScript("OnDragStart", anchor.StartMoving)
  anchor:SetScript("OnDragStop", function(self)
    self:StopMovingOrSizing()
    local p, _, rp, x, y = self:GetPoint()
    NS.db.pos = { p, rp, x, y }
  end)
  anchor.bg = anchor:CreateTexture(nil, "BACKGROUND")
  anchor.bg:SetAllPoints()
  anchor.bg:SetColorTexture(0.2, 1, 0.4, 0.3)
  anchor.label = anchor:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  anchor.label:SetPoint("CENTER")
  anchor.label:SetText("Lootly\n" .. L["Drag to move"] .. "\n" .. L["Right-click minimap button to lock"])

  local pos = NS.db.pos
  if pos then
    anchor:SetPoint(pos[1], UIParent, pos[2], pos[3], pos[4])
  else
    anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 220)
  end
  self:Refresh()
  anchor:EnableMouse(not NS.db.locked)
  anchor.bg:SetShown(not NS.db.locked)
  anchor.label:SetShown(not NS.db.locked)
end

NS.CoinString = coinString
