-- Pergamino reutilizable con scroll: muestra bloques de título, cabecera, texto y separador.
local _, MES = ...

local PADDING = 16
local INK = { 0.18, 0.11, 0.04 }
local INK_SOFT = { 0.36, 0.25, 0.12 }

local Parchment = {}

local function acquire(self, kind)
	self.used[kind] = (self.used[kind] or 0) + 1
	local pool = self.pool[kind]
	local obj = pool[self.used[kind]]
	if not obj then
		if kind == "sep" then
			obj = self.child:CreateTexture(nil, "ARTWORK")
			obj:SetColorTexture(INK_SOFT[1], INK_SOFT[2], INK_SOFT[3], 0.5)
			obj:SetHeight(1)
		else
			obj = self.child:CreateFontString(nil, "ARTWORK")
			obj:SetJustifyH("LEFT")
			obj:SetJustifyV("TOP")
			if obj.SetWordWrap then obj:SetWordWrap(true) end
			if obj.SetNonSpaceWrap then obj:SetNonSpaceWrap(true) end
		end
		pool[self.used[kind]] = obj
	end
	obj:Show()
	return obj
end

-- blocks: lista de { kind = "title"|"header"|"text"|"original"|"sep", text = "..." }
function Parchment:SetBlocks(blocks)
	local fonts = MES.Fonts()
	for _, pool in pairs(self.pool) do
		for _, obj in ipairs(pool) do obj:Hide() end
	end
	self.used = {}

	local width = self.scroll:GetWidth()
	if not width or width < 50 then width = self:GetWidth() - PADDING * 2 - 22 end
	self.child:SetWidth(width)

	local y = 0
	for _, b in ipairs(blocks) do
		if b.kind == "sep" then
			local t = acquire(self, "sep")
			y = y + 6
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", self.child, "TOPLEFT", 10, -y)
			t:SetPoint("TOPRIGHT", self.child, "TOPRIGHT", -10, -y)
			y = y + 8
		elseif b.text and b.text ~= "" then
			local fs = acquire(self, "fs")
			local font, color = fonts.text, INK
			if b.kind == "title" then
				font = fonts.title
				fs:SetJustifyH("CENTER")
			else
				fs:SetJustifyH("LEFT")
				if b.kind == "header" then font = fonts.header
				elseif b.kind == "original" then font, color = fonts.small, INK_SOFT end
			end
			fs:SetFontObject(font)
			fs:SetTextColor(color[1], color[2], color[3])
			fs:SetWidth(width)
			fs:SetText(b.text)
			fs:ClearAllPoints()
			fs:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -y)
			y = y + fs:GetStringHeight() + (b.kind == "title" and 12 or 10)
		end
	end
	self.contentHeight = y
	self.child:SetHeight(math.max(y, 1))
	self.scroll:SetVerticalScroll(0)
end

-- Ajusta la altura del pergamino al contenido, entre minH y maxH.
function Parchment:FitHeight(minH, maxH)
	local h = (self.contentHeight or 0) + PADDING * 2 + 6
	self:SetHeight(math.max(minH, math.min(maxH, h)))
end

function MES.CreateParchment(name, parent, width, height)
	local f = CreateFrame("Frame", name, parent or UIParent, BackdropTemplateMixin and "BackdropTemplate" or nil)
	f:SetSize(width or 320, height or 420)
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)

	-- Fondo color pergamino uniforme (las texturas de misión no cubren bien un marco de tamaño variable).
	local base = f:CreateTexture(nil, "BACKGROUND", nil, -8)
	base:SetPoint("TOPLEFT", 4, -4)
	base:SetPoint("BOTTOMRIGHT", -4, 4)
	base:SetColorTexture(0.89, 0.81, 0.64, 1)
	if f.SetBackdrop then
		f:SetBackdrop({
			edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",
			edgeSize = 16,
			insets = { left = 4, right = 4, top = 4, bottom = 4 },
		})
		f:SetBackdropBorderColor(0.45, 0.32, 0.16, 1)
	end

	local scroll = CreateFrame("ScrollFrame", name and (name .. "Scroll") or nil, f, "UIPanelScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", PADDING, -PADDING)
	scroll:SetPoint("BOTTOMRIGHT", -PADDING - 18, PADDING)
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)

	f.scroll, f.child = scroll, child
	f.pool = { fs = {}, sep = {} }
	f.used = {}
	for k, v in pairs(Parchment) do f[k] = v end
	f:Hide()
	return f
end
