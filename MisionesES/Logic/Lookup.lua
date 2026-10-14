-- Búsqueda de traducciones en la base de datos generada (Data/*.lua).
local _, MES = ...

local LONG = { t = "title", d = "text", o = "objectives", p = "progress", c = "completion" }

-- Misión ficticia para /mes test y las vistas previas.
MES.TEST_QUEST_ID = -1
MES.testQuest = {
	title = "Misión de prueba",
	text = "Saludos, $N. Esta es una misión de ejemplo para comprobar cómo se ve la traducción junto al texto original.$B$BSi puedes leer esto, el addon funciona correctamente.",
	objectives = "Habla con el NPC de prueba.",
	progress = "¿Ya terminaste lo que te pedí?",
	completion = "¡Bien hecho, $c! Aquí tienes tu recompensa.",
}
MES.testQuestEN = {
	title = "Test Quest",
	text = "Greetings, $N. This is a sample quest to check how the translation looks next to the original text.$B$BIf you can read this, the addon works correctly.",
	objectives = "Speak with the test NPC.",
}

local function hashSet(h)
	local set = {}
	for part in (h or ""):gmatch("[^|]+") do set[part] = true end
	return set
end

-- Devuelve la traducción de una misión como tabla { title, text, objectives, progress, completion, ia, h }.
function MES.GetQuest(questID)
	if not questID or questID == 0 then return nil end
	if questID == MES.TEST_QUEST_ID then return MES.testQuest end
	local row = MES.DB.quests[questID]
	if not row then return nil end
	local q = { ia = row.ia == 1, h = row.h }
	for short, long in pairs(LONG) do q[long] = row[short] end
	return q
end

-- true si el título + descripción que muestra el juego no coinciden con el inglés del que se tradujo.
function MES.IsOutdated(q, title, text)
	if not q or not q.h or not title or not text or text == "" then return false end
	local set = hashSet(q.h)
	for _, key in ipairs(MES.Keys(title .. " " .. text)) do
		if set[key] then return false end
	end
	return true
end

-- Devuelve texto ES, esIA para un texto de diálogo en inglés.
function MES.GetGossip(text)
	for _, key in ipairs(MES.Keys(text)) do
		local v = MES.DB.gossip[key]
		if type(v) == "string" then return v, false end
		if type(v) == "table" then return v.x, true end
	end
	return nil
end

function MES.CountDB()
	local q, g = 0, 0
	for _ in pairs(MES.DB.quests) do q = q + 1 end
	for _ in pairs(MES.DB.gossip) do g = g + 1 end
	return q, g
end
