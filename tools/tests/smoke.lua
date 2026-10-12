-- Smoke test del addon con un stub mínimo de la API de WoW.
-- Uso: lua5.1 smoke.lua <carpeta del addon> <questID> <título EN> <texto EN> <diálogo EN> <diálogo ES esperado>
local addonDir, questID, titleEN, textEN, gossipEN, gossipES = arg[1], tonumber(arg[2]), arg[3], arg[4], arg[5], arg[6]

local failures = 0
local function check(cond, msg)
	if cond then print("ok   " .. msg) else failures = failures + 1; print("FAIL " .. msg) end
end

-- Objeto genérico: cualquier método desconocido existe y no hace nada.
local function newObject(kind)
	local o = { _kind = kind, _shown = false, _alpha = 1, _text = "", _scripts = {}, _events = {} }
	local mt = {}
	mt.__index = function(_, k)
		if k == "TitleText" or k == "DetailsFrame" then return nil end -- campos, no métodos
		return function() end
	end
	setmetatable(o, mt)
	function o:Show() self._shown = true end
	function o:Hide()
		if self._shown and self._scripts.OnHide then self._scripts.OnHide(self) end
		self._shown = false
	end
	function o:IsShown() return self._shown end
	function o:IsVisible() return self._shown end
	function o:SetShown(v) if v then self:Show() else self:Hide() end end
	function o:SetAlpha(a) self._alpha = a end
	function o:GetAlpha() return self._alpha end
	function o:GetWidth() return 320 end
	function o:GetHeight() return 420 end
	function o:GetStringHeight() return 14 end
	function o:SetText(t) self._text = t end
	function o:GetText() return self._text end
	function o:SetScript(k, f) self._scripts[k] = f end
	function o:GetScript(k) return self._scripts[k] end
	function o:HookScript(k, f) self._scripts[k] = f end
	function o:RegisterEvent(e) self._events[e] = true end
	function o:GetChecked() return false end
	function o:GetFont() return "Fonts\\FRIZQT__.TTF", 12 end
	function o:CreateTexture() return newObject("Texture") end
	function o:CreateFontString() return newObject("FontString") end
	function o:GetVerticalScroll() return 0 end
	function o:GetID() return 1 end
	return o
end

local frames = {}
_G.CreateFrame = function(kind, name)
	local f = newObject(kind)
	frames[#frames + 1] = f
	if name then _G[name] = f end
	return f
end
_G.CreateFont = function() return newObject("Font") end
_G.UIParent = newObject("Frame")
_G.QuestFrame = newObject("Frame")
_G.GossipFrame = newObject("Frame")
_G.QuestFont, _G.QuestTitleFont = newObject("Font"), newObject("Font")
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
_G.UISpecialFrames = {}
_G.SlashCmdList = {}
_G.tinsert = table.insert
_G.hooksecurefunc = function() end
_G.MouseIsOver = function() return false end
_G.BackdropTemplateMixin = {}
_G.DEFAULT_CHAT_FRAME = { AddMessage = function(_, m) print("     chat: " .. m) end }
_G.Settings = {
	RegisterCanvasLayoutCategory = function() return newObject("Category") end,
	RegisterAddOnCategory = function() end,
}
_G.strsplit = function(sep, s, n)
	local out, start = {}, 1
	while true do
		if n and #out == n - 1 then out[#out + 1] = s:sub(start); break end
		local i = s:find(sep, start, true)
		if not i then out[#out + 1] = s:sub(start); break end
		out[#out + 1] = s:sub(start, i - 1)
		start = i + #sep
	end
	return unpack(out)
end
_G.C_Timer = { NewTicker = function() return { Cancel = function() end } end }
_G.GetTime = function() return 0 end

local locale = "enUS"
_G.GetLocale = function() return locale end
_G.UnitName = function(u) return u == "player" and "Arthas" or "Marshal Dughan" end
_G.UnitClass = function() return "Warrior", "WARRIOR" end
_G.UnitRace = function() return "Human", "Human" end
_G.UnitSex = function() return 2 end
_G.UnitGUID = function() return "Creature-0-0-0-0-240-0" end

local current = { id = questID, title = titleEN, text = textEN }
_G.GetQuestID = function() return current.id end
_G.GetTitleText = function() return current.title end
_G.GetQuestText = function() return current.text end
_G.GetObjectiveText = function() return "Kill things." end
_G.GetProgressText = function() return "" end
_G.GetRewardText = function() return "" end
_G.GetRewardMoney = function() return 0 end
_G.GetRewardXP = function() return 0 end
_G.GetNumQuestRewards = function() return 0 end
_G.GetNumQuestChoices = function() return 0 end
_G.GetQuestItemInfo = function() end
_G.IsQuestCompletable = function() return true end
_G.C_GossipInfo = {
	GetText = function() return gossipEN end,
	GetAvailableQuests = function() return { { questID = questID } } end,
	GetActiveQuests = function() return {} end,
}

-- Cargar el addon en el orden del .toc
local MES = {}
local toc = io.open(addonDir .. "/MisionesES.toc"):read("*a")
for line in toc:gmatch("[^\r\n]+") do
	if not line:match("^##") and line:match("%.lua$") then
		local path = addonDir .. "/" .. line:gsub("\\", "/")
		local chunk = assert(loadfile(path))
		chunk("MisionesES", MES)
	end
end

local function fire(event, ...)
	for _, f in ipairs(frames) do
		if f._events[event] and f._scripts.OnEvent then f._scripts.OnEvent(f, event, ...) end
	end
end

-- Registrar lo que muestran las vistas
local lastBlocks
local showBeside = MES.ShowBeside
MES.ShowBeside = function(panel, anchor, blocks)
	lastBlocks = blocks
	return showBeside(panel, anchor, blocks)
end
local function shownText()
	local out = {}
	for _, b in ipairs(lastBlocks or {}) do out[#out + 1] = b.text or "" end
	return table.concat(out, " | ")
end

fire("ADDON_LOADED", "MisionesES")
fire("PLAYER_LOGIN")
check(MisionesES_Config and MisionesES_Config.mode == "lateral", "configuración por defecto creada")
check(_G.MisionesES_Setup and MisionesES_Setup:IsShown(), "asistente inicial visible la primera vez")

local dbq, dbg = MES.CountDB()
check(dbq > 1000 and dbg > 1000, ("base de datos cargada (%d misiones, %d diálogos)"):format(dbq, dbg))

fire("QUEST_DETAIL")
local q = MES.GetQuest(questID)
check(MisionesES_SidePanel:IsShown(), "panel lateral visible en QUEST_DETAIL")
check(lastBlocks and lastBlocks[1].text == MES.Personalize(q.title), "panel muestra el título ES: " .. tostring(q.title))
check(not MES.IsOutdated(q, titleEN, textEN), "hash EN del juego coincide con la base (no desactualizada)")
check(MES.IsOutdated(q, titleEN, textEN .. " Extra."), "texto EN distinto se detecta como desactualizado")

MisionesES_Config.mode = "bilingue"
fire("QUEST_DETAIL")
check(MisionesES_Bilingual and MisionesES_Bilingual:IsShown(), "ventana bilingüe visible")
check(QuestFrame:GetAlpha() == 0, "QuestFrame original oculto en modo bilingüe")
fire("QUEST_FINISHED")
check(QuestFrame:GetAlpha() == 1 and not MisionesES_Bilingual:IsShown(), "QUEST_FINISHED restaura la ventana original")
MisionesES_Config.mode = "lateral"

fire("GOSSIP_SHOW")
local es = MES.GetGossip(gossipEN)
check(es ~= nil, "diálogo encontrado por hash: " .. tostring(es))
check(shownText():find(MES.Personalize(gossipES), 1, true) ~= nil, "panel de diálogo muestra el ES personalizado")
check(shownText():find(MES.Personalize(q.title), 1, true) ~= nil, "panel de diálogo lista la misión traducida")
fire("GOSSIP_CLOSED")
check(not MisionesES_SidePanel:IsShown(), "GOSSIP_CLOSED oculta el panel")

-- Recolector
MisionesES_Config.collector = true
current = { id = 999999, title = "A Brand New Quest", text = "Hello Arthas, help us." }
fire("QUEST_DETAIL")
local cap = MisionesES_Captura and MisionesES_Captura.quests[999999]
check(cap and cap.text == "Hello $N, help us.", "recolector guarda misión nueva con $N")
current = { id = questID, title = titleEN, text = textEN }
fire("QUEST_DETAIL")
check(MisionesES_Captura.quests[questID] == nil, "recolector ignora misiones ya traducidas")
_G.C_GossipInfo.GetText = function() return "Unknown words, Arthas." end
fire("GOSSIP_SHOW")
local gcount = 0
for _, t in pairs(MisionesES_Captura.gossip) do gcount = gcount + 1; check(t == "Unknown words, $N.", "recolector guarda diálogo nuevo") end
check(gcount == 1, "un diálogo capturado")

-- Cliente en otro idioma: no muestra nada
locale = "esMX"
MES.SidePanel():Hide()
fire("QUEST_DETAIL")
check(not MisionesES_SidePanel:IsShown(), "con cliente no inglés no se muestra nada")

-- Vista previa y comandos
locale = "enUS"
SlashCmdList.MISIONESES("test")
check(MisionesES_Preview and MisionesES_Preview:IsShown(), "/mes test abre la vista previa")
SlashCmdList.MISIONESES("estado")

print(failures == 0 and "TODO OK" or (failures .. " FALLOS"))
os.exit(failures == 0 and 0 or 1)
