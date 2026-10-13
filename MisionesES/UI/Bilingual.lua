-- Modo "bilingüe": pergamino antiguo que sustituye a QuestFrame, con cada párrafo en español seguido
-- de su original en inglés (el sello de lacre muestra u oculta el inglés).
local _, MES = ...

local win, lastQ, lastCtx

-- Divide en párrafos (líneas en blanco o $B$B ya convertidos en saltos de línea).
local function paragraphs(text)
	local out = {}
	text = (text or ""):gsub("\r", "")
	for p in (text .. "\n\n"):gmatch("(.-)\n%s*\n") do
		p = p:gsub("^%s+", ""):gsub("%s+$", "")
		if p ~= "" then out[#out + 1] = p end
	end
	return out
end

-- Intercala párrafos ES y EN si coinciden en número; si no, todo el ES y después todo el EN.
function MES.Interleave(blocks, es, en, showOriginal)
	local pes, pen = paragraphs(MES.Personalize(es)), paragraphs(en)
	if not showOriginal or #pen == 0 then
		for _, p in ipairs(pes) do blocks[#blocks + 1] = { kind = "text", text = p } end
	elseif #pes == #pen then
		for i = 1, #pes do
			blocks[#blocks + 1] = { kind = "text", text = pes[i] }
			blocks[#blocks + 1] = { kind = "original", text = pen[i] }
		end
	else
		for _, p in ipairs(pes) do blocks[#blocks + 1] = { kind = "text", text = p } end
		for _, p in ipairs(pen) do blocks[#blocks + 1] = { kind = "original", text = p } end
	end
	return blocks
end

local function rewardsBlock()
	local items = {}
	for _, kind in ipairs({ "reward", "choice" }) do
		local n = (kind == "reward" and GetNumQuestRewards or GetNumQuestChoices)() or 0
		for i = 1, n do
			local itemName, texture, count = GetQuestItemInfo(kind, i)
			if itemName then
				items[#items + 1] = { icon = texture, name = itemName, count = count, questType = kind, questIndex = i }
			end
		end
	end
	local extra = {}
	local money = GetRewardMoney and GetRewardMoney() or 0
	if money > 0 and GetCoinTextureString then extra[#extra + 1] = GetCoinTextureString(money) end
	local xp = GetRewardXP and GetRewardXP() or 0
	if xp > 0 then extra[#extra + 1] = MES.L.XP:format(xp) end
	if #items == 0 and #extra == 0 then return nil end
	return { kind = "rewards", items = items, extra = table.concat(extra, "    ") }
end

local function create()
	win = MES.CreateParchment("MisionesES_Bilingual", UIParent, 384, 512, {
		rolls = true,
		sealTooltip = MES.L.SEAL_TOOLTIP,
		seal = function()
			MES.cfg.showOriginal = not MES.cfg.showOriginal
			if lastQ then MES.ShowBilingual(lastQ, lastCtx) end
		end,
	})
	win:SetFrameStrata("DIALOG")
	win.scroll:SetPoint("BOTTOMRIGHT", -22, 62)
	win:ArrowInside()
	-- Acción principal (Aceptar / Continuar / Completar) siempre a la derecha, como en el juego.
	win.primary = MES.CreateRibbonButton(win, "red")
	win.primary:SetPoint("BOTTOMRIGHT", -14, 14)
	win.secondary = MES.CreateRibbonButton(win, "brown")
	win.secondary:SetPoint("BOTTOMLEFT", 14, 14)
	win:SetScript("OnHide", function()
		if QuestFrame then QuestFrame:SetAlpha(1) end
	end)
	return win
end

-- Devuelve true si la ventana bilingüe se encargó de la fase; false para usar el modo lateral.
function MES.ShowBilingual(q, ctx)
	local phase = ctx.phase
	if not QuestFrame then return false end
	if phase == "complete" and (GetNumQuestChoices() or 0) > 1 then return false end
	win = win or create()
	lastQ, lastCtx = q, ctx

	local show = MES.cfg.showOriginal
	local blocks = { { kind = "title", text = MES.Personalize(q.title) } }
	if show then blocks[#blocks + 1] = { kind = "subtitle", text = ctx.title } end
	blocks[#blocks + 1] = { kind = "sep" }

	if phase == "detail" then
		MES.Interleave(blocks, q.text, ctx.text, show)
		if q.objectives and q.objectives ~= "" then
			blocks[#blocks + 1] = { kind = "header", text = MES.L.OBJECTIVES }
			MES.Interleave(blocks, q.objectives, ctx.objectives, show)
		end
		win.primary:SetText(MES.L.ACCEPT)
		win.primary:SetScript("OnClick", function() AcceptQuest() end)
		win.secondary:SetText(MES.L.DECLINE)
		win.secondary:SetScript("OnClick", function() DeclineQuest() end)
		win.primary:Enable()
	elseif phase == "progress" then
		MES.Interleave(blocks, q.progress, ctx.progress, show)
		win.primary:SetText(MES.L.CONTINUE)
		win.primary:SetScript("OnClick", function() CompleteQuest() end)
		if IsQuestCompletable() then win.primary:Enable() else win.primary:Disable() end
		win.secondary:SetText(MES.L.CANCEL)
		win.secondary:SetScript("OnClick", function() CloseQuest() end)
	else
		MES.Interleave(blocks, q.completion, ctx.completion, show)
		win.primary:SetText(MES.L.COMPLETE)
		win.primary:SetScript("OnClick", function()
			GetQuestReward((GetNumQuestChoices() or 0) == 1 and 1 or 0)
		end)
		win.primary:Enable()
		win.secondary:SetText(MES.L.CANCEL)
		win.secondary:SetScript("OnClick", function() CloseQuest() end)
	end

	if phase ~= "progress" then
		local rewards = rewardsBlock()
		if rewards then
			blocks[#blocks + 1] = { kind = "sep" }
			blocks[#blocks + 1] = { kind = "header", text = MES.L.REWARDS }
			blocks[#blocks + 1] = rewards
		end
	end
	MES.NoteBlocks(blocks, q.ia, ctx.outdated)

	-- Cubre la ventana original entera para que sus botones (invisibles) no reciban clics.
	win:ClearAllPoints()
	win:SetAllPoints(QuestFrame)
	QuestFrame:SetAlpha(0)
	win:Show()
	win:SetBlocks(blocks)
	return true
end

function MES.HideBilingual()
	if win then win:Hide() end
	if QuestFrame then QuestFrame:SetAlpha(1) end
end
