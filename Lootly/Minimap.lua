local ADDON, NS = ...
local L = NS.L
local M = {}
NS.Minimap = M

local btn

local function place()
  local angle = math.rad(NS.db.minimap.angle)
  local r = Minimap:GetWidth() / 2 + 5
  btn:ClearAllPoints()
  btn:SetPoint("CENTER", Minimap, "CENTER", math.cos(angle) * r, math.sin(angle) * r)
end

local function onDrag()
  local mx, my = Minimap:GetCenter()
  local px, py = GetCursorPosition()
  local sc = Minimap:GetEffectiveScale()
  local atan = math.atan2 or math.atan
  NS.db.minimap.angle = math.deg(atan(py / sc - my, px / sc - mx))
  place()
end

function M:Refresh()
  if not btn then return end
  btn:SetShown(not NS.db.minimap.hide)
  place()
end

function M:Init()
  btn = CreateFrame("Button", "LootlyMinimapButton", Minimap)
  btn:SetSize(31, 31)
  btn:SetFrameStrata("MEDIUM")
  btn:SetFrameLevel(8)
  btn:RegisterForClicks("LeftButtonUp", "RightButtonUp")
  btn:RegisterForDrag("LeftButton")
  btn:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

  local bg = btn:CreateTexture(nil, "BACKGROUND")
  bg:SetSize(20, 20)
  bg:SetPoint("TOPLEFT", 7, -5)
  bg:SetTexture("Interface\\Minimap\\UI-Minimap-Background")
  local icon = btn:CreateTexture(nil, "ARTWORK")
  icon:SetSize(17, 17)
  icon:SetPoint("TOPLEFT", 7, -6)
  icon:SetTexture("Interface\\Icons\\INV_Box_01")
  icon:SetTexCoord(0.05, 0.95, 0.05, 0.95)
  local border = btn:CreateTexture(nil, "OVERLAY")
  border:SetSize(53, 53)
  border:SetPoint("TOPLEFT")
  border:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")

  btn:SetScript("OnClick", function(_, b)
    if b == "RightButton" then
      NS.Display:SetLocked(not NS.db.locked)
    else
      NS.Config:Toggle()
    end
  end)
  btn:SetScript("OnDragStart", function(self) self:SetScript("OnUpdate", onDrag) end)
  btn:SetScript("OnDragStop", function(self) self:SetScript("OnUpdate", nil) end)
  btn:SetScript("OnEnter", function(self)
    GameTooltip:SetOwner(self, "ANCHOR_LEFT")
    GameTooltip:AddLine("Lootly")
    GameTooltip:AddLine(L["Left-click: settings"], 1, 1, 1)
    GameTooltip:AddLine(L["Right-click: move loot position"], 1, 1, 1)
    GameTooltip:Show()
  end)
  btn:SetScript("OnLeave", GameTooltip_Hide)
  self:Refresh()
end
