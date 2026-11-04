local ADDON, NS = ...
local L = NS.L
local R = {}
NS.RollChat = R

local ICON = "|TInterface\\AddOns\\Lootly\\Media\\roll_%s:%d:%d|t"
-- Los dados se dibujan más grandes: su imagen es más ancha que alta.
local function icon(name, size)
  size = size or (name == "need" and 19 or 14)
  return ICON:format(name, size, size)
end

-- Convierte una cadena global en patrón y recuerda a qué argumento corresponde cada captura.
local function compile(g)
  local pat, order, n, pos = "", {}, 0, 1
  local function lit(s) return (s:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?])", "%%%1")) end
  while true do
    local s, e, idx, t = g:find("%%(%d?)%$?([sd])", pos)
    if not s then break end
    pat = pat .. lit(g:sub(pos, s - 1)) .. (t == "s" and "(.+)" or "(%d+)")
    n = n + 1
    order[n] = tonumber(idx) or n
    pos = e + 1
  end
  return "^" .. pat .. lit(g:sub(pos)) .. "$", order
end

-- { global, tipo, opción, nombres de los argumentos (en el orden del texto original) }
local DEFS = {
  -- Orden importante: los patrones más específicos primero ("Everyone passed on" encaja también con "%s passed on").
  { "LOOT_ROLL_ALL_PASSED", "allpassed", nil, { "item" } },
  { "LOOT_ROLL_NEED", "choice", "need", { "player", "item" } },
  { "LOOT_ROLL_NEED_SELF", "choice", "need", { "item" }, true },
  { "LOOT_ROLL_GREED", "choice", "greed", { "player", "item" } },
  { "LOOT_ROLL_GREED_SELF", "choice", "greed", { "item" }, true },
  { "LOOT_ROLL_PASSED", "choice", "pass", { "player", "item" } },
  { "LOOT_ROLL_PASSED_SELF", "choice", "pass", { "item" }, true },
  { "LOOT_ROLL_PASSED_AUTO", "choice", "pass", { "player", "item" } },
  { "LOOT_ROLL_PASSED_SELF_AUTO", "choice", "pass", { "item" }, true },
  { "LOOT_ROLL_ROLLED_NEED", "rolled", "need", { "roll", "item", "player" } },
  { "LOOT_ROLL_ROLLED_GREED", "rolled", "greed", { "roll", "item", "player" } },
  { "LOOT_ROLL_WON_NO_SPAM_NEED", "won", "need", { "player", "roll", "item" } },
  { "LOOT_ROLL_WON_NO_SPAM_GREED", "won", "greed", { "player", "roll", "item" } },
  { "LOOT_ROLL_WON_NO_SPAM_DE", "won", "de", { "player", "roll", "item" } },
  { "LOOT_ROLL_YOU_WON_NO_SPAM_NEED", "won", "need", { "roll", "item" }, true },
  { "LOOT_ROLL_YOU_WON_NO_SPAM_GREED", "won", "greed", { "roll", "item" }, true },
  { "LOOT_ROLL_YOU_WON_NO_SPAM_DE", "won", "de", { "roll", "item" }, true },
  -- Los genéricos van al final: sus patrones también encajarían con los "NO_SPAM".
  { "LOOT_ROLL_WON", "won", nil, { "player", "item" } },
  { "LOOT_ROLL_YOU_WON", "won", nil, { "item" }, true },
}

local compiled
local state = {}

local function build()
  compiled = {}
  -- Primero los mensajes propios ("You won"), que si no encajarían con "%s won".
  for pass = 1, 2 do
    for _, d in ipairs(DEFS) do
      local g = _G[d[1]]
      if g and (pass == 1) == (d[5] == true or d[2] == "allpassed") then
        local pat, order = compile(g)
        compiled[#compiled + 1] = { pat = pat, order = order, kind = d[2], opt = d[3], names = d[4], self = d[5] }
      end
    end
  end
end

-- Devuelve la definición y los argumentos con nombre, o nil si no es un mensaje de tirada.
function R.Parse(msg)
  if not compiled then build() end
  for _, c in ipairs(compiled) do
    local caps = { msg:match(c.pat) }
    if #caps > 0 then
      local args = {}
      for i, v in ipairs(caps) do args[c.names[c.order[i]]] = v end
      if c.self then args.player = UnitName("player"); args.isSelf = true end
      return c, args
    end
  end
end

local function get(item)
  local s = state[item]
  if not s then s = { need = 0, greed = 0, pass = 0, rolls = {} } state[item] = s end
  return s
end

local OPT = { need = "Need", greed = "Greed", pass = "Pass" }

local function line(...) DEFAULT_CHAT_FRAME:AddMessage(string.format(...)) end

local function flush(item, winner, roll, opt, isSelf, allPassed)
  local s = get(item)
  state[item] = nil
  if allPassed then
    line("%s |cffff5555%s|r", item, L["Everyone passed"])
  elseif isSelf then
    line("%s  |cff55ff55✓ %s|r%s", item, L["You won"], roll and (" (" .. roll .. ")") or "")
  else
    line("%s  |cff55ff55✓|r |cffffffff%s|r %s%s", item, winner, L["won"], roll and (" (" .. roll .. ")") or "")
  end
  local me = UnitName("player")
  if s.mine then
    local r = s.rolls[me]
    line("%s %s |cffffffff%s|r%s", L["You chose"], icon(s.mine), L[OPT[s.mine]], r and (" (" .. r .. ")") or "")
  end
  if not allPassed then
    line("%s |cff55ff55%d|r   %s |cffffd100%d|r   %s |cffff5555%d|r",
      icon("need"), s.need, icon("greed"), s.greed, icon("pass"), s.pass)
  end
end

function R:Handle(msg)
  local c, a = R.Parse(msg)
  if not c then return false end
  local item = a.item
  local s = get(item)
  if c.kind == "choice" then
    s[c.opt] = s[c.opt] + 1
    if a.isSelf then s.mine = c.opt end
  elseif c.kind == "rolled" then
    s.rolls[a.player] = tonumber(a.roll)
  elseif c.kind == "won" then
    local roll = tonumber(a.roll) or s.rolls[a.player]
    if c.opt and c.opt ~= "de" and s.mine == nil and a.isSelf then s.mine = c.opt end
    flush(item, a.player, roll, c.opt, a.isSelf)
  elseif c.kind == "allpassed" then
    flush(item, nil, nil, nil, false, true)
  end
  return true
end

function R:Init()
  build()
  local f = CreateFrame("Frame")
  f:RegisterEvent("CHAT_MSG_LOOT")
  f:SetScript("OnEvent", function(_, _, msg)
    if NS.db.rollSummary then R:Handle(msg) end
  end)
  if ChatFrame_AddMessageEventFilter then
    ChatFrame_AddMessageEventFilter("CHAT_MSG_LOOT", function(_, _, msg)
      if NS.db.rollSummary and NS.db.rollHide and R.Parse(msg) then return true end
    end)
  end
end
