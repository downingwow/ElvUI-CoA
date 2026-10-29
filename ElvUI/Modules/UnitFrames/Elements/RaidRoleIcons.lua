local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local UF = E:GetModule("UnitFrames")

--Lua functions
local match = string.match
local select, tonumber = select, tonumber
--WoW API / Variables
local CreateFrame = CreateFrame
local GetNumRaidMembers = GetNumRaidMembers
local GetRaidRosterInfo = GetRaidRosterInfo
local IsPartyLeader = IsPartyLeader
local UnitInParty = UnitInParty
local UnitInRaid = UnitInRaid

local function CheckLeader(unit)
	if unit == "player" then
		return IsPartyLeader()
	elseif unit ~= "player" and (UnitInParty(unit) or UnitInRaid(unit)) then
		local gtype, index = match(unit, "(%D+)(%d+)")
		index = tonumber(index)
		if gtype == "party" and GetNumRaidMembers() == 0 then
			return GetPartyLeaderIndex() == index
		elseif gtype == "raid" and GetNumRaidMembers() > 0 then
			return select(2, GetRaidRosterInfo(index)) == 2
		end
	end
end

local function UpdateOverride(self)
	local element = self.LeaderIndicator

	if element.PreUpdate then
		element:PreUpdate()
	end

	local isLeader = CheckLeader(self.unit)

	if isLeader then
		element:Show()
	else
		element:Hide()
	end

	if element.PostUpdate then
		return element:PostUpdate(isLeader)
	end
end

function UF:Construct_RaidRoleFrames(frame)
	local anchor = CreateFrame("Frame", nil, frame.RaisedElementParent)
	frame.LeaderIndicator = anchor:CreateTexture(nil, "OVERLAY")
	frame.AssistantIndicator = anchor:CreateTexture(nil, "OVERLAY")
	frame.MasterLooterIndicator = anchor:CreateTexture(nil, "OVERLAY")

	-- Set textures immediately so preview also works if the oUF elements are disabled.
	frame.LeaderIndicator:SetTexture([[Interface\GroupFrame\UI-Group-LeaderIcon]])
	frame.AssistantIndicator:SetTexture([[Interface\GroupFrame\UI-Group-AssistantIcon]])
	frame.MasterLooterIndicator:SetTexture([[Interface\GroupFrame\UI-Group-MasterLooter]])

	anchor:Size(24, 12)
	frame.LeaderIndicator:Size(12)
	frame.AssistantIndicator:Size(12)
	frame.MasterLooterIndicator:Size(11)

	frame.LeaderIndicator.Override = UpdateOverride

	frame.LeaderIndicator.PostUpdate = UF.RaidRoleUpdate
	frame.AssistantIndicator.PostUpdate = UF.RaidRoleUpdate
	frame.MasterLooterIndicator.PostUpdate = UF.RaidRoleUpdate

	return anchor
end

local function IsRightRaidRolePosition(position)
	return position == "TOPRIGHT" or position == "RIGHT" or position == "BOTTOMRIGHT"
end

local function IsCenterRaidRolePosition(position)
	return position == "TOP" or position == "CENTER" or position == "BOTTOM"
end

function UF:Configure_RaidRoleIcons(frame)
	local raidRoleFrameAnchor = frame.RaidRoleFramesAnchor
	local db = frame.db and frame.db.raidRoleIcons
	if not raidRoleFrameAnchor or not db then return end

	if db.enable or db.preview then
		raidRoleFrameAnchor:Show()

		if db.enable then
			if not frame:IsElementEnabled("LeaderIndicator") then
				frame:EnableElement("LeaderIndicator")
				frame:EnableElement("MasterLooterIndicator")
				frame:EnableElement("AssistantIndicator")
			end
		elseif frame:IsElementEnabled("LeaderIndicator") then
			frame:DisableElement("LeaderIndicator")
			frame:DisableElement("MasterLooterIndicator")
			frame:DisableElement("AssistantIndicator")
		end

		local size = db.size or 12
		local position = db.position or "TOPLEFT"
		local xOffset = db.xOffset or 0
		local yOffset = db.yOffset or 0

		raidRoleFrameAnchor:Size(size * 2, size)
		frame.LeaderIndicator:Size(size)
		frame.AssistantIndicator:Size(size)
		frame.MasterLooterIndicator:Size(size)

		raidRoleFrameAnchor:ClearAllPoints()

		-- Preserve the old TOPLEFT/TOPRIGHT placement at the default offsets.
		if position == "TOPLEFT" then
			raidRoleFrameAnchor:Point("LEFT", frame.Health, "TOPLEFT", 2 + xOffset, yOffset)
		elseif position == "TOPRIGHT" then
			raidRoleFrameAnchor:Point("RIGHT", frame, "TOPRIGHT", -2 + xOffset, yOffset)
		else
			raidRoleFrameAnchor:Point(position, frame, position, xOffset, yOffset)
		end

		-- First refresh the real game state. Preview then overrides visibility below.
		if db.enable then
			if frame.LeaderIndicator and frame.LeaderIndicator.ForceUpdate then frame.LeaderIndicator:ForceUpdate() end
			if frame.MasterLooterIndicator and frame.MasterLooterIndicator.ForceUpdate then frame.MasterLooterIndicator:ForceUpdate() end
			if frame.AssistantIndicator and frame.AssistantIndicator.ForceUpdate then frame.AssistantIndicator:ForceUpdate() end
		end

		-- RaidRoleUpdate expects the icon texture as self. Use a dot-call here.
		if frame.LeaderIndicator then
			UF.RaidRoleUpdate(frame.LeaderIndicator)
		end
	else
		raidRoleFrameAnchor:Hide()
		if frame:IsElementEnabled("LeaderIndicator") then
			frame:DisableElement("LeaderIndicator")
			frame:DisableElement("MasterLooterIndicator")
			frame:DisableElement("AssistantIndicator")
		end
	end
end

function UF:RaidRoleUpdate()
	local anchor = self and self.GetParent and self:GetParent()
	if not anchor then return end

	local raisedParent = anchor:GetParent()
	local frame = raisedParent and raisedParent:GetParent()
	if not frame then return end

	local leader = frame.LeaderIndicator
	local assistant = frame.AssistantIndicator
	local masterLooter = frame.MasterLooterIndicator
	if not leader or not masterLooter or not assistant then return end

	local db = frame.db
	local roleDB = db and db.raidRoleIcons
	if not roleDB then return end

	if roleDB.preview then
		-- Use the real RL/ML icons as preview, not a separate fake overlay.
		leader:Show()
		masterLooter:Show()
		assistant:Hide()
	end

	local isLeader = leader:IsShown()
	local isMasterLooter = masterLooter:IsShown()
	local isAssist = assistant:IsShown()
	local position = roleDB.position or "TOPLEFT"
	local rightSide = IsRightRaidRolePosition(position)
	local centerSide = IsCenterRaidRolePosition(position)

	leader:ClearAllPoints()
	assistant:ClearAllPoints()
	masterLooter:ClearAllPoints()

	if isLeader then
		if rightSide then
			leader:Point("RIGHT", anchor, "RIGHT")
			masterLooter:Point("LEFT", anchor, "LEFT")
		else
			leader:Point("LEFT", anchor, "LEFT")
			masterLooter:Point("RIGHT", anchor, "RIGHT")
		end
	elseif isAssist then
		if rightSide then
			assistant:Point("RIGHT", anchor, "RIGHT")
			masterLooter:Point("LEFT", anchor, "LEFT")
		else
			assistant:Point("LEFT", anchor, "LEFT")
			masterLooter:Point("RIGHT", anchor, "RIGHT")
		end
	elseif isMasterLooter then
		if centerSide then
			masterLooter:Point("CENTER", anchor, "CENTER")
		elseif rightSide then
			masterLooter:Point("RIGHT", anchor, "RIGHT")
		else
			masterLooter:Point("LEFT", anchor, "LEFT")
		end
	end
end
