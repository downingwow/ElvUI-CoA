local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local UF = E:GetModule("UnitFrames")
local LSM = E.Libs.LSM

--Lua functions
local unpack = unpack
local abs, min = math.abs, math.min
--WoW API / Variables
local CreateFrame = CreateFrame
local UnitIsPlayer = UnitIsPlayer
local UnitReaction = UnitReaction
local UnitCanAttack = UnitCanAttack

local _, ns = ...
local ElvUF = ns.oUF
assert(ElvUF, "ElvUI was unable to locate oUF.")

local INVERT_ANCHORPOINT = {
	TOPLEFT = "BOTTOMRIGHT",
	LEFT = "RIGHT",
	BOTTOMLEFT = "TOPRIGHT",
	RIGHT = "LEFT",
	TOPRIGHT = "BOTTOMLEFT",
	BOTTOMRIGHT = "TOPLEFT",
	CENTER = "CENTER",
	TOP = "BOTTOM",
	BOTTOM = "TOP"
}

local ticks = {}


-- Size a castbar docked into the InfoPanel from the InfoPanel's real visible width.
-- This is important when "Outside Portrait" shortens the panel: the old 3.3.5 client
-- can otherwise keep the castbar's previous explicit width for a frame and the fill/spark
-- briefly render underneath the portrait.
local function DockCastbarToInfoPanel(frame, castbar, db, iconInsidePortrait)
	local panel = frame and frame.InfoPanel
	if not panel then return end

	local panelWidth = panel:GetWidth() or 0

	-- Fallback for the first layout pass, before GetWidth() has resolved the two anchors.
	if panelWidth <= 1 then
		local frameWidth = frame.UNIT_WIDTH or frame:GetWidth() or db.width or 1
		local leftInset = frame.BORDER + frame.SPACING
		local rightInset = frame.BORDER + frame.SPACING
		local outsidePortrait = db.infoPanel
			and db.infoPanel.outsidePortrait
			and frame.USE_PORTRAIT
			and not frame.USE_PORTRAIT_OVERLAY
			and frame.PORTRAIT_WIDTH
			and frame.PORTRAIT_WIDTH > 0

		if outsidePortrait then
			if frame.ORIENTATION == "LEFT" then
				leftInset = frame.PORTRAIT_WIDTH + frame.BORDER + frame.SPACING
			elseif frame.ORIENTATION == "RIGHT" then
				rightInset = frame.PORTRAIT_WIDTH + frame.BORDER + frame.SPACING
			end
		end

		panelWidth = frameWidth - leftInset - rightInset
	end

	local castLeft = 0
	local castRight = 0

	-- An attached cast icon lives inside the InfoPanel's horizontal space.
	if not iconInsidePortrait and db.castbar.icon and db.castbar.iconAttached and castbar.Icon and castbar.Icon.bg then
		local iconWidth = (castbar.Icon.bg:GetWidth() or 0) - frame.BORDER
		if iconWidth < 0 then iconWidth = 0 end
		local iconSpace = iconWidth + frame.SPACING * 3
		if frame.ORIENTATION == "RIGHT" then
			castRight = iconSpace
		else
			castLeft = iconSpace
		end
	end

	local castWidth = panelWidth - castLeft - castRight
	if castWidth < 1 then castWidth = 1 end

	-- Use vertical anchors + an explicit calculated width. This avoids carrying the old
	-- db.castbar.width into the first rendered frame after the InfoPanel became narrower.
	castbar:ClearAllPoints()
	castbar:Point("TOPLEFT", panel, "TOPLEFT", castLeft, 0)
	castbar:Point("BOTTOMLEFT", panel, "BOTTOMLEFT", castLeft, 0)
	castbar:Width(castWidth)
end

local function DefaultCastGradientEnd(r, g, b)
	return r + ((1-r) * 0.18), g + ((1-g) * 0.18), b + ((1-b) * 0.18)
end

local function ApplyCastGradient(statusbar, colorKey, r, g, b)
	local texture = statusbar:GetStatusBarTexture()
	if not texture or not texture.SetGradientAlpha then return end

	local colors = UF.db.colors
	local saved = colorKey and colors.castGradientColors and colors.castGradientColors[colorKey]
	local er, eg, eb
	if saved then
		er, eg, eb = saved.r, saved.g, saved.b
	else
		er, eg, eb = DefaultCastGradientEnd(r, g, b)
	end

	statusbar:SetStatusBarColor(1, 1, 1, 1)
	if statusbar.__reverseFill then
		texture:SetGradientAlpha('HORIZONTAL', er, eg, eb, 1, r, g, b, 1)
	else
		texture:SetGradientAlpha('HORIZONTAL', r, g, b, 1, er, eg, eb, 1)
	end
	-- Keep the castbar backdrop based on the real base color. SetStatusBarColor(1,1,1)
	-- is required for the gradient texture but would otherwise make the backdrop white/grey.
	UF.UpdateBackdropTextureColor(statusbar, r, g, b)
	statusbar.__ElvUICastGradientApplied = true
end


local function GetClassCastGradient(unit, fallbackR, fallbackG, fallbackB)
	if not UF.db.colors.castGradientClassColor or not UnitIsPlayer(unit) then return fallbackR, fallbackG, fallbackB end

	local _, class = UnitClass(unit)
	if not class then return fallbackR, fallbackG, fallbackB end

	local colors = UF.db.colors
	local base = colors.healthGradientBaseColors and colors.healthGradientBaseColors.class and colors.healthGradientBaseColors.class[class]
	local finish = colors.healthGradientColors and colors.healthGradientColors.class and colors.healthGradientColors.class[class]

	local br, bg, bb = fallbackR, fallbackG, fallbackB
	if base then br, bg, bb = base.r, base.g, base.b end

	local er, eg, eb
	if finish then
		er, eg, eb = finish.r, finish.g, finish.b
	else
		er, eg, eb = DefaultCastGradientEnd(br, bg, bb)
	end

	return br, bg, bb, er, eg, eb
end

local function ApplyClassCastGradient(statusbar, unit, r, g, b)
	local texture = statusbar:GetStatusBarTexture()
	if not texture or not texture.SetGradientAlpha then return false end

	local br, bg, bb, er, eg, eb = GetClassCastGradient(unit, r, g, b)
	if not er then return false end

	statusbar:SetStatusBarColor(1, 1, 1, 1)
	if statusbar.__reverseFill then
		texture:SetGradientAlpha('HORIZONTAL', er, eg, eb, 1, br, bg, bb, 1)
	else
		texture:SetGradientAlpha('HORIZONTAL', br, bg, bb, 1, er, eg, eb, 1)
	end
	-- Match the normal Class Castbar backdrop when no custom backdrop is selected.
	-- UF:UpdateBackdropTextureColor also preserves Custom Backdrop when it is enabled.
	UF.UpdateBackdropTextureColor(statusbar, br, bg, bb)
	statusbar.__ElvUICastGradientApplied = true
	return true
end

local function ClearCastGradient(statusbar, r, g, b)
	if not statusbar.__ElvUICastGradientApplied then return end
	local texture = statusbar:GetStatusBarTexture()
	if texture and texture.SetGradientAlpha then
		texture:SetGradientAlpha('HORIZONTAL', 1, 1, 1, 1, 1, 1, 1, 1)
	end
	statusbar:SetStatusBarColor(r, g, b)
	statusbar.__ElvUICastGradientApplied = nil
end

function UF:Construct_Castbar(frame, moverName)
	local castbar = CreateFrame("StatusBar", nil, frame)
	castbar:SetFrameLevel(frame.RaisedElementParent:GetFrameLevel() + 30) --Make it appear above everything else
	self.statusbars[castbar] = true
	castbar.CustomDelayText = self.CustomCastDelayText
	castbar.CustomTimeText = self.CustomTimeText
	castbar.PostCastStart = self.PostCastStart
	castbar.PostCastStop = self.PostCastStop
	castbar.PostCastInterruptible = self.PostCastInterruptible
	castbar:SetClampedToScreen(true)
	castbar:CreateBackdrop(nil, nil, nil, self.thinBorders, true)

	castbar.Time = castbar:CreateFontString(nil, "OVERLAY")
	self:Configure_FontString(castbar.Time)
	castbar.Time.__ElvUICastbarOwner = frame
	castbar.Time:Point("RIGHT", castbar, "RIGHT", -4, 0)
	castbar.Time:SetTextColor(0.84, 0.75, 0.65)
	castbar.Time:SetJustifyH("RIGHT")

	castbar.Text = castbar:CreateFontString(nil, "OVERLAY")
	self:Configure_FontString(castbar.Text)
	castbar.Text.__ElvUICastbarOwner = frame
	castbar.Text:Point("LEFT", castbar, "LEFT", 4, 0)
	castbar.Text:SetTextColor(0.84, 0.75, 0.65)
	castbar.Text:SetJustifyH("LEFT")
	castbar.Text:SetWordWrap(false)

	castbar.Spark_ = castbar:CreateTexture(nil, "OVERLAY")
	castbar.Spark_:SetTexture([[Interface\CastingBar\UI-CastingBar-Spark]])
	castbar.Spark_:SetBlendMode("ADD")
	castbar.Spark_:SetVertexColor(1, 1, 1)
	castbar.Spark_:Size(20, 40)

	--Set to castbar.SafeZone
	castbar.LatencyTexture = castbar:CreateTexture(nil, "OVERLAY")
	castbar.LatencyTexture:SetTexture(E.media.blankTex)
	castbar.LatencyTexture:SetVertexColor(0.69, 0.31, 0.31, 0.75)

	castbar.bg = castbar:CreateTexture(nil, "BORDER")
	castbar.bg:SetAllPoints()
	castbar.bg:SetTexture(E.media.blankTex)
	castbar.bg:Show()

	local button = CreateFrame("Frame", nil, castbar)
	local holder = CreateFrame("Frame", nil, castbar)
	button:SetTemplate(nil, nil, nil, self.thinBorders, true)

	castbar.Holder = holder
	--these are placeholder so the mover can be created.. it will be changed.
	castbar.Holder:Point("TOPLEFT", frame, "BOTTOMLEFT", 0, -(frame.BORDER - frame.SPACING))
	castbar:Point("BOTTOMLEFT", castbar.Holder, "BOTTOMLEFT", frame.BORDER, frame.BORDER)
	button:Point("RIGHT", castbar, "LEFT", -E.Spacing*3, 0)

	if moverName then
		local name = frame:GetName()
		local configName = string.lower(string.gsub(name, "^ElvUF_", ""))
		E:CreateMover(castbar.Holder, name.."CastbarMover", moverName, nil, -6, nil, "ALL,SOLO", nil, "unitframe,"..configName..",castbar")
	end

	local icon = button:CreateTexture(nil, "ARTWORK")
	local offset = frame.BORDER --use frame.BORDER since it may be different from E.Border due to forced thin borders
	icon:SetInside(nil, offset, offset)
	icon.bg = button

	--Set to castbar.Icon
	castbar.ButtonIcon = icon

	return castbar
end

function UF:Configure_Castbar(frame)
	if not frame.VARIABLES_SET then return end
	local castbar = frame.Castbar
	local db = frame.db

	-- Per-unit Castbar texture. Falls back to the global UnitFrame statusbar texture.
	castbar.__ElvUIStatusBarTextureName = db.castbar and db.castbar.texture or nil
	local castTexture = LSM:Fetch("statusbar", castbar.__ElvUIStatusBarTextureName or self.db.statusbar) or E.media.normTex or E.media.blankTex
	castbar:SetStatusBarTexture(castTexture)

	-- Reverse Fill (Cast fuellt von rechts nach links); muss vor allen Textur-Ankern stehen
	UF:SetupReverseFill(castbar, db.castbar and db.castbar.reverseFill, false)

	if db.castbar.enable then
		if not frame:IsElementEnabled("Castbar") then
			frame:EnableElement("Castbar")
		end

		castbar:Width(db.castbar.width - ((frame.BORDER+frame.SPACING)*2))
		castbar:Height(db.castbar.height - ((frame.BORDER+frame.SPACING)*2))
		castbar.Holder:Width(db.castbar.width)
		castbar.Holder:Height(db.castbar.height)

		local color = E.db.unitframe.colors.borderColor
		castbar.ButtonIcon.bg:SetBackdropBorderColor(color.r, color.g, color.b)

		local oSC = castbar.Holder:GetScript("OnSizeChanged")
		if oSC then oSC(castbar.Holder) end

		if db.castbar.strataAndLevel and db.castbar.strataAndLevel.useCustomStrata then
			castbar:SetFrameStrata(db.castbar.strataAndLevel.frameStrata)
		end

		if db.castbar.strataAndLevel and db.castbar.strataAndLevel.useCustomLevel then
			castbar:SetFrameLevel(db.castbar.strataAndLevel.frameLevel)
		end

		castbar.timeToHold = db.castbar.timeToHold

		-- Per-unit castbar text styling (Pdy / CoA)
		local castFont = LSM:Fetch("font", db.castbar.font or UF.db.font)
		local castFontSize = db.castbar.fontSize or UF.db.fontSize or 12
		local castFontOutline = db.castbar.fontOutline or UF.db.fontOutline or "OUTLINE"
		castbar.Text:FontTemplate(castFont, castFontSize, castFontOutline)
		castbar.Time:FontTemplate(castFont, castFontSize, castFontOutline)

		local textColor = db.castbar.textColor
		if textColor then
			castbar.Text:SetTextColor(textColor.r or 0.84, textColor.g or 0.75, textColor.b or 0.65)
			castbar.Time:SetTextColor(textColor.r or 0.84, textColor.g or 0.75, textColor.b or 0.65)
		else
			castbar.Text:SetTextColor(0.84, 0.75, 0.65)
			castbar.Time:SetTextColor(0.84, 0.75, 0.65)
		end

		-- Text und Zeit tauschen (Zeit links, Name rechts)
		castbar.Text:ClearAllPoints()
		castbar.Time:ClearAllPoints()
		if db.castbar.swapText then
			castbar.Text:Point("RIGHT", castbar, "RIGHT", -4, 0)
			castbar.Text:SetJustifyH("RIGHT")
			castbar.Time:Point("LEFT", castbar, "LEFT", 4, 0)
			castbar.Time:SetJustifyH("LEFT")
		else
			castbar.Text:Point("LEFT", castbar, "LEFT", 4, 0)
			castbar.Text:SetJustifyH("LEFT")
			castbar.Time:Point("RIGHT", castbar, "RIGHT", -4, 0)
			castbar.Time:SetJustifyH("RIGHT")
		end

		--Latency
		if db.castbar.latency then
			castbar.SafeZone = castbar.LatencyTexture
			castbar.LatencyTexture:Show()
		else
			castbar.SafeZone = nil
			castbar.LatencyTexture:Hide()
		end

		local iconInsidePortrait = db.castbar.iconInsidePortrait
			and db.castbar.insideInfoPanel
			and frame.USE_INFO_PANEL
			and db.castbar.icon
			and frame.USE_PORTRAIT
			and (UF:IsPortraitDetached(frame, db) or not frame.USE_PORTRAIT_OVERLAY)
			and frame.Portrait
			and frame.Portrait.backdrop

		--Icon
		if db.castbar.icon then
			castbar.Icon = castbar.ButtonIcon
			castbar.Icon:SetTexCoord(unpack(E.TexCoords))

			if iconInsidePortrait then
				-- The portrait frame defines the icon size; keep the full castbar width.
			elseif not db.castbar.iconAttached then
				castbar.Icon.bg:Size(db.castbar.iconSize)
			else
				if db.castbar.insideInfoPanel and frame.USE_INFO_PANEL then
					castbar.Icon.bg:Size(db.infoPanel.height - frame.SPACING*2)
				else
					castbar.Icon.bg:Size(db.castbar.height - frame.SPACING*2)
				end

				castbar:Width(db.castbar.width - castbar.Icon.bg:GetWidth() - (frame.BORDER + frame.SPACING*5))
			end

			castbar.Icon.bg:Show()
		else
			castbar.ButtonIcon.bg:Hide()
			castbar.Icon = nil
		end

		if db.castbar.spark then
			castbar.Spark = castbar.Spark_
			castbar.Spark:ClearAllPoints()
			castbar.Spark:Point("CENTER", castbar:GetStatusBarTexture(), castbar.__reverseFill and "LEFT" or "RIGHT", 0, 0)
			castbar.Spark:Height(db.castbar.height * 2)
		elseif castbar.Spark then
			castbar.Spark:Hide()
			castbar.Spark = nil
		end

		castbar:ClearAllPoints()
		if db.castbar.insideInfoPanel and frame.USE_INFO_PANEL then
			DockCastbarToInfoPanel(frame, castbar, db, iconInsidePortrait)

			if db.castbar.spark then
				castbar.Spark:Height(db.infoPanel and db.infoPanel.height * 2) -- Grab the height from the infopanel.
			end

			if castbar.Holder.mover then
				E:DisableMover(castbar.Holder.mover:GetName())
			end
		else
			local isMoved = E:HasMoverBeenMoved(frame:GetName().."CastbarMover") or not castbar.Holder.mover
			if not isMoved then
				castbar.Holder.mover:ClearAllPoints()
			end

			castbar:ClearAllPoints()
			if frame.ORIENTATION ~= "RIGHT" then
				castbar:Point("BOTTOMRIGHT", castbar.Holder, "BOTTOMRIGHT", -(frame.BORDER+frame.SPACING), frame.BORDER+frame.SPACING)
				if not isMoved then
					castbar.Holder.mover:Point("TOPRIGHT", frame, "BOTTOMRIGHT", 0, -(frame.BORDER - frame.SPACING))
				end
			else
				castbar:Point("BOTTOMLEFT", castbar.Holder, "BOTTOMLEFT", frame.BORDER+frame.SPACING, frame.BORDER+frame.SPACING)
				if not isMoved then
					castbar.Holder.mover:Point("TOPLEFT", frame, "BOTTOMLEFT", 0, -(frame.BORDER - frame.SPACING))
				end
			end

			if castbar.Holder.mover then
				E:EnableMover(castbar.Holder.mover:GetName())
			end
		end

		if iconInsidePortrait and db.castbar.icon then
			castbar.Icon.bg:ClearAllPoints()
			castbar.Icon.bg:SetAllPoints(frame.Portrait.backdrop)
			castbar.Icon.bg:SetFrameLevel(castbar:GetFrameLevel() + 1)
		elseif not db.castbar.iconAttached and db.castbar.icon then
			local attachPoint = db.castbar.iconAttachedTo == "Frame" and frame or frame.Castbar
			local anchorPoint = db.castbar.iconPosition
			castbar.Icon.bg:ClearAllPoints()
			castbar.Icon.bg:Point(INVERT_ANCHORPOINT[anchorPoint], attachPoint, anchorPoint, db.castbar.iconXOffset, db.castbar.iconYOffset)
		elseif db.castbar.icon then
			castbar.Icon.bg:ClearAllPoints()
			if frame.ORIENTATION == "RIGHT" then
				castbar.Icon.bg:Point("LEFT", castbar, "RIGHT", frame.SPACING*3, 0)
			else
				castbar.Icon.bg:Point("RIGHT", castbar, "LEFT", -frame.SPACING*3, 0)
			end
		end

		--Adjust tick heights
		castbar.tickHeight = castbar:GetHeight()

		if db.castbar.ticks then --Only player unitframe has this
			--Set tick width and color
			castbar.tickWidth = db.castbar.tickWidth
			castbar.tickColor = db.castbar.tickColor

			for i = 1, #ticks do
				ticks[i]:SetVertexColor(castbar.tickColor.r, castbar.tickColor.g, castbar.tickColor.b, castbar.tickColor.a)
				ticks[i]:Width(castbar.tickWidth)
			end
		end

		castbar.custom_backdrop = UF.db.colors.customcastbarbackdrop and UF.db.colors.castbar_backdrop
		UF:ToggleTransparentStatusBar(UF.db.colors.transparentCastbar, castbar, castbar.bg, nil, UF.db.colors.invertCastbar)
	else
		if not db.castbar.enable and frame:IsElementEnabled("Castbar") then
			frame:DisableElement("Castbar")

			if castbar.Holder.mover then
				E:DisableMover(castbar.Holder.mover:GetName())
			end
		end
	end
end

function UF:CustomCastDelayText(duration)
	local db = self:GetParent().db
	if not (db and db.castbar) then return end
	db = db.castbar.format

	if self.channeling then
		if db == "CURRENT" then
			self.Time:SetFormattedText("%.1f |cffaf5050%.2f|r", abs(duration - self.max), self.delay)
		elseif db == "CURRENTMAX" then
			self.Time:SetFormattedText("%.1f / %.2f |cffaf5050%.2f|r", abs(duration - self.max), self.max, self.delay)
		elseif db == "REMAINING" then
			self.Time:SetFormattedText("%.1f |cffaf5050%.2f|r", duration, self.delay)
		elseif db == "REMAININGMAX" then
			self.Time:SetFormattedText("%.1f / %.2f |cffaf5050%.2f|r", duration, self.max, self.delay)
		end
	else
		if db == "CURRENT" then
			self.Time:SetFormattedText("%.1f |cffaf5050%s %.2f|r", duration, "+", self.delay)
		elseif db == "CURRENTMAX" then
			self.Time:SetFormattedText("%.1f / %.2f |cffaf5050%s %.2f|r", duration, self.max, "+", self.delay)
		elseif db == "REMAINING" then
			self.Time:SetFormattedText("%.1f |cffaf5050%s %.2f|r", abs(duration - self.max), "+", self.delay)
		elseif db == "REMAININGMAX" then
			self.Time:SetFormattedText("%.1f / %.2f |cffaf5050%s %.2f|r", abs(duration - self.max), self.max, "+", self.delay)
		end
	end
end

function UF:CustomTimeText(duration)
	local db = self:GetParent().db
	if not (db and db.castbar) then return end
	db = db.castbar.format

	if self.channeling then
		if db == "CURRENT" then
			self.Time:SetFormattedText("%.1f", abs(duration - self.max))
		elseif db == "CURRENTMAX" then
			self.Time:SetFormattedText("%.1f / %.2f", abs(duration - self.max), self.max)
		elseif db == "REMAINING" then
			self.Time:SetFormattedText("%.1f", duration)
		elseif db == "REMAININGMAX" then
			self.Time:SetFormattedText("%.1f / %.2f", duration, self.max)
		end
	else
		if db == "CURRENT" then
			self.Time:SetFormattedText("%.1f", duration)
		elseif db == "CURRENTMAX" then
			self.Time:SetFormattedText("%.1f / %.2f", duration, self.max)
		elseif db == "REMAINING" then
			self.Time:SetFormattedText("%.1f", abs(duration - self.max))
		elseif db == "REMAININGMAX" then
			self.Time:SetFormattedText("%.1f / %.2f", abs(duration - self.max), self.max)
		end
	end
end

function UF:HideTicks()
	for i = 1, #ticks do
		ticks[i]:Hide()
	end
end

function UF:SetCastTicks(frame, numTicks)
	UF:HideTicks()
	if numTicks and numTicks <= 0 then return end
	local w = frame:GetWidth()
	local d = w / numTicks

	for i = 1, numTicks do
		if not ticks[i] then
			ticks[i] = frame:CreateTexture(nil, "OVERLAY")
			ticks[i]:SetTexture(E.media.normTex)
			E:RegisterStatusBar(ticks[i])
			ticks[i]:SetVertexColor(frame.tickColor.r, frame.tickColor.g, frame.tickColor.b, frame.tickColor.a)
			ticks[i]:Width(frame.tickWidth)
		end

		ticks[i]:Height(frame.tickHeight)
		ticks[i]:ClearAllPoints()
		if frame.__reverseFill then
			ticks[i]:Point("LEFT", frame, "RIGHT", -d * i, 0)
		else
			ticks[i]:Point("RIGHT", frame, "LEFT", d * i, 0)
		end
		ticks[i]:Show()
	end
end

function UF:PostCastStart(unit)
	local db = self:GetParent().db
	if not db or not db.castbar then return end

	if unit == "vehicle" then unit = "player" end

	if db.castbar.displayTarget and self.curTarget then
		self.Text:SetText(self.spellName.." > "..self.curTarget)
	end

	-- Get length of Time, then calculate available length for Text
	local timeWidth = self.Time:GetStringWidth()
	local textWidth = self:GetWidth() - timeWidth - 10
	local textStringWidth = self.Text:GetStringWidth()

	if timeWidth == 0 or textStringWidth == 0 then
		E:Delay(0.05, function() -- Delay may need tweaking
			textWidth = self:GetWidth() - self.Time:GetStringWidth() - 10
			textStringWidth = self.Text:GetStringWidth()
			if textWidth > 0 then self.Text:Width(min(textWidth, textStringWidth)) end
		end)
	else
		self.Text:Width(min(textWidth, textStringWidth))
	end

	self.unit = unit

	-- Latenz-Zone auf die gespiegelte Seite setzen (oUF verankert sie fuer die normale Richtung)
	local safeZone = self.SafeZone
	if safeZone and self.__reverseFill and self:GetOrientation() == "HORIZONTAL" then
		safeZone:ClearAllPoints()
		safeZone:SetPoint("TOP")
		safeZone:SetPoint("BOTTOM")
		safeZone:SetPoint(self.casting and "LEFT" or "RIGHT")
	end

	if self.channeling and db.castbar.ticks and unit == "player" then
		local unitframe = E.global.unitframe
		local baseTicks = unitframe.ChannelTicks[self.spellName]

		if baseTicks then
			UF:SetCastTicks(self, baseTicks)
			self.hadTicks = true
		else
			UF:HideTicks()
		end
	end

	local colors = ElvUF.colors
	local r, g, b = colors.castColor[1], colors.castColor[2], colors.castColor[3]
	local gradientKey = 'castColor'

	if (self.notInterruptible and unit ~= "player") and UnitCanAttack("player", unit) then
		r, g, b = colors.castNoInterrupt[1], colors.castNoInterrupt[2], colors.castNoInterrupt[3]
		gradientKey = 'castNoInterrupt'
	elseif UF.db.colors.castClassColor and UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		local t = UnitIsUnit("player", unit) and E.media.herocolor or RAID_CLASS_COLORS[class]
		if t then r, g, b = t.r, t.g, t.b end
		gradientKey = nil
	elseif UF.db.colors.castReactionColor then
		local Reaction = UnitReaction(unit, "player")
		local t = Reaction and ElvUF.colors.reaction[Reaction]
		if t then r, g, b = t[1], t[2], t[3] end
		gradientKey = nil
	end

	self:SetStatusBarColor(r, g, b)
	if UF.db.colors.castGradient then
		if gradientKey == nil and UF.db.colors.castClassColor and UnitIsPlayer(unit) and UF.db.colors.castGradientClassColor then
			if not ApplyClassCastGradient(self, unit, r, g, b) then ApplyCastGradient(self, gradientKey, r, g, b) end
		else
			ApplyCastGradient(self, gradientKey, r, g, b)
		end
	else
		ClearCastGradient(self, r, g, b)
	end
end

function UF:PostCastStop(unit)
	if self.hadTicks and unit == "player" then
		UF:HideTicks()
		self.hadTicks = false
	end
end

function UF:PostCastInterruptible(unit)
	if unit == "vehicle" or unit == "player" then return end

	local colors = ElvUF.colors
	local r, g, b = colors.castColor[1], colors.castColor[2], colors.castColor[3]
	local gradientKey = 'castColor'

	if self.notInterruptible and UnitCanAttack("player", unit) then
		r, g, b = colors.castNoInterrupt[1], colors.castNoInterrupt[2], colors.castNoInterrupt[3]
		gradientKey = 'castNoInterrupt'
	elseif UF.db.colors.castClassColor and UnitIsPlayer(unit) then
		local _, class = UnitClass(unit)
		local t = UnitIsUnit("player", unit) and E.media.herocolor or RAID_CLASS_COLORS[class]
		if t then r, g, b = t.r, t.g, t.b end
		gradientKey = nil
	elseif UF.db.colors.castReactionColor then
		local Reaction = UnitReaction(unit, "player")
		local t = Reaction and ElvUF.colors.reaction[Reaction]
		if t then r, g, b = t[1], t[2], t[3] end
		gradientKey = nil
	end

	self:SetStatusBarColor(r, g, b)
	if UF.db.colors.castGradient then
		if gradientKey == nil and UF.db.colors.castClassColor and UnitIsPlayer(unit) and UF.db.colors.castGradientClassColor then
			if not ApplyClassCastGradient(self, unit, r, g, b) then ApplyCastGradient(self, gradientKey, r, g, b) end
		else
			ApplyCastGradient(self, gradientKey, r, g, b)
		end
	else
		ClearCastGradient(self, r, g, b)
	end
end