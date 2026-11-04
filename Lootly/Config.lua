local ADDON, NS = ...
local L = NS.L
local C = {}
NS.Config = C

local WHITE = "Interface\\Buttons\\WHITE8X8"
local PAGE_W, ROW_H = 340, 38
local PREVIEW_W = 250

local FONTS = {
  { STANDARD_TEXT_FONT, "Default" },
  { "Fonts\\FRIZQT__.TTF", "Friz Quadrata" },
  { "Fonts\\ARIALN.TTF", "Arial Narrow" },
  { "Fonts\\SKURRI.TTF", "Skurri" },
  { "Fonts\\MORPHEUS.TTF", "Morpheus" },
}

local function qualityName(i)
  local names = { [0] = L["Poor"], L["Common"], L["Uncommon"], L["Rare"], L["Epic"], L["Legendary"] }
  return names[i]
end

-- Las opciones son comunes a todos los temas.
local PAGES = {
  { label = L["Look"], opts = {
    { "cycle", "theme", L["Theme"], function() return NS.ThemeOrder end, function(v) return NS.Themes[v].label end },
    { "cycle", "font", L["Font"], function() local t = {} for i, f in ipairs(FONTS) do t[i] = f[1] end return t end,
      function(v) for _, f in ipairs(FONTS) do if f[1] == v then return f[2] end end return v end },
    { "slider", "fontSize", L["Name font size"], 8, 28, 1 },
    { "slider", "valueFontSize", L["Value font size"], 8, 24, 1 },
    { "slider", "opacity", L["Opacity"], 0, 1, 0.05, true },
    { "slider", "glow", L["Glow"], 0, 1, 0.05, true },
    { "slider", "iconSize", L["Icon size"], 20, 56, 1 },
    { "slider", "rowWidth", L["Width"], 180, 420, 5 },
  } },
  { label = L["Behavior"], opts = {
    { "slider", "duration", L["Duration (s)"], 1, 15, 0.5 },
    { "slider", "maxRows", L["Max rows"], 2, 12, 1 },
    { "cycle", "lang", L["Language"], function() return { "es", "en" } end, function(v) return v == "es" and "Español" or "English" end },
    { "cycle", "minQuality", L["Minimum quality"], function() return { 0, 1, 2, 3, 4, 5 } end, qualityName },
  } },
  { label = L["Content"], opts = {
    { "check", "showValue", L["Show sell value"] },
    { "check", "showCount", L["Show quantity"] },
    { "check", "showMoney", L["Show money"] },
    { "check", "merge", L["Merge repeated items"] },
    { "check", "highlight", L["Highlight epic+"] },
    { "check", "sound", L["Sound on rare+"] },
    { "check", "rollSummary", L["Roll results in chat"] },
    { "check", "rollHide", L["Hide default roll messages"] },
  } },
  { label = L["Position"], opts = {
    { "cycle", "side", L["Side"], function() return { "LEFT", "RIGHT" } end, function(v) return v == "LEFT" and L["Left"] or L["Right"] end },
    { "cycle", "growUp", L["Loot direction"], function() return { true, false } end, function(v) return v and L["Upwards"] or L["Downwards"] end },
    { "action", L["Move position"], function() NS.Display:SetLocked(not NS.db.locked) end },
  } },
}

local frame, controls, previewPanel, syncing = nil, {}, nil, false
local pages, navButtons = {}, {}

local function round(v, step) return math.floor(v / step + 0.5) * step end

local function makeSlider(parent, opt, y)
  local _, key, label, min, max, step, pct = unpack(opt)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("TOPLEFT", 0, y - 9)
  fs:SetText(label)
  local val = parent:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
  val:SetPoint("TOPRIGHT", 0, y - 10)
  val:SetWidth(40)
  val:SetJustifyH("RIGHT")
  local s = CreateFrame("Slider", nil, parent)
  s:SetOrientation("HORIZONTAL")
  s:SetSize(130, 14)
  s:SetPoint("TOPRIGHT", -46, y - 9)
  s:SetMinMaxValues(min, max)
  s:SetValueStep(step)
  if s.SetObeyStepOnDrag then s:SetObeyStepOnDrag(true) end
  local track = s:CreateTexture(nil, "BACKGROUND")
  track:SetColorTexture(1, 1, 1, 0.2)
  track:SetHeight(4)
  track:SetPoint("LEFT")
  track:SetPoint("RIGHT")
  s:SetThumbTexture(WHITE)
  local th = s:GetThumbTexture()
  th:SetSize(10, 14)
  th:SetVertexColor(0.7, 0.9, 1, 1)
  local function show(v) val:SetText(pct and (math.floor(v * 100 + 0.5) .. "%") or tostring(v)) end
  s:SetScript("OnValueChanged", function(_, v)
    v = round(v, step)
    show(v)
    if not syncing and NS.db[key] ~= v then NS:Set(key, v) end
  end)
  controls[#controls + 1] = function()
    s:SetValue(NS.db[key])
    show(NS.db[key])
  end
end

local function makeCheck(parent, opt, y)
  local _, key, label = unpack(opt)
  local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
  cb:SetSize(26, 26)
  cb:SetPoint("TOPLEFT", -4, y - 5)
  local t = cb.Text or cb.text
  if t then t:SetText(label) end
  cb:SetScript("OnClick", function(self) NS:Set(key, self:GetChecked() and true or false) end)
  controls[#controls + 1] = function() cb:SetChecked(NS.db[key]) end
end

local function arrowButton(parent, dir)
  local b = CreateFrame("Button", nil, parent)
  b:SetSize(26, 26)
  local name = dir < 0 and "PrevPage" or "NextPage"
  b:SetNormalTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. name .. "-Up")
  b:SetPushedTexture("Interface\\Buttons\\UI-SpellbookIcon-" .. name .. "-Down")
  b:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
  return b
end

-- Selector con flechas izquierda / derecha.
local function makeCycle(parent, opt, y)
  local _, key, label, values, fmt = unpack(opt)
  local fs = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
  fs:SetPoint("TOPLEFT", 0, y - 9)
  fs:SetText(label)
  local nextB = arrowButton(parent, 1)
  nextB:SetPoint("TOPRIGHT", 0, y - 5)
  local prevB = arrowButton(parent, -1)
  prevB:SetPoint("TOPRIGHT", -150, y - 5)
  local val = parent:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  val:SetPoint("TOPRIGHT", -26, y - 10)
  val:SetWidth(124)
  val:SetJustifyH("CENTER")
  local function step(d)
    local list = values()
    local idx = 1
    for i, v in ipairs(list) do if v == NS.db[key] then idx = i end end
    idx = idx + d
    if idx > #list then idx = 1 elseif idx < 1 then idx = #list end
    NS:Set(key, list[idx])
  end
  prevB:SetScript("OnClick", function() step(-1) end)
  nextB:SetScript("OnClick", function() step(1) end)
  controls[#controls + 1] = function() val:SetText(tostring(fmt(NS.db[key]))) end
end

local function makeAction(parent, opt, y)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(PAGE_W - 10, 26)
  b:SetPoint("TOPLEFT", 0, y - 6)
  b:SetText(opt[2])
  b:SetScript("OnClick", opt[3])
end

local function selectPage(i)
  for n, p in ipairs(pages) do p:SetShown(n == i) end
  for n, b in ipairs(navButtons) do b.sel:SetShown(n == i) end
end

local function sampleData()
  local Q = ITEM_QUALITY_COLORS
  return {
    { icon = "Interface\\Icons\\INV_Misc_Herb_19", name = "Zephyrite", quality = 3, color = Q[3], count = 3, value = 15500 },
    { icon = "Interface\\Icons\\INV_Sword_39", name = "Staff of Jordan", quality = 4, color = Q[4], count = 1, value = 250000 },
    { icon = "Interface\\Icons\\INV_Misc_Coin_01", name = L["Money"], color = { r = 1, g = 0.82, b = 0 }, count = 1, value = 251234, money = true },
  }
end

local function button(parent, text, point, fn)
  local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
  b:SetSize(PREVIEW_W - 10, 26)
  b:SetPoint(unpack(point))
  b:SetText(text)
  b:SetScript("OnClick", fn)
  return b
end

local function build()
  frame = CreateFrame("Frame", "LootlyConfig", UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
  frame:SetSize(840, 500)
  frame:SetPoint("CENTER")
  frame:SetFrameStrata("DIALOG")
  frame:SetMovable(true)
  frame:EnableMouse(true)
  frame:SetClampedToScreen(true)
  frame:RegisterForDrag("LeftButton")
  frame:SetScript("OnDragStart", frame.StartMoving)
  frame:SetScript("OnDragStop", frame.StopMovingOrSizing)
  frame:SetBackdrop({ bgFile = WHITE, edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border", edgeSize = 14,
    insets = { left = 3, right = 3, top = 3, bottom = 3 } })
  frame:SetBackdropColor(0.07, 0.09, 0.13, 0.94)
  frame:SetBackdropBorderColor(1, 1, 1, 0.5)
  tinsert(UISpecialFrames, "LootlyConfig")

  local close = CreateFrame("Button", nil, frame, "UIPanelCloseButton")
  close:SetPoint("TOPRIGHT", -2, -2)

  -- Barra lateral
  local side = frame:CreateTexture(nil, "BACKGROUND", nil, 1)
  side:SetColorTexture(0, 0, 0, 0.35)
  side:SetPoint("TOPLEFT", 3, -3)
  side:SetPoint("BOTTOMLEFT", 3, 3)
  side:SetWidth(170)
  local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  title:SetPoint("TOPLEFT", 20, -20)
  title:SetText("Lootly")

  for i, page in ipairs(PAGES) do
    local nb = CreateFrame("Button", nil, frame)
    nb:SetSize(150, 32)
    nb:SetPoint("TOPLEFT", 13, -62 - (i - 1) * 36)
    nb.sel = nb:CreateTexture(nil, "BACKGROUND")
    nb.sel:SetAllPoints()
    nb.sel:SetColorTexture(0.29, 0.64, 1, 0.3)
    local hl = nb:CreateTexture(nil, "HIGHLIGHT")
    hl:SetAllPoints()
    hl:SetColorTexture(1, 1, 1, 0.08)
    local t = nb:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    t:SetPoint("LEFT", 12, 0)
    t:SetText(page.label)
    nb:SetScript("OnClick", function() selectPage(i) end)
    navButtons[i] = nb

    local pf = CreateFrame("Frame", nil, frame)
    pf:SetSize(PAGE_W, 420)
    pf:SetPoint("TOPLEFT", 195, -50)
    pf:Hide()
    local h = pf:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    h:SetPoint("BOTTOMLEFT", pf, "TOPLEFT", 0, 12)
    h:SetText(page.label)
    for n, opt in ipairs(page.opts) do
      local y = -(n - 1) * ROW_H
      if opt[1] == "slider" then makeSlider(pf, opt, y)
      elseif opt[1] == "check" then makeCheck(pf, opt, y)
      elseif opt[1] == "cycle" then makeCycle(pf, opt, y)
      else makeAction(pf, opt, y) end
    end
    pages[i] = pf
  end

  -- Vista previa
  previewPanel = CreateFrame("Frame", nil, frame)
  previewPanel:SetSize(PREVIEW_W, 300)
  previewPanel:SetPoint("TOPLEFT", 565, -50)
  local ph = previewPanel:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
  ph:SetPoint("BOTTOMLEFT", previewPanel, "TOPLEFT", 0, 12)
  ph:SetText(L["Preview"])
  for _, data in ipairs(sampleData()) do
    NS.Display:CreatePreview(previewPanel, data)
  end

  button(frame, L["Test"], { "BOTTOMLEFT", 565, 100 }, function() NS:Test() end)
  frame.lockBtn = button(frame, "", { "BOTTOMLEFT", 565, 64 }, function() NS.Display:SetLocked(not NS.db.locked) end)
  button(frame, L["Reset"], { "BOTTOMLEFT", 565, 28 }, function() NS:Reset() C:Sync() end)

  selectPage(1)
end

-- Coloca las filas de la vista previa (escaladas para caber en el panel).
function C:LayoutPreviews()
  if not previewPanel then return end
  local y = 0
  for _, row in ipairs(NS.Display:GetPreviews()) do
    local w, h = row:GetSize()
    local scale = math.min(1, PREVIEW_W / w)
    row:SetScale(scale)
    row:ClearAllPoints()
    row:SetPoint("TOPLEFT", previewPanel, "TOPLEFT", 0, -y / scale)
    y = y + h * scale + 14
  end
end

function C:Sync()
  if not frame then return end
  syncing = true
  for _, fn in ipairs(controls) do fn() end
  frame.lockBtn:SetText(NS.db.locked and L["Unlock"] or L["Lock"])
  syncing = false
  self:LayoutPreviews()
end

function C:Toggle()
  if not frame then build() end
  if frame:IsShown() then frame:Hide() else frame:Show() self:Sync() end
end
