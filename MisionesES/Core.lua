-- MisionesES: núcleo compartido (configuración, normalización, hash y utilidades de texto)
local ADDON, MES = ...
_G.MisionesES = MES

MES.name = ADDON
MES.version = "0.2.0"
MES.DB = { quests = {}, gossip = {}, meta = {} }

MES.defaults = {
	setupDone = false,
	mode = "lateral",      -- "lateral" = panel junto a la ventana, "bilingue" = ventana única EN + ES
	fontSize = 13,
	showQuest = true,
	showQuestLog = true,
	showGossip = true,
	showOriginal = true,   -- ventana bilingüe: mostrar el inglés bajo cada párrafo (sello de lacre)
	collector = false,     -- solo para el mantenedor: captura textos EN que faltan
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

-- El addon traduce del inglés: con el cliente en otro idioma no muestra nada.
function MES.IsEnglishClient()
	local loc = GetLocale()
	return loc == "enUS" or loc == "enGB"
end

------------------------------------------------------------------------------------------------
-- Normalización y hash. Deben comportarse EXACTAMENTE igual que tools/normalize.py.
------------------------------------------------------------------------------------------------

-- djb2 de 32 bits en hexadecimal.
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

local function finish(s)
	s = s:gsub("[ \t\n\v\f\r]+", " ")
	s = s:gsub("^ ", ""):gsub(" $", "")
	return (s:lower())
end
MES.Finish = finish

local function replaceWord(s, word, token)
	if not word or word == "" then return s end
	return (s:gsub("%f[%a]" .. escapePattern(word:lower()) .. "%f[%A]", token))
end

-- Formas normalizadas del texto que muestra el juego:
--   1) solo el nombre del jugador sustituido por $n
--   2) además la clase y la raza por $c / $r
-- La base de datos se generó desde plantillas ($N, $C, $R), así que una de las dos coincide.
function MES.Keys(text)
	if not text or text == "" then return {} end
	local name = UnitName("player")
	if name and name ~= "" then
		text = text:gsub(escapePattern(name), "$n")
	end
	local nameOnly = finish(text)
	local full = replaceWord(nameOnly, UnitClass("player"), "$c")
	full = replaceWord(full, UnitRace("player"), "$r")
	if full == nameOnly then return { MES.Hash(nameOnly) } end
	return { MES.Hash(nameOnly), MES.Hash(full) }
end

-- Lo que guarda el recolector: el nombre del jugador pasa a ser $N para servir a cualquiera.
function MES.Normalize(text)
	if not text then return nil end
	text = text:gsub("^%s+", ""):gsub("%s+$", "")
	local name = UnitName("player")
	if name and name ~= "" then
		text = text:gsub(escapePattern(name), "$N")
	end
	return text
end

------------------------------------------------------------------------------------------------
-- Personalización del texto en español para el jugador actual.
------------------------------------------------------------------------------------------------

MES.classES = {
	WARRIOR = { "Guerrero", "Guerrera" }, MAGE = { "Mago", "Maga" }, PRIEST = { "Sacerdote", "Sacerdotisa" },
	ROGUE = { "Pícaro", "Pícara" }, DRUID = { "Druida", "Druida" }, HUNTER = { "Cazador", "Cazadora" },
	SHAMAN = { "Chamán", "Chamán" }, PALADIN = { "Paladín", "Paladín" }, WARLOCK = { "Brujo", "Bruja" },
}
MES.raceES = {
	Human = { "Humano", "Humana" }, Dwarf = { "Enano", "Enana" }, NightElf = { "Elfo de la noche", "Elfa de la noche" },
	Gnome = { "Gnomo", "Gnoma" }, Orc = { "Orco", "Orco" }, Scourge = { "No-muerto", "No-muerta" },
	Tauren = { "Tauren", "Tauren" }, Troll = { "Trol", "Trol" },
}

local function lowerFirst(s)
	return (s:gsub("^%u", string.lower))
end

function MES.Personalize(text)
	if not text then return nil end
	local female = UnitSex("player") == 3
	local g = female and 2 or 1
	local name = UnitName("player") or ""
	local className, classFile = UnitClass("player")
	local raceName, raceFile = UnitRace("player")
	className = MES.classES[classFile] and MES.classES[classFile][g] or className or ""
	raceName = MES.raceES[raceFile] and MES.raceES[raceFile][g] or raceName or ""
	text = text:gsub("%$[Gg]%s*([^:;]-)%s*:%s*([^;]-)%s*;", function(m, f) return female and f or m end)
	text = text:gsub("%$N", name):gsub("%$n", name)
	text = text:gsub("%$C", className):gsub("%$c", lowerFirst(className))
	text = text:gsub("%$R", raceName):gsub("%$r", lowerFirst(raceName))
	text = text:gsub("%$[Bb]", "\n")
	return text
end

------------------------------------------------------------------------------------------------
-- Utilidades del juego
------------------------------------------------------------------------------------------------

-- El cliente moderno quitó la global MouseIsOver: se usa el método del frame si existe.
function MES.IsMouseOver(frame)
	if frame.IsMouseOver then return frame:IsMouseOver() end
	return MouseIsOver and MouseIsOver(frame) or false
end

-- questID de la misión seleccionada en el registro (soporta API clásica y moderna).
function MES.SelectedLogQuestID()
	-- Registro moderno en el mapa (WoW Forever): el panel de detalle guarda el questID.
	local details = QuestMapFrame and QuestMapFrame.DetailsFrame
	if details and details.questID and details.questID > 0 and details:IsShown() then
		return details.questID
	end
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

function MES.GossipText()
	if C_GossipInfo and C_GossipInfo.GetText then return C_GossipInfo.GetText() end
	if GetGossipText then return GetGossipText() end
end

-- Fuentes con tamaño configurable. Títulos y encabezados en letra medieval (Morpheus), como los libros del juego.
local MORPHEUS = "Fonts\\MORPHEUS.TTF"
function MES.Fonts()
	if not MES.fonts then
		MES.fonts = {
			title = CreateFont("MisionesES_TitleFont"),
			header = CreateFont("MisionesES_HeaderFont"),
			text = CreateFont("MisionesES_TextFont"),
			small = CreateFont("MisionesES_SmallFont"),
			button = CreateFont("MisionesES_ButtonFont"),
		}
	end
	local size = MES.cfg and MES.cfg.fontSize or 13
	local base = (QuestFont and QuestFont:GetFont()) or STANDARD_TEXT_FONT
	MES.fonts.title:SetFont(MORPHEUS, size + 8, "")
	MES.fonts.header:SetFont(MORPHEUS, size + 3, "")
	MES.fonts.text:SetFont(base, size, "")
	MES.fonts.small:SetFont(base, size - 2, "")
	MES.fonts.button:SetFont(MORPHEUS, 15, "")
	for _, f in pairs(MES.fonts) do f:SetSpacing(2) end
	return MES.fonts
end
