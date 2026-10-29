local E, L, V, P, G = unpack(ElvUI)
local CCB = E:NewModule("CoAResources", "AceEvent-3.0")
local LSM = E.Libs.LSM

-- Register as a proper ElvUI plugin so CoA Resources is listed in
-- ElvUI's built-in "Plugins Loaded" information together with its version.
local EP = LibStub and LibStub("LibElvUIPlugin-1.0", true)
if EP then
    EP:RegisterPlugin("ElvUI_CoAResources")
end

local CreateFrame, UnitAura = CreateFrame, UnitAura
local UnitPower, UnitPowerMax = UnitPower, UnitPowerMax
local UnitAffectingCombat = UnitAffectingCombat
local floor, min, max = math.floor, math.min, math.max
local pairs, ipairs, tonumber, tostring = pairs, ipairs, tonumber, tostring
local insert, sort = table.insert, table.sort
local format = string.format

P.coaResources = P.coaResources or {
    enable = true,
    autoDetect = true,
    hideOriginalFrames = false,
    autoAuraResources = false, -- exact FrameXML data first; heuristic aura scan is fallback only
    maxPips = 12,
    width = 220,
    height = 14,
    frameStrata = "LOW",
    frameLevel = 5,
    spacing = 3,
    rowSpacing = 5,
    texture = "Norm Tex",
    backgroundTexture = "Norm Tex",
    useClassColor = true, -- legacy; per-resource Base Color now stores the actual class-color default
    color = {r = 0.10, g = 0.65, b = 1.00},
    gradient = false,
    gradientColor = {r = 0.35, g = 0.85, b = 1.00},
    background = {r = 0.08, g = 0.08, b = 0.08, a = 0.75},
    transparent = false,
    showBorder = true,
    borderColor = {r = 0, g = 0, b = 0, a = 1},
    showText = true,
    showResourceName = true,
    font = "PT Sans Narrow",
    fontSize = 12,
    fontOutline = "OUTLINE",
    textColor = {r = 1, g = 1, b = 1},
    combatOnly = false,
    auraFallbackMax = 6,
    detectedAuras = {},
    resourceSettings = {},
    enabledResources = {},
}

local function GetClassToken()
    if _G.C_Player and _G.C_Player.GetClass then
        local c = _G.C_Player:GetClass()
        if c then return c end
    end
    local _, c = UnitClass("player")
    return c
end

local function GetClassColor()
    local class = GetClassToken()
    local c = (_G.CUSTOM_CLASS_COLORS and _G.CUSTOM_CLASS_COLORS[class]) or (_G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[class])
    if c then return c.r or 1, c.g or 1, c.b or 1 end
    return 0.10, 0.65, 1.00
end


local function PlayerLevel()
    if _G.C_Player and _G.C_Player.GetLevel then
        local ok, level = pcall(_G.C_Player.GetLevel)
        if ok and tonumber(level) then return tonumber(level) end
    end
    return tonumber(UnitLevel and UnitLevel("player")) or 1
end

local function IsSpellIDKnownSafe(spellID)
    if not spellID then return false end
    if _G.IsSpellIDKnown then
        local ok, known = pcall(_G.IsSpellIDKnown, spellID)
        if ok then return known and true or false end
    end
    if _G.C_Spell and _G.C_Spell.IsAnyRankKnown then
        local ok, known = pcall(_G.C_Spell.IsAnyRankKnown, spellID, true)
        if ok then return known and true or false end
    end
    if _G.IsSpellKnown then
        local ok, known = pcall(_G.IsSpellKnown, spellID)
        if ok then return known and true or false end
    end
    return false
end

local function IsCAKnownSafe(id)
    if _G.C_CharacterAdvancement and _G.C_CharacterAdvancement.IsKnownID then
        local ok, known = pcall(_G.C_CharacterAdvancement.IsKnownID, id)
        if ok then return known and true or false end
    end
    return false
end

-- Visibility conditions copied from Ascension's ClassResources.lua / class resource mixins.
-- A fixed resource is only rendered when the original CoA frame would be eligible to show.
local CLASS_CONDITIONS = {
    TINKER = function() return PlayerLevel() >= 10 and IsCAKnownSafe(4051) end,
    RANGER = function()
        if IsSpellIDKnownSafe(802036) then return true end
        for spellID = 501715, 501723 do
            if IsSpellIDKnownSafe(spellID) then return true end
        end
        return false
    end,
    SONOFARUGAL = function()
        return PlayerLevel() >= 10 and (IsCAKnownSafe(9905) or IsSpellIDKnownSafe(92112))
    end,
    SUNCLERIC = function() return PlayerLevel() >= 2 and IsSpellIDKnownSafe(804584) end,
    WILDWALKER = function() return IsCAKnownSafe(4059) end,
    PROPHET = function() return IsCAKnownSafe(4053) end,
    STARCALLER = function() return IsSpellIDKnownSafe(800386) or IsSpellIDKnownSafe(524781) end,
    MONK = function() return IsSpellIDKnownSafe(803157) end,
    CHRONOMANCER = function() return IsCAKnownSafe(31183) end,
    BARBARIAN = function() return PlayerLevel() >= 10 and IsSpellIDKnownSafe(92083) end,
}

local function ClassResourceConditionMet(class)
    local condition = CLASS_CONDITIONS[class]
    if condition then
        local ok, visible = pcall(condition)
        return ok and visible or false
    end
    return true
end

local function AuraByID(spellID, filter)
    if not spellID then return false, 0, nil end
    local function scan(f)
        for i = 1, 64 do
            local name, _, _, count, _, duration, expirationTime, caster, _, _, id = UnitAura("player", i, f)
            if not name then break end
            if id == spellID then
                count = tonumber(count) or 0
                if count == 0 then count = 1 end
                return true, count, name, duration, expirationTime, caster
            end
        end
    end
    if filter == "HELPFUL" or filter == "HARMFUL" then
        return scan(filter)
    end
    local found, count, name, duration, expirationTime, caster = scan("HELPFUL")
    if found then return found, count, name, duration, expirationTime, caster end
    return scan("HARMFUL")
end

local function SpellMax(spellID, fallback)
    if _G.GetSpellMaxStack and spellID then
        local ok, value = pcall(_G.GetSpellMaxStack, spellID)
        value = ok and tonumber(value) or nil
        if value and value > 0 then return value end
    end
    return fallback or 1
end

local function TalentRank(id)
    if _G.C_CharacterAdvancement and _G.C_CharacterAdvancement.GetTalentRankByID then
        local a = _G.C_CharacterAdvancement.GetTalentRankByID(id)
        return tonumber(a) or 0
    end
    return 0
end

-- Exact resource definitions extracted from the user's Ascension FrameXML.zip.
-- Multiple rows per class are intentional (e.g. Pyromancer Heat + Ember, Cultist Doom + Void).
local CLASS_RESOURCES = {
    CULTIST = {
        {name="Doom", kind="AURA", spellID=500706, filter="HARMFUL", max=100, mode="BAR"},
        {name="Void", kind="AURA", spellID=800431, filter="HELPFUL", max=6, mode="PIPS"},
    },
    FLESHWARDEN = {
        {name="Flesh Orbs", kind="AURA", spellID=500906, filter="HELPFUL", max=6, mode="PIPS"},
    },
    PYROMANCER = {
        {name="Ember", kind="AURA", spellID=807533, filter="HARMFUL", maxSpellID=807533, fallbackMax=2, mode="PIPS"},
        {name="Heat", kind="AURA", spellID=807389, filter="HARMFUL", max=100, mode="BAR", allowOverMax=true},
    },
    RANGER = {
        {name="Ranger Resource", dynamicName=true, kind="AURA", spellID=804329, filter="HELPFUL", max=5, mode="PIPS"},
    },
    TINKER = {
        {name="Scrap", kind="TINKER_SCRAP", spellID=801816, filter="HELPFUL", mode="PIPS"},
    },
    REAPER = {
        {name="Reaped Souls", kind="AURA", spellID=500363, filter="ANY", max=3, mode="PIPS"},
        {name="Soul Fragments", kind="AURA", spellID=805077, filter="ANY", max=3, mode="PIPS"},
    },
    STORMBRINGER = {
        {name="Static", kind="AURA", spellID=803102, filter="HARMFUL", max=100, mode="BAR"},
    },
    NECROMANCER = {
        {name="Life Force", kind="NECRO_LIFEFORCE", visualSpellID=525004, capacitySpellID=805011, mode="BAR"},
    },
    CHRONOMANCER = {
        {name="Orbs of Fate", kind="AURA", spellID=804455, filter="HELPFUL", max=5, mode="PIPS", hideWhenZero=true},
    },
    MONK = {
        {name="Combo Chain", kind="AURA", spellID=704576, filter="HELPFUL", maxSpellID=704576, fallbackMax=10, mode="PIPS"},
    },
    DEMONHUNTER = {
        {name="Felfury", kind="AURA", spellID=800058, filter="HELPFUL", maxSpellID=800058, fallbackMax=6, mode="PIPS"},
    },
    SONOFARUGAL = {
        {name="Bloodmage Resource", dynamicName=true, kind="FIRST_ACTIVE_AURA", auras={{680687,"HARMFUL"},{706613,"HARMFUL"}}, max=10, mode="BAR"},
    },
    SUNCLERIC = {
        {name="Solar Resource", dynamicName=true, kind="SUNCLERIC", normalSpellID=500149, sunsetSpellID=804584, mode="BAR"},
    },
    BARBARIAN = {
        {name="Tankard", kind="AURA", spellID=805813, filter="HELPFUL", max=10, mode="BAR"},
    },
    WILDWALKER = {
        {name="Primalist Resource", dynamicName=true, kind="AURA", spellID=680441, filter="HELPFUL", max=15, mode="BAR"},
    },
    PROPHET = {
        {name="Venomancer Resource", dynamicName=true, kind="AURA", spellID=804972, filter="HELPFUL", maxSpellID=804972, fallbackMax=5, mode="PIPS"},
    },
    STARCALLER = {
        {name="Starcaller Resource", dynamicName=true, kind="AURA", spellID=802985, filter="HELPFUL", maxSpellID=802985, fallbackMax=4, mode="PIPS"},
    },
    -- Runemaster's old 800305 bar is commented out by Ascension in this client build.
    -- It is intentionally not hard-enabled; Alternative Power / fallback detection handles live resources.
}

CCB.CLASS_RESOURCES = CLASS_RESOURCES

-- Some Ascension/CoA FrameXML resources expose their real display name only
-- through the spell/aura itself. Keep def.name as a stable profile key, but
-- resolve the visible label from the client so custom class names stay exact.
local function SafeSpellName(spellID)
    if not spellID or not _G.GetSpellInfo then return nil end
    local ok, name = pcall(_G.GetSpellInfo, spellID)
    if ok and type(name) == "string" and name ~= "" then return name end
    return nil
end

local function GetDefinitionDisplayName(def)
    if not def then return "Resource" end
    if not def.dynamicName then return def.name or "Resource" end

    if def.kind == "FIRST_ACTIVE_AURA" then
        -- Prefer the aura that is currently active; otherwise use the first
        -- spell name available in the client DBC.
        for _, entry in ipairs(def.auras or {}) do
            local found = AuraByID(entry[1], entry[2])
            if found then
                local activeName = SafeSpellName(entry[1])
                if activeName then return activeName end
            end
        end
        for _, entry in ipairs(def.auras or {}) do
            local auraName = SafeSpellName(entry[1])
            if auraName then return auraName end
        end
    elseif def.kind == "SUNCLERIC" then
        local sunsetFound, sunset = AuraByID(def.sunsetSpellID, "HARMFUL")
        if sunsetFound and (tonumber(sunset) or 0) > 0 then
            return SafeSpellName(def.sunsetSpellID) or "Sunset"
        end
        return SafeSpellName(def.normalSpellID) or "Solar"
    elseif def.spellID then
        local spellName = SafeSpellName(def.spellID)
        if spellName then return spellName end
    end

    return def.name or "Resource"
end

function CCB:GetResourceEnableKey(class, def, index)
    class = class or GetClassToken() or "UNKNOWN"
    return class..":"..(def and def.name or tostring(index or 1))
end

function CCB:IsResourceEnabledByKey(key)
    -- Options.lua can query the fixed resource registry before this module's
    -- Initialize() has assigned self.db. In that early phase, treat every
    -- resource as enabled (the profile default) instead of indexing nil.
    local db = (E.db and E.db.coaResources) or self.db
    if not db then return true end
    db.enabledResources = db.enabledResources or {}
    local value = db.enabledResources[key]
    if value == nil then return true end
    return value == true
end

function CCB:IsFixedResourceEnabled(class, def, index)
    return self:IsResourceEnabledByKey(self:GetResourceEnableKey(class, def, index))
end

function CCB:GetAllKnownResources()
    local list = {}
    for class, defs in pairs(CLASS_RESOURCES) do
        for index, def in ipairs(defs) do
            insert(list, {
                class = class,
                name = GetDefinitionDisplayName(def) or ("Resource "..index),
                key = self:GetResourceEnableKey(class, def, index),
                mode = def.mode or "AUTO",
            })
        end
    end
    sort(list, function(a,b)
        if a.class == b.class then return a.name < b.name end
        return a.class < b.class
    end)
    return list
end

local function ResolveDefinition(def)
    if def.kind == "AURA" then
        local found, count = AuraByID(def.spellID, def.filter)
        local mx = def.max or SpellMax(def.maxSpellID or def.spellID, def.fallbackMax or 1)
        return found and count or 0, mx, true
    elseif def.kind == "FIRST_ACTIVE_AURA" then
        for _, entry in ipairs(def.auras or {}) do
            local found, count = AuraByID(entry[1], entry[2])
            if found then return count, def.max or SpellMax(entry[1], 10), true end
        end
        return 0, def.max or 10, true
    elseif def.kind == "TINKER_SCRAP" then
        local found, count = AuraByID(def.spellID, def.filter)
        local rawMax = SpellMax(def.spellID, 100)
        local mx = max(1, floor(rawMax / 10))
        local cur = floor((found and count or 0) / 10)
        return cur, mx, true, (found and count or 0), rawMax
    elseif def.kind == "NECRO_LIFEFORCE" then
        local _, visual = AuraByID(def.visualSpellID, "ANY")
        local foundCapacity, capacity = AuraByID(def.capacitySpellID, "ANY")
        local visualMax = SpellMax(def.visualSpellID, 0)
        local coreMax = SpellMax(def.capacitySpellID, 0)
        local mx = foundCapacity and capacity or max(visualMax, coreMax, 1)
        mx = min(48, max(1, mx))
        return min(mx, max(0, visual or 0)), mx, true
    elseif def.kind == "SUNCLERIC" then
        local sunsetFound, sunset = AuraByID(def.sunsetSpellID, "HARMFUL")
        if sunsetFound and sunset > 0 then
            return sunset, 5 + TalentRank(29182), true
        end
        local normalFound, normal = AuraByID(def.normalSpellID, "HELPFUL")
        return normalFound and normal or 0, SpellMax(def.normalSpellID, 5), true
    end
    return 0, 1, false
end

local function GetAlternativePowerResource()
    if not _G.UnitAlternativePower or not _G.UnitAlternativePowerType then return nil end
    local t = _G.UnitAlternativePowerType("player")
    if not t or t <= 0 then return nil end
    local cur = tonumber(_G.UnitAlternativePower("player")) or 0
    local mx, mode, name = 100, "BAR", "Custom Resource"
    if _G.GetCustomResourceInfo then
        local ok, info = pcall(_G.GetCustomResourceInfo, t)
        if ok and info then
            mx = tonumber(info.maxValue) or mx
            mode = info.type == "segmented" and "PIPS" or "BAR"
            name = info.tooltipTitle or name
            if type(name) == "string" then name = name:gsub(" %%d/%%d", "") end
        end
    end
    if _G.EnumUtil and _G.Enum and _G.Enum.CustomPowerType and _G.EnumUtil.ValueToString then
        local enumName = _G.EnumUtil.ValueToString(_G.Enum.CustomPowerType, t)
        if enumName then name = enumName end
    end
    return {key="ALT:"..t, settingKey="ALT:"..t, name=name, current=cur, max=mx, mode=mode, score=5000}
end

local function GetCustomPowerFallback()
    local out = {}
    if not UnitPower or not UnitPowerMax then return out end
    for id = 7, 31 do
        local ok1, cur = pcall(UnitPower, "player", id)
        local ok2, mx = pcall(UnitPowerMax, "player", id)
        cur, mx = ok1 and tonumber(cur) or 0, ok2 and tonumber(mx) or 0
        if mx and mx > 0 then
            insert(out, {key="POWER:"..id, settingKey="POWER:"..id, name="CoA Power "..id, current=cur or 0, max=mx, mode=(mx <= 12 and "PIPS" or "BAR"), score=1000})
        end
    end
    return out
end

function CCB:GetDetectedResources()
    local class = GetClassToken()
    local result, seen = {}, {}
    local function add(r)
        if not r or not r.key or seen[r.key] then return end
        seen[r.key] = true
        insert(result, r)
    end

    local defs = CLASS_RESOURCES[class]
    if defs and ClassResourceConditionMet(class) then
        for index, def in ipairs(defs) do
            local cur, mx, valid, rawCur, rawMax = ResolveDefinition(def)
            if valid and self:IsFixedResourceEnabled(class, def, index) and not (def.hideWhenZero and (tonumber(cur) or 0) <= 0) then
                add({
                    key="FIXED:"..class..":"..index,
                    settingKey=class..":"..(def.name or tostring(index)),
                    name=GetDefinitionDisplayName(def),
                    current=cur or 0,
                    max=mx or 1,
                    mode=def.mode,
                    allowOverMax=def.allowOverMax,
                    rawCurrent=rawCur,
                    rawMax=rawMax,
                    score=10000-index,
                })
            end
        end
    end

    -- Strict FrameXML whitelist mode:
    -- if a class has no fixed Ascension resource definition, show nothing.
    -- If a known resource is disabled in General, never replace it with Mana/Energy/Power IDs.
    if not defs then
        return result
    end

    sort(result, function(a,b) return (a.score or 0) > (b.score or 0) end)
    return result
end

local function CopyColor(c, fallback)
    local f = fallback or {r=1,g=1,b=1,a=1}
    c = c or f
    return {r=c.r or f.r or 1, g=c.g or f.g or 1, b=c.b or f.b or 1, a=(c.a ~= nil and c.a or f.a or 1)}
end

function CCB:GetResourceSettingKey(resource, index)
    if resource and resource.settingKey then return resource.settingKey end
    if resource and resource.key then return resource.key end
    return (GetClassToken() or "UNKNOWN")..":"..tostring(index or 1)
end

function CCB:GetResourceDB(resource, index)
    local db = self:RefreshDB() or self.db
    db.resourceSettings = db.resourceSettings or {}
    local key = self:GetResourceSettingKey(resource, index)
    local rdb = db.resourceSettings[key]
    if not rdb then
        local defaultYOffset = -((index or 1)-1) * ((db.height or 14) + (db.rowSpacing or 5) + (db.fontSize or 12) + 6)
        rdb = {
            enable = true,
            combatOnly = db.combatOnly == true,
            mode = resource and resource.mode or "AUTO",
            width = db.width or 220,
            height = db.height or 14,
            frameStrata = db.frameStrata or "LOW",
            frameLevel = db.frameLevel or 5,
            xOffset = 0,
            yOffset = defaultYOffset,
            spacing = db.spacing or 3,
            texture = db.texture or "Norm Tex",
            backgroundTexture = db.backgroundTexture or db.texture or "Norm Tex",
            useClassColor = false, -- legacy field retained for profile compatibility
            color = (function() local r,g,b=GetClassColor(); return {r=r,g=g,b=b,a=1} end)(),
            gradient = db.gradient == true,
            gradientColor = (function() local r,g,b=GetClassColor(); return {r=math.min(1,r*1.18+.06),g=math.min(1,g*1.18+.06),b=math.min(1,b*1.18+.06),a=1} end)(),
            background = CopyColor(db.background, {r=.08,g=.08,b=.08,a=.75}),
            transparent = db.transparent == true,
            showBorder = db.showBorder ~= false,
            borderColor = CopyColor(db.borderColor, {r=0,g=0,b=0,a=1}),
            showName = db.showResourceName ~= false,
            showValue = db.showText ~= false,
            font = db.font or "PT Sans Narrow",
            fontSize = db.fontSize or 12,
            fontOutline = db.fontOutline or "OUTLINE",
            textColor = CopyColor(db.textColor, {r=1,g=1,b=1}),
            textPosition = "ABOVE",
            valueFormat = "CURRENT_MAX",
            nameAlign = "LEFT",
            valueAlign = "RIGHT",
            nameX = 0,
            nameY = 0,
            valueX = 0,
            valueY = 0,
        }
        db.resourceSettings[key] = rdb
    end
    -- Forward-fill fields added in later versions without overwriting user choices.
    if rdb.enable == nil then rdb.enable = true end
    if rdb.combatOnly == nil then rdb.combatOnly = db.combatOnly == true end
    if not rdb.mode then rdb.mode = resource and resource.mode or "AUTO" end
    if not rdb.width then rdb.width = db.width or 220 end
    if not rdb.height then rdb.height = db.height or 14 end
    if not rdb.frameStrata then rdb.frameStrata = db.frameStrata or "LOW" end
    if rdb.frameLevel == nil then rdb.frameLevel = db.frameLevel or 5 end
    if rdb.xOffset == nil then rdb.xOffset = 0 end
    if rdb.yOffset == nil then rdb.yOffset = -((index or 1)-1) * ((rdb.height or 14) + (db.rowSpacing or 5) + (rdb.fontSize or 12) + 6) end
    if rdb.spacing == nil then rdb.spacing = db.spacing or 3 end
    if not rdb.texture then rdb.texture = db.texture or "Norm Tex" end
    if not rdb.backgroundTexture then rdb.backgroundTexture = db.backgroundTexture or rdb.texture or db.texture or "Norm Tex" end
    -- One-time migration: old profiles used a "Use CoA Class Color" toggle.
    -- Store that class color as the editable Base Color so disabling Gradient stays visually identical.
    if not rdb.baseColorMigrated then
        if rdb.useClassColor ~= false then
            local cr,cg,cb = GetClassColor()
            rdb.color = {r=cr,g=cg,b=cb,a=1}
        elseif not rdb.color then
            rdb.color = CopyColor(db.color, {r=.10,g=.65,b=1})
        end
        rdb.useClassColor = false
        rdb.baseColorMigrated = true
    elseif not rdb.color then
        local cr,cg,cb = GetClassColor()
        rdb.color = {r=cr,g=cg,b=cb,a=1}
    end
    if rdb.gradient == nil then rdb.gradient = false end
    if not rdb.gradientColor then
        local cr,cg,cb = GetClassColor()
        rdb.gradientColor = {r=math.min(1,cr*1.18+.06),g=math.min(1,cg*1.18+.06),b=math.min(1,cb*1.18+.06),a=1}
    end
    if not rdb.background then rdb.background = CopyColor(db.background, {r=.08,g=.08,b=.08,a=.75}) end
    if rdb.transparent == nil then rdb.transparent = db.transparent == true end
    if rdb.showBorder == nil then rdb.showBorder = db.showBorder ~= false end
    if not rdb.borderColor then rdb.borderColor = CopyColor(db.borderColor, {r=0,g=0,b=0,a=1}) end
    if rdb.showName == nil then rdb.showName = db.showResourceName ~= false end
    if rdb.showValue == nil then rdb.showValue = db.showText ~= false end
    if not rdb.font then rdb.font = db.font or "PT Sans Narrow" end
    if not rdb.fontSize then rdb.fontSize = db.fontSize or 12 end
    if not rdb.fontOutline then rdb.fontOutline = db.fontOutline or "OUTLINE" end
    if not rdb.textColor then rdb.textColor = CopyColor(db.textColor, {r=1,g=1,b=1}) end
    if not rdb.textPosition then rdb.textPosition = "ABOVE" end
    if not rdb.valueFormat then rdb.valueFormat = "CURRENT_MAX" end
    -- migrate old shared text offsets to the new independent offsets
    if not rdb.nameAlign then rdb.nameAlign = "LEFT" end
    if not rdb.valueAlign then rdb.valueAlign = "RIGHT" end
    if rdb.nameX == nil then rdb.nameX = rdb.textX or 0 end
    if rdb.nameY == nil then rdb.nameY = rdb.textY or 0 end
    if rdb.valueX == nil then rdb.valueX = rdb.textX or 0 end
    if rdb.valueY == nil then rdb.valueY = rdb.textY or 0 end
    return rdb, key
end

function CCB:GetFixedResourceEntries()
    local class = GetClassToken()
    local defs = CLASS_RESOURCES[class] or {}
    local out = {}
    for i, def in ipairs(defs) do
        if self:IsFixedResourceEnabled(class, def, i) then
            insert(out, {
                key="FIXED:"..class..":"..i,
                settingKey=class..":"..(def.name or tostring(i)),
                name=GetDefinitionDisplayName(def) or ("Resource "..i),
                mode=def.mode or "AUTO",
            })
        end
    end
    return out
end

function CCB:CreateFrames()
    if self.holder then return end
    local holder = CreateFrame("Frame", "ElvUI_CoAResourcesHolder", E.UIParent)
    holder:SetSize(1,1)
    holder:SetPoint("CENTER", E.UIParent, "CENTER", 0, -180)
    self.holder = holder
    self.rows = {}
    self.resourceAnchors = self.resourceAnchors or {}
    for rowIndex = 1, 8 do
        local row = CreateFrame("Frame", nil, E.UIParent)
        row:SetSize(220,14)
        row:Hide()
        row.pips = {}
        for i = 1, 48 do
            local p = CreateFrame("StatusBar", nil, row)
            p:SetMinMaxValues(0,1)
            p:SetValue(1)
            p:CreateBackdrop("Default")
            p.bg = p:CreateTexture(nil,"BORDER")
            p.bg:SetAllPoints(p)
            p:Hide()
            row.pips[i] = p
        end
        row.bar = CreateFrame("StatusBar", nil, row)
        row.bar:SetAllPoints(row)
        row.bar:CreateBackdrop("Default")
        row.bar.bg = row.bar:CreateTexture(nil,"BORDER")
        row.bar.bg:SetAllPoints(row.bar)
        row.bar:Hide()

        -- Dedicated text overlay. StatusBar fill textures are rendered by child frames and
        -- can otherwise cover FontStrings parented directly to the row. Keep all resource
        -- text on a higher frame level, like ElvUI unitframe health/power text.
        row.textOverlay = CreateFrame("Frame", nil, row)
        row.textOverlay:SetAllPoints(row)
        row.textOverlay:SetFrameStrata(row:GetFrameStrata())
        row.textOverlay:SetFrameLevel(row:GetFrameLevel() + 20)
        if row.textOverlay.EnableMouse then row.textOverlay:EnableMouse(false) end

        row.nameText = row.textOverlay:CreateFontString(nil,"OVERLAY")
        row.nameText:SetJustifyH("LEFT")
        row.valueText = row.textOverlay:CreateFontString(nil,"OVERLAY")
        row.valueText:SetJustifyH("RIGHT")
        self.rows[rowIndex] = row
    end
end

local function SafeMoverToken(key)
    key = tostring(key or "Resource")
    return (key:gsub("[^%w_]", "_"))
end

function CCB:GetResourceAnchor(resource, index, width, height)
    self.resourceAnchors = self.resourceAnchors or {}
    local key = self:GetResourceSettingKey(resource, index)
    local anchor = self.resourceAnchors[key]
    if not anchor then
        local token = SafeMoverToken(key)
        anchor = CreateFrame("Frame", "ElvUI_CoAResourcesAnchor_"..token, E.UIParent)
        anchor:SetSize(width or 220, height or 14)
        anchor:SetPoint("CENTER", E.UIParent, "CENTER", 0, -180 - ((index or 1)-1)*28)
        self.resourceAnchors[key] = anchor
        if E.CreateMover then
            E:CreateMover(anchor, "ElvUI_CoAResourcesMover_"..token, "CoA Class Bars - "..tostring(resource and resource.name or key), nil, nil, nil, "ALL,SOLO")
        end
    end
    anchor:SetSize(width or 220, height or 14)
    return anchor
end

local function ApplyResourceFont(fontString, font, size, outline)
    if not fontString then return end

    local shadowOutline = outline == "SHADOWOUTLINE"
    fontString:SetFont(font, size, shadowOutline and "OUTLINE" or outline)

    if shadowOutline then
        fontString:SetShadowColor(0, 0, 0, 1)
        fontString:SetShadowOffset(1, -1)
    else
        fontString:SetShadowColor(0, 0, 0, 0)
        fontString:SetShadowOffset(0, 0)
    end
end

local function ApplyBorder(frame, rdb)
    if not frame or not frame.backdrop then return end

    -- The resource bars already have their own background texture (frame.bg).
    -- ElvUI's CreateBackdrop("Default") also creates a filled backdrop behind it.
    -- Keep that backdrop fill permanently transparent so it is border-only;
    -- otherwise enabling Transparent merely reveals the ElvUI backdrop and makes
    -- the bar look brighter instead of actually transparent.
    if frame.backdrop.SetBackdropColor then
        frame.backdrop:SetBackdropColor(0, 0, 0, 0)
    end

    local c = rdb.borderColor or {r=0,g=0,b=0,a=1}
    if frame.backdrop.SetBackdropBorderColor then
        frame.backdrop:SetBackdropBorderColor(c.r or 0, c.g or 0, c.b or 0, rdb.showBorder and (c.a or 1) or 0)
    end
end

function CCB:ApplyMedia(row, rdb)
    local texture = (LSM and LSM:Fetch("statusbar", rdb.texture)) or E.media.normTex or E.media.blankTex
    local backgroundTexture = (LSM and LSM:Fetch("statusbar", rdb.backgroundTexture or rdb.texture)) or texture or E.media.normTex or E.media.blankTex
    local font = (LSM and LSM:Fetch("font", rdb.font)) or E.media.normFont
    local r,g,b = rdb.color.r,rdb.color.g,rdb.color.b
    local gr,gg,gb = rdb.gradientColor.r,rdb.gradientColor.g,rdb.gradientColor.b
    local br,bg,bb,ba = rdb.background.r,rdb.background.g,rdb.background.b,rdb.background.a or .75

    row.bar:SetFrameLevel(row:GetFrameLevel() + 1)
    if row.textOverlay then row.textOverlay:SetFrameLevel(row:GetFrameLevel() + 20) end
    row.bar:SetStatusBarTexture(texture)
    if rdb.gradient and row.bar:GetStatusBarTexture() and row.bar:GetStatusBarTexture().SetGradientAlpha then
        row.bar:SetStatusBarColor(1,1,1,1)
        row.bar:GetStatusBarTexture():SetGradientAlpha("HORIZONTAL", r,g,b,1, gr,gg,gb,1)
    else
        row.bar:SetStatusBarColor(r,g,b)
    end
    row.bar.bg:SetTexture(backgroundTexture)
    row.bar.bg:SetVertexColor(br,bg,bb,rdb.transparent and 0 or ba)
    ApplyBorder(row.bar, rdb)

    for _,p in ipairs(row.pips) do
        p:SetFrameLevel(row:GetFrameLevel() + 1)
        p:SetStatusBarTexture(texture)
        if rdb.gradient and p:GetStatusBarTexture() and p:GetStatusBarTexture().SetGradientAlpha then
            p:SetStatusBarColor(1,1,1,1)
            p:GetStatusBarTexture():SetGradientAlpha("HORIZONTAL", r,g,b,1, gr,gg,gb,1)
        else
            p:SetStatusBarColor(r,g,b)
        end
        p.bg:SetTexture(backgroundTexture)
        p.bg:SetVertexColor(br,bg,bb,rdb.transparent and 0 or ba)
        ApplyBorder(p, rdb)
    end

    ApplyResourceFont(row.nameText, font, rdb.fontSize or 12, rdb.fontOutline or "OUTLINE")
    ApplyResourceFont(row.valueText, font, rdb.fontSize or 12, rdb.fontOutline or "OUTLINE")
    row.nameText:SetTextColor(rdb.textColor.r, rdb.textColor.g, rdb.textColor.b)
    row.valueText:SetTextColor(rdb.textColor.r, rdb.textColor.g, rdb.textColor.b)

    row.nameText:ClearAllPoints()
    row.valueText:ClearAllPoints()
    local position = rdb.textPosition or "ABOVE"
    local nameAlign = rdb.nameAlign or "LEFT"
    local valueAlign = rdb.valueAlign or "RIGHT"
    local nameX, nameY = rdb.nameX or 0, rdb.nameY or 0
    local valueX, valueY = rdb.valueX or 0, rdb.valueY or 0

    local function SetTextAnchor(fs, align, x, y)
        align = align or "CENTER"
        if align ~= "LEFT" and align ~= "RIGHT" then align = "CENTER" end
        fs:SetJustifyH(align)
        if position == "OVERLAY" then
            if align == "LEFT" then
                fs:SetPoint("LEFT", row, "LEFT", 4 + x, y)
            elseif align == "RIGHT" then
                fs:SetPoint("RIGHT", row, "RIGHT", -4 + x, y)
            else
                fs:SetPoint("CENTER", row, "CENTER", x, y)
            end
        elseif position == "BELOW" then
            if align == "LEFT" then
                fs:SetPoint("TOPLEFT", row, "BOTTOMLEFT", x, -2 + y)
            elseif align == "RIGHT" then
                fs:SetPoint("TOPRIGHT", row, "BOTTOMRIGHT", x, -2 + y)
            else
                fs:SetPoint("TOP", row, "BOTTOM", x, -2 + y)
            end
        else
            if align == "LEFT" then
                fs:SetPoint("BOTTOMLEFT", row, "TOPLEFT", x, 2 + y)
            elseif align == "RIGHT" then
                fs:SetPoint("BOTTOMRIGHT", row, "TOPRIGHT", x, 2 + y)
            else
                fs:SetPoint("BOTTOM", row, "TOP", x, 2 + y)
            end
        end
    end

    SetTextAnchor(row.nameText, nameAlign, nameX, nameY)
    SetTextAnchor(row.valueText, valueAlign, valueX, valueY)

end

function CCB:LayoutRow(row, count, rdb)
    count = min(max(count or 1,1), #row.pips)
    local spacing,width,height = rdb.spacing or 3, rdb.width or 220, rdb.height or 14
    local each = (width - ((count-1)*spacing)) / count
    row:SetSize(width,height)
    for i,p in ipairs(row.pips) do
        p:ClearAllPoints()
        if i <= count then
            p:SetSize(each,height)
            if i == 1 then p:SetPoint("LEFT",row,"LEFT",0,0) else p:SetPoint("LEFT",row.pips[i-1],"RIGHT",spacing,0) end
        end
    end
end

-- E.db is replaced by a new table whenever the profile changes (E:UpdateAll). Never keep using
-- a cached table from the previous profile: re-resolve it before every use.
function CCB:RefreshDB()
    local cur = E.db and E.db.coaResources
    if not cur and E.db then
        E.db.coaResources = E:CopyTable({}, P.coaResources)
        cur = E.db.coaResources
    end
    if cur then
        if cur ~= self.db then
            self.db = cur
            self.originalFrameStates = self.originalFrameStates or {}
        end
        cur.detectedAuras = cur.detectedAuras or {}
        cur.resourceSettings = cur.resourceSettings or {}
        cur.enabledResources = cur.enabledResources or {}
    end
    return self.db
end

function CCB:Update()
    self:RefreshDB()
    if not self.holder or not self.db then return end
    if not self.db.enable then
        for _, row in ipairs(self.rows or {}) do row:Hide() end
        return
    end
    local resources = self:GetDetectedResources()
    if #resources == 0 then
        for _, row in ipairs(self.rows or {}) do row:Hide() end
        return
    end

    local anyShown = false
    local inCombat = UnitAffectingCombat("player") and true or false
    for i,row in ipairs(self.rows) do
        local resource = resources[i]
        row:ClearAllPoints()
        if resource then
            local rdb = self:GetResourceDB(resource, i)
            if rdb.enable and rdb.combatOnly and not inCombat then
                -- "Only in combat" is set for this resource: hide the bar but keep its mover anchor
                row:Hide()
                row.nameText:Hide()
                row.valueText:Hide()
            elseif rdb.enable then
                anyShown = true
                local width, height = rdb.width or 220, rdb.height or 14
                local anchor = self:GetResourceAnchor(resource, i, width, height)
                anchor:Show()
                row:SetPoint("CENTER", anchor, "CENTER", 0, 0)
                row:SetSize(width,height)

                -- Keep CoA resources below fullscreen/map UI by default while allowing
                -- each resource to override its own draw layer.
                local strata = rdb.frameStrata or "LOW"
                local level = tonumber(rdb.frameLevel) or 5
                anchor:SetFrameStrata(strata)
                anchor:SetFrameLevel(level)
                row:SetFrameStrata(strata)
                row:SetFrameLevel(level)
                if row.textOverlay then
                    row.textOverlay:SetFrameStrata(strata)
                    row.textOverlay:SetFrameLevel(level + 20)
                end

                row:Show()
                self:ApplyMedia(row, rdb)

                local cur, mx = tonumber(resource.current) or 0, max(1, tonumber(resource.max) or 1)
                local mode = rdb.mode or resource.mode or "AUTO"
                if mode == "AUTO" then mode = (mx <= (self.db.maxPips or 12)) and "PIPS" or "BAR" end

                if mode == "PIPS" and mx <= #row.pips then
                    row.bar:Hide()
                    local count = min(max(floor(mx + .5),1), #row.pips)
                    self:LayoutRow(row,count,rdb)
                    for pidx,p in ipairs(row.pips) do
                        if pidx <= count then
                            p:Show()
                            p:SetAlpha(1)
                            p:SetValue(pidx <= cur and 1 or 0)
                        else p:Hide() end
                    end
                else
                    for _,p in ipairs(row.pips) do p:Hide() end
                    row.bar:Show()
                    row.bar:SetMinMaxValues(0,mx)
                    row.bar:SetValue(resource.allowOverMax and min(cur,mx) or cur)
                end

                local displayCur = resource.rawCurrent and tonumber(resource.rawCurrent) or cur
                local displayMax = resource.rawMax and tonumber(resource.rawMax) or mx
                local valueText = ""
                if (rdb.valueFormat or "CURRENT_MAX") == "CURRENT" then
                    valueText = tostring(floor(displayCur + .5))
                elseif rdb.valueFormat == "PERCENT" then
                    local pct = displayMax > 0 and (displayCur / displayMax * 100) or 0
                    valueText = tostring(floor(pct + .5)).."%"
                else
                    valueText = floor(displayCur + .5).." / "..floor(displayMax + .5)
                end

                row.nameText:SetJustifyH(rdb.nameAlign or "LEFT")
                row.valueText:SetJustifyH(rdb.valueAlign or "RIGHT")
                if rdb.showName then
                    row.nameText:SetText(resource.name or "Resource")
                    row.nameText:Show()
                else
                    row.nameText:Hide()
                end
                if rdb.showValue then
                    row.valueText:SetText(valueText)
                    row.valueText:Show()
                else
                    row.valueText:Hide()
                end
            else
                row:Hide()
                row.nameText:Hide()
                row.valueText:Hide()
                local key = self:GetResourceSettingKey(resource, i)
                if self.resourceAnchors and self.resourceAnchors[key] then self.resourceAnchors[key]:Hide() end
            end
        else
            row:Hide()
            row.nameText:Hide()
            row.valueText:Hide()
        end
    end

    if anyShown then self.holder:Show() else self.holder:Hide() end
end

function CCB:DebugResources()
    local class = GetClassToken()
    E:Print("CoA Class Bars - "..tostring(class))
    local list = self:GetDetectedResources()
    if #list == 0 then E:Print("No enabled custom class resource is registered for this class."); return end
    for i,r in ipairs(list) do
        E:Print(format("%d. %s [%s] %s/%s mode=%s", i, tostring(r.name), tostring(r.key), tostring(r.current), tostring(r.max), tostring(r.mode or "AUTO")))
    end
end

function CCB:ResetAuraLearning()
    self.db.detectedAuras = {}
    E:Print("CoA Class Bars: fallback learning cache cleared.")
    self:Update()
end

local ORIGINAL_RESOURCE_FRAMES = {
    "CoAResourceBar",
    "CoAResourceSegmentBar",
    "CoAResourceOrb",
    "CustomResourceContainer",
}

function CCB:ApplyOriginalFrameVisibility()
    if not self.db then return end
    local hide = self.db.hideOriginalFrames == true
    self.originalFrameStates = self.originalFrameStates or {}

    for _, frameName in ipairs(ORIGINAL_RESOURCE_FRAMES) do
        local frame = _G[frameName]
        if frame then
            if not frame.__ElvUICoAResourcesHideHooked and hooksecurefunc then
                frame.__ElvUICoAResourcesHideHooked = true
                hooksecurefunc(frame, "Show", function(f)
                    if CCB.db and CCB.db.hideOriginalFrames then
                        f:Hide()
                    end
                end)
            end

            if hide then
                if self.originalFrameStates[frameName] == nil then
                    self.originalFrameStates[frameName] = frame:IsShown() and true or false
                end
                frame:Hide()
            else
                local wasShown = self.originalFrameStates[frameName]
                self.originalFrameStates[frameName] = nil
                if wasShown then
                    frame:Show()
                elseif frame.Update then
                    pcall(frame.Update, frame, true)
                end
            end
        end
    end
end

function CCB:SlashCommand(msg)
    msg = string.lower(msg or "")
    if msg == "debug" then self:DebugResources()
    elseif msg == "toggle" then self.db.enable = not self.db.enable; self:Update()
    elseif msg == "resetlearn" then self:ResetAuraLearning()
    else
        E:Print("/coabars debug - show exact detected resources")
        E:Print("/coabars toggle - enable/disable CoA Class Bars")
        E:Print("/coabars resetlearn - clear learned cache")
    end
end

function CCB:ProfileChanged()
    self.db = nil
    self:RefreshDB()
    if not self.db then return end
    -- the new profile may have other positions: re-anchor existing mover anchors, then redraw
    if E.SetMoversPositions then pcall(E.SetMoversPositions, E) end
    self:ApplyOriginalFrameVisibility()
    self:Update()
    -- ElvUI finishes its own profile update afterwards; redraw once more shortly after
    if E.Delay then E:Delay(0.5, function() CCB:Update() end) end
end

function CCB:Initialize()
    -- Migrate settings from the previous CoA Class Bars profile key once.
    if not E.db.coaResources and E.db.coaClassBars then
        E.db.coaResources = E:CopyTable({}, E.db.coaClassBars)
    end
    if not E.db.coaResources then E.db.coaResources = P.coaResources end
    self.db = E.db.coaResources
    self.db.detectedAuras = self.db.detectedAuras or {}
    self.db.resourceSettings = self.db.resourceSettings or {}
    self.db.enabledResources = self.db.enabledResources or {}
    self:CreateFrames()
    self:ApplyOriginalFrameVisibility()
    self:RegisterEvent("PLAYER_ENTERING_WORLD","Update")
    self:RegisterEvent("PLAYER_TARGET_CHANGED","Update")
    self:RegisterEvent("UNIT_POWER","Update")
    self:RegisterEvent("UNIT_POWER_UPDATE","Update")
    self:RegisterEvent("UNIT_POWER_ALTERNATIVE_UPDATE","Update")
    self:RegisterEvent("UNIT_MAXPOWER","Update")
    self:RegisterEvent("UNIT_AURA","Update")
    self:RegisterEvent("SPELLS_CHANGED","Update")
    -- Ascension fires these when learned spells / Character Advancement change.
    pcall(function() self:RegisterEvent("ASCENSION_SPELLS_UPDATED","Update") end)
    pcall(function() self:RegisterEvent("CHARACTER_ADVANCEMENT_PENDING_BUILD_UPDATED","Update") end)
    self:RegisterEvent("PLAYER_LEVEL_UP","Update")
    self:RegisterEvent("PLAYER_REGEN_DISABLED","Update")
    self:RegisterEvent("PLAYER_REGEN_ENABLED","Update")
    self:RegisterEvent("UPDATE_SHAPESHIFT_FORM","Update")
    -- E.db is just the profile table; the AceDB object that fires profile callbacks is E.data
    local dbObj = E.data
    if dbObj and dbObj.RegisterCallback then
        dbObj.RegisterCallback(CCB,"OnProfileChanged","ProfileChanged")
        dbObj.RegisterCallback(CCB,"OnProfileCopied","ProfileChanged")
        dbObj.RegisterCallback(CCB,"OnProfileReset","ProfileChanged")
    end
    -- also follow ElvUI's own full refresh (also covers resets/imports that bypass the AceDB callbacks)
    if E.UpdateAll and hooksecurefunc then
        hooksecurefunc(E, "UpdateAll", function() CCB:ProfileChanged() end)
    end
    SLASH_COACLASSBARS1 = "/coabars"
    SlashCmdList.COACLASSBARS = function(msg) CCB:SlashCommand(msg) end
    self.elapsed = 0
    self.holder:SetScript("OnUpdate", function(_, elapsed)
        CCB.elapsed = (CCB.elapsed or 0) + elapsed
        if CCB.elapsed >= .20 then
            CCB.elapsed = 0
            if CCB.db then
                CCB:ApplyOriginalFrameVisibility()
                if CCB.db.autoDetect then CCB:Update() end
            end
        end
    end)
    self:Update()
end

E:RegisterModule(CCB:GetName())
