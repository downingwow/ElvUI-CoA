local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local THREAT = E:GetModule("Threat")
local DT = E:GetModule("DataTexts")
local S = E:GetModule("Skins", true)
local LSM = E.Libs.LSM

--Lua functions
local pairs, select = pairs, select
local wipe = table.wipe
--WoW API / Variables
local GetNumPartyMembers = GetNumPartyMembers
local GetNumRaidMembers = GetNumRaidMembers
local GetThreatStatusColor = GetThreatStatusColor
local UnitDetailedThreatSituation = UnitDetailedThreatSituation
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local UnitIsUnit = UnitIsUnit
local UnitName = UnitName
local UnitReaction = UnitReaction

local UNKNOWN = UNKNOWN

local partyUnits, raidUnits = {}, {}
for i = 1, 4 do partyUnits[i] = "party"..i end
for i = 1, 40 do raidUnits[i] = "raid"..i end

function THREAT:UpdateAppearance()
	if not self.bar then return end

	local color = self.db.textColor or {r = 1, g = 1, b = 1}
	local texture = (self.db.texture and LSM and LSM:Fetch("statusbar", self.db.texture)) or E.media.normTex

	self.bar:SetStatusBarTexture(texture or E.media.normTex)

	local font = E.media.normFont
	if self.db.font and LSM then
		font = LSM:Fetch("font", self.db.font) or font
	end

	self.bar.text:FontTemplate(font, self.db.textSize or 12, self.db.textOutline or "NONE")
	self.bar.text:SetTextColor(color.r or 1, color.g or 1, color.b or 1)
	self.bar.text:ClearAllPoints()
	self.bar.text:Point("CENTER", self.bar, "CENTER", self.db.textX or 0, self.db.textY or 0)
end

function THREAT:UpdatePosition()
	if not self.bar then return end

	if self.db.detach then
		self.bar:SetParent(E.UIParent)
		self.bar:Size(self.db.width or 300, self.db.height or 20)

		if self.bar.mover then
			self.bar.mover:Size(self.db.width or 300, self.db.height or 20)
			self.bar.mover:SetScale(1)
			self.bar.mover:SetAlpha(1)

			self.bar:ClearAllPoints()
			self.bar:Point("CENTER", self.bar.mover, "CENTER")
		end
	else
		if self.bar.mover then
			self.bar.mover:SetScale(0.0001)
			self.bar.mover:SetAlpha(0)
		end

		if self.db.position == "RIGHTCHAT" then
			self.bar:SetInside(RightChatDataPanel)
			self.bar:SetParent(RightChatDataPanel)
		else
			self.bar:SetInside(LeftChatDataPanel)
			self.bar:SetParent(LeftChatDataPanel)
		end
	end

	self:UpdateAppearance()
	self.bar:SetFrameStrata("MEDIUM")

	if S and S.UpdateFrameShadow then
		S:UpdateFrameShadow("threat")
	end
end

function THREAT:GetLargestThreatOnList(percent)
	local largestValue, largestUnit = 0
	for unit, threatPercent in pairs(self.list) do
		if threatPercent > largestValue then
			largestValue = threatPercent
			largestUnit = unit
		end
	end

	return (percent - largestValue), largestUnit
end

function THREAT:GetColor(unit)
	if UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		local color = UnitIsUnit("player", unit) and E.media.herocolor or RAID_CLASS_COLORS[class]
		if not color then
			return 194, 194, 194
		end

		return color.r*255, color.g*255, color.b*255
	end

	local unitReaction = UnitReaction(unit, "player")
	if unitReaction then
		local reaction = ElvUF.colors.reaction[unitReaction]
		return reaction[1]*255, reaction[2]*255, reaction[3]*255
	else
		return 194, 194, 194
	end
end

local function ClearThreatGradient(statusBar)
	if not statusBar then return end

	local texture = statusBar:GetStatusBarTexture()
	if texture and texture.SetGradientAlpha then
		texture:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
	end
end

function THREAT:GetThreatColorKey(status)
	if not status or status <= 0 then
		return "low"
	elseif status == 1 then
		return "medium"
	else
		return "high"
	end
end

function THREAT:ApplyBarColor(key, fallbackR, fallbackG, fallbackB)
	if not self.bar then return end

	local db = self.db
	local base = db.customColors and db.colors and db.colors[key]

	if not base then
		ClearThreatGradient(self.bar)
		self.bar:SetStatusBarColor(fallbackR or 1, fallbackG or 1, fallbackB or 1)
		return
	end

	local r, g, b = base.r or 1, base.g or 1, base.b or 1
	local texture = self.bar:GetStatusBarTexture()

	if db.gradient and texture and texture.SetGradientAlpha then
		local finish = db.gradientColors and db.gradientColors[key] or base
		local er, eg, eb = finish.r or r, finish.g or g, finish.b or b

		-- StatusBarColor must be white or WoW multiplies the texture gradient.
		self.bar:SetStatusBarColor(1, 1, 1, 1)
		texture:SetGradientAlpha("HORIZONTAL", r, g, b, 1, er, eg, eb, 1)
	else
		ClearThreatGradient(self.bar)
		self.bar:SetStatusBarColor(r, g, b)
	end
end

function THREAT:ShowPreview()
	if not self.bar then return end

	self.bar:Show()
	self.bar:SetMinMaxValues(0, 100)
	self.bar:SetValue(65)
	self.bar.text:SetText("Threat Preview: 65%")
	self:UpdateAppearance()
	self:ApplyBarColor("preview", 1, 0.55, 0.15)

	if S and S.UpdateFrameShadow then
		S:UpdateFrameShadow("threat")
	end
end

function THREAT:SetPreview(state)
	self.preview = state and true or false

	if self.preview then
		self:ShowPreview()
	else
		self:Update()
	end
end

function THREAT:Update()
	if not UnitExists("target") or (DT and DT.ShowingBGStats) then
		if self.preview then
			self:ShowPreview()
		elseif self.bar:IsShown() then
			self.bar:Hide()
		end

		return
	end

	local _, status, percent = UnitDetailedThreatSituation("player", "target")
	local petExists = HasPetUI()

	if percent and percent > 0 and (GetNumPartyMembers() > 0 or petExists == 1) then
		local name = UnitName("target")
		self.bar:Show()

		if percent == 100 then
			if petExists == 1 then
				self.list.pet = select(3, UnitDetailedThreatSituation("pet", "target"))
			end

			if GetNumRaidMembers() > 0 then
				for i = 1, 40 do
					if UnitExists(raidUnits[i]) and not UnitIsUnit(raidUnits[i], "player") then
						self.list[raidUnits[i]] = select(3, UnitDetailedThreatSituation(raidUnits[i], "target"))
					end
				end
			else
				for i = 1, 4 do
					if UnitExists(partyUnits[i]) then
						self.list[partyUnits[i]] = select(3, UnitDetailedThreatSituation(partyUnits[i], "target"))
					end
				end
			end

			local leadPercent, largestUnit = self:GetLargestThreatOnList(percent)
			if leadPercent > 0 and largestUnit then
				local r, g, b = self:GetColor(largestUnit)
				self.bar.text:SetFormattedText(L["ABOVE_THREAT_FORMAT"], name, percent, leadPercent, r, g, b, UnitName(largestUnit) or UNKNOWN)

				if E.Role == "Tank" then
					self:ApplyBarColor("tanking", 0, 0.839, 0)
					self.bar:SetValue(leadPercent)
				else
					local sr, sg, sb = GetThreatStatusColor(status or 0)
					self:ApplyBarColor(self:GetThreatColorKey(status), sr, sg, sb)
					self.bar:SetValue(percent)
				end
			else
				local sr, sg, sb = GetThreatStatusColor(status or 0)
				self:ApplyBarColor(self:GetThreatColorKey(status), sr, sg, sb)
				self.bar:SetValue(percent)
				self.bar.text:SetFormattedText("%s: %.0f%%", name, percent)
			end
		else
			local sr, sg, sb = GetThreatStatusColor(status or 0)
			self:ApplyBarColor(self:GetThreatColorKey(status), sr, sg, sb)
			self.bar:SetValue(percent)
			self.bar.text:SetFormattedText("%s: %.0f%%", name, percent)
		end
	else
		if self.preview then
			self:ShowPreview()
		else
			self.bar:Hide()
		end
	end

	wipe(self.list)
end

function THREAT:ToggleEnable()
	if self.db.enable then
		self:RegisterEvent("PLAYER_TARGET_CHANGED", "Update")
		self:RegisterEvent("UNIT_THREAT_LIST_UPDATE", "Update")
		self:RegisterEvent("PARTY_MEMBERS_CHANGED", "Update")
		self:RegisterEvent("RAID_ROSTER_UPDATE", "Update")
		self:RegisterEvent("UNIT_PET", "Update")
		self:Update()
	else
		self.bar:Hide()
		self:UnregisterEvent("PLAYER_TARGET_CHANGED")
		self:UnregisterEvent("UNIT_THREAT_LIST_UPDATE")
		self:UnregisterEvent("PARTY_MEMBERS_CHANGED")
		self:UnregisterEvent("RAID_ROSTER_UPDATE")
		self:UnregisterEvent("UNIT_PET")
	end
end

function THREAT:Initialize()
	self.db = E.db.general.threat

	self.bar = CreateFrame("StatusBar", "ElvUI_ThreatBar", E.UIParent)
	self.bar:CreateBackdrop("Default")
	self.bar:SetMinMaxValues(0, 100)

	-- Give the frame a real initial position/size before the mover is created.
	-- When Threat is attached, UpdatePosition() will hide the mover and anchor
	-- the bar back inside the selected chat datatext panel.
	self.bar:Size(self.db.width or 300, self.db.height or 20)
	self.bar:Point("BOTTOM", E.UIParent, "BOTTOM", 0, 160)

	self.bar.text = self.bar:CreateFontString(nil, "OVERLAY")
	self.bar.text:Point("CENTER", self.bar, "CENTER")

	E:CreateMover(
		self.bar,
		"ThreatBarMover",
		"Threat Bar",
		nil,
		nil,
		nil,
		"ALL,GENERAL",
		nil,
		"general,threatGroup"
	)

	self.list = {}
	self.preview = false

	self:UpdatePosition()
	self:ToggleEnable()

	self.Initialized = true
end

local function InitializeCallback()
	THREAT:Initialize()
end

E:RegisterModule(THREAT:GetName(), InitializeCallback)
