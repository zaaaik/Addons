-- Diálogos (gossip): texto del NPC y títulos de misiones disponibles, traducidos al lado.
local _, MES = ...

-- IDs de misiones ofrecidas o activas en el diálogo actual.
local function gossipQuestIDs()
	local ids = {}
	if C_GossipInfo then
		for _, getter in ipairs({ C_GossipInfo.GetAvailableQuests, C_GossipInfo.GetActiveQuests }) do
			if getter then
				for _, info in ipairs(getter() or {}) do
					if info.questID then ids[#ids + 1] = info.questID end
				end
			end
		end
	end
	return ids
end

function MES.ShowGossip(text)
	local panel = MES.SidePanel()
	if not MES.cfg.showGossip or not GossipFrame then return end

	local blocks = { { kind = "title", text = UnitName("npc") or "" } }
	local es, isAI = MES.GetGossip(text)
	if es then
		blocks[#blocks + 1] = { kind = "text", text = MES.Personalize(es) }
	end
	local titles = {}
	for _, id in ipairs(gossipQuestIDs()) do
		local q = MES.GetQuest(id)
		if q and q.title then titles[#titles + 1] = "• " .. MES.Personalize(q.title) end
	end
	if #titles > 0 then
		blocks[#blocks + 1] = { kind = "header", text = MES.L.QUESTS }
		blocks[#blocks + 1] = { kind = "text", text = table.concat(titles, "\n") }
	end
	MES.NoteBlocks(blocks, isAI, false)
	if MES.ShowBeside(panel, GossipFrame, blocks) then MES.sideOwner = "gossip" end
end

function MES.HideGossip()
	if MES.sideOwner == "gossip" then MES.SidePanel():Hide() end
end
