local E, L, V, P, G = unpack(select(2, ...))
local B = E:GetModule("Blizzard")

local _G = _G
local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UIParent = UIParent
local pairs, ipairs, type = pairs, ipairs, type
local max = math.max

-- Common Blizzard windows in the 3.3.5a client. Frames that are load-on-demand
-- are picked up automatically as soon as their Blizzard addon is loaded.
local WINDOW_FRAMES = {
	-- Core / always available
	"CharacterFrame",
	"SpellBookFrame",
	"QuestLogFrame",
	"FriendsFrame",
	"WorldMapFrame",
	"MerchantFrame",
	"BankFrame",
	"GossipFrame",
	"QuestFrame",
	"TradeFrame",
	"MailFrame",
	"DressUpFrame",
	"ItemTextFrame",
	"PetStableFrame",
	"PetitionFrame",
	"TaxiFrame",

	-- Load-on-demand Blizzard windows
	"TradeSkillFrame",
	"CraftFrame",
	"AuctionFrame",
	"ClassTrainerFrame",
	"InspectFrame",
	"GuildBankFrame",
	"CalendarFrame",
	"MacroFrame",
	"GlyphFrame",
	"PlayerTalentFrame",
	"ItemSocketingFrame",
	"TimeManagerFrame",
	"TokenFrame",
	"BarberShopFrame",
	"AchievementFrame",
	"LFDParentFrame",
	"PVPParentFrame",
	"LFRParentFrame",
	"GuildFrame",
	"GuildRegistrarFrame",
	"TabardFrame",
	"HelpFrame",
	"HelpMenuFrame",
	"InterfaceOptionsFrame",
	"VideoOptionsFrame",
	"AudioOptionsFrame",
	"KeyBindingFrame",
	"ChannelFrame",
	"LootFrame",
	"StackSplitFrame",
	"RaidInfoFrame",

	-- Ascension / CoA replacements and custom Blizzard-style panels.
	"AscensionCharacterFrame",
	"AscensionSpellbookFrame",
	"AscensionInspectFrame",
	"AscensionLFGFrame",
	"AscensionPVEFrame",
	"AscensionPVPFrame",
	"AscensionRulesetFrame",
	"PathToAscensionFrame",
}

B.MovableBlizzardWindows = B.MovableBlizzardWindows or {}

local function GetDB()
	return E.db and E.db.general and E.db.general.blizzardWindowMover
end

local function CopyPoints(frame)
	local points = {}
	for i = 1, frame:GetNumPoints() do
		local point, relativeTo, relativePoint, x, y = frame:GetPoint(i)
		points[#points + 1] = {
			point = point,
			relativeTo = relativeTo,
			relativePoint = relativePoint,
			x = x or 0,
			y = y or 0,
		}
	end
	return points
end

local function RestorePoints(frame, points)
	if not frame or not points or #points == 0 then return end
	frame:ClearAllPoints()
	for _, p in ipairs(points) do
		local relativeTo = p.relativeTo
		if type(relativeTo) == "string" then
			relativeTo = _G[relativeTo]
		end
		if not relativeTo then relativeTo = UIParent end
		frame:SetPoint(p.point or "CENTER", relativeTo, p.relativePoint or p.point or "CENTER", p.x or 0, p.y or 0)
	end
end

function B:GetBlizzardWindowPosition(frame)
	if not frame or not frame.GetCenter then return end
	local cx, cy = frame:GetCenter()
	local ux, uy = UIParent:GetCenter()
	if not cx or not cy or not ux or not uy then return end
	return cx - ux, cy - uy
end

function B:SaveBlizzardWindowPosition(frame)
	local db = GetDB()
	if not db or not db.enabled or not frame or not frame.GetName then return end
	local name = frame:GetName()
	if not name then return end

	local x, y = self:GetBlizzardWindowPosition(frame)
	if not x or not y then return end

	db.positions = db.positions or {}
	db.positions[name] = {x = x, y = y}
	if frame.SetUserPlaced then frame:SetUserPlaced(true) end
	frame.__ElvUIWindowMoverHasPosition = true
end

local function ApplyWorldMapPosition(frame, position)
	-- The 3.3.5 WorldMap code reads WorldMapButton:GetCenter() every frame.
	-- Replacing WorldMapFrame's anchors while it is still being shown can briefly
	-- leave the map button without a valid center and causes FrameXML errors.
	-- Wait until both frames are fully laid out, then translate the existing
	-- anchors instead of replacing them with a single CENTER anchor. This keeps
	-- width, height, scale and the original anchor geometry completely intact.
	if not frame:IsShown() then return end

	local mapButton = _G.WorldMapButton
	if mapButton and mapButton.GetCenter then
		local bx, by = mapButton:GetCenter()
		if not bx or not by then return end
	end

	local cx, cy = frame:GetCenter()
	local ux, uy = UIParent:GetCenter()
	if not cx or not cy or not ux or not uy then return end

	local targetX = ux + (position.x or 0)
	local targetY = uy + (position.y or 0)
	local dx, dy = targetX - cx, targetY - cy
	if dx == 0 and dy == 0 then return true end

	local points = CopyPoints(frame)
	if #points == 0 then return end

	frame:ClearAllPoints()
	for _, p in ipairs(points) do
		local relativeTo = p.relativeTo
		if type(relativeTo) == "string" then
			relativeTo = _G[relativeTo]
		end
		if not relativeTo then relativeTo = UIParent end
		frame:SetPoint(p.point or "CENTER", relativeTo, p.relativePoint or p.point or "CENTER", (p.x or 0) + dx, (p.y or 0) + dy)
	end

	if frame.SetUserPlaced then frame:SetUserPlaced(true) end
	frame.__ElvUIWindowMoverHasPosition = true
	return true
end

function B:ApplyBlizzardWindowPosition(frame)
	local db = GetDB()
	if not db or not db.enabled or not frame or not frame.GetName then return end
	local name = frame:GetName()
	local position = db.positions and db.positions[name]
	if not position then return end

	if InCombatLockdown() and frame.IsProtected and frame:IsProtected() then return end

	if name == "WorldMapFrame" then
		return ApplyWorldMapPosition(frame, position)
	end

	-- Guard so our own SetPoint hook (below) does not react to this call.
	frame.__ElvUIWindowMoverApplying = true
	frame:ClearAllPoints()
	frame:SetPoint("CENTER", UIParent, "CENTER", position.x or 0, position.y or 0)
	frame.__ElvUIWindowMoverApplying = nil
	if frame.SetUserPlaced then frame:SetUserPlaced(true) end
	frame.__ElvUIWindowMoverHasPosition = true
	return true
end

local function StartMoving(handle)
	local frame = handle.__owner
	local db = GetDB()
	if not frame or not db or not db.enabled then return end
	if InCombatLockdown() and frame.IsProtected and frame:IsProtected() then return end

	frame:StartMoving()
	frame.__ElvUIWindowMoverMoving = true
end

local function StopMoving(handle)
	local frame = handle.__owner
	if not frame or not frame.__ElvUIWindowMoverMoving then return end
	frame:StopMovingOrSizing()
	frame.__ElvUIWindowMoverMoving = nil
	B:SaveBlizzardWindowPosition(frame)
end

function B:CreateBlizzardWindowDragHandle(frame)
	if not frame or frame.__ElvUIWindowMoverHandle then return end

	local handle = CreateFrame("Frame", nil, frame)
	handle.__owner = frame
	-- Use nearly the entire title area. Several Ascension/Blizzard panels have
	-- a very small or non-standard title region, so the old 44px insets made
	-- their drag handle effectively unusable. Keep the close-button corner free.
	handle:SetHeight(28)
	handle:SetPoint("TOPLEFT", frame, "TOPLEFT", 8, -2)
	handle:SetPoint("TOPRIGHT", frame, "TOPRIGHT", -34, -2)
	handle:SetFrameLevel(max((frame:GetFrameLevel() or 1) + 100, 100))
	handle:EnableMouse(true)
	handle:RegisterForDrag("LeftButton")
	handle:SetScript("OnDragStart", StartMoving)
	handle:SetScript("OnDragStop", StopMoving)
	frame.__ElvUIWindowMoverHandle = handle

	-- Der Griff liegt per Frame-Level ueber allem im Titelbereich und wuerde den
	-- Close-Button (X) teilweise verdecken, weil dessen Skin/Position je nach Fenster
	-- unter den Griff ragt. Close-Button deshalb ueber den Griff heben.
	local name = frame:GetName()
	local closeButton = frame.CloseButton or (name and (_G[name .. "CloseButton"] or _G[name .. "Close"]))
	if closeButton and closeButton.SetFrameLevel and closeButton.GetParent and closeButton:GetParent() == frame then
		closeButton:SetFrameLevel(handle:GetFrameLevel() + 1)
	end
end

function B:SetupMovableBlizzardWindow(frame)
	if not frame or not frame.GetName or not frame:GetName() then return end
	local name = frame:GetName()

	if not frame.__ElvUIWindowMoverDefaultPoints then
		frame.__ElvUIWindowMoverDefaultPoints = CopyPoints(frame)
	end

	frame:SetMovable(true)
	if frame.SetClampedToScreen then frame:SetClampedToScreen(true) end
	self:CreateBlizzardWindowDragHandle(frame)

	-- Blizzard's panel manager (and other addons) can add a second anchor to a
	-- window we have moved. A frame with two anchors gets stretched and its
	-- children no longer line up with its background, so whenever somebody else
	-- touches the anchors of a window with a saved position, put it back to a
	-- single clean CENTER anchor.
	if name ~= "WorldMapFrame" and not frame.__ElvUIWindowMoverSetPointHooked then
		frame.__ElvUIWindowMoverSetPointHooked = true
		hooksecurefunc(frame, "SetPoint", function(self)
			if self.__ElvUIWindowMoverApplying or self.__ElvUIWindowMoverMoving then return end
			local db = GetDB()
			if not db or not db.enabled or not db.positions or not db.positions[name] then return end
			if InCombatLockdown() and self.IsProtected and self:IsProtected() then return end

			local point, relativeTo = self:GetPoint(1)
			if self:GetNumPoints() ~= 1 or point ~= "CENTER" or relativeTo ~= UIParent then
				B:ApplyBlizzardWindowPosition(self)
			end
		end)
	end

	if not frame.__ElvUIWindowMoverHooked then
		frame.__ElvUIWindowMoverHooked = true
		frame:HookScript("OnShow", function(self)
			local db = GetDB()
			if not db or not db.enabled then return end

			-- WorldMapFrame needs one layout pass before it is moved. Its FrameXML
			-- OnUpdate reads WorldMapButton:GetCenter(), which can still be nil during
			-- OnShow. Other Blizzard windows keep the original immediate behavior.
			if self:GetName() == "WorldMapFrame" then
				if E.Delay then
					E:Delay(0.05, function()
						if self:IsShown() then B:ApplyBlizzardWindowPosition(self) end
					end)
				end
				return
			end

			-- UIPanelWindows may place a panel immediately before/after OnShow. Apply
			-- once now and again on the next update so Blizzard cannot snap it back.
			B:ApplyBlizzardWindowPosition(self)
			if E.Delay then
				E:Delay(0, function()
					if self:IsShown() then B:ApplyBlizzardWindowPosition(self) end
				end)
			end
		end)
	end

	self.MovableBlizzardWindows[name] = frame
	self:UpdateBlizzardWindowHandle(frame)
	self:ApplyBlizzardWindowPosition(frame)
end

function B:UpdateBlizzardWindowHandle(frame)
	if not frame or not frame.__ElvUIWindowMoverHandle then return end
	local db = GetDB()
	if db and db.enabled then
		frame.__ElvUIWindowMoverHandle:Show()
	else
		frame.__ElvUIWindowMoverHandle:Hide()
	end
end

local WINDOW_EXCLUDE = {
	GameTooltip = true,
	ItemRefTooltip = true,
	ShoppingTooltip1 = true,
	ShoppingTooltip2 = true,

	-- Embedded pages/tabs. These belong to a parent Blizzard window and must
	-- never become independently movable (e.g. Raid is a tab inside FriendsFrame).
	RaidFrame = true,
	PVPFrame = true,
	LFRBrowseFrame = true,
}

function B:IsMovableBlizzardWindow(frame)
	if not frame or not frame.GetName then return false end
	local name = frame:GetName()
	if not name or WINDOW_EXCLUDE[name] then return false end
	if frame == UIParent or frame == WorldFrame then return false end

	-- Only top-level windows may be moved. Blizzard uses many child frames as
	-- tabs/pages inside a real window (RaidFrame inside FriendsFrame is the
	-- classic example). Giving those children their own drag handle tears the
	-- page out of its parent visually.
	local parent = frame.GetParent and frame:GetParent()
	if parent and parent ~= UIParent and parent ~= WorldFrame then
		return false
	end

	return frame.GetPoint and frame.SetPoint and frame.ClearAllPoints and frame.StartMoving and frame.StopMovingOrSizing
end

function B:ScanMovableBlizzardWindows()
	-- Explicit list handles special/non-UIPanel windows.
	for _, name in ipairs(WINDOW_FRAMES) do
		local frame = _G[name]
		if frame and self:IsMovableBlizzardWindow(frame) then
			self:SetupMovableBlizzardWindow(frame)
		end
	end

	-- Blizzard and many 3.3.5a custom clients register their normal panels here.
	-- Scanning the table means newly loaded profession, auction, guild, talent,
	-- calendar, etc. windows do not need a hardcoded entry.
	if _G.UIPanelWindows then
		for name in pairs(_G.UIPanelWindows) do
			local frame = _G[name]
			if frame and self:IsMovableBlizzardWindow(frame) then
				self:SetupMovableBlizzardWindow(frame)
			end
		end
	end
end

function B:ResetBlizzardWindow(frame)
	if not frame then return end
	if InCombatLockdown() and frame.IsProtected and frame:IsProtected() then return end

	frame.__ElvUIWindowMoverHasPosition = nil
	if frame.SetUserPlaced then frame:SetUserPlaced(false) end
	RestorePoints(frame, frame.__ElvUIWindowMoverDefaultPoints)
end

function B:ResetAllBlizzardWindowPositions()
	local db = GetDB()
	if not db then return end
	db.positions = {}

	for _, frame in pairs(self.MovableBlizzardWindows) do
		self:ResetBlizzardWindow(frame)
	end

	-- Let Blizzard rebuild its normal left/center/right panel layout where possible.
	if _G.UpdateUIPanelPositions then _G.UpdateUIPanelPositions() end
	E:Print("Blizzard window positions have been reset.")
end

function B:UpdateMovableBlizzardWindows()
	local db = GetDB()
	if not db then return end

	self:ScanMovableBlizzardWindows()
	for _, frame in pairs(self.MovableBlizzardWindows) do
		self:UpdateBlizzardWindowHandle(frame)
		if db.enabled then
			self:ApplyBlizzardWindowPosition(frame)
		else
			self:ResetBlizzardWindow(frame)
		end
	end

	if not db.enabled and _G.UpdateUIPanelPositions then _G.UpdateUIPanelPositions() end
end

function B:InitializeWindowMover()
	-- Migration from the first mover version: these were accidentally treated
	-- as standalone windows although they are embedded tabs/pages.
	local db = GetDB()
	if db and db.positions then
		db.positions.RaidFrame = nil
		db.positions.PVPFrame = nil
		db.positions.LFRBrowseFrame = nil
	end

	self:ScanMovableBlizzardWindows()

	-- Use an independent event frame because the Blizzard module already uses
	-- ADDON_LOADED for the TradeSkill link button and unregisters that event later.
	if not self.WindowMoverEventFrame then
		local eventFrame = CreateFrame("Frame")
		eventFrame:RegisterEvent("ADDON_LOADED")
		eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
		eventFrame:SetScript("OnEvent", function(_, event)
			if event == "ADDON_LOADED" then
				B:ScanMovableBlizzardWindows()
				if E.Delay then
					E:Delay(0.1, function() B:ScanMovableBlizzardWindows() end)
				end
			elseif event == "PLAYER_REGEN_ENABLED" then
				B:UpdateMovableBlizzardWindows()
			end
		end)
		self.WindowMoverEventFrame = eventFrame
	end

	-- Catch every real UIPanel at the moment it is opened. This covers client-
	-- specific and load-on-demand windows that are not in our explicit list.
	if not self.__WindowMoverShowUIPanelHooked and _G.hooksecurefunc and _G.ShowUIPanel then
		self.__WindowMoverShowUIPanelHooked = true
		hooksecurefunc("ShowUIPanel", function(frame)
			local db = GetDB()
			if not db or not db.enabled or not B:IsMovableBlizzardWindow(frame) then return end
			B:SetupMovableBlizzardWindow(frame)

			if frame:GetName() == "WorldMapFrame" then
				if E.Delay then
					E:Delay(0.05, function()
						if frame:IsShown() then B:ApplyBlizzardWindowPosition(frame) end
					end)
				end
				return
			end

			B:ApplyBlizzardWindowPosition(frame)
			if E.Delay then
				E:Delay(0, function()
					if frame:IsShown() then B:ApplyBlizzardWindowPosition(frame) end
				end)
			end
		end)
	end

	-- Blizzard can reposition UIPanel windows whenever another panel opens/closes.
	-- Only restore frames for which this profile has a saved custom position.
	if not self.__WindowMoverUIPanelHooked and _G.hooksecurefunc and _G.UpdateUIPanelPositions then
		self.__WindowMoverUIPanelHooked = true
		hooksecurefunc("UpdateUIPanelPositions", function()
			local db = GetDB()
			if not db or not db.enabled or not db.positions then return end
			for name in pairs(db.positions) do
				local frame = B.MovableBlizzardWindows[name]
				if frame and frame:IsShown() and not frame.__ElvUIWindowMoverMoving then
					B:ApplyBlizzardWindowPosition(frame)
				end
			end
		end)
	end
end

-- Profile swaps/imports call UpdateAll. Reapply only the positions belonging to
-- the newly active profile.
hooksecurefunc(E, "UpdateAll", function()
	if B.Initialized and B.UpdateMovableBlizzardWindows then
		B:UpdateMovableBlizzardWindows()
	end
end)
