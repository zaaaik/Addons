-- Detector: traduce eventos del juego en "contextos" y avisa a las vistas y al recolector.
-- Las vistas no deciden nada por su cuenta: reciben el contexto y la entrada traducida.
local _, MES = ...

local PHASES = { QUEST_DETAIL = "detail", QUEST_PROGRESS = "progress", QUEST_COMPLETE = "complete" }

-- Contexto de la ventana de misión del NPC con el texto inglés que muestra el juego.
function MES.QuestFrameContext(phase)
	local ctx = { kind = "quest", phase = phase, questID = GetQuestID and GetQuestID(), title = GetTitleText() }
	if phase == "detail" then
		ctx.text, ctx.objectives = GetQuestText(), GetObjectiveText()
	elseif phase == "progress" then
		ctx.progress = GetProgressText()
	else
		ctx.completion = GetRewardText()
	end
	return ctx
end

-- Contexto de la misión seleccionada en el registro.
function MES.QuestLogContext()
	local id = MES.SelectedLogQuestID()
	if not id then return nil end
	local ctx = { kind = "log", phase = "log", questID = id }
	if GetQuestLogQuestText then ctx.text, ctx.objectives = GetQuestLogQuestText() end
	if C_QuestLog and C_QuestLog.GetTitleForQuestID then ctx.title = C_QuestLog.GetTitleForQuestID(id) end
	if not ctx.title and GetQuestLogTitle and GetQuestLogSelection then
		ctx.title = GetQuestLogTitle(GetQuestLogSelection())
	end
	return ctx
end

local function onQuest(phase)
	MES.HideBilingual()
	if not MES.IsEnglishClient() then return end
	local ctx = MES.QuestFrameContext(phase)
	MES.CaptureQuest(ctx)
	local side = MES.SidePanel()
	local q = MES.cfg.showQuest and MES.GetQuest(ctx.questID)
	if not q then
		if MES.sideOwner == "quest" then side:Hide() end
		return
	end
	-- La descripción solo llega en la fase "detail"; en las demás se compara el título.
	ctx.outdated = MES.IsOutdated(q, ctx.title, ctx.text)
	if MES.cfg.mode == "bilingue" and MES.ShowBilingual(q, ctx) then
		side:Hide()
		return
	end
	if MES.ShowBeside(side, QuestFrame, MES.QuestBlocks(q, ctx)) then MES.sideOwner = "quest" end
end

local function onQuestFinished()
	MES.HideBilingual()
	if MES.sideOwner == "quest" then MES.SidePanel():Hide() end
end

local function onGossip()
	if not MES.IsEnglishClient() then return end
	local text = MES.GossipText()
	MES.CaptureGossip(text)
	MES.ShowGossip(text)
end

local function onLogUpdate()
	local ctx = MES.IsEnglishClient() and MES.QuestLogContext()
	if ctx then MES.CaptureQuest(ctx) end
end

function MES.InitDetector()
	local f = CreateFrame("Frame")
	for _, e in ipairs({ "QUEST_DETAIL", "QUEST_PROGRESS", "QUEST_COMPLETE", "QUEST_FINISHED",
		"GOSSIP_SHOW", "GOSSIP_CLOSED", "QUEST_LOG_UPDATE", "QUEST_DATA_LOAD_RESULT" }) do
		pcall(f.RegisterEvent, f, e)
	end
	f:SetScript("OnEvent", function(_, event, ...)
		if PHASES[event] then
			onQuest(PHASES[event])
		elseif event == "QUEST_FINISHED" then
			onQuestFinished()
		elseif event == "GOSSIP_SHOW" then
			onGossip()
		elseif event == "GOSSIP_CLOSED" then
			MES.HideGossip()
		elseif event == "QUEST_LOG_UPDATE" then
			onLogUpdate()
		elseif event == "QUEST_DATA_LOAD_RESULT" then
			MES.OnQuestDataLoad(...)
		end
	end)
	-- Capturar también al cambiar la selección del registro (cliente clásico).
	if hooksecurefunc and SelectQuestLogEntry then
		hooksecurefunc("SelectQuestLogEntry", onLogUpdate)
	end
end
