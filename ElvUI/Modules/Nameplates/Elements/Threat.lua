local E, L, V, P, G = unpack(ElvUI)
local NP = E:GetModule('NamePlates')

local UnitName = UnitName
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit

NP.ThreatPets = {
}

function NP:ThreatIndicator_PreUpdate(unit, pass)
	local nameplate, db, unitTarget, imTank = self.__owner, NP.db.threat, unit..'target', E.myrole == 'TANK' or NP.GroupRoles[E.myname] == 'TANK'
	local unitRole = NP.IsInGroup and (UnitExists(unitTarget) and not UnitIsUnit(unitTarget, 'player')) and NP.GroupRoles[UnitName(unitTarget)] or 'NONE'
	local unitTank = unitRole == 'TANK' or (db.beingTankedByPet and NP.ThreatPets[NP:UnitNPCID(unitTarget)])
	local isTank, offTank, feedbackUnit = unitTank or imTank, db.beingTankedByTank and (unitTank and imTank) or false, (unitTank and unitTarget) or 'player'

	nameplate.ThreatScale = nil

	if pass then
		return isTank, offTank, feedbackUnit
	else
		self.feedbackUnit = feedbackUnit
		self.offTank = offTank
		self.isTank = isTank
	end
end

function NP:ThreatIndicator_PostUpdate(unit, status)
	local nameplate, colors, db = self.__owner, NP.db.colors.threat, NP.db.threat
	local sf = NP:StyleFilterChanges(nameplate)
	if not status and not sf.Scale then
		nameplate.ThreatScale = 1
		NP:ScalePlate(nameplate, 1)
	elseif status and db.enable and db.useThreatColor then
		NP:Health_SetColors(nameplate, true)
		nameplate.ThreatStatus = status

		local Color, ColorKey, Scale
		if status == 3 then -- securely tanking
			if self.offTank then
				Color, ColorKey = colors.offTankColor, 'offTankColor'
			elseif self.isTank then
				Color, ColorKey = colors.goodColor, 'goodColor'
			else
				Color, ColorKey = colors.badColor, 'badColor'
			end
			Scale = self.isTank and db.goodScale or db.badScale
		elseif status == 2 then -- insecurely tanking
			if self.offTank then
				Color, ColorKey = colors.offTankColorBadTransition, 'offTankColorBadTransition'
			elseif self.isTank then
				Color, ColorKey = colors.badTransition, 'badTransition'
			else
				Color, ColorKey = colors.goodTransition, 'goodTransition'
			end
			Scale = 1
		elseif status == 1 then -- not tanking but threat higher than tank
			if self.offTank then
				Color, ColorKey = colors.offTankColorGoodTransition, 'offTankColorGoodTransition'
			elseif self.isTank then
				Color, ColorKey = colors.goodTransition, 'goodTransition'
			else
				Color, ColorKey = colors.badTransition, 'badTransition'
			end
			Scale = 1
		else -- not tanking at all
			if self.isTank then
				Color, ColorKey = colors.badColor, 'badColor'
			else
				Color, ColorKey = colors.goodColor, 'goodColor'
			end
			Scale = self.isTank and db.badScale or db.goodScale
		end

		if sf.HealthColor then
			self.r, self.g, self.b = Color.r, Color.g, Color.b
		else
			NP:ApplyStatusBarColor(nameplate.Health, Color.r, Color.g, Color.b, Color.a, 'threat', ColorKey)
		end

		if Scale then
			nameplate.ThreatScale = Scale

			if not sf.Scale then
				NP:ScalePlate(nameplate, Scale)
			end
		end
	end
end

function NP:Construct_ThreatIndicator(nameplate)
	local ThreatIndicator = nameplate:CreateTexture(nil, 'OVERLAY')
	ThreatIndicator:Size(16, 16)
	ThreatIndicator:Hide()
	ThreatIndicator:Point('CENTER', nameplate, 'TOPRIGHT')

	ThreatIndicator.PreUpdate = NP.ThreatIndicator_PreUpdate
	ThreatIndicator.PostUpdate = NP.ThreatIndicator_PostUpdate

	return ThreatIndicator
end

function NP:Update_ThreatIndicator(nameplate)
	local db = NP.db.threat
	if nameplate.frameType == 'ENEMY_NPC' and db.enable then
		if not nameplate:IsElementEnabled('ThreatIndicator') then
			nameplate:EnableElement('ThreatIndicator')
		end

		if db.indicator then
			nameplate.ThreatIndicator:SetAlpha(1)
		else
			nameplate.ThreatIndicator:SetAlpha(0)
		end
	elseif nameplate:IsElementEnabled('ThreatIndicator') then
		nameplate:DisableElement('ThreatIndicator')
	end
end
