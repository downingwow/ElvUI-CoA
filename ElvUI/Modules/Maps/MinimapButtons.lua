local E, L, V, P, G = unpack(select(2, ...))
local MB = E:NewModule("MinimapButtons", "AceTimer-3.0")

local _G = _G
local pairs, ipairs, select, type = pairs, ipairs, select, type
local ceil = math.ceil
local find, len, sub = string.find, string.len, string.sub
local tinsert, sort = table.insert, table.sort
local unpack = unpack

local CreateFrame = CreateFrame
local UIFrameFadeIn = UIFrameFadeIn
local UIFrameFadeOut = UIFrameFadeOut

local ignoreButtons = {
	ElvConfigToggle = true,
	BattlefieldMinimap = true,
	ButtonCollectFrame = true,
	GameTimeFrame = true,
	MiniMapBattlefieldFrame = true,
	MiniMapLFGFrame = true,
	MiniMapMailFrame = true,
	MiniMapPing = true,
	MiniMapRecordingButton = true,
	MiniMapTracking = true,
	MiniMapTrackingButton = true,
	MiniMapVoiceChatFrame = true,
	MiniMapWorldMapButton = true,
	Minimap = true,
	MinimapBackdrop = true,
	MinimapToggleButton = true,
	MinimapZoneTextButton = true,
	MinimapZoomIn = true,
	MinimapZoomOut = true,
	TimeManagerClockButton = true,
}

local genericIgnores = {
	"GuildInstance",
	"GatherMatePin",
	"GatherNote",
	"GuildMap3Mini",
	"HandyNotesPin",
	"LibRockConfig-1.0_MinimapButton",
	"NauticusMiniIcon",
	"WestPointer",
	"poiMinimap",
	"Spy_MapNoteList_mini",
}

local partialIgnores = {
	"Node",
	"Note",
	"Pin",
}

local whiteList = {
	"LibDBIcon",
}

local buttonFunctions = {
	"SetParent",
	"SetFrameStrata",
	"SetFrameLevel",
	"ClearAllPoints",
	"SetPoint",
	"SetScale",
	"SetSize",
	"SetWidth",
	"SetHeight",
}

local function MouseOverEnter()
	if not MB.frame then return end
	local db = MB:GetDB()
	if not db or not db.mouseover then return end
	UIFrameFadeIn(MB.frame, 0.1, MB.frame:GetAlpha(), db.alpha or 1)
end

local function MouseOverLeave()
	if not MB.frame then return end
	local db = MB:GetDB()
	if not db or not db.mouseover then return end
	UIFrameFadeOut(MB.frame, 0.15, MB.frame:GetAlpha(), 0)
end

function MB:GetDB()
	return E.db and E.db.general and E.db.general.minimap and E.db.general.minimap.buttonFrame
end

function MB:RefreshShadow()
	local S = E:GetModule("Skins", true)
	if S and S.Initialized and S.UpdateFrameShadow then
		S:UpdateFrameShadow("minimapbuttonbar")
	end
end

function MB:LockButton(button)
	for _, func in ipairs(buttonFunctions) do
		button[func] = E.noop
	end
end

function MB:UnlockButton(button)
	for _, func in ipairs(buttonFunctions) do
		button[func] = nil
	end
end

function MB:IsValidButton(button)
	if not button or not button.IsObjectType or not button:IsObjectType("Button") then return false end
	local name = button:GetName()
	if not name then return false end

	local validIcon
	for i = 1, #whiteList do
		if sub(name, 1, len(whiteList[i])) == whiteList[i] then
			validIcon = true
			break
		end
	end

	if not validIcon then
		if ignoreButtons[name] then return false end
		for i = 1, #genericIgnores do
			if sub(name, 1, len(genericIgnores[i])) == genericIgnores[i] then return false end
		end
		for i = 1, #partialIgnores do
			if find(name, partialIgnores[i]) then return false end
		end
	end

	return true
end

function MB:SkinMinimapButton(button)
	if not self:IsValidButton(button) or button.__ElvUI_MinimapButtonFrame then return end

	local name = button:GetName()
	button:SetPushedTexture(nil)
	button:SetHighlightTexture(nil)
	button:SetDisabledTexture(nil)

	for i = 1, button:GetNumRegions() do
		local region = select(i, button:GetRegions())
		if region and region.GetObjectType and region:GetObjectType() == "Texture" then
			local texture = region:GetTexture()
			local textureName = type(texture) == "string" and texture or ""

			if textureName ~= "" and (find(textureName, "Border") or find(textureName, "Background") or find(textureName, "AlphaMask")) then
				region:SetTexture(nil)
			else
				if name == "BagSync_MinimapButton" then
					region:SetTexture("Interface\\AddOns\\BagSync\\media\\icon")
			elseif name == "DBMMinimapButton" then
					region:SetTexture("Interface\\Icons\\INV_Helmet_87")
			elseif name == "OutfitterMinimapButton" and textureName == "Interface\\Addons\\Outfitter\\Textures\\MinimapButton" then
					region:SetTexture(nil)
			elseif name == "SmartBuff_MiniMapButton" then
					region:SetTexture("Interface\\Icons\\Spell_Nature_Purge")
			elseif name == "VendomaticButtonFrame" then
					region:SetTexture("Interface\\Icons\\INV_Misc_Rabbit_2")
			end

				if region:GetTexture() then
					region:ClearAllPoints()
					region:SetPoint("TOPLEFT", button, "TOPLEFT", E.Border, -E.Border)
					region:SetPoint("BOTTOMRIGHT", button, "BOTTOMRIGHT", -E.Border, E.Border)
					region:SetTexCoord(unpack(E.TexCoords))
					region:SetDrawLayer("ARTWORK")
					if not region.__ElvUI_MinimapButtonFrameLocked then
						region.__ElvUI_MinimapButtonFrameLocked = true
						region.SetPoint = E.noop
					end
				end
			end
		end
	end

	button:SetParent(self.frame)
	button:SetFrameLevel(self.frame:GetFrameLevel() + 5)
	button:SetScale(1)
	button:SetTemplate("Default", true)

	button:SetScript("OnDragStart", nil)
	button:SetScript("OnDragStop", nil)

	if not button.__ElvUI_MinimapButtonFrameMouseoverHook then
		button.__ElvUI_MinimapButtonFrameMouseoverHook = true
		button:HookScript("OnEnter", MouseOverEnter)
		button:HookScript("OnLeave", MouseOverLeave)
	end

	button.__ElvUI_MinimapButtonFrame = true
	button.__hidden = not button:IsVisible()
	tinsert(self.buttons, button)
	self.needUpdate = true
end

function MB:ScanButtons()
	if not self.active or not self.frame then return end

	for _, parent in ipairs(self.scanFrames) do
		if parent and parent.GetNumChildren then
			for i = 1, parent:GetNumChildren() do
				local object = select(i, parent:GetChildren())
				if object then self:SkinMinimapButton(object) end
			end
		end
	end

	-- A few older addons create their minimap buttons outside Minimap.
	if _G.AtlasButtonFrame and _G.AtlasButton then self:SkinMinimapButton(_G.AtlasButton) end
	if _G.FishingBuddyMinimapFrame and _G.FishingBuddyMinimapButton then self:SkinMinimapButton(_G.FishingBuddyMinimapButton) end
	if _G.HealBot_MMButton then self:SkinMinimapButton(_G.HealBot_MMButton) end

	if self.needUpdate or self:CheckVisibility() then
		self:UpdateLayout()
	end
end

function MB:CheckVisibility()
	local changed
	for _, button in ipairs(self.buttons) do
		local hidden = not button:IsVisible()
		if button.__hidden ~= hidden then
			button.__hidden = hidden
			changed = true
		end
	end
	return changed
end

function MB:GetVisibleButtons()
	local list = {}
	for _, button in ipairs(self.buttons) do
		if button:IsVisible() then tinsert(list, button) end
	end

	local db = self:GetDB()
	if db and db.sortOrder == "NAME" then
		sort(list, function(a, b)
			return (a:GetName() or "") < (b:GetName() or "")
		end)
	end

	return list
end

function MB:UpdateBackdrop()
	if not self.frame or not self.frame.backdrop then return end
	local db = self:GetDB()
	if not db then return end

	local padding = db.backdropSpacing or 3
	self.frame.backdrop:ClearAllPoints()
	self.frame.backdrop:SetPoint("TOPLEFT", self.frame, "TOPLEFT", -padding, padding)
	self.frame.backdrop:SetPoint("BOTTOMRIGHT", self.frame, "BOTTOMRIGHT", padding, -padding)

	if db.backdrop then self.frame.backdrop:Show() else self.frame.backdrop:Hide() end
end

function MB:UpdateLayout()
	if not self.frame then return end
	local db = self:GetDB()
	if not db then return end

	local visible = self:GetVisibleButtons()
	local count = #visible
	local size = db.buttonSize or 24
	local gap = db.buttonSpacing or 2
	local perRow = db.buttonsPerRow or 8
	if perRow < 1 then perRow = 1 end
	if count > 0 and perRow > count then perRow = count end

	if count == 0 then
		self.frame:Size(size, size)
		if self.frame.mover then self.frame.mover:Size(size, size) end
		if db.backdrop and not db.hideBackdropWhenEmpty then self.frame.backdrop:Show() else self.frame.backdrop:Hide() end
		self:RefreshShadow()
		self.needUpdate = false
		return
	end

	local rows = ceil(count / perRow)
	local width = (size * perRow) + (gap * (perRow - 1))
	local height = (size * rows) + (gap * (rows - 1))
	self.frame:Size(width, height)
	if self.frame.mover then self.frame.mover:Size(width, height) end
	self:UpdateBackdrop()

	local growFrom = db.growFrom or "TOPLEFT"
	local verticalGrowth = (growFrom == "TOPLEFT" or growFrom == "TOPRIGHT") and "DOWN" or "UP"
	local horizontalGrowth = (growFrom == "TOPLEFT" or growFrom == "BOTTOMLEFT") and "RIGHT" or "LEFT"

	for i, button in ipairs(visible) do
		self:UnlockButton(button)
		button:SetFrameStrata(self.frame:GetFrameStrata())
		button:SetFrameLevel(self.frame:GetFrameLevel() + 5)
		button:Size(size)
		button:ClearAllPoints()

		if i == 1 then
			button:Point(growFrom, self.frame, growFrom, 0, 0)
		elseif (i - 1) % perRow == 0 then
			if verticalGrowth == "DOWN" then
				button:Point("TOP", visible[i - perRow], "BOTTOM", 0, -gap)
			else
				button:Point("BOTTOM", visible[i - perRow], "TOP", 0, gap)
			end
		elseif horizontalGrowth == "RIGHT" then
			button:Point("LEFT", visible[i - 1], "RIGHT", gap, 0)
		else
			button:Point("RIGHT", visible[i - 1], "LEFT", -gap, 0)
		end

		self:LockButton(button)
	end

	self.needUpdate = false
	self:RefreshShadow()
end

function MB:UpdatePosition()
	if not self.frame then return end
	local db = self:GetDB()
	if not db then return end

	self.frame:ClearAllPoints()
	if db.anchorToMinimap and _G.Minimap then
		local point = db.anchorPoint or "TOPRIGHT"
		self.frame:Point(point, _G.Minimap, point, db.xOffset or 0, db.yOffset or 0)
		if self.frame.mover then E:DisableMover(self.frame.mover:GetName()) end
	else
		self.frame:SetAllPoints(self.frame.mover)
		if self.frame.mover then E:EnableMover(self.frame.mover:GetName()) end
	end
	self:RefreshShadow()
end

function MB:UpdateAlpha()
	if not self.frame then return end
	local db = self:GetDB()
	if not db then return end
	if db.mouseover then self.frame:SetAlpha(0) else self.frame:SetAlpha(db.alpha or 1) end
end

function MB:UpdateSettings()
	if not self.active then return end
	local db = self:GetDB()
	if db and self.frame then self.frame:SetFrameStrata(db.frameStrata or "LOW") end
	self:UpdateAlpha()
	self:UpdatePosition()
	self:UpdateLayout()
end

function MB:Initialize()
	local db = self:GetDB()
	if not db or not db.enable then return end

	self.buttons = {}
	self.scanFrames = {_G.Minimap, _G.MinimapBackdrop}
	self.active = true

	self.frame = CreateFrame("Frame", "ElvUI_MinimapButtonFrame", E.UIParent)
	self.frame:Size(db.buttonSize or 24)
	self.frame:SetFrameStrata(db.frameStrata or "LOW")
	self.frame:SetClampedToScreen(true)
	self.frame:EnableMouse(true)
	self.frame:CreateBackdrop("Default", true)
	self.frame.backdrop:Hide()
	self.frame:HookScript("OnEnter", MouseOverEnter)
	self.frame:HookScript("OnLeave", MouseOverLeave)

	local defaultAnchor = _G.MMHolder or _G.Minimap
	if defaultAnchor then self.frame:Point("TOPRIGHT", defaultAnchor, "BOTTOMRIGHT", 0, -4) end

	E:CreateMover(self.frame, "MinimapButtonFrameMover", "Minimap Button Frame", nil, nil, nil, "ALL,GENERAL", nil, "maps,minimapButtons")
	if self.frame.mover and self.frame.mover:GetScript("OnSizeChanged") then
		self.frame.mover:SetScript("OnSizeChanged", nil)
	end

	self:UpdateAlpha()
	self:UpdatePosition()
	self:ScanButtons()
	self:ScheduleRepeatingTimer("ScanButtons", 2)
	self.initialized = true
end

local function InitializeCallback()
	MB:Initialize()
end

E:RegisterModule(MB:GetName(), InitializeCallback)
