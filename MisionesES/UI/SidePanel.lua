-- Modo "lateral": pergamino con la traducción junto a la ventana original.
local _, MES = ...

-- Ancho del pergamino: 16 % menos que antes, como en el diseño de referencia.
local PANEL_WIDTH = 285

local side, log

function MES.SidePanel()
	if not side then
		side = MES.CreateParchment("MisionesES_SidePanel", UIParent, PANEL_WIDTH, 420, { rolls = true })
	end
	return side
end

function MES.LogPanel()
	if not log then
		log = MES.CreateParchment("MisionesES_LogPanel", UIParent, PANEL_WIDTH, 420, { rolls = true })
	end
	return log
end

-- Notas al pie: traducción por IA o inglés distinto al de la base de datos.
function MES.NoteBlocks(blocks, isAI, outdated)
	if isAI or outdated then blocks[#blocks + 1] = { kind = "sep" } end
	if isAI then
		blocks[#blocks + 1] = { kind = "note", text = "|T" .. MES.TEX .. "ink_quill_icon:14:14|t " .. MES.L.NOTE_AI }
	end
	if outdated then blocks[#blocks + 1] = { kind = "note", text = MES.L.NOTE_OUTDATED } end
	return blocks
end

-- Bloques para una misión según ctx.phase: "detail", "progress", "complete" o "log".
function MES.QuestBlocks(q, ctx)
	local P = MES.Personalize
	local phase = ctx and ctx.phase
	local blocks = { { kind = "title", text = P(q.title) }, { kind = "sep" } }
	if phase == "progress" then
		blocks[#blocks + 1] = { kind = "text", text = P(q.progress) }
	elseif phase == "complete" then
		blocks[#blocks + 1] = { kind = "text", text = P(q.completion) }
	else
		blocks[#blocks + 1] = { kind = "text", text = P(q.text) }
		if q.objectives and q.objectives ~= "" then
			blocks[#blocks + 1] = { kind = "header", text = MES.L.OBJECTIVES }
			blocks[#blocks + 1] = { kind = "text", text = P(q.objectives) }
		end
	end
	return MES.NoteBlocks(blocks, q.ia, ctx and ctx.outdated)
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
	panel:SetPoint("TOPLEFT", anchorFrame, "TOPRIGHT", 26, -40)
	panel:Show()
	panel:SetBlocks(blocks)
	panel:FitHeight(180, math.max(240, (anchorFrame:GetHeight() or 420) - 70))
	return true
end
