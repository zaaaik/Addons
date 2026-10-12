-- Asistente de primer inicio: elegir modo y preferencias. Se puede repetir desde Opciones.
local _, MES = ...

local wizard

local function create()
	wizard = CreateFrame("Frame", "MisionesES_Setup", UIParent, "BasicFrameTemplateWithInset")
	wizard:SetSize(460, 420)
	wizard:SetPoint("CENTER")
	wizard:SetFrameStrata("DIALOG")
	wizard:SetMovable(true)
	wizard:EnableMouse(true)
	wizard:RegisterForDrag("LeftButton")
	wizard:SetScript("OnDragStart", wizard.StartMoving)
	wizard:SetScript("OnDragStop", wizard.StopMovingOrSizing)
	tinsert(UISpecialFrames, "MisionesES_Setup")

	local title = wizard.TitleText or wizard:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
	if not wizard.TitleText then title:SetPoint("TOP", 0, -5) end
	title:SetText("MisionesES - Configuración inicial")

	local intro = wizard:CreateFontString(nil, "ARTWORK", "GameFontHighlight")
	intro:SetPoint("TOPLEFT", 16, -34)
	intro:SetWidth(428)
	intro:SetJustifyH("LEFT")
	intro:SetText("Elige cómo quieres ver las traducciones. Podrás cambiarlo cuando quieras en Opciones > AddOns > MisionesES o con /mes config.")

	local y = MES.BuildControls(wizard, -72)

	local preview = CreateFrame("Button", nil, wizard, "UIPanelButtonTemplate")
	preview:SetSize(130, 24)
	preview:SetPoint("BOTTOMLEFT", 16, 14)
	preview:SetText("Vista previa")
	preview:SetScript("OnClick", function() MES.ShowTest() end)

	local save = CreateFrame("Button", nil, wizard, "UIPanelButtonTemplate")
	save:SetSize(130, 24)
	save:SetPoint("BOTTOMRIGHT", -16, 14)
	save:SetText("Guardar")
	save:SetScript("OnClick", function()
		MES.cfg.setupDone = true
		wizard:Hide()
		MES.HideTest()
		MES.Print("Configuración guardada. Usa /mes config para cambiarla.")
	end)
	wizard:SetScript("OnHide", function()
		if not MES.cfg.setupDone then
			MES.cfg.setupDone = true
			MES.Print("Se usarán las opciones por defecto. Usa /mes config para cambiarlas.")
		end
	end)
	wizard:SetHeight(-y + 60)
	return wizard
end

function MES.ShowSetup()
	wizard = wizard or create()
	wizard:RefreshControls()
	wizard:Show()
end
