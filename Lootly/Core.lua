local ADDON, NS = ...
local L = NS.L

NS.defaults = {
  enabled = true,
  lang = "es",
  locked = true,
  theme = "Glass",
  font = STANDARD_TEXT_FONT,
  fontSize = 14,
  valueFontSize = 11,
  opacity = 0.6,
  glow = 0.7,
  iconSize = 32,
  rowWidth = 280,
  duration = 6,
  maxRows = 8,
  side = "LEFT",
  growUp = true,
  minQuality = 0,
  showValue = true,
  showCount = true,
  showMoney = true,
  merge = true,
  highlight = true,
  sound = false,
  rollSummary = true,
  rollHide = true,
  minimap = { hide = false, angle = 215 },
}

local function copyDefaults(src, dst)
  for k, v in pairs(src) do
    if type(v) == "table" then
      if type(dst[k]) ~= "table" then dst[k] = {} end
      copyDefaults(v, dst[k])
    elseif dst[k] == nil then
      dst[k] = v
    end
  end
end

function NS:Print(msg)
  print("|cff33ff99Lootly|r: " .. tostring(msg))
end

-- Cambia una opción y actualiza todo lo visible.
function NS:Set(key, value)
  self.db[key] = value
  if key == "lang" then self:Print(L["Reload to apply language"]) end
  if self.Display then self.Display:Refresh() end
  if self.Config then self.Config:Sync() end
end

function NS:Reset()
  local pos = self.db.pos
  for k in pairs(self.db) do self.db[k] = nil end
  copyDefaults(self.defaults, self.db)
  self.db.pos = pos
  if self.Display then self.Display:SetLocked(true) end
  if self.Minimap then self.Minimap:Refresh() end
  self:Print(L["Settings reset"])
end

-- Entradas de prueba.
function NS:Test()
  local D = self.Display
  local C = ITEM_QUALITY_COLORS
  D:Push({ icon = "Interface\\Icons\\INV_Misc_Herb_19", name = "Zephyrite", quality = 3, color = C[3], count = 3, value = 15500, key = "t1" })
  D:Push({ icon = "Interface\\Icons\\INV_Potion_51", name = "Lesser Healing Potion", quality = 1, color = C[1], count = 5, value = 750, key = "t2" })
  D:Push({ icon = "Interface\\Icons\\INV_Sword_39", name = "Staff of Jordan", quality = 4, color = C[4], count = 1, value = 25000, key = "t3" })
  D:Push({ icon = "Interface\\Icons\\INV_Misc_Coin_01", name = L["Money"], quality = nil, color = { r = 1, g = 0.82, b = 0 }, count = 1, value = 251234, key = "money", money = true })
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:SetScript("OnEvent", function(self, _, name)
  if name ~= ADDON then return end
  self:UnregisterEvent("ADDON_LOADED")
  LootlyDB = LootlyDB or {}
  NS.db = LootlyDB
  copyDefaults(NS.defaults, NS.db)
  NS.Display:Init()
  NS.Loot:Init()
  NS.RollChat:Init()
  NS.Minimap:Init()
end)

SLASH_LOOTLY1 = "/lt"
SLASH_LOOTLY2 = "/lootly"
SlashCmdList.LOOTLY = function(msg)
  msg = (msg or ""):lower():match("^%s*(.-)%s*$")
  if msg == "" or msg == "config" then NS.Config:Toggle()
  elseif msg == "test" then NS:Test()
  elseif msg == "unlock" then NS.Display:SetLocked(false)
  elseif msg == "lock" then NS.Display:SetLocked(true)
  elseif msg == "reset" then NS:Reset()
  else NS:Print("/lt [config | test | lock | unlock | reset]") end
end
