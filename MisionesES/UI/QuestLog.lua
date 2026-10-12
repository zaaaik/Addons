-- Registro de misiones: al pasar el ratón por el detalle se muestra la traducción al lado.
local _, MES = ...

-- Pares { marco de detalle a vigilar, marco al que anclar el pergamino } según la versión del cliente.
local function candidates()
	local list = {}
	if QuestLogDetailScrollFrame and QuestLogFrame then
		list[#list + 1] = { QuestLogDetailScrollFrame, QuestLogFrame }
	end
	if QuestLogDetailFrame then
		list[#list + 1] = { QuestLogDetailFrame, QuestLogDetailFrame }
	end
	if QuestMapFrame and QuestMapFrame.DetailsFrame and WorldMapFrame then
		list[#list + 1] = { QuestMapFrame.DetailsFrame, WorldMapFrame }
	end
	if QuestLogPopupDetailFrame then
		list[#list + 1] = { QuestLogPopupDetailFrame, QuestLogPopupDetailFrame }
	end
	return list
end

local shownID, elapsed = nil, 0

local function update()
	local panel = MES.LogPanel()
	if not MES.cfg.showQuestLog or MES.ClientLang() == "es" then
		panel:Hide()
		shownID = nil
		return
	end
	for _, c in ipairs(candidates()) do
		local detail, anchor = c[1], c[2]
		if detail:IsVisible() and MouseIsOver(detail) then
			local id = MES.SelectedLogQuestID()
			local q = MES.GetQuest(id)
			if q then
				if shownID ~= id or not panel:IsShown() then
					MES.ShowBeside(panel, anchor, MES.QuestBlocks(q, "log"))
					shownID = id
				end
				return
			end
		end
	end
	-- El pergamino también cuenta como zona activa para poder hacer scroll en él.
	if panel:IsShown() and MouseIsOver(panel) then return end
	panel:Hide()
	shownID = nil
end

function MES.InitQuestLog()
	local watcher = CreateFrame("Frame")
	watcher:SetScript("OnUpdate", function(_, dt)
		elapsed = elapsed + dt
		if elapsed < 0.15 then return end
		elapsed = 0
		update()
	end)
end
