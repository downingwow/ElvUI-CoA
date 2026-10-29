local E, _, _, P = unpack(ElvUI)
local C, L = unpack(select(2, ...))
local NP = E:GetModule('NamePlates')
local ACD = E.Libs.AceConfigDialog
local ACH = E.Libs.ACH

local _G = _G
local max, strfind, wipe = max, strfind, wipe
local pairs, type, strsplit = pairs, type, strsplit
local next, tonumber, format = next, tonumber, format

local IsAddOnLoaded = IsAddOnLoaded
local GetCVarBool = GetCVarBool
local SetCVar = SetCVar

local function GetAddOnStatus(index, locale, name)
	local status = IsAddOnLoaded(name) and format('|cff33ff33%s|r', L["Enabled"]) or format('|cffff3333%s|r', L["Disabled"])
	return ACH:Description(format('%s: %s', locale, status), index, 'medium')
end

local carryFilterFrom, carryFilterTo

local ORDER = 100
local filters = {}

local positionValues = {
	TOPLEFT = "TOPLEFT",
	LEFT = "LEFT",
	BOTTOMLEFT = "BOTTOMLEFT",
	RIGHT = "RIGHT",
	TOPRIGHT = "TOPRIGHT",
	BOTTOMRIGHT = "BOTTOMRIGHT",
	CENTER = "CENTER",
	TOP = "TOP",
	BOTTOM = "BOTTOM"
}

local growthDirectionValues = {
	DOWN_RIGHT = format(L["%s and then %s"], L["Down"], L["Right"]),
	DOWN_LEFT = format(L["%s and then %s"], L["Down"], L["Left"]),
	UP_RIGHT = format(L["%s and then %s"], L["Up"], L["Right"]),
	UP_LEFT = format(L["%s and then %s"], L["Up"], L["Left"]),
	RIGHT_DOWN = format(L["%s and then %s"], L["Right"], L["Down"]),
	RIGHT_UP = format(L["%s and then %s"], L["Right"], L["Up"]),
	LEFT_DOWN = format(L["%s and then %s"], L["Left"], L["Down"]),
	LEFT_UP = format(L["%s and then %s"], L["Left"], L["Up"])
}

local minHeight, minWidth = 2, 40
local function MaxHeight(unit) local heightType = strfind(unit, 'FRIENDLY') and 'friendlyHeight' or strfind(unit, 'ENEMY') and 'enemyHeight' return max(NP.db.plateSize[heightType] or 0, 20) end
local function MaxWidth(unit) local widthType = strfind(unit, 'FRIENDLY') and 'friendlyWidth' or strfind(unit, 'ENEMY') and 'enemyWidth' return max(NP.db.plateSize[widthType] or 0, 250) end

local function GetUnitSettings(unit, name)
	local copyValues = {}
	for x, y in pairs(NP.db.units) do
		if (type(y) == 'table' and x ~= unit) then
			copyValues[x] = L[x]
		end
	end

	local group = ACH:Group(name, nil, ORDER, 'tree', function(info) return E.db.nameplates.units[unit][info[#info]] end, function(info, value) E.db.nameplates.units[unit][info[#info]] = value NP:ConfigureAll() end, function() return not E.NamePlates.Initialized end)
	group.args.enable = ACH:Toggle(L["Enable"], nil, -10)
	group.args.defaultSettings = ACH:Execute(L["Default Settings"], L["Set Settings to Default"], -8, function() NP:ResetSettings(unit) NP:ConfigureAll() end)
	group.args.copySettings = ACH:Select(L["Copy settings from"], L["Copy settings from another unit."], -7, copyValues, nil, nil, C.Blank, function(_, value) NP:CopySettings(value, unit) NP:ConfigureAll() end)

	group.args.general = ACH:Group(L["General"], nil, 1, nil, function(info) return E.db.nameplates.units[unit][info[#info]] end, function(info, value) E.db.nameplates.units[unit][info[#info]] = value NP:SetCVars() NP:ConfigureAll() end)
	group.args.general.args.visibilityShortcut = ACH:Execute(L["Visibility"], nil, 100, function() ACD:SelectGroup('ElvUI', 'nameplates', 'generalGroup', 'general', 'plateVisibility') end)
	group.args.general.args.nameOnly = ACH:Toggle(L["Name Only"], nil, 101)
	group.args.general.args.showTitle = ACH:Toggle(L["Show Title"], L["Title will only appear if Name Only is enabled or triggered in a Style Filter."], 102)
	if unit == 'ENEMY_NPC' then
		group.args.general.args.greyTappedTargets = ACH:Toggle(L["Grey Tapped Targets"], L["Make tapped targets appear greyed out."], 103)
	end
	group.args.general.args.smartAuraPosition = ACH:Select(L["Smart Aura Position"], L["Will show Buffs in the Debuff position when there are no Debuffs active, or vice versa."], 104, C.Values.SmartAuraPositions)

	group.args.healthGroup = ACH:Group(L["Health"], nil, 2, nil, function(info) return E.db.nameplates.units[unit].health[info[#info]] end, function(info, value) E.db.nameplates.units[unit].health[info[#info]] = value NP:ConfigureAll() end)
	group.args.healthGroup.args.enable = ACH:Toggle(L["Enable"], nil, 1, nil, nil, nil, nil, nil, nil, function() return unit == 'PLAYER' end)
	group.args.healthGroup.args.height = ACH:Range(L["Height"], nil, 3, { min = minHeight, max = MaxHeight(unit), step = 1 })
	group.args.healthGroup.args.width = ACH:Execute(L["Width"], nil, 4, function() ACD:SelectGroup('ElvUI', 'nameplates', 'generalGroup', 'clickableRange') end)
	group.args.healthGroup.args.healPrediction = ACH:Toggle(L["Heal Prediction"], nil, 5)

	group.args.healthGroup.args.textGroup = ACH:Group(L["Text"], nil, 200, nil, function(info) return E.db.nameplates.units[unit].health.text[info[#info]] end, function(info, value) E.db.nameplates.units[unit].health.text[info[#info]] = value NP:ConfigureAll() end)
	group.args.healthGroup.args.textGroup.inline = true
	group.args.healthGroup.args.textGroup.args.enable = ACH:Toggle(L["Enable"], nil, 1)
	group.args.healthGroup.args.textGroup.args.format = ACH:Input(L["Text Format"], nil, 2, nil, 'full')
	group.args.healthGroup.args.textGroup.args.position = ACH:Select(L["Position"], nil, 3, { CENTER = 'CENTER', TOPLEFT = 'TOPLEFT', BOTTOMLEFT = 'BOTTOMLEFT', TOPRIGHT = 'TOPRIGHT', BOTTOMRIGHT = 'BOTTOMRIGHT' })
	group.args.healthGroup.args.textGroup.args.parent = ACH:Select(L["Parent"], nil, 4, { Nameplate = L["Nameplate"], Health = L["Health"] })
	group.args.healthGroup.args.textGroup.args.xOffset = ACH:Range(L["X-Offset"], nil, 5, { min = -100, max = 100, step = 1 })
	group.args.healthGroup.args.textGroup.args.yOffset = ACH:Range(L["Y-Offset"], nil, 6, { min = -100, max = 100, step = 1 })

	group.args.healthGroup.args.textGroup.args.fontGroup = ACH:Group('', nil, 7)
	group.args.healthGroup.args.textGroup.args.fontGroup.inline = true
	group.args.healthGroup.args.textGroup.args.fontGroup.args.font = ACH:SharedMediaFont(L["Font"], nil, 1)
	group.args.healthGroup.args.textGroup.args.fontGroup.args.fontSize = ACH:Range(L["Font Size"], nil, 2, { min = 4, max = 60, step = 1 })
	group.args.healthGroup.args.textGroup.args.fontGroup.args.fontOutline = ACH:FontFlags(L["Font Outline"], nil, 3)

	group.args.powerGroup = ACH:Group(L["Power"], nil, 3, nil, function(info) return E.db.nameplates.units[unit].power[info[#info]] end, function(info, value) E.db.nameplates.units[unit].power[info[#info]] = value NP:ConfigureAll() end)
	group.args.powerGroup.args.enable = ACH:Toggle(L["Enable"], nil, 1)
	group.args.powerGroup.args.hideWhenEmpty = ACH:Toggle(L["Hide When Empty"], nil, 2)
	group.args.powerGroup.args.width = ACH:Range(L["Width"], nil, 3, { min = minWidth, max = MaxWidth(unit), step = 1 })
	group.args.powerGroup.args.height = ACH:Range(L["Height"], nil, 4, { min = minHeight, max = MaxHeight(unit), step = 1 })
	group.args.powerGroup.args.xOffset = ACH:Range(L["X-Offset"], nil, 5, { min = -100, max = 100, step = 1 })
	group.args.powerGroup.args.yOffset = ACH:Range(L["Y-Offset"], nil, 6, { min = -100, max = 100, step = 1 })
	group.args.powerGroup.args.displayAltPower = ACH:Toggle(L["Swap to Alt Power"], nil, 7)
	group.args.powerGroup.args.useAtlas = ACH:Toggle(L["Use Atlas Textures"], nil, 8)
	group.args.powerGroup.args.classColor = ACH:Toggle(L["Use Class Color"], nil, 9)

	group.args.powerGroup.args.textGroup = ACH:Group(L["Text"], nil, 200, nil, function(info) return E.db.nameplates.units[unit].power.text[info[#info]] end, function(info, value) E.db.nameplates.units[unit].power.text[info[#info]] = value NP:ConfigureAll() end)
	group.args.powerGroup.args.textGroup.inline = true
	group.args.powerGroup.args.textGroup.args.enable = ACH:Toggle(L["Enable"], nil, 1)
	group.args.powerGroup.args.textGroup.args.format = ACH:Input(L["Text Format"], nil, 2, nil, 'full')
	group.args.powerGroup.args.textGroup.args.position = ACH:Select(L["Position"], nil, 3, { CENTER = 'CENTER', TOPLEFT = 'TOPLEFT', BOTTOMLEFT = 'BOTTOMLEFT', TOPRIGHT = 'TOPRIGHT', BOTTOMRIGHT = 'BOTTOMRIGHT' })
	group.args.powerGroup.args.textGroup.args.parent = ACH:Select(L["Parent"], nil, 4, { Nameplate = L["Nameplate"], Health = L["Health"] })
	group.args.powerGroup.args.textGroup.args.xOffset = ACH:Range(L["X-Offset"], nil, 5, { min = -100, max = 100, step = 1 })
	group.args.powerGroup.args.textGroup.args.yOffset = ACH:Range(L["Y-Offset"], nil, 6, { min = -100, max = 100, step = 1 })

	group.args.powerGroup.args.textGroup.args.fontGroup = ACH:Group('', nil, 7)
	group.args.powerGroup.args.textGroup.args.fontGroup.inline = true
	group.args.powerGroup.args.textGroup.args.fontGroup.args.font = ACH:SharedMediaFont(L["Font"], nil, 1)
	group.args.powerGroup.args.textGroup.args.fontGroup.args.fontSize = ACH:Range(L["Font Size"], nil, 2, { min = 4, max = 60, step = 1 })
	group.args.powerGroup.args.textGroup.args.fontGroup.args.fontOutline = ACH:FontFlags(L["Font Outline"], nil, 3)

	group.args.castGroup = ACH:Group(L["Cast Bar"], nil, 4, nil, function(info) return E.db.nameplates.units[unit].castbar[info[#info]] end, function(info, value) E.db.nameplates.units[unit].castbar[info[#info]] = value NP:ConfigureAll() end)
	group.args.castGroup.args.enable = ACH:Toggle(L["Enable"], nil, 1)
	group.args.castGroup.args.sourceInterrupt = ACH:Toggle(L["Display Interrupt Source"], L["Display the unit name who interrupted a spell on the castbar. You should increase the Time to Hold to show properly."], 2)
	group.args.castGroup.args.sourceInterruptClassColor = ACH:Toggle(L["Class Color Source"], nil, 3, nil, nil, nil, nil, nil, function() return not E.db.nameplates.units[unit].castbar.sourceInterrupt end)
	-- order 4 is player Display Target
	group.args.castGroup.args.timeToHold = ACH:Range(L["Time To Hold"], L["How many seconds the castbar should stay visible after the cast failed or was interrupted."], 5, { min = 0, max = 5, step = .1 })
	group.args.castGroup.args.width = ACH:Range(L["Width"], nil, 6, { min = minWidth, max = MaxWidth(unit), step = 1 })
	group.args.castGroup.args.height = ACH:Range(L["Height"], nil, 7, { min = minHeight, max = MaxHeight(unit), step = 1 })
	group.args.castGroup.args.xOffset = ACH:Range(L["X-Offset"], nil, 8, { min = -100, max = 100, step = 1 })
	group.args.castGroup.args.yOffset = ACH:Range(L["Y-Offset"], nil, 9, { min = -100, max = 100, step = 1 })

	group.args.castGroup.args.textGroup = ACH:Group(L["Text"], nil, 20)
	group.args.castGroup.args.textGroup.inline = true
	group.args.castGroup.args.textGroup.args.hideSpellName = ACH:Toggle(L["Hide Spell Name"], nil, 1)
	group.args.castGroup.args.textGroup.args.hideTime = ACH:Toggle(L["Hide Time"], nil, 2)
	group.args.castGroup.args.textGroup.args.textPosition = ACH:Select(L["Position"], nil, 3, { ONBAR = L["Cast Bar"], ABOVE = L["Above"], BELOW = L["Below"] })
	group.args.castGroup.args.textGroup.args.castTimeFormat = ACH:Select(L["Cast Time Format"], nil, 4, { CURRENT = L["Current"], CURRENTMAX = L["Current / Max"], REMAINING = L["Remaining"], REMAININGMAX = L["Remaining / Max"] })
	group.args.castGroup.args.textGroup.args.channelTimeFormat = ACH:Select(L["Channel Time Format"], nil, 5, { CURRENT = L["Current"], CURRENTMAX = L["Current / Max"], REMAINING = L["Remaining"], REMAININGMAX = L["Remaining / Max"] })

	group.args.castGroup.args.textGroup.args.time = ACH:Group(L["Time Options"], nil, 10)
	group.args.castGroup.args.textGroup.args.time.args.timeXOffset = ACH:Range(L["X-Offset"], nil, 6, { min = -100, max = 100, step = 1 })
	group.args.castGroup.args.textGroup.args.time.args.timeYOffset = ACH:Range(L["Y-Offset"], nil, 7, { min = -100, max = 100, step = 1 })

	group.args.castGroup.args.textGroup.args.text = ACH:Group(L["Text Options"], nil, 11)
	group.args.castGroup.args.textGroup.args.text.args.textXOffset = ACH:Range(L["X-Offset"], nil, 8, { min = -100, max = 100, step = 1 })
	group.args.castGroup.args.textGroup.args.text.args.textYOffset = ACH:Range(L["Y-Offset"], nil, 9, { min = -100, max = 100, step = 1 })

	group.args.castGroup.args.iconGroup = ACH:Group(L["Icon"], nil, 21)
	group.args.castGroup.args.iconGroup.inline = true
	group.args.castGroup.args.iconGroup.args.showIcon = ACH:Toggle(L["Show Icon"], nil, 1)
	group.args.castGroup.args.iconGroup.args.iconPosition = ACH:Select(L["Position"], nil, 3, { LEFT = L["Left"], RIGHT = L["Right"] })
	group.args.castGroup.args.iconGroup.args.iconSize = ACH:Range(L["Icon Size"], nil, 3, { min = 4, max = 40, step = 1 })
	group.args.castGroup.args.iconGroup.args.iconOffsetX = ACH:Range(L["X-Offset"], nil, 8, { min = -100, max = 100, step = 1 })
	group.args.castGroup.args.iconGroup.args.iconOffsetY = ACH:Range(L["Y-Offset"], nil, 9, { min = -100, max = 100, step = 1 })

	group.args.castGroup.args.fontGroup = ACH:Group(L["Font"], nil, 30)
	group.args.castGroup.args.fontGroup.inline = true
	group.args.castGroup.args.fontGroup.args.font = ACH:SharedMediaFont(L["Font"], nil, 1)
	group.args.castGroup.args.fontGroup.args.fontSize = ACH:Range(L["Font Size"], nil, 2, { min = 4, max = 60, step = 1 })
	group.args.castGroup.args.fontGroup.args.fontOutline = ACH:FontFlags(L["Font Outline"], nil, 3)

	group.args.buffsGroup = ACH:Group(L["Buffs"], nil, 5, nil, function(info) return E.db.nameplates.units[unit].buffs[info[#info]] end, function(info, value) E.db.nameplates.units[unit].buffs[info[#info]] = value NP:ConfigureAll() end)
	group.args.buffsGroup.args.enable = ACH:Toggle(L["Enable"], nil, 1)
	group.args.buffsGroup.args.stackAuras = ACH:Toggle(L["Stack Auras"], L["This will join auras together which are normally separated. Example: Bolstering and Force of Nature."], 2)
	group.args.buffsGroup.args.desaturate = ACH:Toggle(L["Desaturate Icon"], L["Set auras that are not from you to desaturated."], 3)
	group.args.buffsGroup.args.keepSizeRatio = ACH:Toggle(L["Keep Size Ratio"], nil, 4)
	group.args.buffsGroup.args.size = ACH:Range(function() return E.db.nameplates.units[unit].buffs.keepSizeRatio and L["Size"] or L["Width"] end, nil, 5, { min = 6, max = 60, step = 1 })
	group.args.buffsGroup.args.height = ACH:Range(L["Height"], nil, 6, { min = 6, max = 60, step = 1 }, nil, nil, nil, nil, function() return E.db.nameplates.units[unit].buffs.keepSizeRatio end)
	group.args.buffsGroup.args.numAuras = ACH:Range(L["Per Row"], nil, 7, { min = 1, max = 20, step = 1 })
	group.args.buffsGroup.args.numRows = ACH:Range(L["Num Rows"], nil, 8, { min = 1, max = 5, step = 1 })
	group.args.buffsGroup.args.spacing = ACH:Range(L["Spacing"], nil, 9, { min = 0, max = 60, step = 1 })
	group.args.buffsGroup.args.xOffset = ACH:Range(L["X-Offset"], nil, 10, { min = -100, max = 100, step = 1 })
	group.args.buffsGroup.args.yOffset = ACH:Range(L["Y-Offset"], nil, 11, { min = -100, max = 100, step = 1 })
	group.args.buffsGroup.args.anchorPoint = ACH:Select(L["Anchor Point"], L["What point to anchor to the frame you set to attach to."], 12, positionValues)
	group.args.buffsGroup.args.attachTo = ACH:Select(L["Attach To"], L["What to attach the anchor frame to."], 13, { FRAME = L["Frame"], DEBUFFS = L["Debuffs"], HEALTH = L["Health"], POWER = L["Power"] }, nil, nil, nil, nil, function() local position = E.db.nameplates.units[unit].smartAuraPosition return position == 'BUFFS_ON_DEBUFFS' or position == 'FLUID_BUFFS_ON_DEBUFFS' end)
	group.args.buffsGroup.args.growthDirection = ACH:Select(L["Growth Direction"], nil, 14, growthDirectionValues)
	group.args.buffsGroup.args.sortMethod = ACH:Select(L["Sort By"], L["Method to sort by."], 16, { TIME_REMAINING = L["Time Remaining"], DURATION = L["Duration"], NAME = L["Name"], INDEX = L["Index"], PLAYER = L["Player"] })
	group.args.buffsGroup.args.sortDirection = ACH:Select(L["Sort Direction"], L["Ascending or Descending order."], 17, { ASCENDING = L["Ascending"], DESCENDING = L["Descending"] })

	group.args.buffsGroup.args.stacks = ACH:Group(L["Stack Counter"], nil, 20)
	group.args.buffsGroup.args.stacks.inline = true
	group.args.buffsGroup.args.stacks.args.countFont = ACH:SharedMediaFont(L["Font"], nil, 1)
	group.args.buffsGroup.args.stacks.args.countFontSize = ACH:Range(L["Font Size"], nil, 2, { min = 4, max = 60, step = 1 })
	group.args.buffsGroup.args.stacks.args.countFontOutline = ACH:FontFlags(L["Font Outline"], nil, 3)
	group.args.buffsGroup.args.stacks.args.countXOffset = ACH:Range(L["X-Offset"], nil, 10, { min = -100, max = 100, step = 1 })
	group.args.buffsGroup.args.stacks.args.countYOffset = ACH:Range(L["Y-Offset"], nil, 9, { min = -100, max = 100, step = 1 })
	group.args.buffsGroup.args.stacks.args.countPosition = ACH:Select(L["Position"], nil, 3, { TOP = 'TOP', LEFT = 'LEFT', BOTTOM = 'BOTTOM', CENTER = 'CENTER', TOPLEFT = 'TOPLEFT', BOTTOMLEFT = 'BOTTOMLEFT', BOTTOMRIGHT = 'BOTTOMRIGHT', RIGHT = 'RIGHT', TOPRIGHT = 'TOPRIGHT' })

	group.args.buffsGroup.args.duration = ACH:Group(L["Duration"], nil, 25)
	group.args.buffsGroup.args.duration.inline = true
	group.args.buffsGroup.args.duration.args.cooldownShortcut = ACH:Execute(L["Cooldowns"], nil, 1, function() ACD:SelectGroup('ElvUI', 'cooldown', 'nameplates') end)
	group.args.buffsGroup.args.duration.args.durationPosition = ACH:Select(L["Position"], nil, 2, { TOP = 'TOP', LEFT = 'LEFT', BOTTOM = 'BOTTOM', CENTER = 'CENTER', TOPLEFT = 'TOPLEFT', BOTTOMLEFT = 'BOTTOMLEFT', BOTTOMRIGHT = 'BOTTOMRIGHT', RIGHT = 'RIGHT', TOPRIGHT = 'TOPRIGHT' })

	group.args.buffsGroup.args.filtersGroup = ACH:Group(L["FILTERS"], nil, 30)
	group.args.buffsGroup.args.filtersGroup.inline = true
	group.args.buffsGroup.args.filtersGroup.args.minDuration = ACH:Range(L["Minimum Duration"], L["Don't display auras that are shorter than this duration (in seconds). Set to zero to disable."], 1, { min = 0, max = 10800, step = 1 })
	group.args.buffsGroup.args.filtersGroup.args.maxDuration = ACH:Range(L["Maximum Duration"], L["Don't display auras that are longer than this duration (in seconds). Set to zero to disable."], 1, { min = 0, max = 10800, step = 1 })
	group.args.buffsGroup.args.filtersGroup.args.jumpToFilter = ACH:Execute(L["Filters Page"], L["Shortcut to global filters."], 3, function() ACD:SelectGroup('ElvUI', 'filters') end)
	group.args.buffsGroup.args.filtersGroup.args.specialFilters = ACH:Select(L["Add Special Filter"], L["These filters don't use a list of spells like the regular filters. Instead they use the WoW API and some code logic to determine if an aura should be allowed or blocked."], 4, function() wipe(filters) local list = E.global.unitframe.specialFilters if not (list and next(list)) then return filters end for filter in pairs(list) do filters[filter] = L[filter] end return filters end, nil, nil, nil, function(_, value) C.SetFilterPriority(E.db.nameplates.units, unit, 'buffs', value) NP:ConfigureAll() end)
	group.args.buffsGroup.args.filtersGroup.args.specialFilters.sortByValue = true
	group.args.buffsGroup.args.filtersGroup.args.filter = ACH:Select(L["Add Regular Filter"], L["These filters use a list of spells to determine if an aura should be allowed or blocked. The content of these filters can be modified in the Filters section of the config."], 5, function() wipe(filters) local list = E.global.unitframe.aurafilters if not (list and next(list)) then return filters end for filter in pairs(list) do filters[filter] = L[filter] end return filters end, nil, nil, nil, function(_, value) C.SetFilterPriority(E.db.nameplates.units, unit, 'buffs', value) NP:ConfigureAll() end)
	group.args.buffsGroup.args.filtersGroup.args.resetPriority = ACH:Execute(L["Reset Priority"], L["Reset filter priority to the default state."], 7, function() E.db.nameplates.units[unit].buffs.priority = P.nameplates.units[unit].buffs.priority NP:ConfigureAll() end)

	group.args.buffsGroup.args.filtersGroup.args.filterPriority = ACH:MultiSelect(L["Filter Priority"], nil, 8, function() local str = E.db.nameplates.units[unit].buffs.priority if str == '' then return {} end return {strsplit(',', str)} end, nil, nil, function(_, value) local str = E.db.nameplates.units[unit].buffs.priority if str == '' then return end local tbl = {strsplit(',', str)} return tbl[value] end, function() NP:ConfigureAll() end)
	group.args.buffsGroup.args.filtersGroup.args.filterPriority.dragdrop = true
	group.args.buffsGroup.args.filtersGroup.args.filterPriority.dragOnLeave = E.noop -- keep it her
	group.args.buffsGroup.args.filtersGroup.args.filterPriority.dragOnEnter = function(info) carryFilterTo = info.obj.value end
	group.args.buffsGroup.args.filtersGroup.args.filterPriority.dragOnMouseDown = function(info) carryFilterFrom, carryFilterTo = info.obj.value, nil end
	group.args.buffsGroup.args.filtersGroup.args.filterPriority.dragOnMouseUp = function() C.SetFilterPriority(E.db.nameplates.units, unit, 'buffs', carryFilterTo, nil, carryFilterFrom) carryFilterFrom, carryFilterTo = nil, nil end
	group.args.buffsGroup.args.filtersGroup.args.filterPriority.dragOnClick = function() C.SetFilterPriority(E.db.nameplates.units, unit, 'buffs', carryFilterFrom, true) end
	group.args.buffsGroup.args.filtersGroup.args.filterPriority.stateSwitchGetText = C.StateSwitchGetText
	group.args.buffsGroup.args.filtersGroup.args.filterPriority.stateSwitchOnClick = function() C.SetFilterPriority(E.db.nameplates.units, unit, 'buffs', carryFilterFrom, nil, nil, true) end
	group.args.buffsGroup.args.filtersGroup.args.spacer1 = ACH:Description(L["Use drag and drop to rearrange filter priority or right click to remove a filter."] ..'\n'..L["Use Shift+LeftClick to toggle between friendly or enemy or normal state. Normal state will allow the filter to be checked on all units. Friendly state is for friendly units only and enemy state is for enemy units."], 9)

	group.args.debuffsGroup = ACH:Group(L["Debuffs"], nil, 5, nil, function(info) return E.db.nameplates.units[unit].debuffs[info[#info]] end, function(info, value) E.db.nameplates.units[unit].debuffs[info[#info]] = value NP:ConfigureAll() end)
	group.args.debuffsGroup.args.enable = ACH:Toggle(L["Enable"], nil, 1)
	group.args.debuffsGroup.args.stackAuras = ACH:Toggle(L["Stack Auras"], L["This will join auras together which are normally separated. Example: Bolstering and Force of Nature."], 2)
	group.args.debuffsGroup.args.desaturate = ACH:Toggle(L["Desaturate Icon"], L["Set auras that are not from you to desaturated."], 3)
	group.args.debuffsGroup.args.keepSizeRatio = ACH:Toggle(L["Keep Size Ratio"], nil, 4)
	group.args.debuffsGroup.args.size = ACH:Range(function() return E.db.nameplates.units[unit].debuffs.keepSizeRatio and L["Size"] or L["Width"] end, nil, 5, { min = 6, max = 60, step = 1 })
	group.args.debuffsGroup.args.height = ACH:Range(L["Height"], nil, 6, { min = 6, max = 60, step = 1 }, nil, nil, nil, nil, function() return E.db.nameplates.units[unit].debuffs.keepSizeRatio end)
	group.args.debuffsGroup.args.numAuras = ACH:Range(L["Per Row"], nil, 7, { min = 1, max = 20, step = 1 })
	group.args.debuffsGroup.args.numRows = ACH:Range(L["Num Rows"], nil, 8, { min = 1, max = 5, step = 1 })
	group.args.debuffsGroup.args.spacing = ACH:Range(L["Spacing"], nil, 9, { min = 0, max = 60, step = 1 })
	group.args.debuffsGroup.args.xOffset = ACH:Range(L["X-Offset"], nil, 10, { min = -100, max = 100, step = 1 })
	group.args.debuffsGroup.args.yOffset = ACH:Range(L["Y-Offset"], nil, 11, { min = -100, max = 100, step = 1 })
	group.args.debuffsGroup.args.anchorPoint = ACH:Select(L["Anchor Point"], L["What point to anchor to the frame you set to attach to."], 12, positionValues)
	group.args.debuffsGroup.args.attachTo = ACH:Select(L["Attach To"], L["What to attach the anchor frame to."], 13, { FRAME = L["Frame"], BUFFS = L["Buffs"], HEALTH = L["Health"], POWER = L["Power"] }, nil, nil, nil, nil, function() local position = E.db.nameplates.units[unit].smartAuraPosition return position == 'BUFFS_ON_DEBUFFS' or position == 'FLUID_BUFFS_ON_DEBUFFS' end)
	group.args.debuffsGroup.args.growthDirection = ACH:Select(L["Growth Direction"], nil, 14, growthDirectionValues)
	group.args.debuffsGroup.args.sortMethod = ACH:Select(L["Sort By"], L["Method to sort by."], 16, { TIME_REMAINING = L["Time Remaining"], DURATION = L["Duration"], NAME = L["Name"], INDEX = L["Index"], PLAYER = L["Player"] })
	group.args.debuffsGroup.args.sortDirection = ACH:Select(L["Sort Direction"], L["Ascending or Descending order."], 17, { ASCENDING = L["Ascending"], DESCENDING = L["Descending"] })

	group.args.debuffsGroup.args.stacks = ACH:Group(L["Stack Counter"], nil, 20)
	group.args.debuffsGroup.args.stacks.inline = true
	group.args.debuffsGroup.args.stacks.args.countFont = ACH:SharedMediaFont(L["Font"], nil, 1)
	group.args.debuffsGroup.args.stacks.args.countFontSize = ACH:Range(L["Font Size"], nil, 2, { min = 4, max = 60, step = 1 })
	group.args.debuffsGroup.args.stacks.args.countFontOutline = ACH:FontFlags(L["Font Outline"], nil, 3)
	group.args.debuffsGroup.args.stacks.args.countXOffset = ACH:Range(L["X-Offset"], nil, 10, { min = -100, max = 100, step = 1 })
	group.args.debuffsGroup.args.stacks.args.countYOffset = ACH:Range(L["Y-Offset"], nil, 9, { min = -100, max = 100, step = 1 })
	group.args.debuffsGroup.args.stacks.args.countPosition = ACH:Select(L["Position"], nil, 3, { TOP = 'TOP', LEFT = 'LEFT', BOTTOM = 'BOTTOM', CENTER = 'CENTER', TOPLEFT = 'TOPLEFT', BOTTOMLEFT = 'BOTTOMLEFT', BOTTOMRIGHT = 'BOTTOMRIGHT', RIGHT = 'RIGHT', TOPRIGHT = 'TOPRIGHT' })

	group.args.debuffsGroup.args.duration = ACH:Group(L["Duration"], nil, 25)
	group.args.debuffsGroup.args.duration.inline = true
	group.args.debuffsGroup.args.duration.args.cooldownShortcut = ACH:Execute(L["Cooldowns"], nil, 1, function() ACD:SelectGroup('ElvUI', 'cooldown', 'nameplates') end)
	group.args.debuffsGroup.args.duration.args.durationPosition = ACH:Select(L["Position"], nil, 2, { TOP = 'TOP', LEFT = 'LEFT', BOTTOM = 'BOTTOM', CENTER = 'CENTER', TOPLEFT = 'TOPLEFT', BOTTOMLEFT = 'BOTTOMLEFT', BOTTOMRIGHT = 'BOTTOMRIGHT', RIGHT = 'RIGHT', TOPRIGHT = 'TOPRIGHT' })

	group.args.debuffsGroup.args.filtersGroup = ACH:Group(L["FILTERS"], nil, 30)
	group.args.debuffsGroup.args.filtersGroup.inline = true
	group.args.debuffsGroup.args.filtersGroup.args.minDuration = ACH:Range(L["Minimum Duration"], L["Don't display auras that are shorter than this duration (in seconds). Set to zero to disable."], 1, { min = 0, max = 10800, step = 1 })
	group.args.debuffsGroup.args.filtersGroup.args.maxDuration = ACH:Range(L["Maximum Duration"], L["Don't display auras that are longer than this duration (in seconds). Set to zero to disable."], 1, { min = 0, max = 10800, step = 1 })
	group.args.debuffsGroup.args.filtersGroup.args.jumpToFilter = ACH:Execute(L["Filters Page"], L["Shortcut to global filters."], 3, function() ACD:SelectGroup('ElvUI', 'filters') end)
	group.args.debuffsGroup.args.filtersGroup.args.specialFilters = ACH:Select(L["Add Special Filter"], L["These filters don't use a list of spells like the regular filters. Instead they use the WoW API and some code logic to determine if an aura should be allowed or blocked."], 4, function() wipe(filters) local list = E.global.unitframe.specialFilters if not (list and next(list)) then return filters end for filter in pairs(list) do filters[filter] = L[filter] end return filters end, nil, nil, nil, function(_, value) C.SetFilterPriority(E.db.nameplates.units, unit, 'debuffs', value) NP:ConfigureAll() end)
	group.args.debuffsGroup.args.filtersGroup.args.specialFilters.sortByValue = true
	group.args.debuffsGroup.args.filtersGroup.args.filter = ACH:Select(L["Add Regular Filter"], L["These filters use a list of spells to determine if an aura should be allowed or blocked. The content of these filters can be modified in the Filters section of the config."], 5, function() wipe(filters) local list = E.global.unitframe.aurafilters if not (list and next(list)) then return filters end for filter in pairs(list) do filters[filter] = L[filter] end return filters end, nil, nil, nil, function(_, value) C.SetFilterPriority(E.db.nameplates.units, unit, 'debuffs', value) NP:ConfigureAll() end)
	group.args.debuffsGroup.args.filtersGroup.args.resetPriority = ACH:Execute(L["Reset Priority"], L["Reset filter priority to the default state."], 7, function() E.db.nameplates.units[unit].debuffs.priority = P.nameplates.units[unit].debuffs.priority NP:ConfigureAll() end)

	group.args.debuffsGroup.args.filtersGroup.args.filterPriority = ACH:MultiSelect(L["Filter Priority"], nil, 8, function() local str = E.db.nameplates.units[unit].debuffs.priority if str == '' then return {} end return {strsplit(',', str)} end, nil, nil, function(_, value) local str = E.db.nameplates.units[unit].debuffs.priority if str == '' then return end local tbl = {strsplit(',', str)} return tbl[value] end, function() NP:ConfigureAll() end)
	group.args.debuffsGroup.args.filtersGroup.args.filterPriority.dragdrop = true
	group.args.debuffsGroup.args.filtersGroup.args.filterPriority.dragOnLeave = E.noop
	group.args.debuffsGroup.args.filtersGroup.args.filterPriority.dragOnEnter = function(info) carryFilterTo = info.obj.value end
	group.args.debuffsGroup.args.filtersGroup.args.filterPriority.dragOnMouseDown = function(info) carryFilterFrom, carryFilterTo = info.obj.value, nil end
	group.args.debuffsGroup.args.filtersGroup.args.filterPriority.dragOnMouseUp = function() C.SetFilterPriority(E.db.nameplates.units, unit, 'debuffs', carryFilterTo, nil, carryFilterFrom) carryFilterFrom, carryFilterTo = nil, nil end
	group.args.debuffsGroup.args.filtersGroup.args.filterPriority.dragOnClick = function() C.SetFilterPriority(E.db.nameplates.units, unit, 'debuffs', carryFilterFrom, true) end
	group.args.debuffsGroup.args.filtersGroup.args.filterPriority.stateSwitchGetText = C.StateSwitchGetText
	group.args.debuffsGroup.args.filtersGroup.args.filterPriority.stateSwitchOnClick = function() C.SetFilterPriority(E.db.nameplates.units, unit, 'debuffs', carryFilterFrom, nil, nil, true) end
	group.args.debuffsGroup.args.filtersGroup.args.spacer1 = ACH:Description(L["Use drag and drop to rearrange filter priority or right click to remove a filter."] ..'\n'..L["Use Shift+LeftClick to toggle between friendly or enemy or normal state. Normal state will allow the filter to be checked on all units. Friendly state is for friendly units only and enemy state is for enemy units."], 9)

	group.args.portraitGroup = ACH:Group(L["Portrait"], nil, 10, nil, function(info) return E.db.nameplates.units[unit].portrait[info[#info]] end, function(info, value) E.db.nameplates.units[unit].portrait[info[#info]] = value NP:ConfigureAll() end)
	group.args.portraitGroup.args.enable = ACH:Toggle(L["Enable"], nil, 1)
	group.args.portraitGroup.args.width = ACH:Range(L["Width"], nil, 2, { min = 12, max = 64, step = 1 })
	group.args.portraitGroup.args.height = ACH:Range(L["Height"], nil, 3, { min = 12, max = 64, step = 1 })
	group.args.portraitGroup.args.position = ACH:Select(L["Position"], nil, 4, { LEFT = 'LEFT', RIGHT = 'RIGHT', TOP = 'TOP', BOTTOM = 'BOTTOM', CENTER = 'CENTER' })
	group.args.portraitGroup.args.xOffset = ACH:Range(L["X-Offset"], nil, 5, { min = -100, max = 100, step = 1 })
	group.args.portraitGroup.args.yOffset = ACH:Range(L["Y-Offset"], nil, 6, { min = -100, max = 100, step = 1 })

	group.args.levelGroup = ACH:Group(L["Level"], nil, 8, nil, function(info) return E.db.nameplates.units[unit].level[info[#info]] end, function(info, value) E.db.nameplates.units[unit].level[info[#info]] = value NP:ConfigureAll() end)
	group.args.levelGroup.args.enable = ACH:Toggle(L["Enable"], nil, 1)
	group.args.levelGroup.args.format = ACH:Input(L["Text Format"], nil, 2, nil, 'full')
	group.args.levelGroup.args.position = ACH:Select(L["Position"], nil, 3, { CENTER = 'CENTER', TOPLEFT = 'TOPLEFT', BOTTOMLEFT = 'BOTTOMLEFT', TOPRIGHT = 'TOPRIGHT', BOTTOMRIGHT = 'BOTTOMRIGHT' })
	group.args.levelGroup.args.parent = ACH:Select(L["Parent"], nil, 4, { Nameplate = L["Nameplate"], Health = L["Health"] })
	group.args.levelGroup.args.xOffset = ACH:Range(L["X-Offset"], nil, 5, { min = -100, max = 100, step = 1 })
	group.args.levelGroup.args.yOffset = ACH:Range(L["Y-Offset"], nil, 6, { min = -100, max = 100, step = 1 })

	group.args.levelGroup.args.fontGroup = ACH:Group('', nil, 7)
	group.args.levelGroup.args.fontGroup.inline = true
	group.args.levelGroup.args.fontGroup.args.font = ACH:SharedMediaFont(L["Font"], nil, 1)
	group.args.levelGroup.args.fontGroup.args.fontSize = ACH:Range(L["Font Size"], nil, 2, { min = 4, max = 60, step = 1 })
	group.args.levelGroup.args.fontGroup.args.fontOutline = ACH:FontFlags(L["Font Outline"], nil, 3)

	group.args.nameGroup = ACH:Group(L["Name"], nil, 8, nil, function(info) return E.db.nameplates.units[unit].name[info[#info]] end, function(info, value) E.db.nameplates.units[unit].name[info[#info]] = value NP:ConfigureAll() end)
	group.args.nameGroup.args.enable = ACH:Toggle(L["Enable"], nil, 1)
	group.args.nameGroup.args.format = ACH:Input(L["Text Format"], nil, 2, nil, 'full')
	group.args.nameGroup.args.position = ACH:Select(L["Position"], nil, 3, { CENTER = 'CENTER', TOPLEFT = 'TOPLEFT', BOTTOMLEFT = 'BOTTOMLEFT', TOPRIGHT = 'TOPRIGHT', BOTTOMRIGHT = 'BOTTOMRIGHT' })
	group.args.nameGroup.args.parent = ACH:Select(L["Parent"], nil, 4, { Nameplate = L["Nameplate"], Health = L["Health"] })
	group.args.nameGroup.args.xOffset = ACH:Range(L["X-Offset"], nil, 5, { min = -100, max = 100, step = 1 })
	group.args.nameGroup.args.yOffset = ACH:Range(L["Y-Offset"], nil, 6, { min = -100, max = 100, step = 1 })

	group.args.nameGroup.args.fontGroup = ACH:Group('', nil, 7)
	group.args.nameGroup.args.fontGroup.inline = true
	group.args.nameGroup.args.fontGroup.args.font = ACH:SharedMediaFont(L["Font"], nil, 1)
	group.args.nameGroup.args.fontGroup.args.fontSize = ACH:Range(L["Font Size"], nil, 2, { min = 4, max = 60, step = 1 })
	group.args.nameGroup.args.fontGroup.args.fontOutline = ACH:FontFlags(L["Font Outline"], nil, 3)

	group.args.titleGroup = ACH:Group(UNIT_NAME_PLAYER_TITLE, nil, 8, nil, function(info) return E.db.nameplates.units[unit].title[info[#info]] end, function(info, value) E.db.nameplates.units[unit].title[info[#info]] = value NP:ConfigureAll() end)
	group.args.titleGroup.args.enable = ACH:Toggle(L["Enable"], nil, 1)
	group.args.titleGroup.args.format = ACH:Input(L["Text Format"], nil, 2, nil, 'full')
	group.args.titleGroup.args.position = ACH:Select(L["Position"], nil, 3, { CENTER = 'CENTER', TOPLEFT = 'TOPLEFT', BOTTOMLEFT = 'BOTTOMLEFT', TOPRIGHT = 'TOPRIGHT', BOTTOMRIGHT = 'BOTTOMRIGHT' })
	group.args.titleGroup.args.parent = ACH:Select(L["Parent"], nil, 4, { Nameplate = L["Nameplate"], Health = L["Health"] })
	group.args.titleGroup.args.xOffset = ACH:Range(L["X-Offset"], nil, 5, { min = -100, max = 100, step = 1 })
	group.args.titleGroup.args.yOffset = ACH:Range(L["Y-Offset"], nil, 6, { min = -100, max = 100, step = 1 })

	group.args.titleGroup.args.fontGroup = ACH:Group('', nil, 7)
	group.args.titleGroup.args.fontGroup.inline = true
	group.args.titleGroup.args.fontGroup.args.font = ACH:SharedMediaFont(L["Font"], nil, 1)
	group.args.titleGroup.args.fontGroup.args.fontSize = ACH:Range(L["Font Size"], nil, 2, { min = 4, max = 60, step = 1 })
	group.args.titleGroup.args.fontGroup.args.fontOutline = ACH:FontFlags(L["Font Outline"], nil, 3)

	group.args.pvpindicator = ACH:Group(L["PvP Indicator"], L["Horde / Alliance / Honor Info"], 10, nil, function(info) return E.db.nameplates.units[unit].pvpindicator[info[#info]] end, function(info, value) E.db.nameplates.units[unit].pvpindicator[info[#info]] = value NP:ConfigureAll() end)
	group.args.pvpindicator.args.enable = ACH:Toggle(L["Enable"], nil, 1)
	group.args.pvpindicator.args.showBadge = ACH:Toggle(L["Show Badge"], L["Show PvP Badge Indicator if available"], 2)
	group.args.pvpindicator.args.size = ACH:Range(L["Size"], nil, 3, { min = 12, max = 64, step = 1 })
	group.args.pvpindicator.args.position = ACH:Select(L["Position"], nil, 4, { LEFT = 'LEFT', RIGHT = 'RIGHT', TOP = 'TOP', BOTTOM = 'BOTTOM', CENTER = 'CENTER' })
	group.args.pvpindicator.args.xOffset = ACH:Range(L["X-Offset"], nil, 5, { min = -100, max = 100, step = 1 })
	group.args.pvpindicator.args.yOffset = ACH:Range(L["Y-Offset"], nil, 6, { min = -100, max = 100, step = 1 })

	group.args.raidTargetIndicator = ACH:Group(L["Target Marker Icon"], nil, 10, nil, function(info) return E.db.nameplates.units[unit].raidTargetIndicator[info[#info]] end, function(info, value) E.db.nameplates.units[unit].raidTargetIndicator[info[#info]] = value NP:ConfigureAll() end)
	group.args.raidTargetIndicator.args.enable = ACH:Toggle(L["Enable"], nil, 1)
	group.args.raidTargetIndicator.args.size = ACH:Range(L["Size"], nil, 3, { min = 12, max = 64, step = 1 })
	group.args.raidTargetIndicator.args.position = ACH:Select(L["Position"], nil, 4, { LEFT = 'LEFT', RIGHT = 'RIGHT', TOP = 'TOP', BOTTOM = 'BOTTOM', CENTER = 'CENTER' })
	group.args.raidTargetIndicator.args.xOffset = ACH:Range(L["X-Offset"], nil, 5, { min = -100, max = 100, step = 1 })
	group.args.raidTargetIndicator.args.yOffset = ACH:Range(L["Y-Offset"], nil, 6, { min = -100, max = 100, step = 1 })

	if unit == 'PLAYER' then
		group.args.classBarGroup = ACH:Group(L["Combo Points / Runes"], nil, 13, nil, function(info) return E.db.nameplates.units[unit].classpower[info[#info]] end, function(info, value) E.db.nameplates.units[unit].classpower[info[#info]] = value NP:ConfigureAll() end)
		group.args.classBarGroup.args.enable = ACH:Toggle(L["Enable"], nil, 1)
		group.args.classBarGroup.args.classColor = ACH:Toggle(L["Use Class Color"], nil, 2, nil, nil, nil, nil, nil, nil, not E.Retail and E.myclass == 'DEATHKNIGHT')
		group.args.classBarGroup.args.width = ACH:Range(L["Width"], nil, 3, { min = minWidth, max = MaxWidth(unit), step = 1 })
		group.args.classBarGroup.args.height = ACH:Range(L["Height"], nil, 4, { min = minHeight, max = MaxHeight(unit), step = 1 })
		group.args.classBarGroup.args.xOffset = ACH:Range(L["X-Offset"], nil, 5, { min = -100, max = 100, step = 1 })
		group.args.classBarGroup.args.yOffset = ACH:Range(L["Y-Offset"], nil, 6, { min = -100, max = 100, step = 1 })
		group.args.classBarGroup.args.sortDirection = ACH:Select(L["Sort Direction"], L["Defines the sort order of the selected sort method."], 7, { asc = L["Ascending"], desc = L["Descending"], NONE = L["None"] }, nil, nil, nil, nil, nil, function() return (E.myclass ~= 'DEATHKNIGHT') end)

		group.args.castGroup.args.displayTarget = ACH:Toggle(L["Display Target"], L["Display the target of current cast."], 4)

		group.args.general.args.useStaticPosition = ACH:Toggle(L["Use Static Position"], L["When enabled the nameplate will stay visible in a locked position."], 105, nil, nil, nil, nil, nil, function() return not E.db.nameplates.units[unit].enable end)
	elseif unit == 'FRIENDLY_PLAYER' or unit == 'ENEMY_PLAYER' then
		group.args.general.args.markHealers = ACH:Toggle(L["Healer Icon"], L["Display a healer icon over known healers inside battlegrounds or arenas."], 105)
		group.args.general.args.markHealers = ACH:Toggle(L["Tank Icon"], L["Display a tank icon over known tanks inside battlegrounds or arenas."], 106)
	elseif unit == 'ENEMY_NPC' or unit == 'FRIENDLY_NPC' then
		group.args.eliteIcon = ACH:Group(L["Elite Icon"], nil, 13, nil, function(info) return E.db.nameplates.units[unit].eliteIcon[info[#info]] end, function(info, value) E.db.nameplates.units[unit].eliteIcon[info[#info]] = value NP:ConfigureAll() end)
		group.args.eliteIcon.args.enable = ACH:Toggle(L["Enable"], nil, 1)
		group.args.eliteIcon.args.size = ACH:Range(L["Size"], nil, 3, { min = 12, max = 64, step = 1 })
		group.args.eliteIcon.args.position = ACH:Select(L["Position"], nil, 4, { LEFT = 'LEFT', RIGHT = 'RIGHT', TOP = 'TOP', BOTTOM = 'BOTTOM', CENTER = 'CENTER' })
		group.args.eliteIcon.args.xOffset = ACH:Range(L["X-Offset"], nil, 5, { min = -100, max = 100, step = 1 })
		group.args.eliteIcon.args.yOffset = ACH:Range(L["Y-Offset"], nil, 6, { min = -100, max = 100, step = 1 })

		group.args.castGroup.args.displayTarget = ACH:Toggle(L["Display Target"], L["Display the target of current cast."], 4)

		group.args.questIcon = ACH:Group(L["Quest Icon"], nil, 14, nil, function(info) return E.db.nameplates.units[unit].questIcon[info[#info]] end, function(info, value) E.db.nameplates.units[unit].questIcon[info[#info]] = value NP:ConfigureAll() end, nil, not E.Retail)
		group.args.questIcon.args.enable = ACH:Toggle(L["Enable"], nil, 1)
		group.args.questIcon.args.hideIcon = ACH:Toggle(L["Hide Icon"], nil, 2)
		group.args.questIcon.args.size = ACH:Range(L["Size"], nil, 3, { min = 12, max = 64, step = 1 })
		group.args.questIcon.args.position = ACH:Select(L["Position"], nil, 4, { LEFT = 'LEFT', RIGHT = 'RIGHT', TOP = 'TOP', BOTTOM = 'BOTTOM', CENTER = 'CENTER' })
		group.args.questIcon.args.xOffset = ACH:Range(L["X-Offset"], nil, 5, { min = -100, max = 100, step = 1 })
		group.args.questIcon.args.yOffset = ACH:Range(L["Y-Offset"], nil, 6, { min = -100, max = 100, step = 1 })

		group.args.questIcon.args.fontGroup = ACH:Group('', nil, 7)
		group.args.questIcon.args.fontGroup.inline = true
		group.args.questIcon.args.fontGroup.args.font = ACH:SharedMediaFont(L["Font"], nil, 1)
		group.args.questIcon.args.fontGroup.args.fontSize = ACH:Range(L["Font Size"], nil, 2, { min = 4, max = 60, step = 1 })
		group.args.questIcon.args.fontGroup.args.fontOutline = ACH:FontFlags(L["Font Outline"], nil, 3)
		group.args.questIcon.args.fontGroup.args.textPosition = ACH:Select(L["Text Position"], nil, 4, { TOP = 'TOP', LEFT = 'LEFT', BOTTOM = 'BOTTOM', CENTER = 'CENTER', TOPLEFT = 'TOPLEFT', BOTTOMLEFT = 'BOTTOMLEFT', BOTTOMRIGHT = 'BOTTOMRIGHT', RIGHT = 'RIGHT', TOPRIGHT = 'TOPRIGHT' })
	end

	-- Every normal nameplate type gets the same real ElvNP preview.
	group.args.previewMode = ACH:Toggle(
		"Preview Mode",
		"Show a live 1:1 preview of this nameplate type using the real ElvUI nameplate frame, including dummy buffs and debuffs.",
		-9
	)
	group.args.previewMode.get = function()
		return NP:IsPreviewShown(unit)
	end
	group.args.previewMode.set = function(_, value)
		NP:SetPreviewMode(unit, value)
	end
	group.args.previewMode.disabled = function()
		return InCombatLockdown() or not E.NamePlates.Initialized
	end

	if unit == 'FRIENDLY_PLAYER' or unit == 'ENEMY_PLAYER' then
		group.args.healthGroup.args.useClassColor = ACH:Toggle(L["Use Class Color"], nil, 10)
		group.args.healthGroup.args.useUnitFrameClassGradient = ACH:Toggle(
			"Use UnitFrame Class Gradient",
			"Use the class Base and Gradient colors from UnitFrames > General > Colors > Gradient.",
			11
		)
		group.args.healthGroup.args.useUnitFrameClassGradient.disabled = function()
			return not E.db.nameplates.units[unit].health.useClassColor
		end

		group.args.portraitGroup.args.classicon = ACH:Toggle(L["Class Icon"], nil, 2)

		group.args.pvpclassificationindicator = ACH:Group(L["PvP Classification Indicator"], L["Cart / Flag / Orb / Assassin Bounty"], 30, nil, function(info) return E.db.nameplates.units[unit].pvpclassificationindicator[info[#info]] end, function(info, value) E.db.nameplates.units[unit].pvpclassificationindicator[info[#info]] = value NP:ConfigureAll() end)
		group.args.pvpclassificationindicator.args.enable = ACH:Toggle(L["Enable"], nil, 1)
		group.args.pvpclassificationindicator.args.size = ACH:Range(L["Size"], nil, 2, { min = 12, max = 64, step = 1 })
		group.args.pvpclassificationindicator.args.position = ACH:Select(L["Position"], nil, 3, { LEFT = 'LEFT', RIGHT = 'RIGHT', TOP = 'TOP', BOTTOM = 'BOTTOM', CENTER = 'CENTER' })
		group.args.pvpclassificationindicator.args.xOffset = ACH:Range(L["X-Offset"], nil, 4, { min = -100, max = 100, step = 1 })
		group.args.pvpclassificationindicator.args.yOffset = ACH:Range(L["Y-Offset"], nil, 5, { min = -100, max = 100, step = 1 })
	end

	ORDER = ORDER + 2
	return group
end

E.Options.args.nameplates = ACH:Group(L["Nameplates"], nil, 18, 'tab', function(info) return E.db.nameplates[info[#info]] end, function(info, value) E.db.nameplates[info[#info]] = value; NP:ConfigureAll() end)
local NamePlates = E.Options.args.nameplates.args

NamePlates.intro = ACH:Description(L["NAMEPLATE_DESC"], 0)
NamePlates.enable = ACH:Toggle(L["Enable"], nil, 1, nil, nil, nil, function(info) return E.private.nameplates[info[#info]] end, function(info, value) E.private.nameplates[info[#info]] = value E.ShowPopup = true end)
NamePlates.statusbar = ACH:SharedMediaStatusbar(L["StatusBar Texture"], nil, 2)
NamePlates.resetFilters = ACH:Execute(L["Reset Aura Filters"], nil, 3, function() E:StaticPopup_Show('RESET_NP_AF') end)
NamePlates.resetcvars = ACH:Execute(L["Reset CVars"], L["Reset Nameplate CVars to the ElvUI recommended defaults."], 4, function() NP:CVarReset() end, nil, true)

NamePlates.generalGroup = ACH:Group(L["General"], nil, 5, nil, nil, function(info, value) E.db.nameplates[info[#info]] = value NP:SetCVars() NP:ConfigureAll() end, function() return not E.NamePlates.Initialized end)
NamePlates.generalGroup.args.motionType = ACH:Select(L["UNIT_NAMEPLATES_TYPES"], L["Set to either stack nameplates vertically or allow them to overlap."], 1, { OVERLAP = L["UNIT_NAMEPLATES_TYPE_1"], STACKED = L["UNIT_NAMEPLATES_TYPE_2"] })
NamePlates.generalGroup.args.showEnemyCombat = ACH:Select(L["Enemy Combat Toggle"], L["Control enemy nameplates toggling on or off when in combat."], 2, { DISABLED = L["Disable"], TOGGLE_ON = L["Toggle On While In Combat"], TOGGLE_OFF = L["Toggle Off While In Combat"] }, nil, nil, nil, function(info, value) E.db.nameplates[info[#info]] = value NP:PLAYER_REGEN_ENABLED() end)
NamePlates.generalGroup.args.showFriendlyCombat = ACH:Select(L["Friendly Combat Toggle"], L["Control friendly nameplates toggling on or off when in combat."], 3, { DISABLED = L["Disable"], TOGGLE_ON = L["Toggle On While In Combat"], TOGGLE_OFF = L["Toggle Off While In Combat"] }, nil, nil, nil, function(info, value) E.db.nameplates[info[#info]] = value NP:PLAYER_REGEN_ENABLED() end)
NamePlates.generalGroup.args.smoothbars = ACH:Toggle(L["Smooth Bars"], L["Bars will transition smoothly."], 4, nil, nil, 110)
NamePlates.generalGroup.args.spacer1 = ACH:Spacer(6, 'full')
NamePlates.generalGroup.args.lowHealthThreshold = ACH:Range(L["Low Health Threshold"], L["Make the unitframe glow when it is below this percent of health."], 11, { min = 0, softMax = .5, max = .8, step = .01, isPercent = true })
NamePlates.generalGroup.args.loadDistance = ACH:Range(L["Load Distance"], L["Only load nameplates for units within this range."], 12, { min = 5, max = 61, step = 1 }, nil, nil, nil, nil)
NamePlates.generalGroup.args.highlight = ACH:Toggle(L["Hover Highlight"], nil, 13, nil, nil, 125)

NamePlates.generalGroup.args.spacer2 = ACH:Spacer(15, 'full')
NamePlates.generalGroup.args.plateVisibility = ACH:Group(L["Visibility"], nil, 50)
NamePlates.generalGroup.args.plateVisibility.args.enemyVisibility = ACH:MultiSelect(L["Enemy"], nil, 10, { guardians = L["Guardians"], pets = L["Pets"], totems = L["Totems"] }, nil, nil, function(_, key) return E.db.nameplates.visibility.enemy[key] end, function(_, key, value) E.db.nameplates.visibility.enemy[key] = value NP:SetCVars() NP:ConfigureAll() end, function() return not E.db.nameplates.visibility.showAll end)
NamePlates.generalGroup.args.plateVisibility.args.friendlyVisibility = ACH:MultiSelect(L["Friendly"], nil, 15, { guardians = L["Guardians"], pets = L["Pets"], totems = L["Totems"] }, nil, nil, function(_, key) return E.db.nameplates.visibility.friendly[key] end, function(_, key, value) E.db.nameplates.visibility.friendly[key] = value NP:SetCVars() NP:ConfigureAll() end, function() return not E.db.nameplates.visibility.showAll end)

NamePlates.generalGroup.args.bossMods = ACH:Group(L["Boss Mod Auras"], nil, 55, nil, function(info) return E.db.nameplates.bossMods[info[#info]] end, function(info, value) E.db.nameplates.bossMods[info[#info]] = value NP:ConfigureAll() end)
NamePlates.generalGroup.args.bossMods.args.enable = ACH:Toggle(L["Enable"], nil, 0)
NamePlates.generalGroup.args.bossMods.args.supported = ACH:Group(L["Supported"], nil, 1)
NamePlates.generalGroup.args.bossMods.args.supported.inline = true
NamePlates.generalGroup.args.bossMods.args.supported.args.dbm = GetAddOnStatus(1, 'Deadly Boss Mods', 'DBM-Core')
NamePlates.generalGroup.args.bossMods.args.supported.args.bw = GetAddOnStatus(2, 'BigWigs', 'BigWigs')
NamePlates.generalGroup.args.bossMods.args.settings = ACH:Group(' ', nil, 2, nil, nil, nil, function() return not E.db.nameplates.bossMods.enable or not (IsAddOnLoaded('BigWigs') or IsAddOnLoaded('DBM-Core')) end)
NamePlates.generalGroup.args.bossMods.args.settings.inline = true
NamePlates.generalGroup.args.bossMods.args.settings.args.keepSizeRatio = ACH:Toggle(L["Keep Size Ratio"], nil, 1)
NamePlates.generalGroup.args.bossMods.args.settings.args.size = ACH:Range(function() return E.db.nameplates.bossMods.keepSizeRatio and L["Icon Size"] or L["Icon Width"] end, nil, 2, { min = 6, max = 64, step = 1 })
NamePlates.generalGroup.args.bossMods.args.settings.args.height = ACH:Range(L["Icon Height"], nil, 3, { min = 6, max = 64, step = 1 }, nil, nil, nil, nil, function() return E.db.nameplates.bossMods.keepSizeRatio end)
NamePlates.generalGroup.args.bossMods.args.settings.args.spacing = ACH:Range(L["Spacing"], nil, 4, { min = 6, max = 64, step = 1 }, nil, nil, nil, nil, function() return E.db.nameplates.bossMods.keepSizeRatio end)
NamePlates.generalGroup.args.bossMods.args.settings.args.xOffset = ACH:Range(L["X-Offset"], nil, 5, { min = -100, max = 100, step = 1 })
NamePlates.generalGroup.args.bossMods.args.settings.args.yOffset = ACH:Range(L["Y-Offset"], nil, 6, { min = -100, max = 100, step = 1 })
NamePlates.generalGroup.args.bossMods.args.settings.args.anchorPoint = ACH:Select(L["Anchor Point"], L["What point to anchor to the frame you set to attach to."], 7, positionValues)
NamePlates.generalGroup.args.bossMods.args.settings.args.growthDirection = ACH:Select(L["Growth Direction"], nil, 14, growthDirectionValues)

NamePlates.generalGroup.args.clickableRange = ACH:Group(L["Clickable Size"], nil, 70, nil, function(info) return E.db.nameplates.plateSize[info[#info]] end, function(info, value) E.db.nameplates.plateSize[info[#info]] = value NP:ConfigureAll() end)

NamePlates.generalGroup.args.clickableRange.args.width = ACH:Range(L["Clickable Width / Width"], L["Change the width and controls how big of an area on the screen will accept clicks to target unit."], 1, { min = 50, max = 250, step = 1 })
NamePlates.generalGroup.args.clickableRange.args.height = ACH:Range(L["Clickable Height"], L["Controls how big of an area on the screen will accept clicks to target unit."], 2, { min = 10, max = 75, step = 1 })

NamePlates.generalGroup.args.cutaway = ACH:Group(L["Cutaway Bars"], nil, 75)
NamePlates.generalGroup.args.cutaway.args.health = ACH:Group(L["Health"], nil, 1, nil, function(info) return E.db.nameplates.cutaway.health[info[#info]] end, function(info, value) E.db.nameplates.cutaway.health[info[#info]] = value NP:ConfigureAll() end)
NamePlates.generalGroup.args.cutaway.args.health.inline = true
NamePlates.generalGroup.args.cutaway.args.health.args.enabled = ACH:Toggle(L["Enable"], nil, 1)
NamePlates.generalGroup.args.cutaway.args.health.args.forceBlankTexture = ACH:Toggle(L["Blank Texture"], nil, 2)
NamePlates.generalGroup.args.cutaway.args.health.args.lengthBeforeFade = ACH:Range(L["Fade Out Delay"], L["How much time before the cutaway health starts to fade."], 3, { min = .1, max = 1, step = .1 }, nil, nil, nil, function() return not E.db.nameplates.cutaway.health.enabled end)
NamePlates.generalGroup.args.cutaway.args.health.args.fadeOutTime = ACH:Range(L["Fade Out"], L["How long the cutaway health will take to fade out."], 4, { min = .1, max = 1, step = .1 }, nil, nil, nil, function() return not E.db.nameplates.cutaway.health.enabled end)

NamePlates.generalGroup.args.cutaway.args.power = ACH:Group(L["Power"], nil, 2, nil, function(info) return E.db.nameplates.cutaway.power[info[#info]] end, function(info, value) E.db.nameplates.cutaway.power[info[#info]] = value NP:ConfigureAll() end)
NamePlates.generalGroup.args.cutaway.args.power.inline = true
NamePlates.generalGroup.args.cutaway.args.power.args.enabled = ACH:Toggle(L["Enable"], nil, 1)
NamePlates.generalGroup.args.cutaway.args.power.args.forceBlankTexture = ACH:Toggle(L["Blank Texture"], nil, 2)
NamePlates.generalGroup.args.cutaway.args.power.args.lengthBeforeFade = ACH:Range(L["Fade Out Delay"], L["How much time before the cutaway power starts to fade."], 3, { min = .1, max = 1, step = .1 }, nil, nil, nil, function() return not E.db.nameplates.cutaway.power.enabled end)
NamePlates.generalGroup.args.cutaway.args.power.args.fadeOutTime = ACH:Range(L["Fade Out"], L["How long the cutaway power will take to fade out."], 4, { min = .1, max = 1, step = .1 }, nil, nil, nil, function() return not E.db.nameplates.cutaway.power.enabled end)

NamePlates.generalGroup.args.threatGroup = ACH:Group(L["Threat"], nil, 80, nil, function(info) return E.db.nameplates.threat[info[#info]] end, function(info, value) E.db.nameplates.threat[info[#info]] = value NP:ConfigureAll() end)
NamePlates.generalGroup.args.threatGroup.args.enable = ACH:Toggle(L["Enable"], nil, 0)
NamePlates.generalGroup.args.threatGroup.args.goodScale = ACH:Range(L["Good Scale"], nil, 1, { min = .5, max = 1.5, step = .01, isPercent = true }, nil, nil, nil, function() return not E.db.nameplates.threat.enable end)
NamePlates.generalGroup.args.threatGroup.args.badScale = ACH:Range(L["Bad Scale"], nil, 2, { min = .5, max = 1.5, step = .01, isPercent = true }, nil, nil, nil, function() return not E.db.nameplates.threat.enable end)
NamePlates.generalGroup.args.threatGroup.args.useThreatColor = ACH:Toggle(L["Use Threat Color"], nil, 3)
NamePlates.generalGroup.args.threatGroup.args.beingTankedByTank = ACH:Toggle(L["Off Tank"], L["Use Off Tank Color when another Tank has threat."], 4, nil, nil, nil, nil, nil, function() return not E.db.nameplates.threat.useThreatColor end)
NamePlates.generalGroup.args.threatGroup.args.beingTankedByPet = ACH:Toggle(L["Off Tank (Pets)"], nil, 5, nil, nil, nil, nil, nil, function() return not E.db.nameplates.threat.useThreatColor end)
NamePlates.generalGroup.args.threatGroup.args.indicator = ACH:Toggle(L["Show Icon"], nil, 6, nil, nil, nil, nil, nil, function() return not E.db.nameplates.threat.enable end)

NamePlates.colorsGroup = ACH:Group(L["Colors"] or "Colors", nil, 15, nil, nil, nil, function() return not E.NamePlates.Initialized end)

-- Custom Nameplate Base -> Gradient rows.
-- Every statusbar color is displayed as: Label | Base | Gradient | Default.
-- Non-statusbar indicator colors use: Label | Base | Default.
do
	local function GetPath(root, path)
		local node = root
		for i = 1, #path do
			node = node and node[path[i]]
		end
		return node
	end

	local function EnsurePath(root, path)
		local node = root
		for i = 1, #path - 1 do
			local key = path[i]
			node[key] = node[key] or {}
			node = node[key]
		end
		return node, path[#path]
	end

	local function ClearPath(root, path)
		local node = root
		for i = 1, #path - 1 do
			node = node and node[path[i]]
			if not node then return end
		end
		if node then node[path[#path]] = nil end
	end

	local function DefaultGradient(r, g, b)
		return r + ((1-r) * 0.18), g + ((1-g) * 0.18), b + ((1-b) * 0.18)
	end

	local function GradientRoot(create)
		local colors = E.db.nameplates.colors
		local root = rawget(colors, 'gradientColors')
		if not root and create then
			root = {}
			colors.gradientColors = root
		end
		return root
	end

	local function Refresh()
		NP:ConfigureAll()
	end

	local function AddColorRow(args, id, label, order, path, alpha, allowGradient, hidden, gradientPath)
		local gPath = gradientPath or path
		args[id..'Label'] = {
			type = 'description', name = label or id, order = order, width = 0.9,
			hidden = hidden, fontSize = 'medium'
		}
		args[id..'Base'] = {
			type = 'color', name = 'Base Color', order = order + 0.1, width = 0.55, hasAlpha = alpha or false,
			hidden = hidden,
			get = function()
				local c = GetPath(E.db.nameplates.colors, path) or GetPath(P.nameplates.colors, path)
				if not c then return 1, 1, 1, 1 end
				return c.r or 1, c.g or 1, c.b or 1, c.a or 1
			end,
			set = function(_, r, g, b, a)
				local parent, key = EnsurePath(E.db.nameplates.colors, path)
				local c = parent[key] or {}
				parent[key] = c
				c.r, c.g, c.b = r, g, b
				if alpha then c.a = a or 1 end
				Refresh()
			end,
		}

		local nextOrder = order + 0.2
		if allowGradient then
			args[id..'Gradient'] = {
				type = 'color', name = 'Gradient Color', order = nextOrder, width = 0.7, hasAlpha = alpha or false,
				hidden = hidden,
				disabled = function() return not E.db.nameplates.colors.gradient end,
				get = function()
					local c = GetPath(GradientRoot(false), gPath)
					if c then return c.r or 1, c.g or 1, c.b or 1, c.a or 1 end
					local base = GetPath(E.db.nameplates.colors, path) or GetPath(P.nameplates.colors, path)
					if not base then return 1, 1, 1, 1 end
					local r, g, b = DefaultGradient(base.r or 1, base.g or 1, base.b or 1)
					return r, g, b, base.a or 1
				end,
				set = function(_, r, g, b, a)
					local parent, key = EnsurePath(GradientRoot(true), gPath)
					local c = parent[key] or {}
					parent[key] = c
					c.r, c.g, c.b = r, g, b
					if alpha then c.a = a or 1 end
					Refresh()
				end,
			}
			nextOrder = order + 0.3
		end

		args[id..'Default'] = {
			type = 'execute', name = 'Default', order = nextOrder, width = 0.55, hidden = hidden,
			func = function()
				local default = GetPath(P.nameplates.colors, path)
				if default then
					local parent, key = EnsurePath(E.db.nameplates.colors, path)
					parent[key] = {r = default.r, g = default.g, b = default.b}
					if default.a ~= nil then parent[key].a = default.a end
				end
				ClearPath(GradientRoot(false), gPath)
				Refresh()
			end,
		}
		args[id..'Break'] = { type = 'description', name = '', order = order + 0.9, width = 'full', hidden = hidden }
	end

	NamePlates.colorsGroup.args.general = ACH:Group(L["General"] or "General", nil, 1)
	NamePlates.colorsGroup.args.general.inline = true
	local general = NamePlates.colorsGroup.args.general.args
	general.gradient = ACH:Toggle('Gradient', 'Use Base -> Gradient colors on nameplate status bars.', 0,
		nil, nil, nil,
		function() return E.db.nameplates.colors.gradient end,
		function(_, value) E.db.nameplates.colors.gradient = value Refresh() end)
	general.preferGlowColor = ACH:Toggle(L["Prefer Target Color"] or "Prefer Target Color", L["When this is enabled, Low Health Threshold colors will not be displayed while targeted."], 1, nil, nil, nil,
		function() return E.db.nameplates.colors.preferGlowColor end,
		function(_, value) E.db.nameplates.colors.preferGlowColor = value Refresh() end)
	general.auraByDispels = ACH:Toggle(L["Borders By Dispel"] or "Borders By Dispel", nil, 2, nil, nil, nil,
		function() return E.db.nameplates.colors.auraByDispels end,
		function(_, value) E.db.nameplates.colors.auraByDispels = value Refresh() end)
	general.auraByType = ACH:Toggle(L["Borders By Type"] or "Borders By Type", nil, 3, nil, nil, nil,
		function() return E.db.nameplates.colors.auraByType end,
		function(_, value) E.db.nameplates.colors.auraByType = value Refresh() end)
	general.indicatorHeader = ACH:Header('Indicator Colors', 5)
	AddColorRow(general, 'glowColorRow', L["Target Indicator Color"] or 'Target Indicator Color', 6, {'glowColor'}, true, false)
	AddColorRow(general, 'lowHealthColorRow', L["Low Health Color"] or 'Low Health Color', 7, {'lowHealthColor'}, true, false)
	AddColorRow(general, 'lowHealthHalfRow', L["Low Health Half"] or 'Low Health Half', 8, {'lowHealthHalf'}, true, false)

	NamePlates.colorsGroup.args.threat = ACH:Group(L["Threat"] or "Threat", nil, 2, nil, nil, nil, function() return not E.db.nameplates.threat.useThreatColor end)
	NamePlates.colorsGroup.args.threat.inline = true
	local threat = NamePlates.colorsGroup.args.threat.args
	AddColorRow(threat, 'goodColorRow', L["Good Color"] or 'Good Color', 1, {'threat','goodColor'}, false, true)
	AddColorRow(threat, 'goodTransitionRow', L["Good Transition Color"] or 'Good Transition Color', 2, {'threat','goodTransition'}, false, true)
	AddColorRow(threat, 'badTransitionRow', L["Bad Transition Color"] or 'Bad Transition Color', 3, {'threat','badTransition'}, false, true)
	AddColorRow(threat, 'badColorRow', L["Bad Color"] or 'Bad Color', 4, {'threat','badColor'}, false, true)
	local offTankHidden = function() return not E.db.nameplates.threat.beingTankedByTank or not E.db.nameplates.threat.useThreatColor end
	AddColorRow(threat, 'offTankColorRow', L["Off Tank"] or 'Off Tank', 5, {'threat','offTankColor'}, false, true, offTankHidden)
	AddColorRow(threat, 'offTankGoodRow', L["Off Tank Good Transition"] or 'Off Tank Good Transition', 6, {'threat','offTankColorGoodTransition'}, false, true, offTankHidden)
	AddColorRow(threat, 'offTankBadRow', L["Off Tank Bad Transition"] or 'Off Tank Bad Transition', 7, {'threat','offTankColorBadTransition'}, false, true, offTankHidden)

	NamePlates.colorsGroup.args.castGroup = ACH:Group(L["Cast Bar"] or "Cast Bar", nil, 3)
	NamePlates.colorsGroup.args.castGroup.inline = true
	local cast = NamePlates.colorsGroup.args.castGroup.args
	AddColorRow(cast, 'castColorRow', L["Interruptible"] or 'Interruptible', 1, {'castColor'}, false, true, nil, {'cast','castColor'})
	AddColorRow(cast, 'castNoInterruptRow', L["Non-Interruptible"] or 'Non-Interruptible', 2, {'castNoInterruptColor'}, false, true, nil, {'cast','castNoInterruptColor'})
	AddColorRow(cast, 'castInterruptedRow', L["Interrupted"] or 'Interrupted', 3, {'castInterruptedColor'}, false, true, nil, {'cast','castInterruptedColor'})
	cast.castbarDesaturate = ACH:Toggle(L["Desaturated Icon"] or "Desaturated Icon", L["Show the castbar icon desaturated if a spell is not interruptible."], 4, nil, nil, nil,
		function() return E.db.nameplates.colors.castbarDesaturate end,
		function(_, value) E.db.nameplates.colors.castbarDesaturate = value Refresh() end)

	NamePlates.colorsGroup.args.selectionGroup = ACH:Group(L["Selection"] or "Selection", nil, 4)
	NamePlates.colorsGroup.args.selectionGroup.inline = true
	local selection = NamePlates.colorsGroup.args.selectionGroup.args
	local selectionRows = {
		{0, L["Hostile"] or 'Hostile'}, {1, L["Unfriendly"] or 'Unfriendly'}, {2, L["Neutral"] or 'Neutral'},
		{3, L["Friendly"] or 'Friendly'}, {5, L["Player"] or 'Player'}, {6, L["Party"] or 'Party'},
		{7, L["Party PVP"] or 'Party PVP'}, {8, L["Friend"] or 'Friend'}, {9, L["Dead"] or 'Dead'},
		{13, L["Battleground Friendly"] or 'Battleground Friendly'},
	}
	for i = 1, #selectionRows do
		local entry = selectionRows[i]
		AddColorRow(selection, 'selection'..entry[1], entry[2], i, {'selection', entry[1]}, false, true)
	end

	NamePlates.colorsGroup.args.reactions = ACH:Group(L["Reaction Colors"] or "Reaction Colors", nil, 5)
	NamePlates.colorsGroup.args.reactions.inline = true
	local reactions = NamePlates.colorsGroup.args.reactions.args
	AddColorRow(reactions, 'reactionBad', L["Enemy"] or 'Enemy', 1, {'reactions','bad'}, false, true)
	AddColorRow(reactions, 'reactionNeutral', L["Neutral"] or 'Neutral', 2, {'reactions','neutral'}, false, true)
	AddColorRow(reactions, 'reactionGood', L["Friendly"] or 'Friendly', 3, {'reactions','good'}, false, true)
	AddColorRow(reactions, 'reactionTapped', L["Tagged NPC"] or 'Tagged NPC', 4, {'tapped'}, false, true, nil, {'reactions','tapped'})

	NamePlates.colorsGroup.args.healPrediction = ACH:Group(L["Heal Prediction"] or "Heal Prediction", nil, 6)
	NamePlates.colorsGroup.args.healPrediction.inline = true
	local heal = NamePlates.colorsGroup.args.healPrediction.args
	AddColorRow(heal, 'healPersonal', L["Personal"] or 'Personal', 1, {'healPrediction','personal'}, true, true)
	AddColorRow(heal, 'healOthers', L["Others"] or 'Others', 2, {'healPrediction','others'}, true, true)

	NamePlates.colorsGroup.args.power = ACH:Group(L["Power Color"] or "Power Color", nil, 7)
	NamePlates.colorsGroup.args.power.inline = true
	local power = NamePlates.colorsGroup.args.power.args
	local powerRows = {
		{'MANA', L["MANA"] or 'Mana'}, {'RAGE', L["RAGE"] or 'Rage'}, {'FOCUS', L["FOCUS"] or 'Focus'},
		{'ENERGY', L["ENERGY"] or 'Energy'}, {'RUNIC_POWER', L["RUNIC_POWER"] or 'Runic Power'}, {'ALT_POWER', L["Swapped Alt Power"] or 'Swapped Alt Power'},
	}
	for i = 1, #powerRows do
		local entry = powerRows[i]
		AddColorRow(power, 'power'..entry[1], entry[2], i, {'power',entry[1]}, false, true)
	end

	NamePlates.colorsGroup.args.COMBO_POINTS = ACH:Group(L["COMBO_POINTS"] or "Combo Points", nil, 10)
	NamePlates.colorsGroup.args.COMBO_POINTS.inline = true
	local combo = NamePlates.colorsGroup.args.COMBO_POINTS.args
	AddColorRow(combo, 'chargedCombo', L["Charged Combo Point"] or 'Charged Combo Point', 1, {'classResources','chargedComboPoint'}, false, true, function() return not E.Retail end)
	for i = 1, 7 do
		AddColorRow(combo, 'combo'..i, (L["COMBO_POINTS"] or 'Combo Point')..' '..i, i + 1, {'classResources','comboPoints',i}, false, true)
	end

	NamePlates.colorsGroup.args.RUNES = ACH:Group(L["RUNES"] or "Runes", nil, 4, nil, nil, nil, nil, not (E.Retail or E.Wrath))
	NamePlates.colorsGroup.args.RUNES.inline = true
	local runes = NamePlates.colorsGroup.args.RUNES.args
	local runeText = { [-1] = L["RUNE_CHARGE"] or 'Rune Charge', [0] = L["RUNES"] or 'Runes', L["RUNE_BLOOD"] or 'Blood', L["RUNE_FROST"] or 'Frost', L["RUNE_UNHOLY"] or 'Unholy', L["RUNE_DEATH"] or 'Death' }
	for i = -1, 4 do
		local index = i
		local hidden = function()
			return (index == -1 and not E.db.nameplates.colors.chargingRunes) or (E.Wrath and index < 1) or (not E.Wrath and index == 4) or (E.Retail and E.db.unitframe.colors.runeBySpec and index == 0) or (E.Retail and not E.db.unitframe.colors.runeBySpec and index > 0)
		end
		AddColorRow(runes, 'rune'..tostring(i), runeText[i], i == -1 and 10 or i + 1, {'classResources','DEATHKNIGHT',i}, false, true, hidden)
	end
	runes.runeBySpec = ACH:Toggle(L["Color By Spec"] or "Color By Spec", nil, 20, nil, nil, nil,
		function() return E.db.nameplates.colors.runeBySpec end,
		function(_, value) E.db.nameplates.colors.runeBySpec = value Refresh() end, nil, not E.Retail)
	runes.chargingRunes = ACH:Toggle(E.Retail and (L["Charging Rune Color"] or "Charging Rune Color") or (L["Faded Charging Rune"] or "Faded Charging Rune"), nil, 21, nil, nil, nil,
		function() return E.db.nameplates.colors.chargingRunes end,
		function(_, value) E.db.nameplates.colors.chargingRunes = value Refresh() end)
end

NamePlates.friendlyPlayerGroup = GetUnitSettings('FRIENDLY_PLAYER', L["FRIENDLY_PLAYER"])
NamePlates.friendlyNPCGroup = GetUnitSettings('FRIENDLY_NPC', L["FRIENDLY_NPC"])
NamePlates.enemyPlayerGroup = GetUnitSettings('ENEMY_PLAYER', L["ENEMY_PLAYER"])
NamePlates.enemyNPCGroup = GetUnitSettings('ENEMY_NPC', L["ENEMY_NPC"])

NamePlates.targetGroup = ACH:Group(L["Target"], nil, 101, nil, function(info) return E.db.nameplates.units.TARGET[info[#info]] end, function(info, value) E.db.nameplates.units.TARGET[info[#info]] = value NP:SetCVars() NP:ConfigureAll() end, function() return not E.NamePlates.Initialized end)
NamePlates.targetGroup.args.previewMode = ACH:Toggle(
	"Preview Mode",
	"Show the Target settings on a real Enemy Player nameplate preview.",
	1
)
NamePlates.targetGroup.args.previewMode.get = function() return NP:IsPreviewShown('TARGET') end
NamePlates.targetGroup.args.previewMode.set = function(_, value) NP:SetPreviewMode('TARGET', value) end
NamePlates.targetGroup.args.previewMode.disabled = function() return InCombatLockdown() or not E.NamePlates.Initialized end
NamePlates.targetGroup.args.targetScaleShortcut = ACH:Execute(L["Scale"], nil, 2, function() C:StyleFilterSetConfig('ElvUI_Target'); ACD:SelectGroup('ElvUI', 'nameplates', 'stylefilters', 'actions') end)
NamePlates.targetGroup.args.spacer1 = ACH:Spacer(3, 'full')
NamePlates.targetGroup.args.glowStyle = ACH:Select(L["Target/Low Health Indicator"], nil, 4, { none = L["None"], style1 = L["Border Glow"], style2 = L["Background Glow"], style3 = L["Top Arrow"], style4 = L["Side Arrows"], style5 = L["Border Glow"]..' + '..L["Top Arrow"], style6 = L["Background Glow"]..' + '..L["Top Arrow"], style7 = L["Border Glow"]..' + '..L["Side Arrows"], style8 = L["Background Glow"]..' + '..L["Side Arrows"] }, nil, 225)
NamePlates.targetGroup.args.arrowScale = ACH:Range(L["Arrow Scale"], nil, 5, { min = .2, max = 2, step = .01, isPercent = true })
NamePlates.targetGroup.args.arrowSpacing = ACH:Range(L["Arrow Spacing"], nil, 6, { min = 0, max = 50, step = 1 })
NamePlates.targetGroup.args.arrows = ACH:MultiSelect(L["Arrow Texture"], nil, 30, nil, nil, 80, function(_, key) return E.db.nameplates.units.TARGET.arrow == key end, function(_, key) E.db.nameplates.units.TARGET.arrow = key NP:SetCVars() NP:ConfigureAll() end)

local arrows = {
	Arrow = E.Media.Textures.Arrow,
	ArrowRight = E.Media.Textures.ArrowRight,
	ArrowUp = E.Media.Textures.ArrowUp,
}
for key, arrow in pairs(arrows) do
	NamePlates.targetGroup.args.arrows.values[key] = E:TextureString(arrow, ':32:32')
end

for key, arrow in pairs(E.Media.Arrows) do
	arrows[key] = arrow
	NamePlates.targetGroup.args.arrows.values[key] = E:TextureString(arrow, ':32:32')
end

NamePlates.targetGroup.args.classBarGroup = ACH:Group(L["Combo Points / Runes"], nil, 13, nil, function(info) return E.db.nameplates.units.TARGET.classpower[info[#info]] end, function(info, value) E.db.nameplates.units.TARGET.classpower[info[#info]] = value NP:ConfigureAll() end)
NamePlates.targetGroup.args.classBarGroup.inline = true
NamePlates.targetGroup.args.classBarGroup.args.enable = ACH:Toggle(L["Enable"], nil, 1)
NamePlates.targetGroup.args.classBarGroup.args.classColor = ACH:Toggle(L["Use Class Color"], nil, 2, nil, nil, nil, nil, nil, nil, not E.Retail and E.myclass == 'DEATHKNIGHT')
NamePlates.targetGroup.args.classBarGroup.args.width = ACH:Range(L["Width"], nil, 3, { min = minWidth, max = MaxWidth('PLAYER'), step = 1 })
NamePlates.targetGroup.args.classBarGroup.args.height = ACH:Range(L["Height"], nil, 4, { min = minHeight, max = MaxHeight('PLAYER'), step = 1 })
NamePlates.targetGroup.args.classBarGroup.args.xOffset = ACH:Range(L["X-Offset"], nil, 5, { min = -100, max = 100, step = 1 })
NamePlates.targetGroup.args.classBarGroup.args.yOffset = ACH:Range(L["Y-Offset"], nil, 6, { min = -100, max = 100, step = 1 })
NamePlates.targetGroup.args.classBarGroup.args.sortDirection = ACH:Select(L["Sort Direction"], L["Defines the sort order of the selected sort method."], 7, { asc = L["Ascending"], desc = L["Descending"], NONE = L["None"] }, nil, nil, nil, nil, nil, function() return (E.myclass ~= 'DEATHKNIGHT') end)
