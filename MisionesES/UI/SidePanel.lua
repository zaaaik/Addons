-- Modo "lateral": pergamino con la traducción junto a la ventana original.
local _, MES = ...

local side, log

function MES.SidePanel()
	if not side then
		side = MES.CreateParchment("MisionesES_SidePanel", UIParent, 320, 420)
	end
	return side
end

function MES.LogPanel()
	if not log then
		log = MES.CreateParchment("MisionesES_LogPanel", UIParent, 320, 420)
	end
	return log
end

-- Bloques para una misión según la fase: "detail", "progress", "complete" o "log".
function MES.QuestBlocks(q, phase)
	local P = MES.Personalize
	local blocks = { { kind = "title", text = P(q.title) } }
	if phase == "progress" then
		blocks[#blocks + 1] = { kind = "text", text = P(q.progress) }
	elseif phase == "complete" then
		blocks[#blocks + 1] = { kind = "text", text = P(q.completion) }
	else
		blocks[#blocks + 1] = { kind = "text", text = P(q.text) }
		if q.objectives and q.objectives ~= "" then
			blocks[#blocks + 1] = { kind = "header", text = "Objetivos" }
			blocks[#blocks + 1] = { kind = "text", text = P(q.objectives) }
		end
	end
	if q.src == "ia" then
		blocks[#blocks + 1] = { kind = "sep" }
		blocks[#blocks + 1] = { kind = "original", text = "Traducción automática (IA)." }
	end
	return blocks
end

-- Muestra un pergamino a la derecha de anchorFrame. Devuelve false si no hay nada que mostrar.
function MES.ShowBeside(panel, anchorFrame, blocks)
	local hasBody = false
	for i = 2, #blocks do
		if blocks[i].kind == "text" and blocks[i].text and blocks[i].text ~= "" then hasBody = true end
	end
	if not anchorFrame or not hasBody then
		panel:Hide()
		return false
	end
	panel:ClearAllPoints()
	panel:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", 4, -14)
	panel:Show()
	panel:SetBlocks(blocks)
	panel:FitHeight(160, math.max(220, (anchorFrame:GetHeight() or 420) - 30))
	return true
end
