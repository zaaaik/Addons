-- Controles de configuración compartidos por el asistente inicial y el panel de Opciones.
local _, MES = ...

local function label(parent, text, font)
	local fs = parent:CreateFontString(nil, "ARTWORK", font or "GameFontHighlight")
	fs:SetJustifyH("LEFT")
	fs:SetText(text)
	return fs
end

local function check(parent, text, key, y)
	local cb = CreateFrame("CheckButton", nil, parent, "UICheckButtonTemplate")
	cb:SetPoint("TOPLEFT", 16, y)
	local fs = label(parent, text)
	fs:SetPoint("LEFT", cb, "RIGHT", 4, 0)
	cb:SetScript("OnClick", function(self) MES.cfg[key] = self:GetChecked() and true or false end)
	cb.Refresh = function() cb:SetChecked(MES.cfg[key]) end
	return cb
end

-- Tarjeta seleccionable de modo con una pequeña vista previa.
local function modeCard(parent, mode, title, desc, x, y)
	local card = CreateFrame("Button", nil, parent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	card:SetSize(200, 150)
	card:SetPoint("TOPLEFT", x, y)
	if card.SetBackdrop then
		card:SetBackdrop({
			bgFile = "Interface\\Tooltips\\UI-Tooltip-Background",
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 14, insets = { left = 3, right = 3, top = 3, bottom = 3 },
		})
		card:SetBackdropColor(0, 0, 0, 0.6)
	end
	-- Vista previa: rectángulos que imitan la disposición de cada modo.
	local function box(px, py, w, h, r, g, b)
		local t = card:CreateTexture(nil, "ARTWORK")
		t:SetColorTexture(r, g, b, 1)
		t:SetPoint("TOPLEFT", px, py)
		t:SetSize(w, h)
	end
	if mode == "lateral" then
		box(30, -14, 64, 80, 0.55, 0.45, 0.30)
		box(102, -18, 64, 72, 0.87, 0.78, 0.60)
	else
		box(60, -14, 80, 80, 0.87, 0.78, 0.60)
		for i = 0, 3 do
			box(68, -24 - i * 16, 64, 4, 0.18, 0.11, 0.04)
			box(68, -31 - i * 16, 48, 3, 0.45, 0.35, 0.20)
		end
	end
	local t = label(card, title, "GameFontNormal")
	t:SetPoint("TOPLEFT", 10, -100)
	local d = label(card, desc, "GameFontHighlightSmall")
	d:SetPoint("TOPLEFT", 10, -116)
	d:SetWidth(180)
	card:SetScript("OnClick", function()
		MES.cfg.mode = mode
		parent:RefreshControls()
	end)
	card.Refresh = function()
		if card.SetBackdropBorderColor then
			if MES.cfg.mode == mode then card:SetBackdropBorderColor(1, 0.82, 0, 1)
			else card:SetBackdropBorderColor(0.4, 0.4, 0.4, 1) end
		end
	end
	return card
end

-- Construye todos los controles en parent a partir de la coordenada y. Devuelve la y final.
function MES.BuildControls(parent, y)
	local controls = {}
	local h = label(parent, "Modo de visualización", "GameFontNormalLarge")
	h:SetPoint("TOPLEFT", 16, y)
	y = y - 26
	controls[#controls + 1] = modeCard(parent, "lateral", "Panel lateral",
		"Ventana original + traducción al lado.", 16, y)
	controls[#controls + 1] = modeCard(parent, "bilingue", "Ventana bilingüe",
		"Una sola ventana con inglés y español.", 228, y)
	y = y - 162

	local fs = label(parent, "")
	fs:SetPoint("TOPLEFT", 16, y - 4)
	local minus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	minus:SetSize(28, 22)
	minus:SetPoint("TOPLEFT", 200, y)
	minus:SetText("-")
	local plus = CreateFrame("Button", nil, parent, "UIPanelButtonTemplate")
	plus:SetSize(28, 22)
	plus:SetPoint("LEFT", minus, "RIGHT", 4, 0)
	plus:SetText("+")
	local function setSize(delta)
		MES.cfg.fontSize = math.max(10, math.min(20, MES.cfg.fontSize + delta))
		MES.Fonts()
		parent:RefreshControls()
	end
	minus:SetScript("OnClick", function() setSize(-1) end)
	plus:SetScript("OnClick", function() setSize(1) end)
	fs.Refresh = function() fs:SetText(("Tamaño de letra: %d"):format(MES.cfg.fontSize)) end
	controls[#controls + 1] = fs
	y = y - 34

	controls[#controls + 1] = check(parent, "Traducir ventanas de misión", "showQuest", y); y = y - 28
	controls[#controls + 1] = check(parent, "Traducir registro de misiones (al pasar el ratón)", "showQuestLog", y); y = y - 28
	controls[#controls + 1] = check(parent, "Traducir diálogos de NPC", "showGossip", y); y = y - 28

	parent.RefreshControls = function()
		for _, c in ipairs(controls) do c.Refresh() end
	end
	parent:RefreshControls()
	return y
end

function MES.InitOptions()
	local panel = CreateFrame("Frame")
	panel.name = "MisionesES"
	local title = panel:CreateFontString(nil, "ARTWORK", "GameFontNormalHuge")
	title:SetPoint("TOPLEFT", 16, -16)
	title:SetText("MisionesES")
	local y = MES.BuildControls(panel, -56)

	local again = CreateFrame("Button", nil, panel, "UIPanelButtonTemplate")
	again:SetSize(200, 24)
	again:SetPoint("TOPLEFT", 16, y - 10)
	again:SetText("Repetir asistente inicial")
	again:SetScript("OnClick", function()
		if SettingsPanel and SettingsPanel:IsShown() then HideUIPanel(SettingsPanel) end
		if InterfaceOptionsFrame and InterfaceOptionsFrame:IsShown() then InterfaceOptionsFrame:Hide() end
		MES.ShowSetup()
	end)
	panel:SetScript("OnShow", function() panel:RefreshControls() end)

	if Settings and Settings.RegisterCanvasLayoutCategory then
		local category = Settings.RegisterCanvasLayoutCategory(panel, panel.name)
		Settings.RegisterAddOnCategory(category)
		MES.settingsCategory = category
	elseif InterfaceOptions_AddCategory then
		InterfaceOptions_AddCategory(panel)
	end
	MES.optionsPanel = panel
end

function MES.OpenOptions()
	if MES.settingsCategory and Settings and Settings.OpenToCategory then
		Settings.OpenToCategory(MES.settingsCategory:GetID())
	elseif InterfaceOptionsFrame_OpenToCategory then
		InterfaceOptionsFrame_OpenToCategory(MES.optionsPanel)
		InterfaceOptionsFrame_OpenToCategory(MES.optionsPanel)
	end
end
