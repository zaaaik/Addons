-- Modo "bilingüe": ventana única que cubre QuestFrame con texto EN y ES intercalados.
local _, MES = ...

local win

local function rewardsText()
	local parts = {}
	local money = GetRewardMoney and GetRewardMoney() or 0
	if money > 0 and GetCoinTextureString then parts[#parts + 1] = GetCoinTextureString(money) end
	local xp = GetRewardXP and GetRewardXP() or 0
	if xp > 0 then parts[#parts + 1] = MES.L.XP:format(xp) end
	for _, kind in ipairs({ "reward", "choice" }) do
		local n = (kind == "reward" and GetNumQuestRewards or GetNumQuestChoices)() or 0
		for i = 1, n do
			local itemName, texture, count = GetQuestItemInfo(kind, i)
			if itemName then
				local icon = texture and ("|T%s:16|t "):format(texture) or ""
				parts[#parts + 1] = icon .. itemName .. ((count or 1) > 1 and (" x" .. count) or "")
			end
		end
	end
	return table.concat(parts, "\n")
end

local function makeButton(parent, point, x)
	local b = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	b:SetSize(140, 24)
	b:SetPoint(point, parent, point, x, 14)
	return b
end

local function create()
	win = MES.CreateParchment("MisionesES_Bilingual", UIParent, 384, 512)
	win:SetFrameStrata("DIALOG")
	win.scroll:SetPoint("BOTTOMRIGHT", -34, 48)
	win.left = makeButton(win, "BOTTOMLEFT", 16)
	win.right = makeButton(win, "BOTTOMRIGHT", -16)
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

	local P = MES.Personalize
	local blocks = { { kind = "title", text = P(q.title) }, { kind = "original", text = ctx.title } }
	local function pair(es, en)
		if es and es ~= "" then blocks[#blocks + 1] = { kind = "text", text = P(es) } end
		if en and en ~= "" then blocks[#blocks + 1] = { kind = "original", text = en } end
	end

	if phase == "detail" then
		pair(q.text, ctx.text)
		blocks[#blocks + 1] = { kind = "header", text = MES.L.OBJECTIVES }
		pair(q.objectives, ctx.objectives)
		win.left:SetText(MES.L.ACCEPT)
		win.left:SetScript("OnClick", function() AcceptQuest() end)
		win.right:SetText(MES.L.DECLINE)
		win.right:SetScript("OnClick", function() DeclineQuest() end)
		win.left:Enable()
	elseif phase == "progress" then
		pair(q.progress, ctx.progress)
		win.left:SetText(MES.L.CONTINUE)
		win.left:SetScript("OnClick", function() CompleteQuest() end)
		if IsQuestCompletable() then win.left:Enable() else win.left:Disable() end
		win.right:SetText(MES.L.CANCEL)
		win.right:SetScript("OnClick", function() CloseQuest() end)
	else
		pair(q.completion, ctx.completion)
		win.left:SetText(MES.L.COMPLETE)
		win.left:SetScript("OnClick", function()
			GetQuestReward((GetNumQuestChoices() or 0) == 1 and 1 or 0)
		end)
		win.left:Enable()
		win.right:SetText(MES.L.CANCEL)
		win.right:SetScript("OnClick", function() CloseQuest() end)
	end

	local rewards = rewardsText()
	if rewards ~= "" then
		blocks[#blocks + 1] = { kind = "header", text = MES.L.REWARDS }
		blocks[#blocks + 1] = { kind = "text", text = rewards }
	end
	MES.NoteBlocks(blocks, q.ia, ctx.outdated)

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
