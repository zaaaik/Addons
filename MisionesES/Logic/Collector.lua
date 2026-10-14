-- Recolector (solo mantenedor, cliente en inglés): guarda en SavedVariables el texto EN de las
-- misiones y diálogos que faltan en la base de datos o cuyo inglés cambió en Forever.
-- tools/build_db.py lo lee desde la carpeta capturas/ y traduce solo eso.
local _, MES = ...

local function store()
	MisionesES_Captura = MisionesES_Captura or {}
	local c = MisionesES_Captura
	c.version = 2
	c.quests = c.quests or {}
	c.gossip = c.gossip or {}
	c.ids = c.ids or {}
	return c
end

local function active()
	return MES.cfg.collector and MES.IsEnglishClient()
end

local function put(entry, key, value)
	value = MES.Normalize(value)
	if value and value ~= "" then entry[key] = value end
end

-- ctx: contexto del Detector { questID, phase, title, text, objectives, progress, completion }
function MES.CaptureQuest(ctx)
	if not active() or not ctx.questID or ctx.questID <= 0 then return end
	local q = MES.GetQuest(ctx.questID)
	local field = ({ detail = "text", log = "text", progress = "progress", complete = "completion" })[ctx.phase]
	local outdated = q and MES.IsOutdated(q, ctx.title, ctx.text)
	local missingField = q and field and not q[field] and ctx[field] and ctx[field] ~= ""
	if q and not outdated and not missingField then return end
	local c = store()
	c.ids[ctx.questID] = true
	local e = c.quests[ctx.questID] or {}
	c.quests[ctx.questID] = e
	if q and not outdated then
		-- Solo falta este campo: no se tocan los que ya tienen traducción oficial.
		put(e, field, ctx[field])
		return
	end
	for _, k in ipairs({ "title", "text", "objectives", "progress", "completion" }) do
		put(e, k, ctx[k])
	end
end

function MES.CaptureGossip(text)
	if not active() or not text or text == "" or MES.GetGossip(text) then return end
	local normalized = MES.Normalize(text)
	store().gossip[MES.Hash(MES.Finish(normalized))] = normalized
end

------------------------------------------------------------------------------------------------
-- Escaneo masivo de IDs: registra qué misiones existen en Forever y su título EN.
------------------------------------------------------------------------------------------------
local scan

local function scanStore(id)
	local title = C_QuestLog.GetTitleForQuestID(id)
	if not title or title == "" then return end
	local c = store()
	c.ids[id] = true
	if not MES.DB.quests[id] then
		c.quests[id] = c.quests[id] or {}
		put(c.quests[id], "title", title)
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
	if not active() then
		MES.Print("Activa primero el recolector con /mes recolector (cliente en inglés).")
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
				scan.pending[id] = now
				scan.waiting = scan.waiting + 1
				C_QuestLog.RequestLoadQuestByID(id)
			end
			sent = sent + 1
			if id % 1000 == 0 then MES.Print("... %d (encontradas: %d)", id, scan.found) end
		end
		if scan.next > scan.to and scan.waiting <= 0 then MES.StopScan() end
	end)
end

function MES.StopScan()
	if not scan then return end
	scan.ticker:Cancel()
	MES.Print("Escaneo terminado: %d misiones encontradas. Haz /reload para guardarlas en disco.", scan.found)
	scan = nil
end

function MES.CollectorStatus()
	local c = store()
	local q, ids, g = 0, 0, 0
	for _ in pairs(c.quests) do q = q + 1 end
	for _ in pairs(c.ids) do ids = ids + 1 end
	for _ in pairs(c.gossip) do g = g + 1 end
	local dbq, dbg = MES.CountDB()
	MES.Print("Base de datos: %d misiones, %d claves de diálogo (%s, %s).", dbq, dbg,
		MES.DB.meta.fuente or "?", MES.DB.meta.generado or "?")
	MES.Print("Capturado: %d misiones por traducir, %d diálogos, %d IDs escaneados.", q, g, ids)
	MES.Print("Recolector: %s. Idioma del cliente: %s.", MES.cfg.collector and "activado" or "desactivado", GetLocale())
end
