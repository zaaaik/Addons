-- Recolector (solo mantenedor): guarda en SavedVariables los textos que envía el servidor
-- en el idioma del cliente, para generar la base de datos con tools/build_db.py.
local _, MES = ...

local function store()
	MisionesES_Captura = MisionesES_Captura or {}
	local c = MisionesES_Captura
	c.version = 1
	c.quests = c.quests or {}
	c.gossip = c.gossip or {}
	return c
end

local function questEntry(questID)
	local lang = MES.ClientLang()
	local c = store()
	c.quests[questID] = c.quests[questID] or {}
	c.quests[questID][lang] = c.quests[questID][lang] or {}
	return c.quests[questID][lang]
end

local function put(entry, key, value)
	value = MES.Normalize(value)
	if value and value ~= "" then entry[key] = value end
end

local function active()
	return MES.cfg.collector and MES.ClientLang() ~= nil
end

-- phase: "detail", "progress" o "complete" (eventos de QuestFrame).
function MES.CaptureQuestFrame(phase)
	if not active() then return end
	local id = GetQuestID and GetQuestID()
	if not id or id == 0 then return end
	local e = questEntry(id)
	put(e, "title", GetTitleText())
	if phase == "detail" then
		put(e, "text", GetQuestText())
		put(e, "objectives", GetObjectiveText())
	elseif phase == "progress" then
		put(e, "progress", GetProgressText())
	elseif phase == "complete" then
		put(e, "completion", GetRewardText())
	end
end

function MES.CaptureQuestLog()
	if not active() or not GetQuestLogQuestText then return end
	local id = MES.SelectedLogQuestID()
	if not id then return end
	local text, objectives = GetQuestLogQuestText()
	local e = questEntry(id)
	if not e.text then put(e, "text", text) end
	if not e.objectives then put(e, "objectives", objectives) end
	if not e.title and C_QuestLog and C_QuestLog.GetTitleForQuestID then
		put(e, "title", C_QuestLog.GetTitleForQuestID(id))
	end
end

function MES.CaptureGossip()
	if not active() then return end
	local npcID = MES.CurrentNpcID()
	local text = MES.Normalize(MES.GossipText())
	if not npcID or not text or text == "" then return end
	local c = store()
	local lang = MES.ClientLang()
	c.gossip[npcID] = c.gossip[npcID] or {}
	c.gossip[npcID][lang] = c.gossip[npcID][lang] or {}
	c.gossip[npcID][lang][MES.Hash(text)] = text
end

-- Escaneo masivo de títulos y objetivos por questID, sin visitar NPCs.
local scan

local function scanStore(id)
	local e = questEntry(id)
	put(e, "title", C_QuestLog.GetTitleForQuestID(id))
	if C_QuestLog.GetQuestObjectives then
		local lines = {}
		for _, o in ipairs(C_QuestLog.GetQuestObjectives(id) or {}) do
			if o.text and o.text ~= "" then lines[#lines + 1] = o.text end
		end
		if #lines > 0 then e.scanObjectives = table.concat(lines, "\n") end
	end
	scan.found = scan.found + 1
end

function MES.OnQuestDataLoad(id, success)
	if not scan or not scan.pending[id] then return end
	scan.pending[id] = nil
	scan.waiting = scan.waiting - 1
	if success then scanStore(id) end
end

function MES.StartScan(from, to)
	if not (C_QuestLog and C_QuestLog.RequestLoadQuestByID and C_QuestLog.GetTitleForQuestID) then
		MES.Print("Este cliente no tiene C_QuestLog.RequestLoadQuestByID; el escaneo no está disponible.")
		return
	end
	if not MES.cfg.collector then
		MES.Print("Activa primero el recolector con /mes recolector.")
		return
	end
	if scan then MES.Print("Ya hay un escaneo en curso (/mes escanear parar).") return end
	scan = { next = from, to = to, pending = {}, waiting = 0, found = 0 }
	MES.Print("Escaneando misiones %d-%d...", from, to)
	scan.ticker = C_Timer.NewTicker(0.2, function()
		-- Los IDs que no existen pueden no responder nunca: se descartan a los 3 s.
		local now = GetTime()
		for id, t in pairs(scan.pending) do
			if now - t > 3 then
				scan.pending[id] = nil
				scan.waiting = scan.waiting - 1
			end
		end
		local sent = 0
		while scan.next <= scan.to and scan.waiting < 20 and sent < 5 do
			local id = scan.next
			scan.next = id + 1
			local title = C_QuestLog.GetTitleForQuestID(id)
			if title and title ~= "" then
				scanStore(id)
			else
				scan.pending[id] = GetTime()
				scan.waiting = scan.waiting + 1
				C_QuestLog.RequestLoadQuestByID(id)
			end
			sent = sent + 1
			if id % 1000 == 0 then MES.Print("... %d (encontradas: %d)", id, scan.found) end
		end
		if scan.next > scan.to then
			-- Espera a las respuestas pendientes; las que no llegan son IDs inexistentes.
			if scan.waiting <= 0 then MES.StopScan() end
		end
	end)
end

function MES.StopScan()
	if not scan then return end
	scan.ticker:Cancel()
	MES.Print("Escaneo terminado: %d misiones guardadas. Haz /reload para escribirlas en disco.", scan.found)
	scan = nil
end

function MES.CollectorStatus()
	local c = store()
	local es, en, both = 0, 0, 0
	for _, q in pairs(c.quests) do
		if q.es then es = es + 1 end
		if q.en then en = en + 1 end
		if q.es and q.en then both = both + 1 end
	end
	local db = 0
	for _ in pairs(MES.DB.quests) do db = db + 1 end
	MES.Print("Base de datos del addon: %d misiones traducidas.", db)
	MES.Print("Captura pendiente: %d en español, %d en inglés (%d con ambos).", es, en, both)
	MES.Print("Recolector: %s. Idioma del cliente: %s.", MES.cfg.collector and "activado" or "desactivado", GetLocale())
end
