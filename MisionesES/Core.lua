-- MisionesES: núcleo compartido (configuración, utilidades y acceso a datos)
local ADDON, MES = ...
_G.MisionesES = MES

MES.name = ADDON
MES.version = "0.1.0"
MES.DB = { quests = {}, gossip = {} }

MES.defaults = {
	setupDone = false,
	mode = "lateral",      -- "lateral" = panel junto a la ventana, "bilingue" = ventana única EN + ES
	fontSize = 13,
	showQuest = true,
	showQuestLog = true,
	showGossip = true,
	collector = false,     -- solo para el mantenedor: captura textos en SavedVariables
}

function MES.Print(msg, ...)
	if select("#", ...) > 0 then msg = msg:format(...) end
	DEFAULT_CHAT_FRAME:AddMessage("|cffd4a017MisionesES|r: " .. tostring(msg))
end

function MES.InitConfig()
	MisionesES_Config = MisionesES_Config or {}
	for k, v in pairs(MES.defaults) do
		if MisionesES_Config[k] == nil then MisionesES_Config[k] = v end
	end
	MES.cfg = MisionesES_Config
end

-- Idioma del cliente: "es" (esES/esMX), "en" u otro código.
function MES.ClientLang()
	local loc = GetLocale()
	if loc == "esES" or loc == "esMX" then return "es" end
	if loc == "enUS" or loc == "enGB" then return "en" end
	return loc
end

-- Hash djb2 de 32 bits en hexadecimal. tools/luatable.py implementa el mismo algoritmo.
function MES.Hash(s)
	local h = 5381
	for i = 1, #s do
		h = (h * 33 + s:byte(i)) % 4294967296
	end
	return ("%08x"):format(h)
end

local function escapePattern(s)
	return (s:gsub("[%^%$%(%)%%%.%[%]%*%+%-%?]", "%%%0"))
end

-- Sustituye el nombre del jugador por $N para que el texto sirva a cualquier personaje.
function MES.Normalize(text)
	if not text then return nil end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	local name = UnitName("player")
	if name and name ~= "" then
		text = text:gsub(escapePattern(name), "$N")
	end
	return text
end

MES.classES = {
	WARRIOR = "Guerrero", MAGE = "Mago", PRIEST = "Sacerdote", ROGUE = "Pícaro",
	DRUID = "Druida", HUNTER = "Cazador", SHAMAN = "Chamán", PALADIN = "Paladín",
	WARLOCK = "Brujo",
}
MES.raceES = {
	Human = "Humano", Dwarf = "Enano", NightElf = "Elfo de la noche", Gnome = "Gnomo",
	Orc = "Orco", Scourge = "No-muerto", Tauren = "Tauren", Troll = "Trol",
}

-- Prepara un texto de la base de datos para mostrarlo al jugador actual.
function MES.Personalize(text)
	if not text then return nil end
	local name = UnitName("player") or ""
	local _, classFile = UnitClass("player")
	local className = MES.classES[classFile] or UnitClass("player") or ""
	local raceName, raceFile = UnitRace("player")
	raceName = MES.raceES[raceFile] or raceName or ""
	local female = UnitSex("player") == 3
	text = text:gsub("%$[Gg]%s*([^:;]-)%s*:%s*([^;]-)%s*;", function(m, f) return female and f or m end)
	text = text:gsub("%$[Nn]", function() return name end)
	text = text:gsub("%$[Cc]", function() return className end)
	text = text:gsub("%$[Rr]", function() return raceName end)
	text = text:gsub("%$[Bb]", "\n")
	return text
end

function MES.GetQuest(questID)
	if not questID or questID == 0 then return nil end
	if questID == MES.TEST_QUEST_ID then return MES.testQuest end
	return MES.DB.quests[questID]
end

function MES.GetGossip(npcID, text)
	local byNpc = npcID and MES.DB.gossip[npcID]
	text = MES.Normalize(text)
	if not byNpc or not text or text == "" then return nil end
	return byNpc[MES.Hash(text)]
end

-- ID numérico del NPC u objeto con el que se interactúa.
function MES.CurrentNpcID()
	local guid = UnitGUID("npc")
	if not guid then return nil end
	local _, _, _, _, _, id = strsplit("-", guid)
	return tonumber(id)
end

-- questID de la misión seleccionada en el registro (soporta API clásica y moderna).
function MES.SelectedLogQuestID()
	if C_QuestLog and C_QuestLog.GetSelectedQuest then
		local id = C_QuestLog.GetSelectedQuest()
		if id and id > 0 then return id end
	end
	if GetQuestLogSelection then
		local index = GetQuestLogSelection()
		if index and index > 0 then
			if C_QuestLog and C_QuestLog.GetInfo then
				local info = C_QuestLog.GetInfo(index)
				if info and info.questID and info.questID > 0 then return info.questID end
			end
			if GetQuestLogTitle then
				local id = select(8, GetQuestLogTitle(index))
				if id and id > 0 then return id end
			end
		end
	end
	return nil
end

-- Misión ficticia para /mes test y las vistas previas.
MES.TEST_QUEST_ID = -1
MES.testQuest = {
	title = "Misión de prueba",
	text = "Saludos, $N. Esta es una misión de ejemplo para comprobar cómo se ve la traducción junto al texto original.\n\nSi puedes leer esto, el addon funciona correctamente.",
	objectives = "Habla con el NPC de prueba.",
	progress = "¿Ya terminaste lo que te pedí?",
	completion = "¡Bien hecho, $C! Aquí tienes tu recompensa.",
	src = "ejemplo",
}
MES.testQuestEN = {
	title = "Test Quest",
	text = "Greetings, $N. This is a sample quest to check how the translation looks next to the original text.\n\nIf you can read this, the addon works correctly.",
	objectives = "Speak with the test NPC.",
}

-- Fuentes con tamaño configurable.
function MES.Fonts()
	if not MES.fonts then
		MES.fonts = {
			title = CreateFont("MisionesES_TitleFont"),
			header = CreateFont("MisionesES_HeaderFont"),
			text = CreateFont("MisionesES_TextFont"),
			small = CreateFont("MisionesES_SmallFont"),
		}
	end
	local size = MES.cfg and MES.cfg.fontSize or 13
	local base = (QuestFont and QuestFont:GetFont()) or STANDARD_TEXT_FONT
	local titleBase = (QuestTitleFont and QuestTitleFont:GetFont()) or base
	MES.fonts.title:SetFont(titleBase, size + 5, "")
	MES.fonts.header:SetFont(titleBase, size + 2, "")
	MES.fonts.text:SetFont(base, size, "")
	MES.fonts.small:SetFont(base, size - 2, "")
	return MES.fonts
end
