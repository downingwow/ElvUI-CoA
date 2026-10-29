local E, L = unpack(select(2, ...)); --Import: Engine, Locales
local B = E:GetModule("Blizzard")

--Lua functions
local min = math.min
local max = math.max
local floor = math.floor
local select = select
--WoW API / Variables
local GetScreenHeight = GetScreenHeight
local hooksecurefunc = hooksecurefunc

local hideRule = "[@arena1,exists][@arena2,exists][@arena3,exists][@arena4,exists][@arena5,exists][@boss1,exists][@boss2,exists][@boss3,exists][@boss4,exists]"

local function ApplyWatchFrameFont(fontString, font, size, outline)
	if not fontString or not fontString.SetFont then return end

	local shadowOutline = outline == "SHADOWOUTLINE"
	fontString:SetFont(font, size, shadowOutline and "OUTLINE" or outline)

	if shadowOutline and fontString.SetShadowOffset and fontString.SetShadowColor then
		local s = E.mult or 1
		fontString:SetShadowOffset(s, -s)
		fontString:SetShadowColor(0, 0, 0, 1)
	elseif fontString.SetShadowOffset and fontString.SetShadowColor then
		fontString:SetShadowOffset(0, 0)
		fontString:SetShadowColor(0, 0, 0, 0)
	end
end

local function ApplyFontToObject(object, font, size, outline, visited)
	if not object or visited[object] then return end
	visited[object] = true

	if object.GetObjectType and object:GetObjectType() == "FontString" then
		ApplyWatchFrameFont(object, font, size, outline)
	end

	if object.GetRegions then
		for i = 1, select("#", object:GetRegions()) do
			local region = select(i, object:GetRegions())
			if region and region.GetObjectType and region:GetObjectType() == "FontString" then
				ApplyWatchFrameFont(region, font, size, outline)
			end
		end
	end

	if object.GetChildren then
		for i = 1, select("#", object:GetChildren()) do
			ApplyFontToObject(select(i, object:GetChildren()), font, size, outline, visited)
		end
	end
end

local function GetWatchFrameLineSpacing(db, size)
	if db.watchFrameAutoLineSpacing == false then
		return db.watchFrameLineSpacing or 0
	end

	-- Blizzard's old WatchFrame was designed around roughly 12px fonts.
	-- Add progressively more vertical breathing room as the configured font grows.
	return max(0, floor(((size or 12) - 12) * 0.70 + 0.5))
end

local function UpdateWatchFrameMetrics(db, size, spacing)
	-- The 3.3.5 WatchFrame uses fixed 16/29 pixel line heights. Those values
	-- are too small once a larger custom font wraps onto a second line. Keep
	-- Blizzard's original dimensions at 12px and scale them with our font.
	local lineHeight = max(16, floor((size or 12) + 4 + 0.5))
	local multiLineHeight = max(29, floor((lineHeight * 2) + (spacing or 0) - 3 + 0.5))

	_G.WATCHFRAME_LINEHEIGHT = lineHeight
	_G.WATCHFRAME_MULTIPLE_LINEHEIGHT = multiLineHeight
	_G.WATCHFRAMELINES_FONTHEIGHT = size or 12
	_G.WATCHFRAMELINES_FONTSPACING = max(0, floor((lineHeight - (size or 12)) / 2))
end

local function UpdateWatchFrameWidth(db)
	if not WatchFrame then return end

	local width = max(160, min(600, db.watchFrameWidth or 204))
	_G.WATCHFRAME_EXPANDEDWIDTH = width
	_G.WATCHFRAME_MAXLINEWIDTH = max(148, width - 12)

	if not WatchFrame.collapsed then
		WatchFrame:SetWidth(width)
	end

	if _G.WatchFrameMover then
		_G.WatchFrameMover:SetWidth(width)
	end
end

local function ApplyLineSpacing(lines, spacing)
	if not lines then return end

	for i = 1, #lines do
		local line = lines[i]
		local text = line and line.text
		if text and text.SetSpacing then
			text:SetSpacing(spacing)
		end
	end
end

function B:UpdateWatchFrameFont()
	if not WatchFrame or not E.db or not E.db.general then return end

	local db = E.db.general
	local font = E.Libs.LSM:Fetch("font", db.watchFrameFont or db.font)
	local size = db.watchFrameFontSize or db.fontSize or 12
	local outline = db.watchFrameFontOutline or db.fontStyle or "OUTLINE"
	local spacing = GetWatchFrameLineSpacing(db, size)

	if not font then return end
	UpdateWatchFrameWidth(db)
	UpdateWatchFrameMetrics(db, size, spacing)
	ApplyFontToObject(WatchFrame, font, size, outline, {})

	-- SetSpacing changes the measured height of wrapped tracker text. This lets
	-- Blizzard's own WatchFrame layout reserve enough room for larger fonts.
	ApplyLineSpacing(_G.WATCHFRAME_QUESTLINES, spacing)
	ApplyLineSpacing(_G.WATCHFRAME_ACHIEVEMENTLINES, spacing)
end

function B:RefreshWatchFrameLayout()
	self:UpdateWatchFrameFont()

	-- Re-run the Blizzard layout once after changing the font metrics. Without
	-- this second pass, the old WatchFrame may keep offsets calculated for its
	-- default font until the next quest update.
	if WatchFrame_Update and not self.watchFrameLayoutRefresh then
		self.watchFrameLayoutRefresh = true
		WatchFrame_Update()
		self:UpdateWatchFrameFont()
		self.watchFrameLayoutRefresh = false
	end
end

function B:SetObjectiveFrameAutoHide()
	if E.db.general.watchFrameAutoHide then
		RegisterStateDriver(WatchFrame, "visibility", hideRule)
	else
		UnregisterStateDriver(WatchFrame, "visibility")
	end
end

function B:SetWatchFrameHeight()
	local top = WatchFrame:GetTop() or 0
	local screenHeight = GetScreenHeight()
	local gapFromTop = screenHeight - top
	local maxHeight = screenHeight - gapFromTop
	local watchFrameHeight = min(maxHeight, E.db.general.watchFrameHeight)

	WatchFrame:Height(watchFrameHeight)
end

function B:MoveWatchFrame()
	local WatchFrameHolder = CreateFrame("Frame", "WatchFrameHolder", E.UIParent)
	WatchFrameHolder:Size(E.db.general.watchFrameWidth or 204, 22)
	WatchFrameHolder:Point("TOPRIGHT", E.UIParent, "TOPRIGHT", -135, -300)

	E:CreateMover(WatchFrameHolder, "WatchFrameMover", L["Objective Frame"], nil, nil, nil, nil, nil, "general,objectiveFrameGroup")
	WatchFrameHolder:SetAllPoints(WatchFrameMover)
	WatchFrameMover:SetWidth(E.db.general.watchFrameWidth or 204)
	UpdateWatchFrameWidth(E.db.general)

	WatchFrame:ClearAllPoints()
	WatchFrame:SetPoint("TOP", WatchFrameHolder, "TOP")
	B:SetWatchFrameHeight()
	WatchFrame:SetClampedToScreen(false)

	hooksecurefunc(WatchFrame, "SetPoint", function(_, _, parent)
		if parent ~= WatchFrameHolder then
			WatchFrame:ClearAllPoints()
			WatchFrame:SetPoint("TOP", WatchFrameHolder, "TOP")
		end
	end)

	self:SetObjectiveFrameAutoHide()
	self:RefreshWatchFrameLayout()

	-- The Blizzard tracker recycles/recreates font strings whenever it updates.
	-- Re-apply the configured ElvUI Objective Frame font and, for larger fonts,
	-- immediately do one guarded second layout pass using the new line metrics.
	hooksecurefunc("WatchFrame_Update", function()
		if B.watchFrameLayoutRefresh then return end

		B:UpdateWatchFrameFont()
		local db = E.db and E.db.general
		local size = db and (db.watchFrameFontSize or db.fontSize or 12) or 12
		local spacing = db and GetWatchFrameLineSpacing(db, size) or 0

		if spacing > 0 and WatchFrame_Update then
			B.watchFrameLayoutRefresh = true
			WatchFrame_Update()
			B:UpdateWatchFrameFont()
			B.watchFrameLayoutRefresh = false
		end
	end)
end