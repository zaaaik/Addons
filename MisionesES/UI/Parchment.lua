-- Pergamino antiguo reutilizable: hoja envejecida con bordes rasgados, rollos opcionales arriba y abajo,
-- sello de lacre opcional y contenido por bloques con scroll (indicado por una pluma, sin barra).
local _, MES = ...

local TEX = "Interface\\AddOns\\MisionesES\\Textures\\"
MES.TEX = TEX

local PADDING = 28          -- margen interior, dentro de los bordes rasgados
local EDGE = 40             -- tamaño en pantalla de las esquinas del 9-slice
local EDGE_TC = 0.25        -- las esquinas ocupan 64 de 256 px del archivo
-- Colores como en la ventana de misión original: título y encabezados en negro, texto en sepia oscuro.
local INK = { 0.18, 0.12, 0.06 }
local INK_TITLE = { 0, 0, 0 }
local INK_SOFT = { 0.36, 0.26, 0.15 }   -- inglés original: algo más claro que el texto principal
local inkLoaded = false

local Parchment = {}

local function acquire(self, kind)
	self.used[kind] = (self.used[kind] or 0) + 1
	local pool = self.pool[kind]
	local obj = pool[self.used[kind]]
	if not obj then
		if kind == "sep" then
			obj = self.child:CreateTexture(nil, "ARTWORK")
			obj:SetTexture(TEX .. "divider_ink")
			obj:SetHeight(16)
		elseif kind == "reward" then
			obj = CreateFrame("Button", nil, self.child)
			obj:SetSize(44, 44)
			obj.icon = obj:CreateTexture(nil, "ARTWORK")
			obj.icon:SetPoint("CENTER")
			obj.icon:SetSize(30, 30)
			obj.frame = obj:CreateTexture(nil, "OVERLAY")
			obj.frame:SetAllPoints()
			obj.frame:SetTexture(TEX .. "reward_frame")
			obj.count = obj:CreateFontString(nil, "OVERLAY", "NumberFontNormal")
			obj.count:SetPoint("BOTTOMRIGHT", -6, 6)
			obj.label = obj:CreateFontString(nil, "OVERLAY")
			obj.label:SetPoint("LEFT", obj, "RIGHT", 4, 0)
			obj.label:SetJustifyH("LEFT")
			obj:SetScript("OnEnter", function(btn)
				if btn.questType and GameTooltip.SetQuestItem then
					GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
					GameTooltip:SetQuestItem(btn.questType, btn.questIndex)
					GameTooltip:Show()
				end
			end)
			obj:SetScript("OnLeave", function() GameTooltip:Hide() end)
		else
			obj = self.child:CreateFontString(nil, "ARTWORK")
			obj:SetJustifyV("TOP")
			if obj.SetWordWrap then obj:SetWordWrap(true) end
			if obj.SetNonSpaceWrap then obj:SetNonSpaceWrap(true) end
		end
		pool[self.used[kind]] = obj
	end
	obj:Show()
	return obj
end

local STYLE = {
	title = { font = "title", color = INK_TITLE, justify = "LEFT", after = 2 },
	subtitle = { font = "small", color = INK_SOFT, justify = "LEFT", after = 6 },
	header = { font = "header", color = INK_TITLE, justify = "LEFT", before = 6, after = 4 },
	text = { font = "text", color = INK, justify = "LEFT", after = 4 },
	original = { font = "small", color = INK_SOFT, justify = "LEFT", indent = 10, after = 10 },
	note = { font = "small", color = INK_SOFT, justify = "LEFT", after = 4 },
}

-- blocks: lista de { kind = "title"|"subtitle"|"header"|"text"|"original"|"note"|"sep"|"rewards", ... }
-- "rewards": { kind = "rewards", items = { {icon, name, count, questType, questIndex} }, extra = "texto" }
function Parchment:SetBlocks(blocks)
	local fonts = MES.Fonts()
	for _, pool in pairs(self.pool) do
		for _, obj in ipairs(pool) do obj:Hide() end
	end
	self.used = {}

	local width = self:GetWidth() - PADDING * 2 - 6
	self.child:SetWidth(width)

	local y = 0
	for _, b in ipairs(blocks) do
		if b.kind == "sep" then
			local t = acquire(self, "sep")
			y = y + 2
			t:ClearAllPoints()
			t:SetPoint("TOPLEFT", self.child, "TOPLEFT", 8, -y)
			t:SetPoint("TOPRIGHT", self.child, "TOPRIGHT", -8, -y)
			y = y + 20
		elseif b.kind == "rewards" then
			local col = 0
			for _, item in ipairs(b.items or {}) do
				local r = acquire(self, "reward")
				r.icon:SetTexture(item.icon)
				r.count:SetText((item.count or 1) > 1 and item.count or "")
				r.label:SetFontObject(fonts.small)
				r.label:SetTextColor(INK[1], INK[2], INK[3])
				r.label:SetWidth(width / 2 - 52)
				r.label:SetText(item.name)
				r.questType, r.questIndex = item.questType, item.questIndex
				r:ClearAllPoints()
				r:SetPoint("TOPLEFT", self.child, "TOPLEFT", col * (width / 2), -y)
				col = col + 1
				if col == 2 then col = 0; y = y + 48 end
			end
			if col == 1 then y = y + 48 end
			if b.extra and b.extra ~= "" then
				local fs = acquire(self, "fs")
				fs:SetFontObject(fonts.text)
				fs:SetTextColor(INK[1], INK[2], INK[3])
				fs:SetJustifyH("LEFT")
				fs:SetWidth(width)
				fs:SetText(b.extra)
				fs:ClearAllPoints()
				fs:SetPoint("TOPLEFT", self.child, "TOPLEFT", 0, -y)
				y = y + fs:GetStringHeight() + 6
			end
		elseif b.text and b.text ~= "" then
			local st = STYLE[b.kind] or STYLE.text
			local fs = acquire(self, "fs")
			y = y + (st.before or 0)
			local color = st.color
			if not inkLoaded then
				local text, title = MES.InkColors()
				INK[1], INK[2], INK[3] = text[1], text[2], text[3]
				INK_TITLE[1], INK_TITLE[2], INK_TITLE[3] = title[1], title[2], title[3]
				inkLoaded = true
			end
			fs:SetFontObject(fonts[st.font])
			fs:SetTextColor(color[1], color[2], color[3])
			fs:SetShadowOffset(0, 0)  -- como el original: sin sombra
			fs:SetJustifyH(st.justify)
			fs:SetWidth(width - (st.indent or 0))
			fs:SetText(b.text)
			fs:ClearAllPoints()
			fs:SetPoint("TOPLEFT", self.child, "TOPLEFT", st.indent or 0, -y)
			y = y + fs:GetStringHeight() + st.after
		end
	end
	self.contentHeight = y
	self.child:SetHeight(math.max(y, 1))
	self.scroll:SetVerticalScroll(0)
	self:UpdateQuill()
end

-- La flecha indica que queda texto por leer más abajo (y al pulsarla baja el texto).
function Parchment:UpdateQuill()
	local range = self.scroll:GetVerticalScrollRange() or 0
	local pos = self.scroll:GetVerticalScroll() or 0
	if range > 2 and pos < range - 2 then self.quill:Show() else self.quill:Hide() end
end

function Parchment:ScrollBy(delta)
	local range = self.scroll:GetVerticalScrollRange() or 0
	local pos = math.max(0, math.min(range, (self.scroll:GetVerticalScroll() or 0) + delta))
	self.scroll:SetVerticalScroll(pos)
	self:UpdateQuill()
end

-- Ajusta la altura del pergamino al contenido, entre minH y maxH.
function Parchment:FitHeight(minH, maxH)
	local h = (self.contentHeight or 0) + PADDING * 2 + self.sealSpace + self.topSpace * 2
	self:SetHeight(math.max(minH, math.min(maxH, h)))
	self:UpdateQuill()
end

-- Bordes rasgados: 9-slice de parchment_edges (esquinas fijas, lados estirados, centro vacío).
local function addEdges(f)
	local function piece(l, r, t, b)
		local tex = f:CreateTexture(nil, "BORDER")
		tex:SetTexture(TEX .. "parchment_edges")
		tex:SetTexCoord(l, r, t, b)
		return tex
	end
	local a, z = EDGE_TC, 1 - EDGE_TC
	local out = 6
	local tl, tr = piece(0, a, 0, a), piece(z, 1, 0, a)
	local bl, br = piece(0, a, z, 1), piece(z, 1, z, 1)
	for _, c in ipairs({ tl, tr, bl, br }) do c:SetSize(EDGE, EDGE) end
	tl:SetPoint("TOPLEFT", -out, out)
	tr:SetPoint("TOPRIGHT", out, out)
	bl:SetPoint("BOTTOMLEFT", -out, -out)
	br:SetPoint("BOTTOMRIGHT", out, -out)
	local top, bottom = piece(a, z, 0, a), piece(a, z, z, 1)
	top:SetPoint("TOPLEFT", tl, "TOPRIGHT"); top:SetPoint("BOTTOMRIGHT", tr, "BOTTOMLEFT")
	bottom:SetPoint("TOPLEFT", bl, "TOPRIGHT"); bottom:SetPoint("BOTTOMRIGHT", br, "BOTTOMLEFT")
	local left, right = piece(0, a, a, z), piece(z, 1, a, z)
	left:SetPoint("TOPLEFT", tl, "BOTTOMLEFT"); left:SetPoint("BOTTOMRIGHT", bl, "TOPRIGHT")
	right:SetPoint("TOPLEFT", tr, "BOTTOMLEFT"); right:SetPoint("BOTTOMRIGHT", br, "TOPRIGHT")
end

local function addRolls(f)
	local top = f:CreateTexture(nil, "OVERLAY")
	top:SetTexture(TEX .. "scroll_top")
	top:SetHeight(42)
	top:SetPoint("BOTTOMLEFT", f, "TOPLEFT", -22, -16)
	top:SetPoint("BOTTOMRIGHT", f, "TOPRIGHT", 22, -16)
	local bottom = f:CreateTexture(nil, "OVERLAY")
	bottom:SetTexture(TEX .. "scroll_bottom")
	bottom:SetHeight(42)
	bottom:SetPoint("TOPLEFT", f, "BOTTOMLEFT", -22, 16)
	bottom:SetPoint("TOPRIGHT", f, "BOTTOMRIGHT", 22, 16)
end

-- opts: { rolls = true, seal = function() end, sealTooltip = "..." }
function MES.CreateParchment(name, parent, width, height, opts)
	opts = opts or {}
	local f = CreateFrame("Frame", name, parent or UIParent)
	f:SetSize(width or 320, height or 420)
	f:SetFrameStrata("HIGH")
	f:SetClampedToScreen(true)
	f:EnableMouse(true)

	local bg = f:CreateTexture(nil, "BACKGROUND")
	bg:SetTexture(TEX .. "parchment_old")
	bg:SetPoint("TOPLEFT", 4, -4)
	bg:SetPoint("BOTTOMRIGHT", -4, 4)
	addEdges(f)
	if opts.rolls then addRolls(f) end

	-- Con rollos, el de arriba invade la hoja: el contenido empieza más abajo para no tapar el título.
	f.topSpace = opts.rolls and 14 or 0
	local scroll = CreateFrame("ScrollFrame", nil, f)
	scroll:SetPoint("TOPLEFT", PADDING, -PADDING - f.topSpace)
	scroll:SetPoint("BOTTOMRIGHT", -PADDING + 6, PADDING + f.topSpace)  -- el rollo de abajo también invade
	local child = CreateFrame("Frame", nil, scroll)
	child:SetSize(1, 1)
	scroll:SetScrollChild(child)
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(_, delta) f:ScrollBy(-delta * 30) end)

	-- Flecha "hay más texto": en la esquina inferior derecha del área de texto, con un leve vaivén.
	local quill = CreateFrame("Button", nil, f)
	quill:SetSize(26, 26)
	quill:SetPoint("BOTTOMRIGHT", scroll, "BOTTOMRIGHT", 4, 6)
	quill:SetFrameLevel(scroll:GetFrameLevel() + 5)
	quill:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
	quill:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
	quill:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	quill:SetScript("OnClick", function() f:ScrollBy(60) end)
	if quill.CreateAnimationGroup then
		local bob = quill:CreateAnimationGroup()
		local down = bob:CreateAnimation("Translation")
		down:SetOffset(0, -3); down:SetDuration(0.6); down:SetOrder(1)
		local up = bob:CreateAnimation("Translation")
		up:SetOffset(0, 3); up:SetDuration(0.6); up:SetOrder(2)
		bob:SetLooping("REPEAT")
		quill:SetScript("OnShow", function() bob:Play() end)
		quill:SetScript("OnHide", function() bob:Stop() end)
	end
	quill:Hide()

	f.sealSpace = opts.seal and 6 or 0
	if opts.seal then
		local seal = CreateFrame("Button", nil, f)
		seal:SetSize(40, 40)
		seal:SetPoint("TOPRIGHT", -8, -6)
		seal:SetFrameLevel(f:GetFrameLevel() + 5)
		seal:SetNormalTexture(TEX .. "wax_seal")
		seal:SetHighlightTexture(TEX .. "wax_seal_hover")
		seal:SetScript("OnClick", opts.seal)
		seal:SetScript("OnEnter", function(btn)
			GameTooltip:SetOwner(btn, "ANCHOR_RIGHT")
			GameTooltip:SetText(opts.sealTooltip or "")
			GameTooltip:Show()
		end)
		seal:SetScript("OnLeave", function() GameTooltip:Hide() end)
		f.seal = seal
	end

	f.scroll, f.child, f.quill = scroll, child, quill
	f.pool = { fs = {}, sep = {}, reward = {} }
	f.used = {}
	for k, v in pairs(Parchment) do f[k] = v end
	f:Hide()
	return f
end

-- Botón de cinta (roja = acción principal, marrón = secundaria).
function MES.CreateRibbonButton(parent, color)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(160, 40)
	b:SetNormalTexture(TEX .. "ribbon_" .. color)
	b:SetHighlightTexture(TEX .. "ribbon_" .. color .. "_hover")
	local fs = b:CreateFontString(nil, "OVERLAY")
	fs:SetPoint("CENTER", 0, 2)
	fs:SetFontObject(MES.Fonts().button)
	fs:SetTextColor(1, 0.87, 0.6)
	fs:SetShadowOffset(1, -1)
	b:SetFontString(fs)
	b:SetScript("OnDisable", function(btn)
		local t = btn:GetNormalTexture()
		if t and t.SetDesaturated then t:SetDesaturated(true) end
		fs:SetTextColor(0.6, 0.55, 0.5)
	end)
	b:SetScript("OnEnable", function(btn)
		local t = btn:GetNormalTexture()
		if t and t.SetDesaturated then t:SetDesaturated(false) end
		fs:SetTextColor(1, 0.87, 0.6)
	end)
	return b
end
