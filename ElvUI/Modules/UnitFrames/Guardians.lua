local E, L, V, P, G = unpack(select(2, ...))
local UF = E:GetModule("UnitFrames")
local GF = E:NewModule("Guardians", "AceEvent-3.0", "AceTimer-3.0")
UF.Guardians = GF

-- State Tables
GF.activeGuardians = {}       -- Tracked active summons [GUID] = { data }
GF.customGuardiansList = {}   -- Set of lowercase guardian names to track [name] = true
GF.learnedMaxHealth = setmetatable({}, {
	__index = function(_, key)
		return E.db and E.db.unitframe.units.guardians and E.db.unitframe.units.guardians.learnedMaxHealth and E.db.unitframe.units.guardians.learnedMaxHealth[key]
	end,
	__newindex = function(_, key, value)
		if E.db and E.db.unitframe.units.guardians then
			if not E.db.unitframe.units.guardians.learnedMaxHealth then
				E.db.unitframe.units.guardians.learnedMaxHealth = {}
			end
			E.db.unitframe.units.guardians.learnedMaxHealth[key] = value
		end
	end
})      -- Session-learned max health for guardians [name] = maxHealth
GF.framePool = {}             -- Active visible bars
GF.inactiveFramePool = {}     -- Recycled bars
GF.container = nil            -- Main parent / mover frame

GF.guardianCounter = 0
local function GetNextCreationID()
	GF.guardianCounter = GF.guardianCounter + 1
	return GF.guardianCounter
end

-- Pre-defined spell durations for SPELL_SUMMON mapping
local spellDurations = {
	-- Force of Nature (Treants)
	[2062] = 30, [33908] = 30,
	-- Summon Gargoyle
	[49206] = 30,
	-- Mirror Image
	[55342] = 30,
	-- Feral Spirit (Spirit Wolves)
	[51533] = 45,
	-- Summon Water Elemental
	[31687] = 45, [43987] = 45,
	-- Army of the Dead (Ghouls)
	[42650] = 40,
	-- Dancing Rune Weapon
	[49028] = 12,
	-- Fire Elemental Totem
	[28726] = 120,
	-- Earth Elemental Totem
	[2062] = 120,
	-- Summon Doomguard
	[18540] = 900,
	-- Summon Infernal
	[1122] = 60,
	-- Snake Trap (Snakes)
	[34600] = 15,
	-- Bloodworms
	[50452] = 20,
	-- Wild Imp
	[104317] = 20,
	-- Dreadstalker
	[193332] = 12,
	-- Demonic Tyrant
	[265187] = 15,
	-- Vile Fiend
	[264119] = 15,
	-- Project Ascension Necromancer Summons
	[500971] = -1, -- Raise: Ghoul (Permanent)
}

-- Fallback defaults for nameplate-only tracking (when SPELL_SUMMON is missed or on UI reload)
local nameDefaults = {
	["treant"] = { ["duration"] = 30, ["icon"] = "Interface\\Icons\\Spell_Nature_ForceOfNature" },
	["force of nature"] = { ["duration"] = 30, ["icon"] = "Interface\\Icons\\Spell_Nature_ForceOfNature" },
	["mirror image"] = { ["duration"] = 30, ["icon"] = "Interface\\Icons\\Spell_Magic_LesserInvisibilty" },
	["gargoyle"] = { ["duration"] = 30, ["icon"] = "Interface\\Icons\\Spell_Shadow_GatherShadows" },
	["ebon gargoyle"] = { ["duration"] = 30, ["icon"] = "Interface\\Icons\\Spell_Shadow_GatherShadows" },
	["spirit wolf"] = { ["duration"] = 45, ["icon"] = "Interface\\Icons\\Spell_Shaman_FeralSpirit" },
	["water elemental"] = { ["duration"] = 45, ["icon"] = "Interface\\Icons\\Spell_Frost_SummonWaterElemental" },
	["army of the dead"] = { ["duration"] = 40, ["icon"] = "Interface\\Icons\\Spell_DeathKnight_ArmyOfTheDead" },
	["ghoul"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead" }, -- Permanent
	["ghoulish minion"] = { ["duration"] = 40, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead" },
	["bloodworm"] = { ["duration"] = 20, ["icon"] = "Interface\\Icons\\Spell_DeathKnight_BloodPlague" },
	["wild imp"] = { ["duration"] = 20, ["icon"] = "Interface\\Icons\\Spell_Shadow_SummonImp" },
	["dreadstalker"] = { ["duration"] = 12, ["icon"] = "Interface\\Icons\\Ability_Warlock_CallDreadstalkers" },
	["vile fiend"] = { ["duration"] = 15, ["icon"] = "Interface\\Icons\\Ability_Warlock_SummonVilefiend" },
	["demonic tyrant"] = { ["duration"] = 15, ["icon"] = "Interface\\Icons\\Ability_Warlock_SummonDemonicTyrant" },
	["fire elemental"] = { ["duration"] = 120, ["icon"] = "Interface\\Icons\\Spell_Fire_Elemental_Totem" },
	["earth elemental"] = { ["duration"] = 120, ["icon"] = "Interface\\Icons\\Spell_Nature_EarthElemental_Totem" },
	["dancing rune weapon"] = { ["duration"] = 12, ["icon"] = "Interface\\Icons\\INV_Sword_07" },
	["shadowy apparition"] = { ["duration"] = 15, ["icon"] = "Interface\\Icons\\Spell_Shadow_ShadowWard" },
	["lightwell"] = { ["duration"] = 180, ["icon"] = "Interface\\Icons\\Spell_Holy_SummonLightwell" },
	
	-- Necromancer Minions (Project Ascension / CoA)
	["skeletal soldier"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead" },
	["greater skeletal warrior"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead" },
	["lesser skeletal warrior"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead" },
	["skeletal rogue"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Ability_Backstab" },
	["skeletal mage"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_ShadowBolt" },
	["skeletal cleric"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Holy_Renew" },
	["skeletal defender"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead" },
	["skeletal guardian"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead" },
	["skeleton"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead" },
	["risen ghoul"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead" },
	["flesh golem"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_GatherShadows" },
	["putrid ghoul"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead" },
	["zombie"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead" },
	["risen zombie"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead" },
	["crypt fiend"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_CryptFiend" },
	["abomination"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", ["npcID"] = 50068 },

	-- Spell / Buff name to physical summon name mappings (crucial for custom specs on Project Ascension)
	["raise: ghoul"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead", ["guardianName"] = "Ghoul" },
	["raise ghoul"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead", ["guardianName"] = "Ghoul" },
	["summon greater skeletal warrior"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead", ["guardianName"] = "Greater Skeletal Warrior" },
	["raise greater skeletal warrior"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead", ["guardianName"] = "Greater Skeletal Warrior" },
	["raise: greater skeletal warrior"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead", ["guardianName"] = "Greater Skeletal Warrior" },
	["summon lesser skeletal warrior"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead", ["guardianName"] = "Lesser Skeletal Warrior" },
	["raise lesser skeletal warrior"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead", ["guardianName"] = "Lesser Skeletal Warrior" },
	["raise: lesser skeletal warrior"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AnimateDead", ["guardianName"] = "Lesser Skeletal Warrior" },
	["summon skeletal rogue"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Ability_Backstab", ["guardianName"] = "Skeletal Rogue" },
	["raise skeletal rogue"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Ability_Backstab", ["guardianName"] = "Skeletal Rogue" },
	["raise: skeletal rogue"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Ability_Backstab", ["guardianName"] = "Skeletal Rogue" },
	["summon crypt fiend"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_CryptFiend", ["guardianName"] = "Crypt Fiend" },
	["raise: crypt fiend"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_CryptFiend", ["guardianName"] = "Crypt Fiend" },
	["summon abomination"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", ["guardianName"] = "Abomination", ["npcID"] = 50068 },
	["raise: abomination"] = { ["duration"] = -1, ["icon"] = "Interface\\Icons\\Spell_Shadow_AbominationExplosion", ["guardianName"] = "Abomination", ["npcID"] = 50068 },
}


-- Safe wrapper for GetSpellInfo icon querying across client versions
local function GetSpellIconTexture(spellID)
	if not spellID then return nil end
	local name, _, icon = GetSpellInfo(spellID)
	return icon
end

-- Normalize spell/buff names by stripping common summon prefixes
local function GetBaseName(name)
	if not name then return "" end
	local clean = string.lower(name)
	clean = string.gsub(clean, "^raise:%s*", "")
	clean = string.gsub(clean, "^raise%s*", "")
	clean = string.gsub(clean, "^summon:%s*", "")
	clean = string.gsub(clean, "^summon%s*", "")
	return clean
end

-- One icon per guardian name. The same guardian can be created from different
-- paths (summon spell, buff scan, nameplate) that each supply another icon, so
-- the icon is resolved by name: built-in default first, then the first icon seen
-- for that name, so all bars of one guardian look the same.
GF.iconByName = GF.iconByName or {}

-- Guardian name -> summon spell ID, taken from the CoA multicast bar
-- (NECROMANCER_SUMMON_SPELLS in Constants.lua). The icon is read from the very same
-- spell with GetSpellInfo, so the guardian bars show the same icon as the multicast bar.
local summonSpellByName = {
	["skeletal archer"] = 500332,
	["skeletal rogue"] = 500969, ["putrid geist"] = 500969,
	["ghoul"] = 500971,
	["skeletal warrior"] = 500970, ["lesser skeletal warrior"] = 500970,
	["skeletal mage"] = 500331,
	["greater skeletal warrior"] = 504901,
	["crypt fiend"] = 504859,
	["ghost"] = 504861,
	["abomination"] = 500335,
	["revenant"] = 500329, ["gargoyle"] = 500329,
	["unholy colossus"] = 500989, ["decaying colossus"] = 500989, ["colossus"] = 500989,
}

local function ResolveIcon(g)
	local clean = string.lower(g.name or "")
	local base = GetBaseName(g.name)

	local spellID = summonSpellByName[clean] or summonSpellByName[base]
	if spellID then
		local spellIcon = GetSpellIconTexture(spellID)
		if spellIcon then
			return spellIcon
		end
	end
	local nd = nameDefaults[clean] or nameDefaults[base]
	if nd and nd.icon then
		return nd.icon
	end
	local cached = GF.iconByName[clean] or GF.iconByName[base]
	if cached then
		return cached
	end
	local icon = g.icon or "Interface\\Icons\\Spell_Nature_ForceOfNature"
	GF.iconByName[clean] = icon
	return icon
end

-- Extract NPC ID from WotLK/Ascension hex GUID string
local function GetNPCIDFromGUID(guid)
	if not guid then return nil end
	local cleanGUID = string.lower(guid)
	-- In WotLK, Creature GUIDs start with "0xf13", Vehicles with "0xf15", Pets with "0xf14"
	local prefix = string.sub(cleanGUID, 1, 5)
	if prefix == "0xf13" or prefix == "0xf15" or prefix == "0xf14" then
		-- NPC ID is stored in hex characters 7 to 12
		local hexID = string.sub(cleanGUID, 7, 12)
		return tonumber(hexID, 16)
	end
	return nil
end

local blacklistedSummons = {
	["lootbot"] = true,
	["loot bot"] = true,
	["guild herald"] = true,
	["guild page"] = true,
	["argent squire"] = true,
	["argent gruntling"] = true,
	["jeeves"] = true,
	["moll-e"] = true,
	["scrapbot"] = true,
	["scrap bot"] = true,
	["field repair bot 74g"] = true,
	["field repair bot 110g"] = true,
	["auto-hammer"] = true,
	["blingtron 4000"] = true,
	["blingtron 5000"] = true,
	["blingtron 6000"] = true,
}

local companionNames = {}
local companionSpellIDs = {}

local function UpdateCompanionBlacklist()
	wipe(companionNames)
	wipe(companionSpellIDs)
	if GetNumCompanions then
		local num = GetNumCompanions("CRITTER")
		if num and num > 0 then
			for i = 1, num do
				local _, creatureName, spellID = GetCompanionInfo("CRITTER", i)
				if creatureName then
					companionNames[string.lower(creatureName)] = true
				end
				if spellID then
					companionSpellIDs[spellID] = true
				end
			end
		end
	end
end

local function IsTrackable(name)
	if not name then return false end
	local clean = strtrim(string.lower(name))
	local base = strtrim(GetBaseName(clean))
	if blacklistedSummons[clean] or blacklistedSummons[base] or companionNames[clean] or companionNames[base] then
		return false
	end
	-- Substring checks to prevent variations (e.g., Lootbot 3000, Blingtron 5000, etc.)
	if string.find(clean, "lootbot") or string.find(clean, "loot bot") or string.find(clean, "loot%-o%-bot") then
		return false
	end
	if string.find(clean, "blingtron") then
		return false
	end
	if string.find(clean, "guild herald") or string.find(clean, "guild page") then
		return false
	end
	if string.find(clean, "argent squire") or string.find(clean, "argent gruntling") then
		return false
	end
	if string.find(clean, "scrapbot") or string.find(clean, "scrap bot") then
		return false
	end
	if string.find(clean, "jeeves") then
		return false
	end
	if string.find(clean, "moll%-e") then
		return false
	end
	return true
end

local function IsTrackableUnit(unit)
	if not unit or not UnitExists(unit) then return false end
	if UnitIsPlayer(unit) then return false end
	if not UnitIsFriend("player", unit) then return false end
	
	local name = UnitName(unit)
	if not name or not IsTrackable(name) then return false end
	
	-- Level-based heuristic: companion pets / vanity pets are always level 1
	local level = UnitLevel(unit)
	local playerLevel = UnitLevel("player")
	if level and level == 1 and playerLevel and playerLevel > 5 then
		return false
	end
	
	-- Creature Type check
	local creatureType = UnitCreatureType(unit)
	if creatureType == "Critter" or creatureType == "Non-combat Pet" or creatureType == "Companion" then
		return false
	end
	
	return true
end

-- Capitalize the first letter of each word in a string (Title Case)
local function CapitalizeName(str)
	if not str then return "" end
	return (string.gsub(str, "(%a)([%w_']*)", function(first, rest)
		return string.upper(first) .. string.lower(rest)
	end))
end

-- Format the name text. Tags: [name], [name:upper], [name:lower], [name:short], [classcolor]
local function FormatNameText(formatStr, name)
	if not formatStr or formatStr == "" then
		formatStr = "[name]"
	end

	local base = CapitalizeName(name)
	local result = formatStr
	result = string.gsub(result, "%[name:upper%]", function() return string.upper(base) end)
	result = string.gsub(result, "%[name:lower%]", function() return string.lower(base) end)
	result = string.gsub(result, "%[name:short%]", function() return string.sub(base, 1, 10) end)
	result = string.gsub(result, "%[name%]", function() return base end)

	if string.find(result, "%[classcolor%]") then
		local c = RAID_CLASS_COLORS[E.myclass] or {r = 1, g = 1, b = 1}
		local hex = string.format("|cff%02x%02x%02x", math.floor(c.r * 255), math.floor(c.g * 255), math.floor(c.b * 255))
		result = string.gsub(result, "%[classcolor%]", hex) .. "|r"
	end

	return result
end

-- Format health text using custom ElvUI-style tags ([healthcolor], [health:current], etc.)
local function FormatHealthText(formatStr, health, maxHealth)
	if not formatStr or formatStr == "" then
		formatStr = "[healthcolor][health:current]"
	end

	local percent = 100
	if maxHealth > 0 then
		percent = math.floor((health / maxHealth) * 100 + 0.5)
	end

	-- 1. Compute health color hex code
	local r, g, b
	if percent > 50 then
		r = (100 - percent) / 50
		g = 1
		b = 0
	else
		r = 1
		g = percent / 50
		b = 0
	end
	
	-- Convert r, g, b to Hex
	local hexColor = string.format("|cff%02x%02x%02x", math.floor(r * 255), math.floor(g * 255), math.floor(b * 255))

	-- 2. Format values using ElvUI's E:ShortValue
	local shortHealth = E:ShortValue(health)
	local shortMax = E:ShortValue(maxHealth)
	local currentMaxStr = shortHealth
	if maxHealth > 0 then
		currentMaxStr = shortHealth .. " / " .. shortMax
	end

	-- 3. Replace tags
	local result = formatStr
	result = string.gsub(result, "%[healthcolor%]", hexColor)
	result = string.gsub(result, "%[health:current%]", shortHealth)
	result = string.gsub(result, "%[health:max%]", shortMax)
	result = string.gsub(result, "%[health:percent%]", percent .. "%%")
	result = string.gsub(result, "%[health:current%-max%]", currentMaxStr)

	-- If [healthcolor] was used, close the color tag with |r
	if string.find(formatStr, "%[healthcolor%]") then
		result = result .. "|r"
	end

	return result
end

-- Dynamic player-level/health-based fallback for default max health estimation when nameplate is absent
local function GetDefaultMaxHealth(guardianName)
	local cleanName = guardianName and string.lower(guardianName) or ""
	if cleanName ~= "" and GF.learnedMaxHealth[cleanName] then
		return GF.learnedMaxHealth[cleanName]
	end

	local playerMax = UnitHealthMax("player")
	if not playerMax or playerMax <= 0 then
		playerMax = 10000
	end
	
	-- Role-based multipliers based on guardian name keywords
	local multiplier = 0.8
	if cleanName ~= "" then
		if string.find(cleanName, "golem") or string.find(cleanName, "abomination") or string.find(cleanName, "defender") or string.find(cleanName, "guardian") or string.find(cleanName, "earth elemental") then
			multiplier = 1.2
		elseif string.find(cleanName, "rogue") or string.find(cleanName, "archer") or string.find(cleanName, "mage") or string.find(cleanName, "imp") or string.find(cleanName, "bloodworm") or string.find(cleanName, "snake") or string.find(cleanName, "ghoul") or string.find(cleanName, "skelet") or string.find(cleanName, "zombie") or string.find(cleanName, "fiend") then
			multiplier = 0.4
		end
	end
	
	return math.max(100, playerMax * multiplier)
end

function GF:LearnMaxHealth(name, maxHP)
	if not name or name == "" or not maxHP or maxHP <= 100 then return end
	local cleanName = string.lower(name)
	local oldMaxHP = GF.learnedMaxHealth[cleanName]
	
	if oldMaxHP ~= maxHP then
		GF.learnedMaxHealth[cleanName] = maxHP
		
		-- Update any active guardians of the same name that are currently using old/fallback max health values
		for guid, g in pairs(GF.activeGuardians) do
			if string.lower(g.name) == cleanName then
				local oldMax = g.maxHealth or 100
				g.maxHealth = maxHP
				if oldMax > 0 then
					g.health = math.floor((g.health / oldMax) * maxHP + 0.5)
				else
					g.health = maxHP
				end
			end
		end
	end
end

-- Helper to dynamically scan tooltips for player ownership (fallback for custom summons)
local tooltipScanner
local function IsPlayerMinion(unit)
	if not unit then return false end
	if not tooltipScanner then
		tooltipScanner = CreateFrame("GameTooltip", "ElvUI_GF_TooltipScanner", nil, "GameTooltipTemplate")
		tooltipScanner:SetOwner(WorldFrame, "ANCHOR_NONE")
	end
	tooltipScanner:ClearLines()
	tooltipScanner:SetUnit(unit)
	
	local playerName = UnitName("player")
	if not playerName or playerName == "" then return false end

	for i = 2, tooltipScanner:NumLines() do
		local leftText = _G["ElvUI_GF_TooltipScannerTextLeft" .. i]
		if leftText then
			local text = leftText:GetText()
			if text and text ~= "" then
				local startIdx, endIdx = string.find(text, playerName, 1, true)
				if startIdx then
					-- Extract characters immediately preceding and succeeding the player's name
					local beforeChar = startIdx > 1 and string.sub(text, startIdx - 1, startIdx - 1) or ""
					local afterChar = endIdx < #text and string.sub(text, endIdx + 1, endIdx + 1) or ""
					
					-- Boundary check before match: must not be an alphanumeric character
					local beforeOk = (beforeChar == "" or not string.match(beforeChar, "[%a%d]"))
					
					-- Boundary check after match: must be non-alphanumeric, or possess standard possessive suffixes like "Johns"
					local afterOk = false
					if afterChar == "" or not string.match(afterChar, "[%a%d]") then
						afterOk = true
					elseif afterChar == "s" then
						local afterSChar = endIdx + 1 < #text and string.sub(text, endIdx + 2, endIdx + 2) or ""
						if afterSChar == "" or not string.match(afterSChar, "[%a%d]") then
							afterOk = true
						end
					end
					
					if beforeOk and afterOk then
						return true
					end
				end
			end
		end
	end
	return false
end

-- Scan player buffs to reconstruct active summons (crucial for /reload or login restoration)
function GF:ScanPlayerBuffs()
	local now = GetTime()
	local playerGUID = UnitGUID("player")
	local matched = false

	local activeBuffCounts = {}
	local activeBuffsOnPlayer = {}

	-- 1. Aggregate and sum counts of all active buffs, resolving spell-to-guardian mappings
	for i = 1, 40 do
		local name, _, icon, count, _, duration, expirationTime, _, _, _, spellID = UnitBuff("player", i)
		if not name then break end

		local cleanName = string.lower(name)
		local baseName = GetBaseName(cleanName)
		local nd = nameDefaults[cleanName] or nameDefaults[baseName]
		local targetName = (nd and nd.guardianName) and string.lower(nd.guardianName) or baseName

		activeBuffsOnPlayer[cleanName] = true
		activeBuffsOnPlayer[baseName] = true
		activeBuffsOnPlayer[targetName] = true

		if (GF.customGuardiansList[targetName] or nameDefaults[targetName] or GF.customGuardiansList[cleanName] or nameDefaults[cleanName] or GF.customGuardiansList[baseName] or nameDefaults[baseName]) and IsTrackable(targetName) and IsTrackable(cleanName) then
			local countVal = (count and count > 1) and count or 1
			activeBuffCounts[targetName] = (activeBuffCounts[targetName] or 0) + countVal
		end
	end

	-- 2. Process aggregated counts to add missing frames or prune excess frames
	for targetName, stackCount in pairs(activeBuffCounts) do
		local currentCount = 0
		for _, g in pairs(GF.activeGuardians) do
			if string.lower(g.name) == targetName or GetBaseName(g.name) == targetName then
				currentCount = currentCount + 1
			end
		end

		if stackCount > currentCount then
			local missingCount = stackCount - currentCount
			for j = 1, missingCount do
				local tempGUID = "temp_" .. targetName .. "_" .. (currentCount + j)
				
				-- Find proper display name capitalization and fallbacks
				local displayName = targetName
				local fallbackIcon = "Interface\\Icons\\Spell_Shadow_AnimateDead"
				local fallbackDuration = -1
				local fallbackNpcID = nil
				
				-- Check in GF.customGuardiansList first (original casing)
				if GF.customGuardiansList[targetName] then
					displayName = GF.customGuardiansList[targetName]
				elseif GF.customGuardiansList[GetBaseName(targetName)] then
					displayName = GF.customGuardiansList[GetBaseName(targetName)]
				end

				for k, v in pairs(nameDefaults) do
					if k == targetName or k == GetBaseName(targetName) then
						displayName = v.guardianName or displayName
						fallbackIcon = v.icon or fallbackIcon
						fallbackDuration = v.duration or fallbackDuration
						fallbackNpcID = v.npcID or fallbackNpcID
						break
					elseif v.guardianName and (string.lower(v.guardianName) == targetName or GetBaseName(v.guardianName) == targetName) then
						displayName = v.guardianName
						fallbackIcon = v.icon or fallbackIcon
						fallbackDuration = v.duration or fallbackDuration
						fallbackNpcID = v.npcID or fallbackNpcID
						break
					end
				end

				local defaultMaxHP = GetDefaultMaxHealth(displayName)
				GF.activeGuardians[tempGUID] = {
					guid = tempGUID,
					name = displayName,
					summonTime = now,
					duration = fallbackDuration,
					endTime = now + (fallbackDuration > 0 and fallbackDuration or 0),
					maxHealth = defaultMaxHP,
					health = defaultMaxHP,
					icon = fallbackIcon,
					nameplateUnit = nil,
					isTempGUID = true,
					npcID = fallbackNpcID,
					creationID = GetNextCreationID(),
				}
				matched = true
			end
		elseif stackCount < currentCount then
			local excess = currentCount - stackCount
			local candidates = {}
			for gGUID, g in pairs(GF.activeGuardians) do
				if string.lower(g.name) == targetName or GetBaseName(g.name) == targetName then
					table.insert(candidates, g)
				end
			end
			
			table.sort(candidates, function(a, b)
				if a.isTempGUID ~= b.isTempGUID then
					return a.isTempGUID
				elseif (a.nameplateUnit == nil) ~= (b.nameplateUnit == nil) then
					return a.nameplateUnit == nil
				elseif a.summonTime ~= b.summonTime then
					return a.summonTime < b.summonTime
				else
					return (a.creationID or 0) < (b.creationID or 0)
				end
			end)
			
			for j = 1, excess do
				local g = candidates[j]
				if g then
					GF.activeGuardians[g.guid] = nil
					matched = true
				end
			end
		end
	end

	-- 3. Prune permanent guardians whose player buff is completely gone
	for gGUID, g in pairs(GF.activeGuardians) do
		local cleanName = string.lower(g.name)
		local baseName = GetBaseName(cleanName)
		if g.duration <= 0 then
			if GF.customGuardiansList[cleanName] or nameDefaults[cleanName] or GF.customGuardiansList[baseName] or nameDefaults[baseName] then
				if not activeBuffsOnPlayer[cleanName] and not activeBuffsOnPlayer[baseName] then
					-- The player buff is missing!
					-- Do NOT prune if it's currently bound to a visible nameplate or unit
					local isBound = g.nameplateUnit ~= nil or g.nameplateFrame ~= nil
					if not isBound then
						if not g.buffLostTime then
							g.buffLostTime = now
						end
					else
						g.buffLostTime = nil
					end
				else
					-- Player buff is present, clear the timestamp
					g.buffLostTime = nil
				end
			end
		end
	end

	if matched then
		GF:RefreshFrames()
	end
end



-- Update internal tracking list from config input
function GF:UpdateCustomGuardiansTable()
	wipe(GF.customGuardiansList)
	local input = E.db.unitframe.units.guardians.customGuardians or ""
	for name in string.gmatch(input, "([^,]+)") do
		local trimmed = strtrim(name)
		local clean = string.lower(trimmed)
		if clean ~= "" then
			GF.customGuardiansList[clean] = trimmed
		end
	end
	GF:RefreshFrames()
end

-- Create Main Mover Container
function GF:CreateContainer()
	if GF.container then return end

	local container = CreateFrame("Frame", "ElvUF_GuardiansContainer", E.UIParent)
	container:SetFrameStrata("LOW") -- like ElvUF_Parent, so the world map/other windows cover the guardians
	container:Size(E.db.unitframe.units.guardians.width or 180, E.db.unitframe.units.guardians.height or 28)
	container:Point("CENTER", E.UIParent, "CENTER", 0, 120)
	
	GF.container = container

	-- Integrate into ElvUI's mover framework
	E:CreateMover(container, "ElvUF_GuardiansMover", "Guardians", nil, nil, nil, "ALL,SOLO", nil, "unitframe,guardians,generalGroup")

	-- Pre-create a pool of 20 bar frames to prevent garbage collection and memory allocation overhead during combat
	for i = 1, 20 do
		local bar = GF:CreateBarFrame()
		bar:Hide()
		table.insert(GF.inactiveFramePool, bar)
	end
end

-- Gradient support -----------------------------------------------------------
-- Same approach as the other UnitFrame bars: the statusbar color is set to white
-- and the real colors are applied through the bar texture's gradient.
local function DefaultGradientEnd(r, g, b)
	return r + ((1 - r) * 0.18), g + ((1 - g) * 0.18), b + ((1 - b) * 0.18)
end

local function ApplyBarColor(statusbar, db, r, g, b, a)
	local texture = statusbar:GetStatusBarTexture()
	local orientation = db.gradientOrientation or "HORIZONTAL"
	a = a or 1

	if db.gradient and texture and texture.SetGradientAlpha then
		local er, eg, eb, ea
		if db.gradientCustom and db.gradientColor then
			er, eg, eb, ea = db.gradientColor.r, db.gradientColor.g, db.gradientColor.b, db.gradientColor.a or a
		else
			er, eg, eb = DefaultGradientEnd(r, g, b)
			ea = a
		end
		statusbar:SetStatusBarColor(1, 1, 1, 1)
		if statusbar.__reverseFill and orientation == "HORIZONTAL" then
			-- keep the base color on the side the bar starts from
			texture:SetGradientAlpha(orientation, er, eg, eb, ea, r, g, b, a)
		else
			texture:SetGradientAlpha(orientation, r, g, b, a, er, eg, eb, ea)
		end
		statusbar.__guardianGradient = true
	else
		if statusbar.__guardianGradient and texture and texture.SetGradientAlpha then
			texture:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
		end
		statusbar.__guardianGradient = nil
		statusbar:SetStatusBarColor(r, g, b, a)
	end
end

-- Create Individual Bar Frame
function GF:CreateBarFrame()
	local bar = CreateFrame("Frame", nil, GF.container)
	bar:SetTemplate("Transparent", nil, nil, nil, UF.thinBorders, true) -- same border handling as the ElvUI unit frames
	
	-- Always-on 1px outline between shadow and frame (independent of backdrop/template state)
	local outline = CreateFrame("Frame", nil, bar)
	outline:SetAllPoints(bar)
	outline:SetFrameLevel(bar:GetFrameLevel() + 2)
	outline:SetBackdrop({edgeFile = E.media.blankTex, edgeSize = E.mult})
	outline:EnableMouse(false)
	bar.outline = outline

	-- 1px outline around the icon
	local iconOutline = CreateFrame("Frame", nil, bar)
	iconOutline:SetBackdrop({edgeFile = E.media.blankTex, edgeSize = E.mult})
	iconOutline:EnableMouse(false)
	bar.iconOutline = iconOutline

	-- Spell/Guardian Icon
	local icon = bar:CreateTexture(nil, "ARTWORK")
	icon:SetTexCoord(0.08, 0.92, 0.08, 0.92) -- Zoom slightly to crop default Blizzard frame border
	bar.icon = icon

	-- Health Bar
	local hp = CreateFrame("StatusBar", nil, bar)
	hp:SetStatusBarTexture(E.media.normTex)
	bar.healthBar = hp

	-- Health Bar Background
	local bg = hp:CreateTexture(nil, "BACKGROUND")
	bg:SetAllPoints()
	bg:SetTexture(E.media.normTex)
	bg:SetVertexColor(0.1, 0.1, 0.1, 0.65)
	hp.bg = bg

	-- Duration Bar (Thin overlay bar at the bottom)
	local db = CreateFrame("StatusBar", nil, bar)
	db:SetStatusBarTexture(E.media.normTex)
	bar.durationBar = db

	-- Info panel strip (optional, configured in ApplyStyleToBar)
	local panel = CreateFrame("Frame", nil, bar)
	panel:SetFrameLevel(math.max(hp:GetFrameLevel() - 1, 0))
	-- fixed 1px outline, independent of Thin Borders / border / spacing settings
	local outline = CreateFrame("Frame", nil, panel)
	outline:SetAllPoints(panel)
	outline:SetBackdrop({edgeFile = E.media.blankTex, edgeSize = E.mult})
	panel.outline = outline
	panel:Hide()
	bar.infoPanel = panel

	-- Name Text String
	local name = hp:CreateFontString(nil, "OVERLAY")
	bar.nameText = name

	-- Health & Duration Value String
	local status = hp:CreateFontString(nil, "OVERLAY")
	bar.statusText = status

	-- Texts live on their own frame above all borders/outlines, so moved texts (X/Y offsets) draw over the borders
	local textFrame = CreateFrame("Frame", nil, bar)
	textFrame:SetAllPoints(bar)
	textFrame:SetFrameLevel(bar:GetFrameLevel() + 6)
	textFrame:EnableMouse(false)
	name:SetParent(textFrame)
	status:SetParent(textFrame)
	bar.textFrame = textFrame

	return bar
end

-- Color of the bar fill: custom color, otherwise ElvUI's health color settings
function GF:GetFillColor(db)
	if db.customColors and db.barColor then
		return db.barColor.r, db.barColor.g, db.barColor.b, db.barColor.a or 1
	end
	local colors = E.db.unitframe.colors
	if colors.healthclass then
		local c = RAID_CLASS_COLORS[E.myclass] or { r = 0.23, g = 0.58, b = 0.84 }
		return c.r, c.g, c.b, 1
	end
	return colors.health.r, colors.health.g, colors.health.b, 1
end

-- ElvUI's default for the bar background (same rules as the health element):
-- the custom health backdrop color if enabled, else the fill color times the health multiplier.
function GF:GetDefaultBackground(db)
	local colors = E.db.unitframe.colors
	if colors.customhealthbackdrop then
		local c = colors.health_backdrop
		return c.r, c.g, c.b, 1
	end
	local mult = (colors.healthMultiplier and colors.healthMultiplier > 0 and colors.healthMultiplier) or 0.35
	local r, g, b = GF:GetFillColor(db)
	return r * mult, g * mult, b * mult, 1
end

function GF:GetBackgroundColor(db)
	local c = db.backgroundColor
	if c then
		return c.r, c.g, c.b, c.a or 1
	end
	local r, g, b = GF:GetDefaultBackground(db)
	return r, g, b, 1
end

-- Show/hide the solid BACKGROUND regions created by the frame template (everything on BACKGROUND except our own texture)
local function SetTemplateBackgroundShown(bar, shown)
	for _, r in ipairs({ bar:GetRegions() }) do
		if r ~= bar.customBG and r ~= bar.tex and r ~= bar.icon and r.GetDrawLayer and r:GetDrawLayer() == "BACKGROUND" then
			if shown then r:Show() else r:Hide() end
		end
	end
end

-- Apply Sizing, Textures, Fonts, and Colors
function GF:ApplyStyleToBar(bar)
	local db = E.db.unitframe.units.guardians
	local nameFont = E.Libs.LSM:Fetch("font", db.nameFont) or E.media.normFont
	local healthFont = E.Libs.LSM:Fetch("font", db.healthFont) or E.media.normFont
	local bgTexture = E.Libs.LSM:Fetch("statusbar", db.backgroundTexture) or E.media.normTex
	local texture = E.Libs.LSM:Fetch("statusbar", db.statusBarTexture) or E.media.normTex

	-- Frame size
	bar:Size(db.width, db.height)
	
	-- Border/spacing exactly like the ElvUI unit frames (Thin Borders aware)
	local border = UF.thinBorders and E.mult or E.Border
	local spacing = UF.thinBorders and 0 or E.Spacing
	local inset = border + spacing

	-- Info panel strip (top/bottom); optionally runs under/over the icon as well
	local panel = bar.infoPanel
	local panelOn = db.infoPanel and panel and true or false
	local panelTop = db.infoPanelPosition == "TOP"
	local panelFull = panelOn and db.infoPanelFullWidth and db.showIcon ~= false
	-- same height math as ElvUI's Configure_InfoPanel: the panel takes its height out of the frame, no overlap with the health bar
	local panelH = panelOn and math.max((db.infoPanelHeight or 14) - (border - spacing), 1) or 0
	local panelOverlap = panelH

	-- Square icon (smaller when the panel runs under/over it)
	local iconSize = db.height - (inset * 2) - (panelFull and panelOverlap or 0)
	bar.icon:Size(iconSize, iconSize)
	bar.icon:ClearAllPoints()
	local iconRight = db.iconPosition == "RIGHT"
	local iconSide = iconRight and "RIGHT" or "LEFT"
	local iconX = iconRight and -inset or inset
	if panelFull then
		-- icon sits on the side of the bar opposite to the panel
		local v = panelTop and "BOTTOM" or "TOP"
		bar.icon:Point(v .. iconSide, bar, v .. iconSide, iconX, panelTop and inset or -inset)
	else
		bar.icon:Point(iconSide, bar, iconSide, iconX, 0)
	end

	-- Healthbar anchors
	bar.healthBar:ClearAllPoints()
	local left, right = inset, -inset
	if db.showIcon ~= false then
		bar.icon:Show()
		if iconRight then
			right = -(inset + iconSize + spacing)
		else
			left = inset + iconSize + spacing
		end
	else
		bar.icon:Hide()
	end

	if panelOn then
		local pl, pr = left, right
		if panelFull then pl, pr = inset, -inset end
		local edge = panelTop and "TOP" or "BOTTOM"
		panel:ClearAllPoints()
		panel:Point(edge .. "LEFT", bar, edge .. "LEFT", pl, panelTop and -inset or inset)
		panel:Point(edge .. "RIGHT", bar, edge .. "RIGHT", pr, panelTop and -inset or inset)
		panel:Height(panelH)
		panel:Show()

		-- own background texture (texture + color adjustable), the template's solid regions are hidden
		SetTemplateBackgroundShown(panel, false)
		if not panel.tex then
			panel.tex = panel:CreateTexture(nil, "BACKGROUND", nil, 1)
		end
		local pinset = E.mult
		local bc = E.media.unitframeBorderColor or E.media.bordercolor
		if bc then panel.outline:SetBackdropBorderColor(bc[1], bc[2], bc[3], bc[4] or 1) end
		panel.tex:ClearAllPoints()
		panel.tex:SetPoint("TOPLEFT", panel, "TOPLEFT", pinset, -pinset)
		panel.tex:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -pinset, pinset)
		panel.tex:SetTexture(E.Libs.LSM:Fetch("statusbar", db.infoPanelTexture or db.backgroundTexture) or E.media.normTex)
		local pc = db.infoPanelColor
		if pc then
			panel.tex:SetVertexColor(pc.r, pc.g, pc.b, pc.a or 1)
		else
			local m = E.media.backdropfadecolor
			panel.tex:SetVertexColor(m[1], m[2], m[3], m[4] or 1)
		end
		panel.tex:Show()

		bar.healthBar:Point("TOPLEFT", bar, "TOPLEFT", left, -(inset + (panelTop and panelOverlap or 0)))
		bar.healthBar:Point("BOTTOMRIGHT", bar, "BOTTOMRIGHT", right, inset + (panelTop and 0 or panelOverlap))
	else
		if panel then panel:Hide() end
		bar.healthBar:Point("TOPLEFT", bar, "TOPLEFT", left, -inset)
		bar.healthBar:Point("BOTTOMRIGHT", bar, "BOTTOMRIGHT", right, inset)
	end
	local textAnchor = (panelOn and db.infoPanelTexts) and panel or bar.healthBar
	bar.healthBar:SetStatusBarTexture(texture)
	bar.healthBar.bg:SetTexture(bgTexture)

	-- Thin duration bar positioned at the bottom of the health bar
	bar.durationBar:ClearAllPoints()
	bar.durationBar:Point("BOTTOMLEFT", bar.healthBar, "BOTTOMLEFT", 0, 0)
	bar.durationBar:Point("BOTTOMRIGHT", bar.healthBar, "BOTTOMRIGHT", 0, 0)
	bar.durationBar:Height(3)
	bar.durationBar:SetStatusBarTexture(texture)

	-- Reverse fill: the bars drain from the other side
	UF:SetupReverseFill(bar.healthBar, db.reverseFill, false)
	UF:SetupReverseFill(bar.durationBar, db.reverseFill, false)

	-- Font configuration
	bar.nameText:FontTemplate(nameFont, db.nameFontSize, db.nameFontOutline)
	bar.nameText:ClearAllPoints()
	local nameAnchor = db.nameAnchor or "LEFT"
	bar.nameText:Point(nameAnchor, textAnchor, nameAnchor, db.nameXOffset or 0, db.nameYOffset or 0)
	bar.nameText:SetJustifyH(string.find(nameAnchor, "LEFT") and "LEFT" or string.find(nameAnchor, "RIGHT") and "RIGHT" or "CENTER")

	bar.statusText:FontTemplate(healthFont, db.healthFontSize, db.healthFontOutline)
	bar.statusText:ClearAllPoints()
	local healthAnchor = db.healthAnchor or "RIGHT"
	bar.statusText:Point(healthAnchor, textAnchor, healthAnchor, db.healthXOffset or 0, db.healthYOffset or 0)
	bar.statusText:SetJustifyH(string.find(healthAnchor, "LEFT") and "LEFT" or string.find(healthAnchor, "RIGHT") and "RIGHT" or "CENTER")

	-- Frame backdrop like the ElvUI unit frames; re-applied to drop a custom backdrop color
	local bgActive = db.backgroundColor or panelOn -- own background texture instead of the template's solid fill
	if not bar.__templateSet or (bar.__customBackdrop and not bgActive) then
		bar:SetTemplate("Transparent", nil, nil, nil, UF.thinBorders, true)
		bar.__templateSet = true
		bar.__customBackdrop = nil
	end

	for _, f in ipairs({ bar, bar.healthBar, bar.durationBar, bar.infoPanel, bar.outline, bar.iconOutline, bar.textFrame }) do
		f:SetFrameStrata("LOW")
	end
	if bar.pdySkinShadow then bar.pdySkinShadow:SetFrameStrata("LOW") end
	if bar.textFrame then bar.textFrame:SetFrameLevel(bar:GetFrameLevel() + 6) end
	if bar.iconOutline then
		local oc = E.media.unitframeBorderColor or E.media.bordercolor or {0, 0, 0}
		bar.iconOutline:ClearAllPoints()
		bar.iconOutline:SetPoint("TOPLEFT", bar.icon, "TOPLEFT", 0, 0)
		bar.iconOutline:SetPoint("BOTTOMRIGHT", bar.icon, "BOTTOMRIGHT", 0, 0)
		bar.iconOutline:SetFrameLevel(bar:GetFrameLevel() + 2)
		bar.iconOutline:SetBackdropBorderColor(oc[1], oc[2], oc[3], 1)
		if db.showIcon ~= false then bar.iconOutline:Show() else bar.iconOutline:Hide() end
	end
	if bar.outline then
		local oc = E.media.unitframeBorderColor or E.media.bordercolor or {0, 0, 0}
		bar.outline:SetBackdropBorderColor(oc[1], oc[2], oc[3], 1)
		bar.outline:SetFrameLevel(bar:GetFrameLevel() + 2)
		bar.outline:Show()
	end

	-- Bar colors
	local fr, fg, fb, fa = GF:GetFillColor(db)
	ApplyBarColor(bar.healthBar, db, fr, fg, fb, fa)
	if db.customColors then
		ApplyBarColor(bar.durationBar, db, db.durationColor.r, db.durationColor.g, db.durationColor.b, db.durationColor.a)
	else
		local classColor = RAID_CLASS_COLORS[E.myclass] or { r = 0.23, g = 0.58, b = 0.84 }
		ApplyBarColor(bar.durationBar, db, classColor.r, classColor.g, classColor.b, 0.8)
	end

	-- Background
	-- Default: ElvUI's own health backdrop (bar background texture tinted like the unit frames).
	-- With a picked color: like ElvUI's transparent unit frames the color (incl. alpha) goes on the
	-- frame backdrop, which shows through wherever the bar fill is not, and the opaque background texture is hidden.
	local custom = db.backgroundColor
	if bgActive then
		bar.ignoreFrameTemplates = true -- keep ElvUI's template updates from resetting the color
		bar.ignoreBackdropColors = true -- E:UpdateBackdropColors would otherwise reset it to the faded default (~80% opaque)
		-- own background texture: its vertex alpha is reliable, unlike the backdrop color on 3.3.5
		-- The template's solid background textures (SetBackdrop leaves several opaque white "SolidTexture"
		-- regions on BACKGROUND, tinted by SetBackdropColor) can't be made see-through reliably, so hide them
		-- and let our own texture draw the background.
		bar:SetBackdropColor(0, 0, 0, 0)
		SetTemplateBackgroundShown(bar, false)
		if not bar.customBG then
			bar.customBG = bar:CreateTexture(nil, "BACKGROUND", nil, 1)
			bar.customBG:SetTexture(E.media.blankTex)
		end
		local inset = UF.thinBorders and E.mult or (E.Border or 1)
		-- leave the info panel strip free, so its own (possibly transparent) texture lets the world shine through
		local cut = panelOn and (panelH + inset) or 0
		bar.customBG:ClearAllPoints()
		bar.customBG:SetPoint("TOPLEFT", bar, "TOPLEFT", inset, -inset - ((panelOn and panelTop) and cut - inset or 0))
		bar.customBG:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", -inset, inset + ((panelOn and not panelTop) and cut - inset or 0))
		if custom then
			bar.customBG:SetVertexColor(custom.r, custom.g, custom.b, custom.a or 1)
			bar.healthBar.bg:SetAlpha(0)
		else
			local m = E.media.backdropfadecolor
			bar.customBG:SetVertexColor(m[1], m[2], m[3], m[4] or 1)
			local br, bgc, bb = GF:GetDefaultBackground(db)
			bar.healthBar.bg:SetVertexColor(br, bgc, bb, 1)
			bar.healthBar.bg:SetAlpha(1)
		end
		bar.customBG:Show()
		bar.__customBackdrop = true
	else
		bar.ignoreFrameTemplates = nil
		bar.ignoreBackdropColors = nil
		SetTemplateBackgroundShown(bar, true)
		if bar.customBG then bar.customBG:Hide() end
		local br, bgc, bb = GF:GetDefaultBackground(db)
		bar.healthBar.bg:SetVertexColor(br, bgc, bb, 1)
		bar.healthBar.bg:SetAlpha(1)
	end

	-- Text colors (independent of the bar colors)
	local nc, hc = db.nameColor, db.healthColor
	bar.nameText:SetTextColor(nc.r, nc.g, nc.b, nc.a or 1)
	bar.statusText:SetTextColor(hc.r, hc.g, hc.b, hc.a or 1)
end

-- Refresh UI Frames & Positions
function GF:RefreshFrames()
	if not GF.container then return end

	local list = {}
	local now = GetTime()
	
	-- Filter and compile active summons list
	for guid, g in pairs(GF.activeGuardians) do
		local isExpired = g.duration > 0 and now >= g.endTime
		if isExpired then
			GF.activeGuardians[guid] = nil
		else
			local isPerm = g.duration <= 0
			local show = isPerm and E.db.unitframe.units.guardians.showPermanent or g.duration > 0
			if show then
				table.insert(list, g)
			end
		end
	end

	-- Sort by oldest summon time first
	table.sort(list, function(a, b)
		if a.summonTime ~= b.summonTime then
			return a.summonTime < b.summonTime
		else
			return (a.creationID or 0) < (b.creationID or 0)
		end
	end)

	-- In-place pool adjustment to prevent hide/reshow rendering flicker
	local currentSize = #GF.framePool
	local targetSize = #list

	if currentSize > targetSize then
		for i = currentSize, targetSize + 1, -1 do
			local bar = table.remove(GF.framePool, i)
			if bar then
				bar:Hide()
				table.insert(GF.inactiveFramePool, bar)
			end
		end
	elseif currentSize < targetSize then
		for i = currentSize + 1, targetSize do
			local bar = tremove(GF.inactiveFramePool)
			if not bar then
				bar = GF:CreateBarFrame()
			end
			table.insert(GF.framePool, bar)
		end
	end

	-- Render and position bars
	local db = E.db.unitframe.units.guardians
	local spacing = db.spacing
	local growth = db.growthDirection

	local prevBar = nil
	for i, g in ipairs(list) do
		local bar = GF.framePool[i]
		
		GF:ApplyStyleToBar(bar)
		
		if not bar:IsShown() then
			bar:Show()
		end

		bar.guardianGUID = g.guid

		-- Set fixed values
		bar.icon:SetTexture(ResolveIcon(g))
		bar.nameText:SetText(FormatNameText(E.db.unitframe.units.guardians.nameFormat, g.name))

		-- Dynamic Alignment
		bar:ClearAllPoints()
		if i == 1 then
			if growth == "UP" then
				bar:Point("BOTTOM", GF.container, "BOTTOM", 0, 0)
			elseif growth == "DOWN" then
				bar:Point("TOP", GF.container, "TOP", 0, 0)
			elseif growth == "LEFT" then
				bar:Point("RIGHT", GF.container, "RIGHT", 0, 0)
			elseif growth == "RIGHT" then
				bar:Point("LEFT", GF.container, "LEFT", 0, 0)
			end
		else
			if growth == "UP" then
				bar:Point("BOTTOM", prevBar, "TOP", 0, spacing)
			elseif growth == "DOWN" then
				bar:Point("TOP", prevBar, "BOTTOM", 0, -spacing)
			elseif growth == "LEFT" then
				bar:Point("RIGHT", prevBar, "LEFT", -spacing, 0)
			elseif growth == "RIGHT" then
				bar:Point("LEFT", prevBar, "RIGHT", spacing, 0)
			end
		end
		
		-- Instantly update bar values (health/duration) during a refresh to prevent any lag/delays
		GF:UpdateBarContent(bar, g, now)
		
		prevBar = bar
	end

	-- The container (and its mover) always stays the size of ONE bar. The first bar sits on the matching
	-- edge/corner of it and the others grow outward from there, so the growth direction is stable and
	-- doesn't shift the bars when guardians come and go (a container that resizes around its center would).
	GF.container:Size(db.width, db.height)

	GF:UpdateShadows()
end

-- Shadows are drawn by the global shadow system (Skins -> Shadows); the
-- "guardians" key there decides whether and how the bars get a shadow.
function GF:UpdateShadows()
	local S = E:GetModule("Skins", true)
	if S and S.UpdateFrameShadow then
		S:UpdateFrameShadow("guardians")
	end
end

-- Update Bar Content values (Health and Timer values)
function GF:UpdateBarContent(bar, g, now)
	-- Update Health
	bar.healthBar:SetMinMaxValues(0, g.maxHealth)
	bar.healthBar:SetValue(g.health)

	-- Update Duration Timer
	if g.duration > 0 then
		local remaining = g.endTime - now
		if remaining < 0 then remaining = 0 end
		
		bar.durationBar:SetMinMaxValues(0, g.duration)
		bar.durationBar:SetValue(remaining)
		bar.durationBar:Show()

		local healthText = FormatHealthText(E.db.unitframe.units.guardians.healthTextFormat, g.health, g.maxHealth)
		bar.statusText:SetText(string.format("%s | %.1fs", healthText, remaining))
	else
		-- Infinite/Permanent guardian
		bar.durationBar:Hide()
		local healthText = FormatHealthText(E.db.unitframe.units.guardians.healthTextFormat, g.health, g.maxHealth)
		bar.statusText:SetText(healthText)
	end
end

-- Highly optimized OnUpdate tick handler for container
local updateInterval = 0.05
local elapsedSinceLastUpdate = 0
local function Container_OnUpdate(self, elapsed)
	elapsedSinceLastUpdate = elapsedSinceLastUpdate + elapsed
	if elapsedSinceLastUpdate < updateInterval then return end
	elapsedSinceLastUpdate = 0

	local now = GetTime()
	local needsRefresh = false

	-- Real-time precision update for the player's primary pet directly from the server
	if UnitExists("pet") and IsTrackableUnit("pet") then
		local petGUID = UnitGUID("pet")
		local cleanPetGUID = petGUID and string.lower(petGUID)
		if cleanPetGUID and GF.activeGuardians[cleanPetGUID] then
			local g = GF.activeGuardians[cleanPetGUID]
			local petMaxHP = UnitHealthMax("pet")
			local ignoreSync = false
			if petMaxHP and petMaxHP > 0 and petMaxHP <= 100 then
				ignoreSync = g.lastCombatEventTime and (now - g.lastCombatEventTime < 2.0)
			end
			
			if petMaxHP and petMaxHP > 0 then
				local oldMax = g.maxHealth or 100
				local newMax = g.maxHealth
				if petMaxHP <= 100 then
					newMax = (g.maxHealth and g.maxHealth > 100) and g.maxHealth or GetDefaultMaxHealth(g.name)
				else
					newMax = petMaxHP
					GF:LearnMaxHealth(g.name, petMaxHP)
				end
				
				if g.maxHealth ~= newMax then
					g.maxHealth = newMax
					if oldMax > 0 then
						g.health = math.floor((g.health / oldMax) * newMax + 0.5)
					else
						g.health = newMax
					end
				end
				
				if petMaxHP > 100 then
					g.lastPreciseUnitTime = now
				end
			end
			
			if not ignoreSync then
				local petHP = UnitHealth("pet")
				if petHP and petHP > 0 and petMaxHP and petMaxHP > 0 then
					if petMaxHP <= 100 then
						g.health = (petHP / petMaxHP) * g.maxHealth
					else
						g.health = petHP
					end
				end
			end
		end
	end

	-- Throttled automated unit scanning (every 0.1s) for real-time promotion and sync
	if not self.lastScanTime or (now - self.lastScanTime >= 0.1) then
		self.lastScanTime = now
		
		-- 1. Static high-probability units
		if UnitExists("target") then GF:UpdateGuardianFromUnit("target") end
		if UnitExists("focus") then GF:UpdateGuardianFromUnit("focus") end
		if UnitExists("mouseover") then GF:UpdateGuardianFromUnit("mouseover") end
		if UnitExists("pet") then GF:UpdateGuardianFromUnit("pet") end
		for i = 1, 4 do
			local uId = "partypet" .. i
			if UnitExists(uId) then GF:UpdateGuardianFromUnit(uId) end
		end
		if UnitExists("targettarget") then GF:UpdateGuardianFromUnit("targettarget") end
		if UnitExists("focustarget") then GF:UpdateGuardianFromUnit("focustarget") end
		if UnitExists("mouseovertarget") then GF:UpdateGuardianFromUnit("mouseovertarget") end
		
		-- 2. Boss targets (dungeons/raids)
		for i = 1, 4 do
			local uId = "boss" .. i .. "target"
			if UnitExists(uId) then GF:UpdateGuardianFromUnit(uId) end
		end
		
		-- 3. Group / Raid member targets
		local numRaid = GetNumRaidMembers()
		if numRaid and numRaid > 0 then
			for i = 1, numRaid do
				local uId = "raid" .. i .. "target"
				if UnitExists(uId) then GF:UpdateGuardianFromUnit(uId) end
			end
		else
			for i = 1, 4 do
				local uId = "party" .. i .. "target"
				if UnitExists(uId) then GF:UpdateGuardianFromUnit(uId) end
			end
		end

		-- 4. Active nameplates (up to 40)
		for i = 1, 40 do
			local uId = "nameplate" .. i
			if UnitExists(uId) then GF:UpdateGuardianFromUnit(uId) end
		end
	end

	-- Natural Out-of-Combat Regeneration Simulation (every 1.0s)
	-- To prevent health bar fighting/flickering, we only simulate regeneration for guardians
	-- that have NO active, real-time sync sources (i.e. not targeted, not focused, no visible nameplate).
	if not self.lastRegenTime or (now - self.lastRegenTime >= 1.0) then
		self.lastRegenTime = now
		
		local inCombat = UnitAffectingCombat("player")
		if not inCombat then
			local targetGUID = UnitExists("target") and UnitGUID("target")
			local focusGUID = UnitExists("focus") and UnitGUID("focus")
			local petGUID = UnitExists("pet") and UnitGUID("pet")
			local mouseoverGUID = UnitExists("mouseover") and UnitGUID("mouseover")

			for guid, g in pairs(GF.activeGuardians) do
				local hasActiveSync = (g.nameplateUnit ~= nil) or 
				                      (g.nameplateFrame ~= nil) or 
				                      (g.lastPreciseUnitTime and (now - g.lastPreciseUnitTime < 2.0)) or
				                      (targetGUID and string.lower(targetGUID) == guid) or
				                      (focusGUID and string.lower(focusGUID) == guid) or
				                      (petGUID and string.lower(petGUID) == guid) or
				                      (mouseoverGUID and string.lower(mouseoverGUID) == guid)

				if not hasActiveSync and g.health < g.maxHealth then
					local lastEvent = g.lastCombatEventTime or 0
					if now - lastEvent >= 3.0 then
						-- Regenerate 10% of max health per second out of combat
						local regenAmount = math.ceil(g.maxHealth * 0.10)
						g.health = math.min(g.maxHealth, g.health + regenAmount)
					end
				end
			end
		end
	end

	-- Check for expired durations and over-grace-period buff-lost permanent guardians
	for guid, g in pairs(GF.activeGuardians) do
		local isExpired = g.duration > 0 and now >= g.endTime
		local isGracePeriodOver = g.buffLostTime and (now - g.buffLostTime >= 1.5)
		if isExpired or isGracePeriodOver then
			GF.activeGuardians[guid] = nil
			needsRefresh = true
		end
	end

	for _, bar in ipairs(GF.framePool) do
		local g = GF.activeGuardians[bar.guardianGUID]
		if g then
			-- Verify expiration
			if g.duration > 0 and now >= g.endTime then
				needsRefresh = true
			else
				-- Real-time precision update if friendly nameplate is visible
				local updated = false
				
				-- Check if we have a precise unit ID tracking this guardian to prevent percentage-rounding flicker
				local targetGUID = UnitExists("target") and UnitGUID("target")
				local focusGUID = UnitExists("focus") and UnitGUID("focus")
				local petGUID = UnitExists("pet") and UnitGUID("pet")
				local mouseoverGUID = UnitExists("mouseover") and UnitGUID("mouseover")
				
				local hasPreciseUnit = (g.lastPreciseUnitTime and (now - g.lastPreciseUnitTime < 1.0)) or
				                       (targetGUID and string.lower(targetGUID) == g.guid) or
				                       (focusGUID and string.lower(focusGUID) == g.guid) or
				                       (petGUID and string.lower(petGUID) == g.guid) or
				                       (mouseoverGUID and string.lower(mouseoverGUID) == g.guid)
				
				if not hasPreciseUnit then
					if g.nameplateFrame and g.nameplateFrame.Health then
						local _, maxHP = g.nameplateFrame.Health:GetMinMaxValues()
						if maxHP and maxHP > 0 then
							local oldMax = g.maxHealth or 100
							local newMax = g.maxHealth
							if maxHP <= 100 then
								newMax = (g.maxHealth and g.maxHealth > 100) and g.maxHealth or GetDefaultMaxHealth(g.name)
							else
								newMax = maxHP
								GF:LearnMaxHealth(g.name, maxHP)
							end
							
							if g.maxHealth ~= newMax then
								g.maxHealth = newMax
								if oldMax > 0 then
									g.health = math.floor((g.health / oldMax) * newMax + 0.5)
								else
									g.health = newMax
								end
							end
							
							local ignoreSync = false
							if UnitAffectingCombat("player") then
								ignoreSync = g.lastCombatEventTime and (now - g.lastCombatEventTime < 2.0)
							end
							
							if not ignoreSync then
								local hp = g.nameplateFrame.Health:GetValue()
								if hp and hp > 0 then
									if maxHP <= 100 then
										g.health = (hp / maxHP) * g.maxHealth
									else
										g.health = hp
									end
								end
							end
							updated = true
						end
					end
					
					if not updated and g.nameplateUnit then
						local maxHP = UnitHealthMax(g.nameplateUnit)
						if maxHP and maxHP > 0 then
							local oldMax = g.maxHealth or 100
							local newMax = g.maxHealth
							if maxHP <= 100 then
								newMax = (g.maxHealth and g.maxHealth > 100) and g.maxHealth or GetDefaultMaxHealth(g.name)
							else
								newMax = maxHP
								GF:LearnMaxHealth(g.name, maxHP)
							end
							
							if g.maxHealth ~= newMax then
								g.maxHealth = newMax
								if oldMax > 0 then
									g.health = math.floor((g.health / oldMax) * newMax + 0.5)
								else
									g.health = newMax
								end
							end
							
							local ignoreSync = false
							if UnitAffectingCombat("player") then
								ignoreSync = g.lastCombatEventTime and (now - g.lastCombatEventTime < 2.0)
							end
							
							if not ignoreSync then
								local hp = UnitHealth(g.nameplateUnit)
								if hp and hp > 0 then
									if maxHP <= 100 then
										g.health = (hp / maxHP) * g.maxHealth
									else
										g.health = hp
									end
								end
							end
						end
					end
				end
				
				GF:UpdateBarContent(bar, g, now)
			end
		end
	end

	if needsRefresh then
		GF:RefreshFrames()
	end
end

-- COMBAT_LOG_EVENT_UNFILTERED parser
function GF:COMBAT_LOG_EVENT_UNFILTERED(acEvent, ...)
	local timestamp, event
	local hideCaster, sourceGUID, sourceName, sourceFlags, sourceRaidFlags
	local destGUID, destName, destFlags, destRaidFlags
	local prefixOffset

	local argCount = select("#", ...)
	local arg1 = select(1, ...)
	local arg2 = select(2, ...)

	timestamp = arg1
	event = arg2

	local offset = 3
	if type(select(offset, ...)) == "boolean" then
		hideCaster = select(offset, ...)
		offset = offset + 1
	end

	sourceGUID = select(offset, ...)
	sourceName = select(offset + 1, ...)
	sourceFlags = select(offset + 2, ...)
	offset = offset + 3

	if type(select(offset, ...)) == "number" then
		sourceRaidFlags = select(offset, ...)
		offset = offset + 1
	end

	destGUID = select(offset, ...)
	destName = select(offset + 1, ...)
	destFlags = select(offset + 2, ...)
	offset = offset + 3

	if sourceRaidFlags ~= nil then
		destRaidFlags = select(offset, ...)
		offset = offset + 1
	end

	prefixOffset = offset

	local playerGUID = UnitGUID("player")
	local cPlayerGUID = playerGUID and string.lower(playerGUID)
	local cSourceGUID = sourceGUID and string.lower(sourceGUID)
	local cDestGUID = destGUID and string.lower(destGUID)
	
	-- Global Pre-Resolver: Resolve temporary/unbound GUIDs for OUR units from source or destination
	if cSourceGUID and cSourceGUID ~= cPlayerGUID and sourceFlags and type(sourceFlags) == "number" and bit.band(sourceFlags, 0x00000001) ~= 0 then
		local g = GF.activeGuardians[cSourceGUID]
		if not g and sourceName then
			local cleanSourceName = string.lower(sourceName)
			local baseSourceName = GetBaseName(cleanSourceName)
			local npcID = GetNPCIDFromGUID(cSourceGUID)
			local tempKey = nil
			for tGUID, candidate in pairs(GF.activeGuardians) do
				local match = false
				if npcID and candidate.npcID and candidate.npcID == npcID then
					match = true
				elseif GetBaseName(candidate.name) == baseSourceName then
					match = true
				end
				
				if match and (candidate.isTempGUID or string.find(tGUID, "temp_") or not candidate.nameplateUnit) then
					tempKey = tGUID
					break
				end
			end
			
			if tempKey then
				g = GF.activeGuardians[tempKey]
				GF.activeGuardians[tempKey] = nil
				g.guid = cSourceGUID
				g.isTempGUID = nil
				GF.activeGuardians[cSourceGUID] = g
				GF:RefreshFrames()
			end
		end
	end

	if cDestGUID and cDestGUID ~= cPlayerGUID then
		local isHostile = (destFlags and type(destFlags) == "number" and bit.band(destFlags, 0x00000040) ~= 0)
		local isNeutral = (destFlags and type(destFlags) == "number" and bit.band(destFlags, 0x00000020) ~= 0)
		
		if not isHostile and not isNeutral then
			local isMine = (destFlags and type(destFlags) == "number" and bit.band(destFlags, 0x00000001) ~= 0)
			local isCaster = (cSourceGUID == cPlayerGUID)
			
			if isMine or isCaster then
				local g = GF.activeGuardians[cDestGUID]
				if not g and destName then
					local cleanDestName = string.lower(destName)
					local baseDestName = GetBaseName(cleanDestName)
					local npcID = GetNPCIDFromGUID(cDestGUID)
					local tempKey = nil
					for tGUID, candidate in pairs(GF.activeGuardians) do
						local match = false
						if npcID and candidate.npcID and candidate.npcID == npcID then
							match = true
						elseif GetBaseName(candidate.name) == baseDestName then
							match = true
						end
						
						if match and (candidate.isTempGUID or string.find(tGUID, "temp_") or not candidate.nameplateUnit) then
							tempKey = tGUID
							break
						end
					end
					
					if tempKey then
						g = GF.activeGuardians[tempKey]
						GF.activeGuardians[tempKey] = nil
						g.guid = cDestGUID
						g.isTempGUID = nil
						GF.activeGuardians[cDestGUID] = g
						GF:RefreshFrames()
					elseif isMine then
						-- Brand new guardian discovered via combat log heal/spell action!
						-- We ONLY allow creating a BRAND NEW guardian if it is explicitly ours (isMine)
						local cleanName = string.lower(destName)
						local baseName = GetBaseName(cleanName)
						local track = (E.db.unitframe.units.guardians.trackAllMySummons or GF.customGuardiansList[cleanName] or GF.customGuardiansList[baseName]) and IsTrackable(destName)
						if track then
							local nd = nameDefaults[cleanName] or nameDefaults[baseName]
							local duration = nd and nd.duration or -1
							local icon = nd and nd.icon or "Interface\\Icons\\Spell_Shadow_AnimateDead"
							local defaultMaxHP = GetDefaultMaxHealth(destName)
							local fallbackNpcID = nd and nd.npcID or GetNPCIDFromGUID(cDestGUID)
							
							g = {
								guid = cDestGUID,
								name = destName,
								summonTime = GetTime(),
								duration = duration,
								endTime = GetTime() + (duration > 0 and duration or 0),
								maxHealth = defaultMaxHP,
								health = defaultMaxHP,
								icon = icon,
								nameplateUnit = nil,
								npcID = fallbackNpcID,
								creationID = GetNextCreationID(),
							}
							GF.activeGuardians[cDestGUID] = g
							GF:RefreshFrames()
						end
					end
				end
			end
		end
	end
	
	-- A. Handle Summons (Direct SPELL_SUMMON or SPELL_AURA_APPLIED from minion to player)
	if event == "SPELL_SUMMON" and (cSourceGUID == cPlayerGUID or (sourceName and sourceName == UnitName("player"))) then
		local spellID = select(prefixOffset, ...)
		local duration = spellDurations[spellID] or -1
		local icon = GetSpellIconTexture(spellID)

		local cleanName = string.lower(destName)
		if duration == -1 and nameDefaults[cleanName] then
			duration = nameDefaults[cleanName].duration
			icon = icon or nameDefaults[cleanName].icon
		end

		-- Verify tracking allowance
		local track = (E.db.unitframe.units.guardians.trackAllMySummons or GF.customGuardiansList[cleanName]) and IsTrackable(destName)
		if spellID and companionSpellIDs[spellID] then
			track = false
		end
		if track and cDestGUID then
			local defaultMaxHP = GetDefaultMaxHealth(destName)
			local fallbackNpcID = nameDefaults[cleanName] and nameDefaults[cleanName].npcID or GetNPCIDFromGUID(cDestGUID)
			
			GF.activeGuardians[cDestGUID] = {
				guid = cDestGUID,
				name = destName,
				summonTime = GetTime(),
				duration = duration,
				endTime = GetTime() + (duration > 0 and duration or 0),
				maxHealth = defaultMaxHP, -- fallback value; corrected by nameplate unit query on visibility
				health = defaultMaxHP,
				icon = icon,
				spellID = spellID,
				nameplateUnit = nil,
				npcID = fallbackNpcID,
				creationID = GetNextCreationID(),
			}
			GF:RefreshFrames()
			GF:ScanPlayerBuffs() -- Reconcile buffs instantly to prune stale duplicates!
		end
	elseif event == "SPELL_AURA_APPLIED" then
		if cDestGUID == cPlayerGUID or (destName and destName == UnitName("player")) then
			local spellID = select(prefixOffset, ...)
			local spellName = select(prefixOffset + 1, ...)
			local spellSchool = select(prefixOffset + 2, ...)
			local auraType = select(prefixOffset + 3, ...)
			if auraType == "BUFF" then
				local cleanSpellName = string.lower(spellName)
				local baseSpellName = GetBaseName(cleanSpellName)
				local nd = nameDefaults[cleanSpellName] or nameDefaults[baseSpellName]
				local targetName = (nd and nd.guardianName) and nd.guardianName or baseSpellName
				local cleanTargetName = string.lower(targetName)
				local baseTargetName = GetBaseName(cleanTargetName)

				local track = (E.db.unitframe.units.guardians.trackAllMySummons or GF.customGuardiansList[cleanTargetName] or GF.customGuardiansList[baseTargetName] or GF.customGuardiansList[cleanSpellName] or GF.customGuardiansList[baseSpellName]) and IsTrackable(targetName)
				if track and cSourceGUID and cSourceGUID ~= cPlayerGUID then
					-- This is a tracked summon buff applied by the summon itself!
					-- We can register this summon immediately with its real unique GUID!
					local duration = nd and nd.duration or -1
					local icon = GetSpellIconTexture(spellID) or (nd and nd.icon) or "Interface\\Icons\\Spell_Shadow_AnimateDead"
					local defaultMaxHP = GetDefaultMaxHealth(targetName)
					local fallbackNpcID = nd and nd.npcID or GetNPCIDFromGUID(cSourceGUID)

					GF.activeGuardians[cSourceGUID] = {
						guid = cSourceGUID,
						name = targetName,
						summonTime = GetTime(),
						duration = duration,
						endTime = GetTime() + (duration > 0 and duration or 0),
						maxHealth = defaultMaxHP,
						health = defaultMaxHP,
						icon = icon,
						spellID = spellID,
						nameplateUnit = nil,
						npcID = fallbackNpcID,
						creationID = GetNextCreationID(),
					}
					GF:RefreshFrames()
					GF:ScanPlayerBuffs() -- Reconcile buffs instantly to prune stale duplicates!
				end
			end
		end
	
	-- B. Handle Death & Despawns (including Aura Removals for replaced/dismissed custom summons)
	elseif event == "UNIT_DIED" then
		if cDestGUID then
			if GF.activeGuardians[cDestGUID] then
				GF.activeGuardians[cDestGUID] = nil
				GF:RefreshFrames()
			else
				-- Try to remove a temp/unbound candidate of the same name (if it belongs to us)
				if destName and destFlags and type(destFlags) == "number" and bit.band(destFlags, 0x00000001) ~= 0 then
					local cleanDestName = string.lower(destName)
					local baseDestName = GetBaseName(cleanDestName)
					local npcID = GetNPCIDFromGUID(cDestGUID)
					local tempKey = nil
					for tGUID, candidate in pairs(GF.activeGuardians) do
						local match = false
						if npcID and candidate.npcID and candidate.npcID == npcID then
							match = true
						elseif GetBaseName(candidate.name) == baseDestName then
							match = true
						end
						
						if match and (candidate.isTempGUID or string.find(tGUID, "temp_") or not candidate.nameplateUnit) then
							tempKey = tGUID
							break
						end
					end
					if tempKey then
						GF.activeGuardians[tempKey] = nil
						GF:RefreshFrames()
					end
				end
			end
		end
	elseif event == "SPELL_AURA_REMOVED" then
		local matched = false
		
		-- Fallback for SPELL_AURA_REMOVED when cast on the player (handling dismiss/replace/despawn)
		if cDestGUID == cPlayerGUID or (destName and destName == UnitName("player")) then
			local spellID = select(prefixOffset, ...)
			local spellName = select(prefixOffset + 1, ...)
			if spellName then
				local cleanSpellName = string.lower(spellName)
				local baseSpellName = GetBaseName(cleanSpellName)
				
				-- Check if the player still has this buff active (meaning it was just a stack/refresh update, not a real removal)
				local hasBuff = false
				for i = 1, 40 do
					local bName = UnitBuff("player", i)
					if bName and (string.lower(bName) == cleanSpellName or GetBaseName(bName) == baseSpellName) then
						hasBuff = true
						break
					end
				end
				
				if not hasBuff then
					-- Compile candidates for this spellName
					local candidates = {}
					for gGUID, g in pairs(GF.activeGuardians) do
						if GetBaseName(g.name) == baseSpellName or (g.spellID and g.spellID == spellID) then
							table.insert(candidates, g)
						end
					end
					
					if #candidates > 0 then
						-- Sort candidates to remove temporary ones first, then offline ones, then oldest
						table.sort(candidates, function(a, b)
							if a.isTempGUID ~= b.isTempGUID then
								return a.isTempGUID
							elseif (a.nameplateUnit == nil) ~= (b.nameplateUnit == nil) then
								return a.nameplateUnit == nil
							elseif a.summonTime ~= b.summonTime then
								return a.summonTime < b.summonTime
							else
								return (a.creationID or 0) < (b.creationID or 0)
							end
						end)
						
						-- Remove only ONE candidate!
						local target = candidates[1]
						if target then
							GF.activeGuardians[target.guid] = nil
							matched = true
						end
					end
				end
			end
		end
		
		if matched then
			GF:RefreshFrames()
		end

	-- C. Handle Damage
	elseif cDestGUID and (string.find(event, "_DAMAGE") or event == "SWING_DAMAGE") then
		local amount = 0
		if event == "SWING_DAMAGE" then
			amount = select(prefixOffset, ...)
		elseif event == "ENVIRONMENTAL_DAMAGE" then
			amount = select(prefixOffset + 1, ...)
		elseif string.find(event, "_DAMAGE") then
			amount = select(prefixOffset + 3, ...)
		end
		
		if amount and amount > 0 then
			local g = GF.activeGuardians[cDestGUID]
			if g then
				g.health = g.health - amount
				if g.health < 0 then g.health = 0 end
				g.lastCombatEventTime = GetTime()
			end
		end

	-- D. Handle Healing
	elseif cDestGUID and string.find(event, "_HEAL") then
		local amount = select(prefixOffset + 3, ...)
		if amount and amount > 0 then
			local g = GF.activeGuardians[cDestGUID]
			if g then
				g.health = g.health + amount
				if g.health > g.maxHealth then g.health = g.maxHealth end
				g.lastCombatEventTime = GetTime()
			end
		end
	end
end

-- ElvUI Nameplates Module Secure Hook
function GF:NamePlateCallback(nameplate, event, unit)
	if not nameplate then return end
	
	unit = unit or nameplate.unit
	
	if event == "NAME_PLATE_UNIT_ADDED" or event == "UNIT_FACTION" or event == "UNIT_FLAGS" or event == "UNIT_NAME_UPDATE" then
		if not unit then return end
		local guid = nameplate.unitGUID or UnitGUID(unit)
		local name = nameplate.unitName or UnitName(unit)
		if not IsTrackableUnit(unit) then
			-- Prune this untrackable unit from active guardians if it exists
			local deleted = false
			local cleanGUID = guid and string.lower(guid)
			if cleanGUID and GF.activeGuardians[cleanGUID] then
				GF.activeGuardians[cleanGUID] = nil
				deleted = true
			end
			local cleanName = name and string.lower(name)
			if cleanName and not IsTrackable(cleanName) then
				local baseName = GetBaseName(cleanName)
				for gGUID, g in pairs(GF.activeGuardians) do
					local gCleanName = string.lower(g.name)
					if gCleanName == cleanName or GetBaseName(gCleanName) == baseName then
						GF.activeGuardians[gGUID] = nil
						deleted = true
					end
				end
			end
			if deleted then
				GF:RefreshFrames()
			end
			return
		end
		if not name then return end

		local cleanName = string.lower(name)
		local baseName = GetBaseName(cleanName)
		local cleanGUID = guid and string.lower(guid) or nil

		-- Try to find an existing active guardian
		local g = cleanGUID and GF.activeGuardians[cleanGUID] or nil
		
		-- If not found by GUID, try to find an unbound candidate by name or NPC ID
		if not g then
			local isFriendlyMinion = UnitIsUnit("pet", unit) or IsPlayerMinion(unit)
			local npcID = GetNPCIDFromGUID(cleanGUID)
			
			-- Fallback: if tooltip scanning (IsPlayerMinion) failed, but it's a friendly non-player unit,
			-- we check if we have a temporary unbound guardian of the same NPC ID or name.
			-- This is highly reliable for custom/secondary summons on Project Ascension.
			local isCandidate = false
			if not isFriendlyMinion and UnitIsFriend("player", unit) and not UnitIsPlayer(unit) then
				for tGUID, candidate in pairs(GF.activeGuardians) do
					if not candidate.nameplateUnit and (candidate.isTempGUID or string.find(tGUID, "temp_")) then
						if (npcID and candidate.npcID and candidate.npcID == npcID) or (GetBaseName(candidate.name) == baseName) then
							isCandidate = true
							break
						end
					end
				end
			end

			if isFriendlyMinion or isCandidate then
				-- Look for a temp GUID or any entry of the same name with no nameplateUnit
				local tempKey = nil
				for tGUID, candidate in pairs(GF.activeGuardians) do
					local match = false
					if npcID and candidate.npcID and candidate.npcID == npcID then
						match = true
					elseif GetBaseName(candidate.name) == baseName then
						match = true
					end
					
					if match and not candidate.nameplateUnit then
						tempKey = tGUID
						break
					end
				end
				
				if tempKey then
					g = GF.activeGuardians[tempKey]
					if cleanGUID and tempKey ~= cleanGUID then
						-- Promote the key to the real GUID!
						GF.activeGuardians[tempKey] = nil
						g.guid = cleanGUID
						g.isTempGUID = nil
						GF.activeGuardians[cleanGUID] = g
					end
				end
			end
		end

		if g then
			-- We matched an existing active guardian (by GUID or name)!
			g.nameplateUnit = unit
			g.nameplateFrame = nameplate
			
			local updated = false
			
			local targetGUID = UnitExists("target") and UnitGUID("target")
			local focusGUID = UnitExists("focus") and UnitGUID("focus")
			local petGUID = UnitExists("pet") and UnitGUID("pet")
			local mouseoverGUID = UnitExists("mouseover") and UnitGUID("mouseover")
			
			local hasPreciseUnit = (g.lastPreciseUnitTime and (GetTime() - g.lastPreciseUnitTime < 1.0)) or
			                       (targetGUID and string.lower(targetGUID) == g.guid) or
			                       (focusGUID and string.lower(focusGUID) == g.guid) or
			                       (petGUID and string.lower(petGUID) == g.guid) or
			                       (mouseoverGUID and string.lower(mouseoverGUID) == g.guid)
			
			if not hasPreciseUnit then
				if nameplate and nameplate.Health then
					local _, maxHP = nameplate.Health:GetMinMaxValues()
					if maxHP and maxHP > 0 then
						local oldMax = g.maxHealth or 100
						local newMax = g.maxHealth
						if maxHP <= 100 then
							newMax = (g.maxHealth and g.maxHealth > 100) and g.maxHealth or GetDefaultMaxHealth(g.name)
						else
							newMax = maxHP
							GF:LearnMaxHealth(g.name, maxHP)
						end
						
						if g.maxHealth ~= newMax then
							g.maxHealth = newMax
							if oldMax > 0 then
								g.health = math.floor((g.health / oldMax) * newMax + 0.5)
							else
								g.health = newMax
							end
						end
						
						local ignoreSync = false
						if UnitAffectingCombat("player") then
							ignoreSync = g.lastCombatEventTime and (GetTime() - g.lastCombatEventTime < 2.0)
						end
						
						if not ignoreSync then
							local hp = nameplate.Health:GetValue()
							if hp and hp > 0 then
								if maxHP <= 100 then
									g.health = (hp / maxHP) * g.maxHealth
								else
									g.health = hp
								end
							end
						end
						updated = true
					end
				end
				
				if not updated and unit then
					local maxHP = UnitHealthMax(unit)
					if maxHP and maxHP > 0 then
						local oldMax = g.maxHealth or 100
						local newMax = g.maxHealth
						if maxHP <= 100 then
							newMax = (g.maxHealth and g.maxHealth > 100) and g.maxHealth or GetDefaultMaxHealth(g.name)
						else
							newMax = maxHP
							GF:LearnMaxHealth(g.name, maxHP)
						end
						
						if g.maxHealth ~= newMax then
							g.maxHealth = newMax
							if oldMax > 0 then
								g.health = math.floor((g.health / oldMax) * newMax + 0.5)
							else
								g.health = newMax
							end
						end
						
						local ignoreSync = false
						if UnitAffectingCombat("player") then
							ignoreSync = g.lastCombatEventTime and (GetTime() - g.lastCombatEventTime < 2.0)
						end
						
						if not ignoreSync then
							local hp = UnitHealth(unit)
							if hp and hp > 0 then
								if maxHP <= 100 then
									g.health = (hp / maxHP) * g.maxHealth
								else
									g.health = hp
								end
							end
						end
						updated = true
					end
				end
			end
			
			if not g.icon and (nameDefaults[cleanName] or nameDefaults[baseName]) then
				local nd = nameDefaults[cleanName] or nameDefaults[baseName]
				g.icon = nd.icon
			end
			GF:RefreshFrames()
		else
			-- Scenario 3: New guardian detected from nameplate (Matches list or belongs to player)
			if UnitIsFriend("player", unit) and not UnitIsPlayer(unit) then
				if (GF.customGuardiansList[cleanName] or GF.customGuardiansList[baseName] or E.db.unitframe.units.guardians.trackAllMySummons) and IsTrackable(name) then
					local isFriendlyMinion = UnitIsUnit("pet", unit) or IsPlayerMinion(unit)
					-- For custom servers like Project Ascension where tooltip scanning might fail,
					-- allow tracking of friendly non-player units if they match our custom list.
					if isFriendlyMinion or (UnitIsFriend("player", unit) and not UnitIsPlayer(unit) and GF.customGuardiansList[cleanName]) then
						local nd = nameDefaults[cleanName] or nameDefaults[baseName]
						local duration = nd and nd.duration or -1
						local icon = nd and nd.icon or nil
						
						if not icon then
							icon = "Interface\\Icons\\Spell_Shadow_AnimateDead"
						end
						
						local maxHP, hp
						local updated = false
						
						if nameplate and nameplate.Health then
							hp = nameplate.Health:GetValue()
							_, maxHP = nameplate.Health:GetMinMaxValues()
							if hp and hp > 0 and maxHP and maxHP > 0 then
								updated = true
							end
						end
						
						if not updated and unit then
							maxHP = UnitHealthMax(unit)
							hp = UnitHealth(unit)
							if maxHP and maxHP > 0 and hp and hp > 0 then
								updated = true
							end
						end
						
						local defaultMaxHP = GetDefaultMaxHealth(baseName)
						if updated then
							if maxHP <= 100 then
								hp = (hp / maxHP) * defaultMaxHP
								maxHP = defaultMaxHP
							else
								GF:LearnMaxHealth(name, maxHP)
							end
						else
							maxHP = defaultMaxHP
							hp = defaultMaxHP
						end
						
						-- Assign a GUID (fallback to a generated unique name-based ID if GUID is nil)
						local finalGUID = cleanGUID or ("np_temp_" .. cleanName .. "_" .. GetTime())
						local fallbackNpcID = nd and nd.npcID or GetNPCIDFromGUID(cleanGUID)
						
						GF.activeGuardians[finalGUID] = {
							guid = finalGUID,
							name = name,
							summonTime = GetTime(),
							duration = duration,
							endTime = GetTime() + (duration > 0 and duration or 0),
							maxHealth = maxHP,
							health = hp,
							icon = icon,
							nameplateUnit = unit,
							nameplateFrame = nameplate,
							npcID = fallbackNpcID,
							creationID = GetNextCreationID(),
						}
						GF:RefreshFrames()
						GF:ScanPlayerBuffs() -- Reconcile buffs instantly to prune stale duplicates!
					end
				end
			end
		end
	elseif event == "NAME_PLATE_UNIT_REMOVED" then
		-- Clean up unit reference when nameplate leaves screen (but do NOT delete our active guardian)
		local guid = nameplate.unitGUID or (unit and UnitGUID(unit))
		local cleanGUID = guid and string.lower(guid)
		for gGUID, g in pairs(GF.activeGuardians) do
			if g.nameplateFrame == nameplate or (unit and g.nameplateUnit == unit) or (cleanGUID and gGUID == cleanGUID) then
				g.nameplateUnit = nil
				g.nameplateFrame = nil
			end
		end
		GF:RefreshFrames()
	end
end

function GF:PLAYER_ENTERING_WORLD()
	-- Prevent frame state leaking across zone switches/loading screens
	wipe(GF.activeGuardians)
	GF.guardianCounter = 0
	UpdateCompanionBlacklist()
	GF:RefreshFrames()
	GF:ScanPlayerBuffs()
end

function GF:UNIT_AURA(_, unit)
	if unit == "player" then
		GF:ScanPlayerBuffs()
	end
end

-- Dynamic Max Health learning from targets/mouseover/pets
function GF:UpdateGuardianFromUnit(unit)
	if not unit or not UnitExists(unit) then return end
	if not IsTrackableUnit(unit) then
		-- Prune this untrackable unit from active guardians if it exists
		local guid = UnitGUID(unit)
		local name = UnitName(unit)
		local deleted = false
		local cleanGUID = guid and string.lower(guid)
		if cleanGUID and GF.activeGuardians[cleanGUID] then
			GF.activeGuardians[cleanGUID] = nil
			deleted = true
		end
		local cleanName = name and string.lower(name)
		if cleanName and not IsTrackable(cleanName) then
			local baseName = GetBaseName(cleanName)
			for gGUID, g in pairs(GF.activeGuardians) do
				local gCleanName = string.lower(g.name)
				if gCleanName == cleanName or GetBaseName(gCleanName) == baseName then
					GF.activeGuardians[gGUID] = nil
					deleted = true
				end
			end
		end
		if deleted then
			GF:RefreshFrames()
		end
		return
	end
	local guid = UnitGUID(unit)
	local cleanGUID = guid and string.lower(guid)
	if cleanGUID then
		local g = GF.activeGuardians[cleanGUID]
		local promoted = false
		if not g then
			-- Try to find a temporary/unbound candidate of the same name or NPC ID to associate with this new GUID!
			local name = UnitName(unit)
			local cleanName = name and string.lower(name)
			local baseName = GetBaseName(cleanName)
			
			local isFriendlyMinion = UnitIsUnit("pet", unit) or IsPlayerMinion(unit)
			local npcID = GetNPCIDFromGUID(cleanGUID)
			local isCandidate = false
			if not isFriendlyMinion and UnitIsFriend("player", unit) and not UnitIsPlayer(unit) then
				for tGUID, candidate in pairs(GF.activeGuardians) do
					if not candidate.nameplateUnit and (candidate.isTempGUID or string.find(tGUID, "temp_")) then
						if (npcID and candidate.npcID and candidate.npcID == npcID) or (GetBaseName(candidate.name) == baseName) then
							isCandidate = true
							break
						end
					end
				end
			end

			if cleanName and (isFriendlyMinion or isCandidate) then
				local tempKey = nil
				for tGUID, candidate in pairs(GF.activeGuardians) do
					local match = false
					if npcID and candidate.npcID and candidate.npcID == npcID then
						match = true
					elseif GetBaseName(candidate.name) == baseName then
						match = true
					end
					
					if match and (candidate.isTempGUID or string.find(tGUID, "temp_") or not candidate.nameplateUnit) then
						tempKey = tGUID
						break
					end
				end
				
				if tempKey then
					g = GF.activeGuardians[tempKey]
					GF.activeGuardians[tempKey] = nil
					g.guid = cleanGUID
					g.isTempGUID = nil
					GF.activeGuardians[cleanGUID] = g
					promoted = true
				end
			end
		end

		if g then
			-- Automatically bind nameplate reference if it's currently unbound or if this is a nameplate token
			local isNameplateToken = string.find(unit, "^nameplate")
			if isNameplateToken or not g.nameplateUnit or not g.nameplateFrame then
				local NP = E:GetModule('NamePlates', true)
				if NP and NP.PlateGUID then
					local rawGUID = UnitGUID(unit)
					local plateFrame = rawGUID and NP.PlateGUID[rawGUID]
					if plateFrame then
						g.nameplateUnit = unit
						g.nameplateFrame = plateFrame
					end
				end
			end

			local maxHP = UnitHealthMax(unit)
			local hp = UnitHealth(unit)
			local ignoreSync = false
			if UnitAffectingCombat("player") then
				ignoreSync = g.lastCombatEventTime and (GetTime() - g.lastCombatEventTime < 2.0)
			end
			
			local maxHealthUpdated = false
			if maxHP and maxHP > 0 then
				local oldMax = g.maxHealth or 100
				local newMax = g.maxHealth
				if maxHP <= 100 then
					newMax = (g.maxHealth and g.maxHealth > 100) and g.maxHealth or GetDefaultMaxHealth(g.name)
				else
					newMax = maxHP
					GF:LearnMaxHealth(g.name, maxHP)
				end
				
				if g.maxHealth ~= newMax then
					g.maxHealth = newMax
					if oldMax > 0 then
						g.health = math.floor((g.health / oldMax) * newMax + 0.5)
					else
						g.health = newMax
					end
					maxHealthUpdated = true
				end
				
				if maxHP > 100 then
					g.lastPreciseUnitTime = GetTime()
				end
			end
			
			local healthUpdated = false
			if not ignoreSync then
				local isValidHP = hp and hp > 0
				if maxHP and maxHP > 0 and isValidHP then
					if maxHP <= 100 then
						g.health = (hp / maxHP) * g.maxHealth
					else
						g.health = hp
					end
					healthUpdated = true
				end
			end
			
			if promoted then
				GF:RefreshFrames()
			elseif healthUpdated or maxHealthUpdated then
				-- Immediate, lightweight bar content update instead of full layout refresh!
				for _, bar in ipairs(GF.framePool) do
					if bar.guardianGUID == cleanGUID then
						GF:UpdateBarContent(bar, g, GetTime())
						break
					end
				end
			end
		end
	end
end

function GF:PLAYER_TARGET_CHANGED()
	GF:UpdateGuardianFromUnit("target")
end

function GF:UNIT_HEALTH(_, unit)
	if unit == "target" or unit == "pet" or string.find(unit, "pet") or unit == "focus" or unit == "targettarget" or unit == "focustarget" or unit == "mouseover" or unit == "mouseovertarget" then
		GF:UpdateGuardianFromUnit(unit)
	end
end

function GF:UNIT_MAXHEALTH(_, unit)
	if unit == "target" or unit == "pet" or string.find(unit, "pet") or unit == "focus" or unit == "targettarget" or unit == "focustarget" or unit == "mouseover" or unit == "mouseovertarget" then
		GF:UpdateGuardianFromUnit(unit)
	end
end
function GF:COMPANION_UPDATE()
	UpdateCompanionBlacklist()
end

function GF:COMPANION_LEARNED()
	UpdateCompanionBlacklist()
end

-- Toggle Plugin On/Off
function GF:ToggleModule()
	if E.db.unitframe.units.guardians.enable then
		GF:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		GF:RegisterEvent("PLAYER_ENTERING_WORLD")
		GF:RegisterEvent("UNIT_AURA")
		GF:RegisterEvent("PLAYER_TARGET_CHANGED")
		GF:RegisterEvent("UNIT_HEALTH")
		GF:RegisterEvent("UNIT_MAXHEALTH")
		GF:RegisterEvent("COMPANION_UPDATE")
		GF:RegisterEvent("COMPANION_LEARNED")
		
		GF:CreateContainer()
		GF.container:Show()
		GF.container:SetScript("OnUpdate", Container_OnUpdate)
		
		E:EnableMover("ElvUF_GuardiansMover")
		
		GF:UpdateCustomGuardiansTable()
		GF:ScanPlayerBuffs()
	else
		GF:UnregisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
		GF:UnregisterEvent("PLAYER_ENTERING_WORLD")
		GF:UnregisterEvent("UNIT_AURA")
		GF:UnregisterEvent("PLAYER_TARGET_CHANGED")
		GF:UnregisterEvent("UNIT_HEALTH")
		GF:UnregisterEvent("UNIT_MAXHEALTH")
		GF:UnregisterEvent("COMPANION_UPDATE")
		GF:UnregisterEvent("COMPANION_LEARNED")
		
		if GF.container then
			GF.container:Hide()
			GF.container:SetScript("OnUpdate", nil)
			E:DisableMover("ElvUF_GuardiansMover")
		end
		
		-- Hide & recycle active frames
		for _, bar in ipairs(GF.framePool) do
			bar:Hide()
			table.insert(GF.inactiveFramePool, bar)
		end
		wipe(GF.framePool)
		wipe(GF.activeGuardians)
		GF.guardianCounter = 0
	end
end

-- Refresh Configurations
function GF:UpdateSettings()
	if not E.db.unitframe.units.guardians.enable then return end
	
	if GF.container then
		GF.container:Size(E.db.unitframe.units.guardians.width, E.db.unitframe.units.guardians.height)
	end
	
	GF:RefreshFrames()
end

-- Initialize Module
function GF:Initialize()
	-- Defaults live in P.unitframe.units.guardians (Settings/Profile.lua)
	local db = E.db.unitframe.units.guardians
	if not db.learnedMaxHealth then
		db.learnedMaxHealth = {}
	end

	-- Hook into ElvUI's Nameplates callbacks safely
	local NP = E:GetModule('NamePlates')
	if NP then
		hooksecurefunc(NP, "NamePlateCallBack", function(self, nameplate, event, unit)
			GF:NamePlateCallback(nameplate, event, unit)
		end)
	end

	-- Register Debug Slash Command
	_G.SLASH_GFDEBUG1 = "/gfdebug"
	_G.SlashCmdList["GFDEBUG"] = function()
		print("|cff1784d1ElvUI Guardians Debug Info:|r")
		local count = 0
		for guid, g in pairs(GF.activeGuardians) do
			count = count + 1
			local npText = g.nameplateUnit and ("|cff4deb34" .. g.nameplateUnit .. "|r") or "|cff8c8c8cnil|r"
			local hpText = string.format("%d/%d (%d%%)", g.health, g.maxHealth, g.maxHealth > 0 and math.floor((g.health / g.maxHealth) * 100 + 0.5) or 0)
			print(string.format("  [%d] Name: %s | ID: %s | GUID: %s | HP: %s | Temp: %s | Unit: %s", 
				count, g.name or "nil", tostring(g.creationID), guid or "nil", hpText, 
				tostring(g.isTempGUID), npText))
		end
		if count == 0 then
			print("  No active guardians currently tracked.")
		end

		-- Background layers of the first visible bar (to check what the alpha really does)
		local bar = GF.framePool[1]
		if bar then
			local fr, fg, fb, fa = bar:GetBackdropColor()
			local bgr, bgg, bgb, bga = bar.healthBar.bg:GetVertexColor()
			local fill = bar.healthBar:GetStatusBarTexture()
			local sr, sg, sb, sa = fill:GetVertexColor()
			local c = E.db.unitframe.units.guardians.backgroundColor
			print(string.format("  custom bg: %s", c and string.format("%.2f/%.2f/%.2f a=%.2f", c.r, c.g, c.b, c.a or 1) or "none (ElvUI default)"))
			print(string.format("  frame backdrop: %.2f/%.2f/%.2f a=%.2f | bg texture: a=%.2f alpha=%.2f shown=%s | fill: a=%.2f alpha=%.2f", fr or 0, fg or 0, fb or 0, fa or 0, bga or 0, bar.healthBar.bg:GetAlpha(), tostring(bar.healthBar.bg:IsShown()), sa or 0, fill:GetAlpha()))
			local cb = bar.customBG
			if cb then local cr,cg,cbb,ca = cb:GetVertexColor() print(string.format("  customBG: %.2f/%.2f/%.2f a=%.2f shown=%s", cr or 0, cg or 0, cbb or 0, ca or 0, tostring(cb:IsShown()))) else print("  customBG: none (alte Version oder keine eigene Farbe)") end

			-- Layer dump: every texture/frame on the bar, to find whatever draws an opaque background
			local function dumpRegions(f, indent)
				local regs = { f:GetRegions() }
				for _, r in ipairs(regs) do
					if r.GetObjectType and r:GetObjectType() == "Texture" then
						local rr, rg, rb, ra = r:GetVertexColor()
						print(string.format("%s tex layer=%s a=%.2f col=%.2f/%.2f/%.2f shown=%s w=%.0f h=%.0f %s", indent, tostring(r:GetDrawLayer()), r:GetAlpha() or 0, rr or 0, rg or 0, rb or 0, tostring(r:IsShown()), r:GetWidth() or 0, r:GetHeight() or 0, tostring(r:GetTexture())))
					end
				end
				local kids = { f:GetChildren() }
				for _, k in ipairs(kids) do
					print(string.format("%s frame %s lvl=%s a=%.2f shown=%s", indent, tostring(k:GetObjectType()), tostring(k:GetFrameLevel()), k:GetAlpha() or 0, tostring(k:IsShown())))
					dumpRegions(k, indent .. "  ")
				end
			end
			print("  layers of bar 1:")
			print(string.format("  bar lvl=%s a=%.2f", tostring(bar:GetFrameLevel()), bar:GetAlpha() or 0))
			dumpRegions(bar, "   ")
		end
	end

	-- Re-apply everything when ElvUI refreshes all frames (profile switch/copy/reset)
	hooksecurefunc(UF, "Update_AllFrames", function()
		GF:ToggleModule()
		GF:UpdateSettings()
	end)

	GF:ToggleModule()
end

-- Register self to ElvUI Module manager
local function InitializeCallback()
	GF:Initialize()
end
E:RegisterModule(GF:GetName(), InitializeCallback)

