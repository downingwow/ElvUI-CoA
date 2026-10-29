local E, L, V, P, G = unpack(select(2, ...))
local UF = E:GetModule("UnitFrames")
local _, ns = ...
local ElvUF = ns.oUF
assert(ElvUF, "ElvUI was unable to locate oUF.")

local LSM = E.Libs.LSM
local pairs = pairs
local CreateFrame = CreateFrame

local select = select
local math = math
local find = string.find

local GetInventoryItemID = GetInventoryItemID
local GetSpellInfo = GetSpellInfo
local GetTime = GetTime
local UnitAttackSpeed = UnitAttackSpeed
local UnitCastingInfo = UnitCastingInfo
local UnitRangedDamage = UnitRangedDamage

local mainHandID = GetInventoryItemID("player", 16)
local offHandID = GetInventoryItemID("player", 17)
local rangedID = GetInventoryItemID("player", 18)

local meleeing, ranging, lastHit

local function ShowIdleSwingBars(element)
	if not element or not element.db then return false end

	local showMainhand = element.db.alwaysShowMainhand
	local showOffhand = element.db.alwaysShowOffhand
	if not showMainhand and not showOffhand then return false end

	element:Show()

	element.Twohand:Hide()
	element.Twohand:SetScript("OnUpdate", nil)
	if element.Twohand.Spark then element.Twohand.Spark:Hide() end

	local main = element.Mainhand
	main:SetScript("OnUpdate", nil)
	main:SetMinMaxValues(0, 1)
	main:SetValue(0)
	if main.Text then main.Text:SetText("0.0") end
	if main.Spark then main.Spark:Hide() end
	if showMainhand then main:Show() else main:Hide() end

	local off = element.Offhand
	off:SetScript("OnUpdate", nil)
	off:SetMinMaxValues(0, 1)
	off:SetValue(0)
	if off.Text then off.Text:SetText("0.0") end
	if off.Spark then off.Spark:Hide() end
	if showOffhand then off:Show() else off:Hide() end

	return true
end

local function SwingStopped(element)
	local bar = element.__owner

	for _, Bar in pairs({bar.Twohand, bar.Mainhand, bar.Offhand}) do
		if Bar:IsShown() then return end
	end

	if not ShowIdleSwingBars(bar) then
		bar:Hide()
	end
end

local OnDurationUpdate
do
	local checkElapsed, slamElapsed, slamTime = 0, 0, 0
	local slam = GetSpellInfo(1464)

	function OnDurationUpdate(self, elapsed)
		local now = GetTime()
		local owner = self.__owner

		if self.Spark then
			if owner and owner.db and owner.db.spark then
				self.Spark:Show()
			else
				self.Spark:Hide()
			end
		end

		if self.min and self.max and self.speed then
			local value = now - self.min
			if value < 0 then value = 0 end
			if value > self.speed then value = self.speed end

			self:SetMinMaxValues(0, self.speed)
			self:SetValue(value)

			if self.Text then
				self.Text:SetFormattedText("%.1f", math.max(0, self.max - now))
			end

			if now >= self.max then
				self:SetScript("OnUpdate", nil)
				if self.Spark then self.Spark:Hide() end

				-- End the active swing. If that hand is configured as Always
				-- Show, return it to the idle empty-bar state.
				if owner then
					if self == owner.Twohand then
						self:Hide()
						if owner.db and owner.db.alwaysShowMainhand then
							local idle = owner.Mainhand
							idle:SetMinMaxValues(0, 1)
							idle:SetValue(0)
							if idle.Text then idle.Text:SetText("0.0") end
							if idle.Spark then idle.Spark:Hide() end
							idle:Show()
						end
					elseif self == owner.Mainhand then
						if owner.db and owner.db.alwaysShowMainhand then
							self:SetMinMaxValues(0, 1)
							self:SetValue(0)
							if self.Text then self.Text:SetText("0.0") end
							self:Show()
						else
							self:Hide()
						end
					elseif self == owner.Offhand then
						if owner.db and owner.db.alwaysShowOffhand then
							self:SetMinMaxValues(0, 1)
							self:SetValue(0)
							if self.Text then self.Text:SetText("0.0") end
							self:Show()
						else
							self:Hide()
						end
					end
				else
					self:Hide()
				end
			end
		end
	end
end

local function StartSwingBar(element, Bar, speed, now)
	if not Bar or not speed or speed <= 0 then return end

	element:Show()

	Bar.min = now
	Bar.max = now + speed
	Bar.speed = speed
	Bar:SetMinMaxValues(0, speed)
	Bar:SetValue(0)
	Bar:Show()
	Bar:SetScript("OnUpdate", OnDurationUpdate)

	if Bar.Spark and element.db and element.db.spark then
		Bar.Spark:Show()
	end
end

local function HideSwingBar(Bar)
	if not Bar then return end
	Bar:Hide()
	Bar:SetScript("OnUpdate", nil)
end

local function MeleeChange(self, _, unit)
	if unit ~= "player" then return end

	local element = self.Swing
	if not element then return end

	local now = GetTime()
	local newMainHandID = GetInventoryItemID("player", 16)
	local newOffHandID = GetInventoryItemID("player", 17)
	local mainSpeed, offSpeed = UnitAttackSpeed("player")

	-- Weapon / hand layout changed: clear stale timing state. The next real
	-- WeakAuras-style combat-log swing seeds the correct hand.
	if (mainHandID ~= newMainHandID) or (offHandID ~= newOffHandID) then
		for _, Bar in pairs({element.Twohand, element.Mainhand, element.Offhand}) do
			HideSwingBar(Bar)
			Bar.min, Bar.max, Bar.speed = nil, nil, nil
		end

		mainHandID, offHandID = newMainHandID, newOffHandID
		meleeing = false

		if element.db and (element.db.alwaysShowMainhand or element.db.alwaysShowOffhand) then
			ShowIdleSwingBars(element)
		end

		return
	end

	-- Haste/slow changed during an already active timer: preserve current
	-- percentage rather than restarting the swing.
	if not meleeing then return end

	local function Rescale(Bar, newSpeed)
		if not Bar or not Bar.speed or not Bar.min or not Bar.max or not newSpeed or newSpeed <= 0 then return end
		if math.abs((Bar.speed or 0) - newSpeed) < 0.001 then return end

		local oldSpeed = Bar.speed
		local elapsed = now - Bar.min
		local pct = oldSpeed > 0 and math.max(0, math.min(1, elapsed / oldSpeed)) or 0

		Bar.speed = newSpeed
		Bar.min = now - (newSpeed * pct)
		Bar.max = Bar.min + newSpeed
		Bar:SetMinMaxValues(0, newSpeed)
		Bar:SetValue(newSpeed * pct)
	end

	if offSpeed then
		Rescale(element.Mainhand, mainSpeed)
		Rescale(element.Offhand, offSpeed)
	else
		Rescale(element.Twohand, mainSpeed)
	end
end

local function RangedChange(self, _, unit)
	if unit ~= "player" then return end
	if not ranging then return end

	local element = self.Swing
	local now = GetTime()
	local newRangedID = GetInventoryItemID("player", 18)
	local speed = UnitRangedDamage("player")

	if rangedID ~= newRangedID then
		element.Twohand.speed = UnitRangedDamage(unit)
		element.Twohand.min = GetTime()
		element.Twohand.max = element.Twohand.min + element.Twohand.speed

		element.Twohand:Show()
		element.Twohand:SetMinMaxValues(element.Twohand.min - now, element.Twohand.max - now)
		element.Twohand:SetScript("OnUpdate", OnDurationUpdate)

		rangedID = newRangedID
	else
		if element.Twohand.speed ~= speed then
			local percentage = (element.Twohand.max - GetTime()) / (element.Twohand.speed)
			element.Twohand.min = now - speed * (1 - percentage)
			element.Twohand.max = now + speed * percentage
			element.Twohand.speed = speed
		end
	end
end

local function Ranged(self, _, unit, spellName)
	if unit ~= "player" then return end
	if spellName ~= GetSpellInfo(75) and spellName ~= GetSpellInfo(5019) then return end

	local element = self.Swing
	local now = GetTime()

	element:Show()

	element.Twohand.speed = UnitRangedDamage(unit)
	element.Twohand.min = GetTime()
	element.Twohand.max = element.Twohand.min + element.Twohand.speed

	element.Twohand:Show()
	element.Twohand:SetMinMaxValues(element.Twohand.min - now, element.Twohand.max - now)
	element.Twohand:SetScript("OnUpdate", OnDurationUpdate)

	element.Mainhand:Hide()
	element.Mainhand:SetScript("OnUpdate", nil)

	element.Offhand:Hide()
	element.Offhand:SetScript("OnUpdate", nil)

	meleeing, ranging = false, true
end

local skipNextAttack, skipNextAttackCount

local function HandleMeleeSwing(element, hand, now)
	local mainSpeed, offSpeed = UnitAttackSpeed("player")
	if not mainSpeed then return end

	ranging = false
	meleeing = true

	if not offSpeed then
		-- One weapon / 2H: every melee swing is the main hand.
		HideSwingBar(element.Mainhand)
		HideSwingBar(element.Offhand)
		StartSwingBar(element, element.Twohand, mainSpeed, now)
		return
	end

	-- Dual wield: WeakAuras tells the hands apart through isOffHand.
	HideSwingBar(element.Twohand)

	if hand == "off" then
		StartSwingBar(element, element.Offhand, offSpeed, now)
	else
		StartSwingBar(element, element.Mainhand, mainSpeed, now)
	end
end

local function Melee(self, eventName, ...)
	-- WeakAuras' Swing Timer logic reads Combat Log like this:
	-- timestamp, subEvent, hideCaster, sourceGUID, sourceName, sourceFlags,
	-- sourceRaidFlags, destGUID, destName, destFlags, destRaidFlags, suffix...
	local timestamp, subEvent, _, sourceGUID = ...
	if sourceGUID ~= UnitGUID("player") then return end

	local element = self.Swing
	if not element then return end

	-- The first 11 values are the common CLEU header. Everything after that
	-- is the sub-event-specific suffix.
	local function HandleSuffix(...)
		local isSwingDamage = subEvent == "SWING_DAMAGE"

		if subEvent == "SPELL_EXTRA_ATTACKS" then
			skipNextAttack = timestamp
			skipNextAttackCount = select(4, ...)
			return
		end

		if not isSwingDamage and subEvent ~= "SWING_MISSED" then
			return
		end

		-- Ignore extra-attack combat-log entries exactly like the WA logic,
		-- otherwise proc attacks can incorrectly restart the normal weapon timer.
		if tonumber(skipNextAttack)
			and (timestamp - skipNextAttack) < 0.04
			and tonumber(skipNextAttackCount)
			and skipNextAttackCount > 0
		then
			skipNextAttackCount = skipNextAttackCount - 1
			return
		end

		-- This is the important part from the working WeakAura:
		-- SWING_DAMAGE -> 10th suffix argument is isOffHand
		-- SWING_MISSED -> 2nd suffix argument is isOffHand
		local isOffHand = select(isSwingDamage and 10 or 2, ...)
		HandleMeleeSwing(element, isOffHand and "off" or "main", GetTime())
		lastHit = GetTime()
	end

	HandleSuffix(select(12, ...))
end

local function ParryHaste(self, _, ...)
	local _, subEvent, _, _, _, _, _, destGUID = ...
	if destGUID ~= UnitGUID("player") then return end
	if subEvent ~= "SWING_MISSED" then return end

	local function HandleSuffix(...)
		local missType = select(1, ...)
		if missType ~= "PARRY" then return end

		local element = self.Swing
		local _, offSpeed = UnitAttackSpeed("player")
		local Bar = offSpeed and element.Mainhand or element.Twohand
		if not Bar or not Bar.min or not Bar.max or not Bar.speed then return end

		local now = GetTime()
		local timeLeft = Bar.max - now
		if timeLeft <= 0.2 * Bar.speed then return end

		local offset = 0.4 * Bar.speed
		if timeLeft - offset < 0.2 * Bar.speed then
			offset = timeLeft - 0.2 * Bar.speed
		end

		Bar.max = Bar.max - offset
		Bar.min = Bar.max - Bar.speed
	end

	HandleSuffix(select(12, ...))
end

local function NoCombatHide(self)
	local element = self.Swing

	for _, Bar in pairs({element.Twohand, element.Mainhand, element.Offhand}) do
		Bar:Hide()
		Bar:SetScript("OnUpdate", nil)
		if Bar.Spark then Bar.Spark:Hide() end
	end

	meleeing, ranging = false, false

	if not ShowIdleSwingBars(element) then
		element:Hide()
	end
end

local function ToggleTestMode(self)
	local element = self.Swing

	if element.testMode then
		element.testMode = nil

		if not (meleeing or ranging) then
			for _, Bar in pairs({element.Twohand, element.Mainhand, element.Offhand}) do
				Bar:Hide()
			end

			if not ShowIdleSwingBars(element) then
				element:Hide()
			end
		end
	end
end

local function Enable(self, unit)
	local element = self.Swing

	if element and unit == "player" then
		for _, Bar in pairs({element.Twohand, element.Mainhand, element.Offhand}) do
			Bar.__owner = element

			if Bar:IsObjectType("StatusBar") and not Bar:GetStatusBarTexture() then
				Bar:SetStatusBarTexture([[Interface\TargetingFrame\UI-StatusBar]])
			end

			if Bar.Spark and Bar.Spark:IsObjectType("Texture") and not Bar.Spark:GetTexture() then
				Bar.Spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
			end

			if Bar.Text then
				Bar.Text:SetParent(Bar)
			end
		end

		self:RegisterEvent("UNIT_SPELLCAST_SUCCEEDED", Ranged)
		self:RegisterEvent("UNIT_RANGEDDAMAGE", RangedChange)
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", Melee)
		self:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED", ParryHaste)
		self:RegisterEvent("UNIT_ATTACK_SPEED", MeleeChange)
		self:RegisterEvent("PLAYER_REGEN_ENABLED", NoCombatHide)
		self:RegisterEvent("PLAYER_REGEN_DISABLED", ToggleTestMode)

		return true
	end
end

local function Disable(self)
	local element = self.Swing

	if element then
		self:UnregisterEvent("UNIT_SPELLCAST_SUCCEEDED", Ranged)
		self:UnregisterEvent("UNIT_RANGEDDAMAGE", RangedChange)
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED", Melee)
		self:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED", ParryHaste)
		self:UnregisterEvent("UNIT_ATTACK_SPEED", MeleeChange)
		self:UnregisterEvent("PLAYER_REGEN_ENABLED", NoCombatHide)
		self:UnregisterEvent("PLAYER_REGEN_DISABLED", ToggleTestMode)

		element:Hide()
	end
end

ElvUF:AddElement("Swing", nil, Enable, Disable)

function UF:Construct_Swingbar(frame)
	local frameName = frame:GetName()
	local swingbar = CreateFrame("Frame", frameName.."SwingBar", frame)
	swingbar:SetFrameLevel(frame.RaisedElementParent:GetFrameLevel() + 30)
	swingbar:SetClampedToScreen(true)

	swingbar.MainhandHolder = CreateFrame("Frame", nil, swingbar)
	swingbar.MainhandHolder:Size(270, 20)
	swingbar.MainhandHolder:Point("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -36)

	swingbar.OffhandHolder = CreateFrame("Frame", nil, swingbar)
	swingbar.OffhandHolder:Size(270, 20)
	swingbar.OffhandHolder:Point("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -62)

	E:CreateMover(
		swingbar.MainhandHolder,
		frameName.."SwingMainhandMover",
		"Player Swing Timer Mainhand",
		nil,
		-6,
		nil,
		"ALL,SOLO",
		nil,
		"unitframe,player,swingbar"
	)

	E:CreateMover(
		swingbar.OffhandHolder,
		frameName.."SwingOffhandMover",
		"Player Swing Timer Offhand",
		nil,
		-6,
		nil,
		"ALL,SOLO",
		nil,
		"unitframe,player,swingbar"
	)

	swingbar.Holder = swingbar.MainhandHolder

	swingbar.Twohand = CreateFrame("StatusBar", frameName.."SwingBar_Twohand", swingbar)
	swingbar.Mainhand = CreateFrame("StatusBar", frameName.."SwingBar_Mainhand", swingbar)
	swingbar.Offhand = CreateFrame("StatusBar", frameName.."SwingBar_Offhand", swingbar)

	for _, Bar in pairs({swingbar.Twohand, swingbar.Mainhand, swingbar.Offhand}) do
		UF.statusbars[Bar] = true
		Bar:CreateBackdrop("Default", nil, nil, self.thinBorders, true)
		Bar:Hide()

		Bar.bg = Bar:CreateTexture(nil, "BORDER")
		Bar.bg:SetAllPoints(Bar)
		Bar.bg:SetTexture(E.media.blankTex)

		Bar.Spark = Bar:CreateTexture(nil, "OVERLAY")
		Bar.Spark:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
		Bar.Spark:SetBlendMode("ADD")
		Bar.Spark:SetVertexColor(1, 1, 1)
		Bar.Spark:Size(20, 40)

		Bar.Text = swingbar:CreateFontString(nil, "OVERLAY")
	end

	return swingbar
end

local function ApplySwingFill(Bar, db)
	local fillTexture = LSM:Fetch("statusbar", db.texture or "ElvUI Norm") or E.media.normTex
	local backgroundTexture = LSM:Fetch("statusbar", db.backgroundTexture or "ElvUI Norm") or E.media.blankTex or E.media.normTex

	Bar:SetStatusBarTexture(fillTexture)
	Bar.bg:SetTexture(backgroundTexture)

	local base = db.color or {r = 0.31, g = 0.31, b = 0.31}
	local second = (db.gradient and db.gradientColor) or base
	local texture = Bar:GetStatusBarTexture()
	local orientation = db.verticalOrientation and "VERTICAL" or "HORIZONTAL"

	Bar:SetStatusBarColor(1, 1, 1, 1)
	if texture and texture.SetGradientAlpha then
		texture:SetGradientAlpha(
			orientation,
			base.r or 1, base.g or 1, base.b or 1, 1,
			second.r or 1, second.g or 1, second.b or 1, 1
		)
	else
		Bar:SetStatusBarColor(base.r or 1, base.g or 1, base.b or 1, 1)
	end

	local bg = db.backdropColor or {r = 0.31, g = 0.31, b = 0.31}
	Bar.bg:SetVertexColor((bg.r or 1) * 0.35, (bg.g or 1) * 0.35, (bg.b or 1) * 0.35)
end

function UF:Configure_Swingbar(frame)
	local swingbar = frame.Swing
	local db = frame.db and frame.db.swingbar
	if not swingbar or not db then return end

	swingbar.db = db

	if db.enable then
		if not frame:IsElementEnabled("Swing") then
			frame:EnableElement("Swing")
		end

		swingbar:Show()

		local barWidth = math.max(5, db.width - (E.Border * 2))
		local barHeight = math.max(5, db.height)

		swingbar.MainhandHolder:Size(db.width, db.height + E.Border * 2)
		swingbar.OffhandHolder:Size(db.width, db.height + E.Border * 2)

		for _, holder in pairs({swingbar.MainhandHolder, swingbar.OffhandHolder}) do
			if holder:GetScript("OnSizeChanged") then
				holder:GetScript("OnSizeChanged")(holder)
			end
		end

		swingbar.Twohand:ClearAllPoints()
		swingbar.Mainhand:ClearAllPoints()
		swingbar.Offhand:ClearAllPoints()

		swingbar.Twohand:Size(barWidth, barHeight)
		swingbar.Mainhand:Size(barWidth, barHeight)
		swingbar.Offhand:Size(barWidth, barHeight)

		swingbar.Twohand:Point("CENTER", swingbar.MainhandHolder, "CENTER")
		swingbar.Mainhand:Point("CENTER", swingbar.MainhandHolder, "CENTER")
		swingbar.Offhand:Point("CENTER", swingbar.OffhandHolder, "CENTER")

		for _, Bar in pairs({swingbar.Twohand, swingbar.Mainhand, swingbar.Offhand}) do
			Bar:SetOrientation(db.verticalOrientation and "VERTICAL" or "HORIZONTAL")
			ApplySwingFill(Bar, db)

			if db.spark then
				if db.verticalOrientation then
					Bar.Spark:Width(db.width)
					Bar.Spark:Height(10)
				else
					Bar.Spark:Height(db.height / 1.2)
					Bar.Spark:Width(20)
				end

				Bar.Spark:ClearAllPoints()
				if db.verticalOrientation then
					Bar.Spark:Point("CENTER", Bar:GetStatusBarTexture(), "TOP")
				else
					Bar.Spark:Point("CENTER", Bar:GetStatusBarTexture(), "RIGHT")
				end
				Bar.Spark:Show()
			else
				Bar.Spark:Hide()
			end

			local x, y = self:GetPositionOffset(db.text.position)
			local textColor = db.text.color

			Bar.Text:ClearAllPoints()
			Bar.Text:Point(db.text.position, Bar, db.text.position, x + db.text.xOffset, y + db.text.yOffset)
			Bar.Text:FontTemplate(LSM:Fetch("font", db.text.font), db.text.fontSize, db.text.fontOutline)
			Bar.Text:SetTextColor(textColor.r, textColor.g, textColor.b)

			if db.text.enable then
				Bar.Text:Show()
			else
				Bar.Text:Hide()
			end
		end

		E:EnableMover(frame:GetName().."SwingMainhandMover")
		E:EnableMover(frame:GetName().."SwingOffhandMover")

		if (db.alwaysShowMainhand or db.alwaysShowOffhand) and not (meleeing or ranging) and not swingbar.testMode then
			ShowIdleSwingBars(swingbar)
		elseif not (meleeing or ranging) and not swingbar.testMode then
			for _, Bar in pairs({swingbar.Twohand, swingbar.Mainhand, swingbar.Offhand}) do
				Bar:Hide()
			end
		end
	else
		if frame:IsElementEnabled("Swing") then
			frame:DisableElement("Swing")
		end

		swingbar:Hide()
		E:DisableMover(frame:GetName().."SwingMainhandMover")
		E:DisableMover(frame:GetName().."SwingOffhandMover")
	end

	local Skins = E:GetModule("Skins", true)
	if Skins and Skins.Initialized and Skins.UpdateFrameShadow then
		Skins:UpdateFrameShadow("swingtimer")
	end
end
