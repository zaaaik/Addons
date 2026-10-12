-- Diálogos (gossip): texto del NPC y títulos de misiones disponibles, traducidos al lado.
local _, MES = ...

function MES.GossipText()
	if C_GossipInfo and C_GossipInfo.GetText then return C_GossipInfo.GetText() end
	if GetGossipText then return GetGossipText() end
end

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

function MES.ShowGossip()
	local panel = MES.SidePanel()
	if not MES.cfg.showGossip or MES.ClientLang() == "es" or not GossipFrame then return end

	local blocks = { { kind = "title", text = UnitName("npc") or "" } }
	local text = MES.GetGossip(MES.CurrentNpcID(), MES.GossipText())
	if text then
		blocks[#blocks + 1] = { kind = "text", text = MES.Personalize(text) }
	end
	local titles = {}
	for _, id in ipairs(gossipQuestIDs()) do
		local q = MES.GetQuest(id)
		if q and q.title then titles[#titles + 1] = "• " .. MES.Personalize(q.title) end
	end
	if #titles > 0 then
		blocks[#blocks + 1] = { kind = "header", text = "Misiones" }
		blocks[#blocks + 1] = { kind = "text", text = table.concat(titles, "\n") }
	end
	if MES.ShowBeside(panel, GossipFrame, blocks) then MES.sideOwner = "gossip" end
end

function MES.HideGossip()
	if MES.sideOwner == "gossip" or not MES.sideOwner then MES.SidePanel():Hide() end
end
