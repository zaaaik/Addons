local ADDON, NS = ...
local L = NS.L
local Loot = {}
NS.Loot = Loot

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or GetItemInfo

-- Convierte una cadena global (ej. "You receive loot: %s.") en patrón.
local function toPat(g)
  g = g:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1")
  g = g:gsub("%%%d%$s", "(.+)"):gsub("%%%d%$d", "(%%d+)")
  g = g:gsub("%%s", "(.+)"):gsub("%%d", "(%%d+)")
  return "^" .. g .. "$"
end

local function build(names)
  local list = {}
  for _, n in ipairs(names) do
    if _G[n] then list[#list + 1] = toPat(_G[n]) end
  end
  return list
end

local P_MULTI, P_SINGLE

-- Devuelve link, cantidad (o nil si no es loot propio).
function Loot.Parse(msg)
  for _, p in ipairs(P_MULTI) do
    local link, n = msg:match(p)
    if link then return link, tonumber(n) or 1 end
  end
  for _, p in ipairs(P_SINGLE) do
    local link = msg:match(p)
    if link then return link, 1 end
  end
end

local function showItem(link, count)
  local item = Item:CreateFromItemLink(link)
  item:ContinueOnItemLoad(function()
    local name, _, quality, _, _, _, _, _, _, icon, sell = GetItemInfo(link)
    quality = quality or 1
    local c = ITEM_QUALITY_COLORS[quality] or ITEM_QUALITY_COLORS[1]
    NS.Display:Push({
      icon = icon, name = name or link, quality = quality, color = c,
      count = count, value = (sell or 0) * count,
      key = link:match("item:(%d+)") or link,
    })
  end)
end

-- Oro: CHAT_MSG_MONEY avisa y PLAYER_MONEY da la cantidad; llegan en orden variable.
local lastMoney, gain, flag = 0, nil, false

local function tryMoney()
  if gain and flag then
    NS.Display:Push({
      icon = "Interface\\Icons\\INV_Misc_Coin_01", name = L["Money"],
      color = { r = 1, g = 0.82, b = 0 }, count = 1, value = gain,
      key = "money", money = true,
    })
    gain, flag = nil, false
  end
end

function Loot:Init()
  P_MULTI = build({ "LOOT_ITEM_SELF_MULTIPLE", "LOOT_ITEM_PUSHED_SELF_MULTIPLE", "LOOT_ITEM_CREATED_SELF_MULTIPLE" })
  P_SINGLE = build({ "LOOT_ITEM_SELF", "LOOT_ITEM_PUSHED_SELF", "LOOT_ITEM_CREATED_SELF" })
  lastMoney = GetMoney()
  local f = CreateFrame("Frame")
  f:RegisterEvent("CHAT_MSG_LOOT")
  f:RegisterEvent("CHAT_MSG_MONEY")
  f:RegisterEvent("PLAYER_MONEY")
  f:SetScript("OnEvent", function(_, ev, msg)
    if ev == "CHAT_MSG_LOOT" then
      local link, n = Loot.Parse(msg)
      if link then showItem(link, n) end
    elseif ev == "CHAT_MSG_MONEY" then
      flag = true
      C_Timer.After(1, function() flag, gain = false, nil end)
      tryMoney()
    else
      local now = GetMoney()
      local diff = now - lastMoney
      lastMoney = now
      if diff > 0 then
        gain = diff
        C_Timer.After(1, function() if gain == diff then gain = nil end end)
        tryMoney()
      end
    end
  end)
end
