local ADDON = ...
local DURATION, SLIDE, ROW_H, ROW_W, MAX_ROWS = 4, 0.25, 34, 280, 8

ScrollLootDB = ScrollLootDB or {}
local db

-- Ancla arrastrable
local anchor = CreateFrame("Frame", "ScrollLootAnchor", UIParent, "BackdropTemplate")
anchor:SetSize(ROW_W, ROW_H)
anchor:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", 20, 220)
anchor:SetMovable(true)
anchor:EnableMouse(false)
anchor:RegisterForDrag("LeftButton")
anchor:SetScript("OnDragStart", anchor.StartMoving)
anchor:SetScript("OnDragStop", function(self)
  self:StopMovingOrSizing()
  local p, _, rp, x, y = self:GetPoint()
  db.pos = { p, rp, x, y }
end)
anchor.bg = anchor:CreateTexture(nil, "BACKGROUND")
anchor.bg:SetAllPoints()
anchor.bg:SetColorTexture(0, 1, 0, 0.3)
anchor.bg:Hide()

local function lock(locked)
  anchor:EnableMouse(not locked)
  anchor.bg:SetShown(not locked)
  db.locked = locked
  print("|cff33ff99ScrollLoot|r: " .. (locked and "bloqueado" or "desbloqueado (arrastra el recuadro verde)"))
end

-- Filas
local rows, active = {}, {}

local function coinString(c)
  local g, s, k = floor(c / 10000), floor(c / 100) % 100, c % 100
  local t = ""
  if g > 0 then t = t .. g .. "|cffffd700g|r " end
  if s > 0 or g > 0 then t = t .. s .. "|cffc7c7cfs|r " end
  return t .. k .. "|cffeda55fc|r"
end

local function layout()
  for i, r in ipairs(active) do
    r:ClearAllPoints()
    r:SetPoint("BOTTOMLEFT", anchor, "BOTTOMLEFT", r.slide or 0, (i - 1) * (ROW_H + 2))
  end
end

local function release(r)
  for i, v in ipairs(active) do
    if v == r then table.remove(active, i) break end
  end
  r:Hide()
  r:SetScript("OnUpdate", nil)
  rows[#rows + 1] = r
  layout()
end

local function newRow()
  local r = table.remove(rows)
  if r then return r end
  r = CreateFrame("Frame", nil, UIParent)
  r:SetSize(ROW_W, ROW_H)
  r.bg = r:CreateTexture(nil, "BACKGROUND")
  r.bg:SetAllPoints()
  r.bg:SetColorTexture(0, 0, 0, 0.6)
  r.bar = r:CreateTexture(nil, "ARTWORK")
  r.bar:SetPoint("TOPLEFT"); r.bar:SetPoint("BOTTOMLEFT"); r.bar:SetWidth(3)
  r.icon = r:CreateTexture(nil, "ARTWORK")
  r.icon:SetSize(ROW_H - 6, ROW_H - 6)
  r.icon:SetPoint("LEFT", 6, 0)
  r.icon:SetTexCoord(0.07, 0.93, 0.07, 0.93)
  r.name = r:CreateFontString(nil, "OVERLAY", "GameFontNormal")
  r.name:SetPoint("TOPLEFT", r.icon, "TOPRIGHT", 6, -1)
  r.name:SetJustifyH("LEFT")
  r.count = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.count:SetPoint("BOTTOMLEFT", r.icon, "BOTTOMRIGHT", 6, 1)
  r.value = r:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
  r.value:SetPoint("BOTTOMRIGHT", -6, 2)
  return r
end

local function push(icon, text, count, value, color)
  if #active >= MAX_ROWS then release(active[1]) end
  local r = newRow()
  r.icon:SetTexture(icon)
  r.name:SetText(text)
  r.name:SetWidth(ROW_W - ROW_H - 12)
  r.count:SetText(count and count > 1 and ("x" .. count) or "")
  r.value:SetText(value or "")
  r.bar:SetColorTexture(color.r, color.g, color.b, 1)
  r.t, r.slide = 0, -60
  r:SetAlpha(0)
  r:Show()
  active[#active + 1] = r
  layout()
  r:SetScript("OnUpdate", function(self, dt)
    self.t = self.t + dt
    local t = self.t
    if t < SLIDE then
      local p = t / SLIDE
      self:SetAlpha(p)
      self.slide = -(1 - p) * 60
      layout()
    elseif t > DURATION then
      local a = 1 - (t - DURATION) / 0.5
      if a <= 0 then release(self) else self:SetAlpha(a) end
    else
      self.slide = 0
      self:SetAlpha(1)
    end
  end)
end

-- Items
local function showItem(link, count)
  local item = Item:CreateFromItemLink(link)
  item:ContinueOnItemLoad(function()
    local name, _, quality, _, _, _, _, _, _, icon, sellPrice = C_Item.GetItemInfo(link)
    quality = quality or 1
    local c = ITEM_QUALITY_COLORS[quality] or ITEM_QUALITY_COLORS[1]
    if db.minQuality and quality < db.minQuality then return end
    local total = (sellPrice or 0) * count
    push(icon, c.hex .. (name or link) .. "|r", count, total > 0 and coinString(total) or nil, c)
  end)
end

-- Patrones robustos (localizados)
local function toPat(g)
  g = g:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
  g = g:gsub("%%%%s", "(.+)"):gsub("%%%%d", "(%%d+)")
  g = g:gsub("%%%%(%d)%%%$s", "(.+)"):gsub("%%%%(%d)%%%$d", "(%%d+)")
  return "^" .. g .. "$"
end
local P_MULTI = { toPat(LOOT_ITEM_SELF_MULTIPLE), toPat(LOOT_ITEM_PUSHED_SELF_MULTIPLE) }
local P_SINGLE = { toPat(LOOT_ITEM_SELF), toPat(LOOT_ITEM_PUSHED_SELF) }

local function onLoot(msg)
  for _, p in ipairs(P_MULTI) do
    local link, n = msg:match(p)
    if link then return showItem(link, tonumber(n) or 1) end
  end
  for _, p in ipairs(P_SINGLE) do
    local link = msg:match(p)
    if link then return showItem(link, 1) end
  end
end

-- Oro
local lastMoney, pending = 0, false
local function onMoney()
  if pending then return end
  pending = true
  C_Timer.After(0.15, function()
    pending = false
    local diff = GetMoney() - lastMoney
    if diff > 0 then
      push("Interface\\Icons\\INV_Misc_Coin_01", "|cffffd700Oro|r", 1, coinString(diff), { r = 1, g = 0.82, b = 0 })
    end
  end)
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, ev, a1)
  if ev == "ADDON_LOADED" and a1 == ADDON then
    db = ScrollLootDB
    if db.pos then
      anchor:ClearAllPoints()
      anchor:SetPoint(db.pos[1], UIParent, db.pos[2], db.pos[3], db.pos[4])
    end
    lock(db.locked ~= false)
    lastMoney = GetMoney()
    self:RegisterEvent("CHAT_MSG_LOOT")
    self:RegisterEvent("CHAT_MSG_MONEY")
    self:RegisterEvent("PLAYER_MONEY")
  elseif ev == "CHAT_MSG_LOOT" then
    onLoot(a1)
  elseif ev == "CHAT_MSG_MONEY" then
    onMoney()
  elseif ev == "PLAYER_MONEY" and not pending then
    lastMoney = GetMoney()
  end
end)

-- Comandos
SLASH_SCROLLLOOT1 = "/sl"
SlashCmdList.SCROLLLOOT = function(m)
  m = (m or ""):lower()
  if m == "unlock" then lock(false)
  elseif m == "lock" then lock(true)
  elseif m == "test" then
    push("Interface\\Icons\\INV_Misc_Herb_19", "|cff0070ddZephyrite|r", 3, coinString(15500), { r = 0, g = 0.44, b = 0.87 })
    push("Interface\\Icons\\INV_Potion_51", "|cffffffffLesser Healing Potion|r", 5, coinString(750), { r = 1, g = 1, b = 1 })
    push("Interface\\Icons\\INV_Ore_Copper_01", "|cffffffffCopper Ore|r", 11, coinString(550), { r = 1, g = 1, b = 1 })
    push("Interface\\Icons\\INV_Misc_Coin_01", "|cffffd700Oro|r", 1, coinString(251234), { r = 1, g = 0.82, b = 0 })
  else
    print("|cff33ff99ScrollLoot|r: /sl test | /sl unlock | /sl lock")
  end
end
