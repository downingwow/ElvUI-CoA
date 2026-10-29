local E, L, V, P, G = unpack(ElvUI)
local NP = E:GetModule('NamePlates')
local UF = E:GetModule('UnitFrames')
local LSM = E.Libs.LSM
local ElvUF = E.oUF

local _G = _G
local select, strsplit, tostring = select, strsplit, tostring
local pairs, ipairs, wipe, tinsert = pairs, ipairs, wipe, tinsert

local CreateFrame = CreateFrame
local GetCVar = GetCVar
local GetCVarDefault = GetCVarDefault
local GetInstanceInfo = GetInstanceInfo
local GetNumGroupMembers = GroupUtil.GetNumGroupMembers
local GetNumSubgroupMembers = GetNumPartyMembers
local GetPartyAssignment = GetPartyAssignment
local InCombatLockdown = InCombatLockdown
local IsInGroup, IsInRaid = GenerateClosure(C_Player.IsInGroup, C_Player), GenerateClosure(C_Player.IsInRaid, C_Player)
local SetCVar = SetCVar
local UnitClass = UnitClass
local UnitClassification = UnitClassification
local UnitCreatureType = UnitCreatureType
local UnitExists = UnitExists
local UnitFactionGroup = UnitFactionGroup
local UnitGroupRolesAssigned = UnitGroupRolesAssigned
local UnitGUID = UnitGUID
local UnitIsEnemy = UnitIsEnemy
local UnitIsFriend = UnitIsFriend
local UnitIsPlayer = UnitIsPlayer
local UnitIsPVPSanctuary = UnitIsPVPSanctuary
local UnitIsUnit = UnitIsUnit
local UnitName = UnitName
local UnitReaction = UnitReaction
local UnitThreatSituation = UnitThreatSituation
local C_NamePlateManager_SetNamePlateSize
if not C_NamePlateManager.GetNamePlateSize then -- if this function isnt set, we are on old version still
	C_NamePlateManager_SetNamePlateSize = function(width, height)
		C_NamePlateManager.SetNamePlateFriendlySize(width, height)
		C_NamePlateManager.SetNamePlateEnemySize(width, height)
	end
else
	C_NamePlateManager_SetNamePlateSize = C_NamePlateManager.SetNamePlateSize
end
local hooksecurefunc = hooksecurefunc

do	-- credit: oUF/private.lua
	local selectionTypes = {[0]=0,[1]=1,[2]=2,[3]=3,[4]=4,[5]=5,[6]=6,[7]=7,[8]=8,[9]=9,[13]=13}
	-- 10 and 11 are unavailable to players, 12 is inconsistent due to bugs and its reliance on cvars

	function NP:UnitExists(unit)
		return unit and UnitExists(unit)
	end

	function NP:UnitSelectionType(unit, considerHostile)
		if considerHostile and UnitThreatSituation('player', unit) then
			return 0
		end
	end
end

local Blacklist = {
	PLAYER = {
		enable = true,
		health = {
			enable = true,
		},
	},
	ENEMY_PLAYER = {},
	FRIENDLY_PLAYER = {},
	ENEMY_NPC = {},
	FRIENDLY_NPC = {},
}

function NP:ResetSettings(unit)
	E:CopyTable(NP.db.units[unit], P.nameplates.units[unit])
end

function NP:CopySettings(from, to)
	if from == to then
		E:Print(L["You cannot copy settings from the same unit."])
		return
	end

	E:CopyTable(NP.db.units[to], E:FilterTableFromBlacklist(NP.db.units[from], Blacklist[to]))
end

do
	local empty = {}
	function NP:PlateDB(nameplate)
		return (nameplate and NP.db.units[nameplate.frameType]) or empty
	end
end

-- Nameplate Base -> Gradient helpers. These are kept here so every nameplate
-- statusbar element can use the same logic without duplicating texture code.
local function NameplateGradientFallback(r, g, b)
	return r + ((1 - r) * 0.18), g + ((1 - g) * 0.18), b + ((1 - b) * 0.18)
end

local function NameplateGradientNode(root, section, key, subKey)
	local node = root and root[section]
	if not node then return end
	node = node[key]
	if subKey ~= nil then
		node = node and node[subKey]
	end
	return node
end

-- Player Nameplates can optionally reuse the exact UnitFrame class gradient
-- colors. This is separate from the generic Nameplate Gradient toggle.
local function UnitFrameClassGradientFallback(r, g, b)
	return r + ((1 - r) * 0.18), g + ((1 - g) * 0.18), b + ((1 - b) * 0.18)
end

function NP:GetUnitFrameClassGradient(class, fallbackR, fallbackG, fallbackB)
	if not class then return end

	local colors = E.db and E.db.unitframe and E.db.unitframe.colors
	if not colors then return end

	local bases = colors.healthGradientBaseColors
	bases = bases and bases.class
	local finishes = colors.healthGradientColors
	finishes = finishes and finishes.class

	local classColor = E:ClassColor(class) or RAID_CLASS_COLORS[class]
	local base = bases and bases[class]
	local finish = finishes and finishes[class]

	local br = base and base.r or (classColor and classColor.r) or fallbackR
	local bg = base and base.g or (classColor and classColor.g) or fallbackG
	local bb = base and base.b or (classColor and classColor.b) or fallbackB
	if br == nil or bg == nil or bb == nil then return end

	local er, eg, eb
	if finish then
		er, eg, eb = finish.r, finish.g, finish.b
	else
		er, eg, eb = UnitFrameClassGradientFallback(br, bg, bb)
	end

	return br, bg, bb, er, eg, eb
end

function NP:ApplyUnitFrameClassGradient(bar, class, fallbackR, fallbackG, fallbackB)
	if not bar then return false end

	local texture = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
	if not texture or not texture.SetGradientAlpha then return false end

	local br, bg, bb, er, eg, eb = self:GetUnitFrameClassGradient(class, fallbackR, fallbackG, fallbackB)
	if not br then return false end

	-- Clear the marker used by the normal Nameplate gradient system. Both use
	-- the same statusbar texture and this class gradient deliberately wins.
	bar.__ElvNPGradient = nil
	bar.__ElvNPGradientData = nil

	bar:SetStatusBarColor(1, 1, 1, 1)
	texture:SetGradientAlpha("HORIZONTAL", br, bg, bb, 1, er, eg, eb, 1)

	bar.__ElvNPUnitFrameClassGradient = true
	bar.__ElvNPUnitFrameClassGradientClass = class
	return true, br, bg, bb
end

function NP:ClearUnitFrameClassGradient(bar)
	if not bar or not bar.__ElvNPUnitFrameClassGradient then return end

	local texture = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
	if texture and texture.SetGradientAlpha then
		texture:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
	end

	bar.__ElvNPUnitFrameClassGradient = nil
	bar.__ElvNPUnitFrameClassGradientClass = nil
end

function NP:GetGradientColor(section, key, subKey, r, g, b, a)
	local colors = NP.db and NP.db.colors
	local custom = colors and NameplateGradientNode(colors.gradientColors, section, key, subKey)
	if custom then
		return custom.r or r, custom.g or g, custom.b or b, custom.a or a or 1
	end

	local er, eg, eb = NameplateGradientFallback(r, g, b)
	return er, eg, eb, a or 1
end

function NP:ApplyStatusBarColor(bar, r, g, b, a, section, key, subKey)
	if not bar or not r or not g or not b then return end

	-- If this bar previously used the UnitFrame class gradient (for example a
	-- recycled player plate or after the option was disabled), remove it first.
	self:ClearUnitFrameClassGradient(bar)

	local texture = bar.GetStatusBarTexture and bar:GetStatusBarTexture()
	local gradient = NP.db and NP.db.colors and NP.db.colors.gradient
	local canGradient = gradient and section and texture and texture.SetGradientAlpha

	if canGradient then
		local er, eg, eb, ea = NP:GetGradientColor(section, key, subKey, r, g, b, a)
		local direction = (bar.GetOrientation and bar:GetOrientation() == 'VERTICAL') and 'VERTICAL' or 'HORIZONTAL'

		-- A white statusbar tint is required or WoW multiplies the gradient texture
		-- by the base StatusBar color.
		bar:SetStatusBarColor(1, 1, 1)
		texture:SetGradientAlpha(direction, r, g, b, a or 1, er, eg, eb, ea or a or 1)
		bar.__ElvNPGradient = true
		bar.__ElvNPGradientData = {r = r, g = g, b = b, a = a, section = section, key = key, subKey = subKey}
	else
		if texture and texture.SetGradientAlpha and bar.__ElvNPGradient then
			texture:SetGradientAlpha('HORIZONTAL', 1, 1, 1, 1, 1, 1, 1, 1)
		end
		bar.__ElvNPGradient = nil
		bar.__ElvNPGradientData = nil
		bar:SetStatusBarColor(r, g, b, a or 1)
	end
end

function NP:SetCVar(cvar, value)
	if GetCVar(cvar) ~= tostring(value) then
		SetCVar(cvar, value)
		if cvar == "nameplateSmoothStacking" then
			C_NamePlateManager.CheckNamePlateMotion()
			StaticPopup_Show("RELOAD_UI_NEEDED")
		end
	end
end

function NP:CVarReset()
	-- NP:SetCVar('nameplateMinAlpha', 1)
	-- NP:SetCVar('nameplateMaxAlpha', 1)
	-- NP:SetCVar('nameplateClassResourceTopInset', GetCVarDefault('nameplateClassResourceTopInset'))
	-- NP:SetCVar('nameplateGlobalScale', 1)
	-- NP:SetCVar('NamePlateHorizontalScale', 1)
	-- NP:SetCVar('nameplateLargeBottomInset', GetCVarDefault('nameplateLargeBottomInset'))
	-- NP:SetCVar('nameplateLargerScale', 1)
	-- NP:SetCVar('nameplateLargeTopInset', GetCVarDefault('nameplateLargeTopInset'))
	-- NP:SetCVar('nameplateMaxAlphaDistance', GetCVarDefault('nameplateMaxAlphaDistance'))
	-- NP:SetCVar('nameplateMaxScale', 1)
	-- NP:SetCVar('nameplateMaxScaleDistance', 40)
	-- NP:SetCVar('nameplateMinAlphaDistance', GetCVarDefault('nameplateMinAlphaDistance'))
	-- NP:SetCVar('nameplateMinScale', 1)
	-- NP:SetCVar('nameplateMinScaleDistance', 0)
	-- NP:SetCVar('nameplateMotionSpeed', GetCVarDefault('nameplateMotionSpeed'))
	-- NP:SetCVar('nameplateOccludedAlphaMult', GetCVarDefault('nameplateOccludedAlphaMult'))
	-- NP:SetCVar('nameplateOtherAtBase', GetCVarDefault('nameplateOtherAtBase'))
	-- NP:SetCVar('nameplateResourceOnTarget', GetCVarDefault('nameplateResourceOnTarget'))
	-- NP:SetCVar('nameplateSelectedAlpha', 1)
	-- NP:SetCVar('nameplateSelectedScale', 1)
	-- NP:SetCVar('nameplateSelfAlpha', 1)
	-- NP:SetCVar('nameplateSelfBottomInset', GetCVarDefault('nameplateSelfBottomInset'))
	-- NP:SetCVar('nameplateSelfScale', 1)
	-- NP:SetCVar('nameplateSelfTopInset', GetCVarDefault('nameplateSelfTopInset'))
	-- NP:SetCVar('nameplateTargetBehindMaxDistance', 40)

	-- if not E.Retail then
	-- 	NP:SetCVar('nameplateNotSelectedAlpha', 1)
	-- end
end

function NP:SetCVars()
	NP:SetCVar('nameplateSmoothStacking', NP.db.motionType == 'STACKED' and 1 or 0)
	NP:SetCVar('nameplateDistance', NP.db.loadDistance)

	-- the order of these is important !!
	if not NP.db.visibility.friendly then
		NP.db.visibility.friendly = {}
	end
	NP:SetCVar('nameplateShowEnemyGuardians', NP.db.visibility.enemy.guardians and 1 or 0)
	NP:SetCVar('nameplateShowEnemyPets', NP.db.visibility.enemy.pets and 1 or 0)
	NP:SetCVar('nameplateShowEnemyTotems', NP.db.visibility.enemy.totems and 1 or 0)
	NP:SetCVar('nameplateShowFriendlyGuardians', NP.db.visibility.friendly.guardians and 1 or 0)
	NP:SetCVar('nameplateShowFriendlyTotems', NP.db.visibility.friendly.totems and 1 or 0)
	NP:SetCVar('nameplateShowFriendlyPets', NP.db.visibility.friendly.pets and 1 or 0)
	NP:SetCVar('showVKeyCastbar', 1)
	SetNamePlateCastBarMode(1)
end

function NP:PLAYER_REGEN_DISABLED()
	if NP.db.showFriendlyCombat == 'TOGGLE_ON' then
		NP:SetCVar('nameplateShowFriends', 1)
	elseif NP.db.showFriendlyCombat == 'TOGGLE_OFF' then
		NP:SetCVar('nameplateShowFriends', 0)
	end

	if NP.db.showEnemyCombat == 'TOGGLE_ON' then
		NP:SetCVar('nameplateShowEnemies', 1)
	elseif NP.db.showEnemyCombat == 'TOGGLE_OFF' then
		NP:SetCVar('nameplateShowEnemies', 0)
	end
end

function NP:PLAYER_REGEN_ENABLED()
	if NP.db.showFriendlyCombat == 'TOGGLE_ON' then
		NP:SetCVar('nameplateShowFriends', 0)
	elseif NP.db.showFriendlyCombat == 'TOGGLE_OFF' then
		NP:SetCVar('nameplateShowFriends', 1)
	end

	if NP.db.showEnemyCombat == 'TOGGLE_ON' then
		NP:SetCVar('nameplateShowEnemies', 0)
	elseif NP.db.showEnemyCombat == 'TOGGLE_OFF' then
		NP:SetCVar('nameplateShowEnemies', 1)
	end
end

function NP:Style(unit)
	local frameName = self:GetName()

	if frameName == 'ElvNP_Test' then
		-- The Nameplate element code in this fork already has dedicated
		-- ElvNP_Test handling. Supply the Blizzard-nameplate pieces that a normal
		-- oUF :Spawn() frame does not have, then let the exact real StylePlate
		-- constructor build every visual element.
		self.isNamePlate = true
		self.isPlayer = true
		self.frameType = 'ENEMY_PLAYER'
		self.isFriend = false
		self.isEnemy = true
		self.reaction = 2
		self.repReaction = 2
		self.className, self.classFile, self.classID = UnitClass('player')
		self.classColor = self.classFile and (E:ClassColor(self.classFile) or RAID_CLASS_COLORS[self.classFile]) or nil

		self.nameplateAnchor = self
		if not self.nameplateAnchor.blizzHighlight then
			self.nameplateAnchor.blizzHighlight = self:CreateTexture(nil, 'OVERLAY')
			self.nameplateAnchor.blizzHighlight:SetTexture(E.Media.Textures.Spark)
			self.nameplateAnchor.blizzHighlight:SetAllPoints(self)
			self.nameplateAnchor.blizzHighlight:Hide()
		end
	end

	if frameName == 'ElvNP_TargetClassPower' then
		NP:StyleTargetPlate(self, unit)
	else
		NP:StylePlate(self, unit)
	end

	return self
end

function NP:Construct_RaisedELement(nameplate)
	local RaisedElement = CreateFrame('Frame', nameplate:GetName() .. 'RaisedElement', nameplate)
	RaisedElement:SetFrameLevel(nameplate:GetFrameLevel()+10)
	RaisedElement:SetAllPoints()
	RaisedElement:EnableMouse(false)

	return RaisedElement
end

function NP:Construct_ClassPowerTwo(nameplate)
	if E.myclass == 'DEATHKNIGHT' then
		nameplate.Runes = NP:Construct_Runes(nameplate)
	elseif E.myclass == 'MONK' then
		nameplate.Stagger = NP:Construct_Stagger(nameplate)
	end
end

function NP:Update_ClassPowerTwo(nameplate)
	if E.myclass == 'DEATHKNIGHT' then
		NP:Update_Runes(nameplate)
	elseif E.myclass == 'MONK' then
		NP:Update_Stagger(nameplate)
	end
end

function NP:StyleTargetPlate(nameplate)
	nameplate:SetScale(E.mult)
	nameplate:ClearAllPoints()
	nameplate:Point('CENTER')
	nameplate:Size(NP.db.plateSize.personalWidth or 150, NP.db.plateSize.personalHeight or 40)

	nameplate.RaisedElement = NP:Construct_RaisedELement(nameplate)
	nameplate.ClassPower = NP:Construct_ClassPower(nameplate)

	NP:Construct_ClassPowerTwo(nameplate)
end

function NP:UpdateTargetPlate(nameplate)
	NP:Update_ClassPower(nameplate)
	--NP:Update_ClassPowerTwo(nameplate)

	nameplate:UpdateAllElements('OnShow')
end

function NP:ScalePlate(nameplate, scale, targetPlate)
	if targetPlate and NP.targetPlate then
		NP.targetPlate:SetScale(E.mult)
		NP.targetPlate = nil
	end

	if not nameplate then return end
	nameplate:SetScale(scale * E.mult)

	if targetPlate then
		NP.targetPlate = nameplate
	end
end

function NP:PostUpdateAllElements(event)
	if event and (event == 'ForceUpdate' or not NP.StyleFilterEventFunctions[event]) then
		NP:StyleFilterUpdate(self, event)
		self.StyleFilterBaseAlreadyUpdated = nil -- keep after StyleFilterUpdate
	end

	if event == 'NAME_PLATE_UNIT_ADDED' and self.isTarget then
		NP:SetupTarget(self)
	end
end

function NP:StylePlate(nameplate)
	nameplate:SetScale(E.mult)

	nameplate.RaisedElement = NP:Construct_RaisedELement(nameplate)
	nameplate.Health = NP:Construct_Health(nameplate)
	nameplate.Health.Text = NP:Construct_TagText(nameplate.RaisedElement)
	nameplate.Health.Text.frequentUpdates = .1
	nameplate.HealCommBar = NP:Construct_HealComm(nameplate)
	nameplate.Power = NP:Construct_Power(nameplate)
	nameplate.Power.Text = NP:Construct_TagText(nameplate.RaisedElement)
	nameplate.Name = NP:Construct_TagText(nameplate.RaisedElement)
	nameplate.Level = NP:Construct_TagText(nameplate.RaisedElement)
	nameplate.Title = NP:Construct_TagText(nameplate.RaisedElement)
	nameplate.ClassificationIndicator = NP:Construct_ClassificationIndicator(nameplate.RaisedElement)
	nameplate.Castbar = NP:Construct_Castbar(nameplate)
	nameplate.Portrait = NP:Construct_Portrait(nameplate.RaisedElement)
	nameplate.QuestIcons = NP:Construct_QuestIcons(nameplate.RaisedElement)
	nameplate.RaidTargetIndicator = NP:Construct_RaidTargetIndicator(nameplate.RaisedElement)
	nameplate.TargetIndicator = NP:Construct_TargetIndicator(nameplate)
	nameplate.ThreatIndicator = NP:Construct_ThreatIndicator(nameplate.RaisedElement)
	nameplate.Highlight = NP:Construct_Highlight(nameplate)
	nameplate.ClassPower = NP:Construct_ClassPower(nameplate)
	nameplate.PvPIndicator = NP:Construct_PvPIndicator(nameplate.RaisedElement) -- Horde / Alliance / HonorInfo
	nameplate.PvPClassificationIndicator = NP:Construct_PvPClassificationIndicator(nameplate.RaisedElement) -- Cart / Flag / Orb / Assassin Bounty
	nameplate.PVPRole = NP:Construct_PVPRole(nameplate.RaisedElement)
	nameplate.Cutaway = NP:Construct_Cutaway(nameplate)
	nameplate.BossMods = NP:Construct_BossMods(nameplate)

	NP:Construct_Auras(nameplate)
	NP:StyleFilterEvents(nameplate) -- prepare the watcher

	--NP:Construct_ClassPowerTwo(nameplate)

	NP.Plates[nameplate] = nameplate:GetName()

	hooksecurefunc(nameplate, 'UpdateAllElements', NP.PostUpdateAllElements)
end

function NP:UpdatePlate(nameplate, updateBase)
	NP:Update_RaidTargetIndicator(nameplate)
	NP:Update_PVPRole(nameplate)
	NP:Update_Portrait(nameplate)
	NP:Update_QuestIcons(nameplate)
	NP:Update_BossMods(nameplate)

	local db = NP:PlateDB(nameplate)
	if db.nameOnly or not db.enable then
		NP:DisablePlate(nameplate, db.enable and db.nameOnly)

		if not db.enable and nameplate.RaisedElement:IsShown() then
			nameplate.RaisedElement:Hide()
		end
	elseif updateBase then
		NP:Update_Tags(nameplate)
		NP:Update_Health(nameplate)
		NP:Update_HealComm(nameplate)
		NP:Update_Highlight(nameplate)
		--NP:Update_Power(nameplate)
		NP:Update_Castbar(nameplate)
		NP:Update_ClassPower(nameplate)
		NP:Update_Auras(nameplate)
		NP:Update_ClassificationIndicator(nameplate)
		NP:Update_PvPIndicator(nameplate) -- Horde / Alliance / HonorInfo
		NP:Update_PvPClassificationIndicator(nameplate) -- Cart / Flag / Orb / Assassin Bounty
		NP:Update_TargetIndicator(nameplate)
		NP:Update_ThreatIndicator(nameplate)
		NP:Update_Cutaway(nameplate)

		--NP:Update_ClassPowerTwo(nameplate)

		if nameplate == _G.ElvNP_Player then
			NP:Update_Fader(nameplate)
		end
	else
		NP:Update_Health(nameplate, true) -- this will only reset the ouf vars so it won't hold stale threat ones
	end
end

NP.DisableInNotNameOnly = {
	'QuestIcons',
	'Highlight',
	'Portrait',
	'PVPRole'
}

NP.DisableElements = {
	'Health',
	'HealCommBar',
	--'Power',
	'ClassificationIndicator',
	'Castbar',
	'ThreatIndicator',
	'TargetIndicator',
	--header'ClassPower',
	'PvPIndicator',
	'PvPClassificationIndicator',
	'Auras'
}

if E.myclass == 'DEATHKNIGHT' then
	tinsert(NP.DisableElements, 'Runes')
elseif E.myclass == 'MONK' then
	tinsert(NP.DisableElements, 'Stagger')
end

function NP:DisablePlate(nameplate, nameOnly, nameOnlySF)
	for _, element in ipairs(NP.DisableElements) do
		if nameplate:IsElementEnabled(element) then
			nameplate:DisableElement(element)
		end
	end

	if nameOnly then
		NP:Update_Tags(nameplate, nameOnlySF)
		NP:Update_Highlight(nameplate, nameOnlySF)
		NP:Update_TargetIndicator(nameplate, nameOnlySF)
		-- The position values here are forced on purpose.
		nameplate.Name:ClearAllPoints()
		nameplate.Name:Point('CENTER', nameplate, 'CENTER', 0, 0)

		nameplate.RaidTargetIndicator:ClearAllPoints()
		nameplate.RaidTargetIndicator:Point('BOTTOM', nameplate, 'TOP', 0, 0)

		nameplate.Portrait:ClearAllPoints()
		nameplate.Portrait:Point('RIGHT', nameplate.Name, 'LEFT', -6, 0)

		nameplate.PVPRole:ClearAllPoints()
		nameplate.PVPRole:Point('RIGHT', (nameplate.Portrait:IsShown() and nameplate.Portrait) or nameplate.Name, 'LEFT', -6, 0)

		nameplate.QuestIcons:ClearAllPoints()
		nameplate.QuestIcons:Point('LEFT', nameplate.Name, 'RIGHT', 6, 0)

		nameplate.Title:ClearAllPoints()
		nameplate.Title:Point('TOP', nameplate.Name, 'BOTTOM', 0, -2)

		if nameplate.isTarget then
			NP:SetupTarget(nameplate, true)
		end
	else
		for _, element in ipairs(NP.DisableInNotNameOnly) do
			if nameplate:IsElementEnabled(element) then
				nameplate:DisableElement(element)
			end
		end
	end
end

function NP:GetClassAnchor()
	local TCP = _G.ElvNP_TargetClassPower
	return TCP.realPlate or TCP
end

function NP:SetupTarget(nameplate, removed)
	if not (NP.db.units and NP.db.units.TARGET) then return end

	local TCP = _G.ElvNP_TargetClassPower
	local cp = NP.db.units.TARGET.classpower or {}

	if removed and nameplate then
		if NP.currentTarget == nameplate then
			NP.currentTarget = nil
		end
	elseif nameplate then
		NP.currentTarget = nameplate
	end

	if removed or not nameplate or not cp.enable then
		TCP.realPlate = nil
	else
		local db = NP:PlateDB(nameplate)
		TCP.realPlate = not db.nameOnly and nameplate or nil
	end

	local anchor = NP:GetClassAnchor()
	if TCP.ClassPower then
		TCP.ClassPower:SetParent(anchor)
		TCP.ClassPower:ClearAllPoints()
		TCP.ClassPower:Point('CENTER', anchor, 'CENTER', cp.xOffset, cp.yOffset)
	end

	if TCP.Runes then
		TCP.Runes:SetParent(anchor)
		TCP.Runes:ClearAllPoints()
		TCP.Runes:Point('CENTER', anchor, 'CENTER', cp.xOffset, cp.yOffset)
	elseif TCP.Stagger then
		TCP.Stagger:SetParent(anchor)
		TCP.Stagger:ClearAllPoints()
		TCP.Stagger:Point('CENTER', anchor, 'CENTER', cp.xOffset, cp.yOffset)
	end
end

function NP:Update_StatusBars()
	for bar in pairs(NP.StatusBars) do
		local sf = NP:StyleFilterChanges(bar:GetParent())
		if not sf.HealthTexture then
			local texture = LSM:Fetch('statusbar', NP.db.statusbar) or E.media.normTex
			if bar.SetStatusBarTexture then
				bar:SetStatusBarTexture(texture)
				local data = bar.__ElvNPGradientData
				if data then
					if NP.db.colors.gradient then
						NP:ApplyStatusBarColor(bar, data.r, data.g, data.b, data.a, data.section, data.key, data.subKey)
					else
						NP:ApplyStatusBarColor(bar, data.r, data.g, data.b, data.a)
					end
				end
			else
				bar:SetTexture(texture)
			end
		end
	end
end

function NP:PARTY_MEMBERS_CHANGED()
	return self:RAID_ROSTER_UPDATE()
end

function NP:RAID_ROSTER_UPDATE()
	local isInRaid = IsInRaid()
	NP.IsInGroup = isInRaid or IsInGroup()

	wipe(NP.GroupRoles)

	if NP.IsInGroup then
		local group = isInRaid and 'raid' or 'party'
		for i = 1, (isInRaid and GetNumGroupMembers()) or GetNumSubgroupMembers() do
			local unit = group .. i
			if UnitExists(unit) then
				NP.GroupRoles[UnitName(unit)] = (GetPartyAssignment('MAINTANK', unit) and 'TANK' or 'NONE')
			end
		end
	end
end

function NP:PLAYER_ENTERING_WORLD(_, initLogin, isReload)
	NP.InstanceType = select(2, GetInstanceInfo())

	if not self.initLogin then
		self.initLogin = true
		NP:ConfigureAll(true)
	end
end

-- Nameplate live preview --------------------------------------------------
-- Uses the real ElvNP_Test frame, built by the exact same StylePlate
-- constructor as live nameplates. The preview only supplies sample unit state;
-- size, health, castbar, portrait, tags, auras, textures and anchors all come
-- from the currently selected real Nameplate DB.
local PREVIEW_TYPES = {
	FRIENDLY_PLAYER = true,
	FRIENDLY_NPC = true,
	ENEMY_PLAYER = true,
	ENEMY_NPC = true,
	TARGET = true,
}

local function PreviewBaseType(unitType)
	-- Target is not a standalone plate layout. It is an overlay/state applied
	-- to an existing plate. Use an Enemy Player plate as the base so every
	-- Target option can be previewed on a complete real nameplate.
	return unitType == 'TARGET' and 'ENEMY_PLAYER' or unitType
end

local function PreviewIsPlayer(unitType)
	return unitType == 'FRIENDLY_PLAYER' or unitType == 'ENEMY_PLAYER'
end

local function PreviewIsFriendly(unitType)
	return unitType == 'FRIENDLY_PLAYER' or unitType == 'FRIENDLY_NPC'
end

function NP:CreatePreviewPlate()
	if _G.ElvNP_Test then
		self.previewPlate = _G.ElvNP_Test
		return self.previewPlate
	end

	-- Initialize calls this while ElvNP is still the active oUF style, so every
	-- child is constructed by the exact same functions as a live nameplate.
	local frame = ElvUF:Spawn('player', 'ElvNP_Test')
	if not frame then return end

	UnregisterUnitWatch(frame)
	frame:SetParent(E.UIParent)
	frame:SetFrameStrata('DIALOG')
	frame:ClearAllPoints()
	frame:Point('CENTER', E.UIParent, 'CENTER', 0, 300)
	frame:Hide()

	-- Do not let ConfigurePlates treat the manually controlled preview like a
	-- Blizzard nameplate.
	NP.Plates[frame] = nil
	self.previewPlate = frame

	return frame
end

function NP:IsPreviewShown(unitType)
	local frame = self.previewPlate or _G.ElvNP_Test
	return frame and frame:IsShown() and self.previewType == unitType
end

function NP:ApplyPreviewHealthColor(frame, unitType)
	if not frame or not frame.Health then return end

	local baseType = PreviewBaseType(unitType)
	local db = NP.db.units[baseType]
	if not db or not db.health or not db.health.enable then return end

	local playerType = PreviewIsPlayer(baseType)
	local friendly = PreviewIsFriendly(baseType)
	local r, g, b

	if playerType and db.health.useClassColor and frame.classFile then
		local classColor = E:ClassColor(frame.classFile) or RAID_CLASS_COLORS[frame.classFile]
		if classColor then
			r, g, b = classColor.r, classColor.g, classColor.b

			if db.health.useUnitFrameClassGradient then
				local br, bg, bb = NP:GetUnitFrameClassGradient(frame.classFile, r, g, b)
				if br then
					r, g, b = br, bg, bb
					if NP:ApplyUnitFrameClassGradient(frame.Health, frame.classFile, r, g, b) then
						if frame.Health.bg then
							frame.Health.bg:SetVertexColor(r * NP.multiplier, g * NP.multiplier, b * NP.multiplier)
						end
						return
					end
				end
			end
		end
	end

	if not r then
		local key = friendly and 'good' or 'bad'
		local color = NP.db.colors.reactions[key]
		r, g, b = color.r, color.g, color.b
		NP:ApplyStatusBarColor(frame.Health, r, g, b, nil, 'reactions', key)
	else
		NP:ApplyStatusBarColor(frame.Health, r, g, b)
	end

	if frame.Health.bg then
		frame.Health.bg:SetVertexColor(r * NP.multiplier, g * NP.multiplier, b * NP.multiplier)
	end
end

function NP:UpdatePreviewPlate()
	local frame = self.previewPlate or _G.ElvNP_Test
	local previewType = self.previewType
	if not frame or not previewType or not frame:IsShown() then return end

	local baseType = PreviewBaseType(previewType)
	local db = NP.db.units[baseType]
	if not db then return end

	local playerType = PreviewIsPlayer(baseType)
	local friendly = PreviewIsFriendly(baseType)
	local isTargetPreview = previewType == 'TARGET'

	-- Sample state only. The visual layout below comes entirely from the same
	-- DB and update functions used by real nameplates.
	frame.isNamePlate = true
	frame.isPlayer = playerType
	frame.isMe = false
	frame.isPet = false
	frame.isFriend = friendly
	frame.isEnemy = not friendly
	frame.isPVPSanctuary = false
	frame.isTarget = isTargetPreview
	frame.reaction = friendly and 5 or 2
	frame.repReaction = friendly and 5 or 2
	frame.frameType = baseType
	frame.previousType = nil
	frame.classification = (baseType == 'ENEMY_NPC') and 'elite' or 'normal'
	frame.creatureType = (baseType:find('_NPC') and 'Humanoid') or nil
	frame.unitName, frame.unitRealm = UnitName('player')

	if playerType then
		frame.className, frame.classFile, frame.classID = UnitClass('player')
		frame.classColor = frame.classFile and (E:ClassColor(frame.classFile) or RAID_CLASS_COLORS[frame.classFile]) or nil
	else
		frame.className, frame.classFile, frame.classID = nil, nil, nil
		frame.classColor = nil
	end

	-- A real Blizzard nameplate uses this global clickable plate size. Health,
	-- castbar, power, portrait and aura sizes are then configured inside it by
	-- their respective unit-type DB exactly as on live plates.
	frame.width, frame.height = NP.db.plateSize.width, NP.db.plateSize.height
	frame:Size(frame.width, frame.height)

	if frame.RaisedElement and db.enable then
		frame.RaisedElement:Show()
	end

	-- Full rebuild through the normal live-plate path.
	NP:UpdatePlate(frame, true)

	-- Repaint oUF data. The dedicated ElvNP_Test hooks keep its Castbar and
	-- Auras visible with preview data instead of requiring a real nearby unit.
	if frame.UpdateAllElements then
		frame:UpdateAllElements('ForceUpdate')
	end

	-- Re-run layout after oUF updates so values that depend on the selected DB
	-- always win over the player unit used only as the oUF data source.
	NP:UpdatePlate(frame, true)
	NP:ApplyPreviewHealthColor(frame, previewType)

	if frame.Castbar then
		NP:Update_Castbar(frame)
	end
	if frame.Buffs_ or frame.Debuffs_ then
		NP:Update_Auras(frame)
	end

	if isTargetPreview then
		NP:SetupTarget(frame)
		if frame.TargetIndicator and frame.TargetIndicator.ForceUpdate then
			frame.TargetIndicator:ForceUpdate()
		end
	else
		-- Undo Target-only state when switching from Target Preview to another
		-- preview type.
		if NP.currentTarget == frame then
			NP:SetupTarget(frame, true)
		end
	end

	frame:SetAlpha(1)
	frame:Show()
end

function NP:SetPreviewMode(unitType, state)
	if InCombatLockdown() then return end
	if not PREVIEW_TYPES[unitType] then return end

	local frame = self.previewPlate or self:CreatePreviewPlate()
	if not frame then return end

	if state then
		self.previewType = unitType
		frame:Show()
		self:UpdatePreviewPlate()
	else
		if self.previewType == unitType then
			if NP.currentTarget == frame then
				NP:SetupTarget(frame, true)
			end
			self.previewType = nil
			frame.isTarget = nil
			frame:Hide()
		end
	end
end

function NP:RefreshPlayerPlateClassGradients()
	-- UnitFrame class-gradient options live under UnitFrames and therefore do
	-- not call Nameplate ConfigureAll. Refresh real player plates plus whichever
	-- preview type is currently visible.
	for frame in pairs(NP.Plates) do
		if frame and frame.Health and (frame.frameType == 'FRIENDLY_PLAYER' or frame.frameType == 'ENEMY_PLAYER') then
			local db = NP:PlateDB(frame)
			if db.health and db.health.useClassColor and db.health.useUnitFrameClassGradient then
				frame.Health:ForceUpdate()
			end
		end
	end

	self:UpdatePreviewPlate()
end

function NP:ConfigurePlates(init)
	NP.SkipFading = true
	if not init then -- these only need to happen when changing options
		for nameplate in pairs(NP.Plates) do
			nameplate:Size(NP.db.plateSize.width, NP.db.plateSize.height)

			nameplate.previousType = nil -- keep over the callback, we still need a full update
			NP:NamePlateCallBack(nameplate, 'NAME_PLATE_UNIT_ADDED')

			nameplate.StyleFilterBaseAlreadyUpdated = nil
			nameplate:UpdateAllElements('ForceUpdate')
		end
	end

	NP.SkipFading = nil
end

function NP:ConfigureAll(init)
	if not E.private.nameplates.enable then return end

	NP:StyleFilterConfigure() -- keep this at the top
	NP:SetNamePlateSizes()
	NP:PLAYER_REGEN_ENABLED()
	NP:UpdateTargetPlate(_G.ElvNP_TargetClassPower)
	NP:Update_StatusBars()

	NP:ConfigurePlates(init) -- keep before toggle static
	NP:UpdatePreviewPlate()
end

function NP:PlateFade(nameplate, timeToFade, startAlpha, endAlpha)
	if not nameplate.nameplateAnchor:IsShown() then return end
	-- we need our own function because we want a smooth transition and dont want it to force update every pass.
	-- its controlled by fadeTimer which is reset when UIFrameFadeOut or UIFrameFadeIn code runs.

	if not nameplate.FadeObject then
		nameplate.FadeObject = {}
	end

	nameplate.FadeObject.timeToFade = (nameplate.isTarget and 0) or timeToFade
	nameplate.FadeObject.startAlpha = startAlpha
	nameplate.FadeObject.endAlpha = endAlpha
	nameplate.FadeObject.diffAlpha = endAlpha - startAlpha

	if nameplate.FadeObject.fadeTimer then
		nameplate.FadeObject.fadeTimer = 0
	else
		E:UIFrameFade(nameplate, nameplate.FadeObject)
	end
end

function NP:UnitNPCID(unit) -- also used by Bags.lua
	local guid = UnitGUID(unit)
	return guid and GetCreatureIDFromGUID(guid), guid
end

function NP:UpdatePlateGUID(nameplate, guid)
	NP.PlateGUID[nameplate.unitGUID] = (guid and nameplate) or nil
end

function NP:UpdatePlateType(nameplate)
	if nameplate.isPVPSanctuary then
		nameplate.frameType = 'FRIENDLY_PLAYER'
	elseif not nameplate.isEnemy and (not nameplate.reaction or nameplate.reaction > 4) then -- keep as: not isEnemy, dont switch to isFriend
		nameplate.frameType = (nameplate.isPlayer and 'FRIENDLY_PLAYER') or 'FRIENDLY_NPC'
	else
		nameplate.frameType = (nameplate.isPlayer and 'ENEMY_PLAYER') or 'ENEMY_NPC'
	end
end

function NP:UpdatePlateSize(nameplate)
	nameplate.width, nameplate.height = NP.db.plateSize.width, NP.db.plateSize.height
	C_NamePlateManager_SetNamePlateSize(nameplate.width, nameplate.height)
	nameplate:Size(nameplate.width, nameplate.height)
end


function NP:UpdatePlateBase(nameplate)
	local update = nameplate.frameType ~= nameplate.previousType
	NP:UpdatePlate(nameplate, update)
	nameplate.StyleFilterBaseAlreadyUpdated = update
	nameplate.previousType = nameplate.frameType
end

function NP:NamePlateCallBack(nameplate, event, unit)
	if not nameplate then
		return
	end
	if event == 'UNIT_FACTION' or event == 'UNIT_FLAGS' then
		nameplate.reaction = UnitReaction('player', unit) -- Player Reaction
		nameplate.repReaction = UnitReaction(unit, 'player') -- Reaction to Player
		nameplate.isFriend = UnitIsFriend('player', unit)
		nameplate.isEnemy = UnitIsEnemy('player', unit)
		nameplate.faction = UnitFactionGroup(unit)
		nameplate.battleFaction = GetUnitBattlefieldFaction(unit)
		nameplate.classColor = (nameplate.isPlayer and RAID_CLASS_COLORS[nameplate.classFile]) or (nameplate.repReaction and NP.db.colors.reactions[nameplate.repReaction == 4 and 'neutral' or nameplate.repReaction <= 3 and 'bad' or 'good']) or nil

		NP:UpdatePlateType(nameplate)
		NP:UpdatePlateSize(nameplate)
		NP:UpdatePlateBase(nameplate)

		NP:StyleFilterUpdate(nameplate, event) -- keep this after UpdatePlateBase
		nameplate.StyleFilterBaseAlreadyUpdated = nil -- keep after StyleFilterUpdate
	elseif event == 'PLAYER_TARGET_CHANGED' then -- we need to check if nameplate exists in here
		NP:SetupTarget(nameplate) -- pass it, even as nil here
	elseif event == 'NAME_PLATE_UNIT_ADDED' then
		if not unit then unit = nameplate.unit end

		nameplate.classification = UnitClassification(unit)
		nameplate.creatureType = UnitCreatureType(unit)
		nameplate.isMe = UnitIsUnit(unit, 'player')
		nameplate.isPet = UnitIsUnit(unit, 'pet')
		nameplate.isFriend = UnitIsFriend('player', unit)
		nameplate.isEnemy = UnitIsEnemy('player', unit)
		nameplate.isPlayer = UnitIsPlayer(unit)
		nameplate.isPVPSanctuary = UnitIsPVPSanctuary(unit)
		nameplate.reaction = UnitReaction('player', unit) -- Player Reaction
		nameplate.repReaction = UnitReaction(unit, 'player') -- Reaction to Player
		nameplate.faction = UnitFactionGroup(unit)
		nameplate.battleFaction = GetUnitBattlefieldFaction(unit)
		nameplate.unitName, nameplate.unitRealm = UnitName(unit)
		nameplate.className, nameplate.classFile, nameplate.classID = UnitClass(unit)
		nameplate.npcID, nameplate.unitGUID = NP:UnitNPCID(unit)
		nameplate.classColor = (nameplate.isPlayer and RAID_CLASS_COLORS[nameplate.classFile]) or (nameplate.repReaction and NP.db.colors.reactions[nameplate.repReaction == 4 and 'neutral' or nameplate.repReaction <= 3 and 'bad' or 'good']) or nil

		if nameplate.unitGUID then
			NP:UpdatePlateGUID(nameplate, nameplate.unitGUID)
		end

		NP:UpdatePlateType(nameplate)
		NP:UpdatePlateSize(nameplate)

		if not nameplate.RaisedElement:IsShown() then
			nameplate.RaisedElement:Show()
		end

		NP:UpdatePlateBase(nameplate)
		NP:BossMods_UpdateIcon(nameplate)

		NP:StyleFilterEventWatch(nameplate) -- fire up the watcher
		NP:StyleFilterSetVariables(nameplate) -- sets: isTarget, isTargetingMe, isFocused
	elseif event == 'NAME_PLATE_UNIT_REMOVED' then
		if nameplate.isTarget then
			NP:ScalePlate(nameplate, 1, true)
			NP:SetupTarget(nameplate, true)
		end

		if nameplate.unitGUID then
			NP:UpdatePlateGUID(nameplate)
		end

		NP:BossMods_UpdateIcon(nameplate, true)

		NP:StyleFilterEventWatch(nameplate, true) -- shut down the watcher
		NP:StyleFilterClearVariables(nameplate)

		-- these can appear on SoftTarget nameplates and they aren't
		-- from NAME_PLATE_UNIT_ADDED which means, they will still be shown
		-- in some cases when the plate previously had the element
		if nameplate.QuestIcons then
			nameplate.QuestIcons:Hide()
		end

		-- vars that we need to keep in a nonstale state
		nameplate.Health.cur = nil -- cutaway
		--nameplate.Power.cur = nil -- cutaway
		nameplate.npcID = nil -- just cause
	end
end

local optionsTable = {
	'EnemyMinus',
	'EnemyMinions',
	'FriendlyMinions',
	'nameplateDistance',
	'MotionDropDown',
	'ShowAll'
}

function NP:HideInterfaceOptions()
	-- for _, x in pairs(optionsTable) do
	-- 	local o = _G['InterfaceOptionsNamesPanelUnitNameplates' .. x]
	-- 	if o then
	-- 		o:SetSize(0.00001, 0.00001)
	-- 		o:SetAlpha(0)
	-- 		o:Hide()
	-- 	end
	-- end
end

function NP:SetNamePlateSizes()
	--if InCombatLockdown() then return end
	C_NamePlateManager_SetNamePlateSize(NP.db.plateSize.width, NP.db.plateSize.height)
end

function NP:Initialize()
	NP.db = E.db.nameplates

	if not E.private.nameplates.enable then return end
	NP.Initialized = true

	NP.thinBorders = NP.db.thinBorders
	NP.SPACING = (NP.thinBorders or E.twoPixelsPlease) and 0 or 1
	NP.BORDER = (NP.thinBorders and not E.twoPixelsPlease) and 1 or 2

	ElvUF:RegisterStyle('ElvNP', NP.Style)
	ElvUF:SetActiveStyle('ElvNP')

	SetCVar('nameplateShowOnlyNames', NP.db.visibility.nameplateShowOnlyNames and '1' or '0')

	NP.Plates = {}
	NP.PlateGUID = {}
	NP.StatusBars = {}
	NP.GroupRoles = {}
	NP.multiplier = 0.35

	ElvUF:Spawn('player', 'ElvNP_TargetClassPower')

	_G.ElvNP_TargetClassPower:Size(NP.db.plateSize.personalWidth or 150, NP.db.plateSize.personalHeight or 40)
	_G.ElvNP_TargetClassPower.frameType = 'TARGET'
	_G.ElvNP_TargetClassPower:SetAttribute('toggleForVehicle', true)
	_G.ElvNP_TargetClassPower:ClearAllPoints()
	_G.ElvNP_TargetClassPower:Point('TOP', E.UIParent, 'BOTTOM', 0, -500)

	ElvUF:SpawnNamePlates('ElvNP_', function(nameplate, event, unit)
		NP:NamePlateCallBack(nameplate, event, unit)
	end)

	-- Build the hidden preview once through the exact same ElvNP style.
	NP:CreatePreviewPlate()

	-- UnitFrame Class Gradient color edits update UnitFrames, not Nameplates.
	-- Hook that existing refresh so both real player nameplates and the active
	-- preview update immediately when those shared colors change.
	if not NP.UnitFrameGradientRefreshHooked then
		hooksecurefunc(UF, 'Update_AllFrames', function()
			if NP.Initialized then
				NP:RefreshPlayerPlateClassGradients()
			end
		end)
		NP.UnitFrameGradientRefreshHooked = true
	end

	NP:RegisterEvent('PLAYER_REGEN_ENABLED')
	NP:RegisterEvent('PLAYER_REGEN_DISABLED')
	NP:RegisterEvent('PLAYER_ENTERING_WORLD')
	NP:RegisterEvent('COMBAT_LOG_EVENT_UNFILTERED')
	NP:RegisterEvent('RAID_ROSTER_UPDATE')
	NP:RegisterEvent('PARTY_MEMBERS_CHANGED')
	NP:RegisterEvent('PLAYER_LOGOUT')

	NP:BossMods_RegisterCallbacks()
	NP:StyleFilterInitialize()
	NP:HideInterfaceOptions()
	NP:RAID_ROSTER_UPDATE()
	NP:PARTY_MEMBERS_CHANGED()
	NP:SetCVars()
end

local AuraUpdateEvents = {
	["SPELL_AURA_APPLIED"] = true,
	["SPELL_AURA_REMOVED"] = true,
	["SPELL_AURA_REFRESH"] = true,
	["SPELL_AURA_BROKEN"] = true,
	["SPELL_AURA_BROKEN_SPELL"] = true,
	["SPELL_AURA_APPLIED_DOSE"] = true,
	["SPELL_AURA_REMOVED_DOSE"] = true,
}

function NP:COMBAT_LOG_EVENT_UNFILTERED(_, _, event, _, sourceGUID, sourceName, targetGUID)
	NP:CASTBAR_COMBAT_LOG_EVENT_UNFILTERED(event, sourceGUID, sourceName, targetGUID)
	local auraUpdate = AuraUpdateEvents[event]
	if not auraUpdate then return end
	if targetGUID and targetGUID ~= "" then
		local nameplate = NP.PlateGUID[targetGUID]
		if not nameplate then return end

		nameplate:UpdateElement('Auras')
		NP:StyleFilterUpdate(nameplate, 'UNIT_AURA')
		nameplate.StyleFilterBaseAlreadyUpdated = nil -- keep after StyleFilterUpdate
	end
end

E:RegisterModule(NP:GetName())
