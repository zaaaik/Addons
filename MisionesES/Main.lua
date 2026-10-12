-- Eventos, comandos y vista previa.
local _, MES = ...

local phaseByEvent = { QUEST_DETAIL = "detail", QUEST_PROGRESS = "progress", QUEST_COMPLETE = "complete" }

local function showQuest(phase)
	MES.CaptureQuestFrame(phase)
	MES.HideBilingual()
	local side = MES.SidePanel()
	if not MES.cfg.showQuest or MES.ClientLang() == "es" then side:Hide() return end
	local q = MES.GetQuest(GetQuestID and GetQuestID())
	if not q then side:Hide() return end
	if MES.cfg.mode == "bilingue" and MES.ShowBilingual(q, phase) then
		side:Hide()
		return
	end
	if MES.ShowBeside(side, QuestFrame, MES.QuestBlocks(q, phase)) then MES.sideOwner = "quest" end
end

local function hideQuest()
	MES.HideBilingual()
	if MES.sideOwner == "quest" then MES.SidePanel():Hide() end
end

-- Vista previa con la misión ficticia: simula la ventana original y el modo elegido.
local preview
function MES.ShowTest()
	preview = preview or MES.CreateParchment("MisionesES_Preview", UIParent, 340, 420)
	local en, es = MES.testQuestEN, MES.testQuest
	local P = MES.Personalize
	preview:ClearAllPoints()
	preview:SetPoint("RIGHT", UIParent, "CENTER", -240, 0)
	preview:Show()
	if MES.cfg.mode == "bilingue" then
		preview:SetBlocks({
			{ kind = "title", text = P(es.title) }, { kind = "original", text = en.title },
			{ kind = "text", text = P(es.text) }, { kind = "original", text = P(en.text) },
			{ kind = "header", text = "Objetivos" },
			{ kind = "text", text = P(es.objectives) }, { kind = "original", text = en.objectives },
		})
		MES.SidePanel():Hide()
	else
		preview:SetBlocks({
			{ kind = "title", text = en.title }, { kind = "text", text = P(en.text) },
			{ kind = "header", text = "Quest Objectives" }, { kind = "text", text = en.objectives },
		})
		MES.ShowBeside(MES.SidePanel(), preview, MES.QuestBlocks(es, "detail"))
		MES.sideOwner = "test"
	end
end

function MES.HideTest()
	if preview then preview:Hide() end
	if MES.sideOwner == "test" then MES.SidePanel():Hide() end
end

local function slash(msg)
	local cmd, a, b = strsplit(" ", ((msg or ""):lower():gsub("^%s+", "")), 3)
	if cmd == "config" or cmd == "opciones" then
		MES.OpenOptions()
	elseif cmd == "asistente" then
		MES.ShowSetup()
	elseif cmd == "test" then
		if preview and preview:IsShown() then MES.HideTest() else MES.ShowTest() end
	elseif cmd == "modo" then
		MES.cfg.mode = (MES.cfg.mode == "lateral") and "bilingue" or "lateral"
		MES.Print("Modo: %s", MES.cfg.mode)
	elseif cmd == "recolector" then
		MES.cfg.collector = not MES.cfg.collector
		MES.Print("Recolector %s.", MES.cfg.collector and "activado" or "desactivado")
	elseif cmd == "escanear" then
		if a == "parar" then MES.StopScan()
		else MES.StartScan(tonumber(a) or 1, tonumber(b) or 30000) end
	elseif cmd == "estado" then
		MES.CollectorStatus()
	else
		MES.Print("Comandos:")
		MES.Print("  /mes config - opciones    /mes asistente - repetir asistente")
		MES.Print("  /mes test - vista previa  /mes modo - cambiar modo")
		MES.Print("  /mes recolector - activar/desactivar captura (mantenedor)")
		MES.Print("  /mes escanear [desde] [hasta] | parar    /mes estado")
	end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:SetScript("OnEvent", function(self, event, ...)
	if event == "ADDON_LOADED" then
		if ... ~= MES.name then return end
		MES.InitConfig()
		MES.Fonts()
		self:UnregisterEvent("ADDON_LOADED")
	elseif event == "PLAYER_LOGIN" then
		MES.InitOptions()
		MES.InitQuestLog()
		SLASH_MISIONESES1 = "/mes"
		SLASH_MISIONESES2 = "/misioneses"
		SlashCmdList.MISIONESES = slash
		for _, e in ipairs({ "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED",
			"GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_LOG_UPDATE", "QUEST_DATA_LOAD_RESULT" }) do
			pcall(self.RegisterEvent, self, e)
		end
		if not MES.cfg.setupDone then MES.ShowSetup() end
		if MES.ClientLang() == "es" and not MES.cfg.collector then
			MES.Print("Cliente en español: no hace falta traducir. Para capturar textos usa /mes recolector.")
		end
	elseif phaseByEvent[event] then
		showQuest(phaseByEvent[event])
	elseif event == "QUEST_FINISHED" then
		hideQuest()
	elseif event == "GOSSIP_SHOW" then
		MES.CaptureGossip()
		MES.ShowGossip()
	elseif event == "GOSSIP_CLOSED" then
		MES.HideGossip()
	elseif event == "QUEST_LOG_UPDATE" then
		MES.CaptureQuestLog()
	elseif event == "QUEST_DATA_LOAD_RESULT" then
		MES.OnQuestDataLoad(...)
	end
end)

-- Capturar también al cambiar la selección del registro (cliente clásico).
if hooksecurefunc and SelectQuestLogEntry then
	hooksecurefunc("SelectQuestLogEntry", function() if MES.cfg then MES.CaptureQuestLog() end end)
end
