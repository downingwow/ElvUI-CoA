local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local DT = E:GetModule("DataTexts")

--[[
	Travel statistics datatexts
	  - Jumps            (character / account)
	  - Distance in km   (character / account)
	  - Distance in mi   (character / account)  <- the "American" value

	Counted: own movement only (walking, running, swimming, mounted, flying on your own mount).
	Not counted: flight paths (taxi) and vehicles.

	Storage (the stats cannot be reconstructed for the past, counting starts with this version):
	  character: ElvCharacterDB.travelStats = { jumps, yards }
	  account:   ElvDB.__travelStats        = { jumps, yards }   (ElvDB root, like __coaGlobalProfile)
	           plus acc.chars["Name-Realm"] = { jumps, yards, class } for the per-character tooltip breakdown
]]

--Lua functions
local _G = _G
local type, tostring, tonumber, ipairs = type, tostring, tonumber, ipairs
local floor = math.floor
local format, gsub, reverse = string.format, string.gsub, string.reverse
--WoW API / Variables
local CreateFrame = CreateFrame
local GetLocale = GetLocale
local GetPlayerMapPosition = GetPlayerMapPosition
local GetUnitSpeed = GetUnitSpeed
local IsFalling, IsFlying, IsSwimming = IsFalling, IsFlying, IsSwimming
local UnitInVehicle, UnitOnTaxi = UnitInVehicle, UnitOnTaxi
local hooksecurefunc = hooksecurefunc
local UnitName, GetRealmName, UnitClass = UnitName, GetRealmName, UnitClass
local pairs, sort, tinsert = pairs, table.sort, table.insert

local isDE = false -- texts are English-only; number format below still follows the client locale
local isDELocale = GetLocale() == "deDE"
local YARDS_TO_KM = 0.0009144
local YARDS_TO_MI = 1 / 1760

local TXT = {
	char = isDE and "Charakter" or "Character",
	acc = isDE and "Account" or "Account",
	shortChar = "Char",
	shortAcc = "Acc",
	jumps = isDE and "Sprünge" or "Jumps",
	distance = isDE and "Strecke" or "Distance",
	title = isDE and "Reisestatistik" or "Travel statistics",
	own = isDE and "Nur selbst zurückgelegt (keine Flugpunkte / Fahrzeuge)" or "Own movement only (no flight paths / vehicles)",
}

----------------------------------------------------------------------------------------------------
-- Storage
----------------------------------------------------------------------------------------------------
local function GetStore(root, key)
	if type(root) ~= "table" then return end
	local t = root[key]
	if type(t) ~= "table" then
		t = {}
		root[key] = t
	end
	t.jumps = tonumber(t.jumps) or 0
	t.yards = tonumber(t.yards) or 0
	return t
end

local function GetStores()
	return GetStore(_G.ElvCharacterDB, "travelStats"), GetStore(_G.ElvDB, "__travelStats")
end

-- per-character entry inside the account store (for the account tooltip breakdown)
local function GetCharKey()
	local n, r = UnitName("player"), GetRealmName()
	if not n then return end
	return n .. "-" .. (r or "")
end

local function GetCharEntry(char, acc)
	if not acc then return end
	local key = GetCharKey()
	if not key then return end
	if type(acc.chars) ~= "table" then acc.chars = {} end
	local e = acc.chars[key]
	if type(e) ~= "table" then
		e = {jumps = 0, yards = 0}
		-- counted before the breakdown existed: take over the character total
		if char then e.jumps, e.yards = char.jumps, char.yards end
		acc.chars[key] = e
	end
	e.jumps = tonumber(e.jumps) or 0
	e.yards = tonumber(e.yards) or 0
	if not e.class then
		local _, token = UnitClass("player")
		e.class = token
	end
	return e
end

----------------------------------------------------------------------------------------------------
-- Tracking
----------------------------------------------------------------------------------------------------
local function IsOwnMovement()
	return not (UnitOnTaxi("player") or UnitInVehicle("player"))
end

-- jumps: JumpOrAscendStart is what the jump key (and the default binding) calls
if _G.JumpOrAscendStart then
	hooksecurefunc("JumpOrAscendStart", function()
		-- only real jumps: not ascending while flying / swimming, not a repeated press in mid-air
		if IsFlying() or IsSwimming() or IsFalling() or not IsOwnMovement() then return end

		local char, acc = GetStores()
		local entry = GetCharEntry(char, acc)
		if char then char.jumps = char.jumps + 1 end
		if acc then acc.jumps = acc.jumps + 1 end
		if entry then entry.jumps = entry.jumps + 1 end
	end)
end

-- distance: integrate the current movement speed (yards / second)
local tracker = CreateFrame("Frame")
local sum, lastX, lastY = 0, 0, 0
tracker:SetScript("OnUpdate", function(_, elapsed)
	sum = sum + elapsed
	if sum < 0.25 then return end
	local dt = sum
	sum = 0

	if dt > 1 then -- loading screen / hitch
		lastX, lastY = 0, 0
		return
	end

	if not IsOwnMovement() then
		lastX, lastY = 0, 0
		return
	end

	-- running against a wall reports speed but the position does not change
	local x, y = GetPlayerMapPosition("player")
	local still = false
	if x ~= 0 or y ~= 0 then
		still = (x == lastX and y == lastY)
		lastX, lastY = x, y
	else
		lastX, lastY = 0, 0 -- no map position (instance, other map open): trust the speed
	end
	if still then return end

	local speed = GetUnitSpeed and GetUnitSpeed("player")
	if not speed or speed <= 0 then return end

	local char, acc = GetStores()
	local yards = speed * dt
	local entry = GetCharEntry(char, acc)
	if char then char.yards = char.yards + yards end
	if acc then acc.yards = acc.yards + yards end
	if entry then entry.yards = entry.yards + yards end
end)

----------------------------------------------------------------------------------------------------
-- Formatting
----------------------------------------------------------------------------------------------------
local thousands = isDELocale and "." or ","
local decimal = isDELocale and "," or "."

local function FormatInt(n)
	local s = tostring(floor((n or 0) + 0.5))
	local out = reverse(gsub(reverse(s), "(%d%d%d)", "%1" .. thousands))
	if out:sub(1, 1) == thousands then out = out:sub(2) end
	return out
end

local function FormatDist(value)
	local int = floor(value)
	local frac = floor((value - int) * 100 + 0.5)
	if frac >= 100 then int, frac = int + 1, 0 end
	return format("%s%s%02d", FormatInt(int), decimal, frac)
end

local function GetValue(store, kind)
	if not store then return 0 end
	if kind == "jumps" then return store.jumps end
	if kind == "km" then return store.yards * YARDS_TO_KM end
	return store.yards * YARDS_TO_MI
end

local function FormatValue(store, kind)
	local v = GetValue(store, kind)
	if kind == "jumps" then
		return FormatInt(v)
	elseif kind == "km" then
		return FormatDist(v) .. " km"
	end
	return FormatDist(v) .. " mi"
end

----------------------------------------------------------------------------------------------------
-- Datatexts
----------------------------------------------------------------------------------------------------
local function AddBreakdown(acc, kind)
	if not acc or type(acc.chars) ~= "table" then return end

	local list, sumJ, sumY = {}, 0, 0
	for key, e in pairs(acc.chars) do
		if type(e) == "table" then
			local j, y = tonumber(e.jumps) or 0, tonumber(e.yards) or 0
			sumJ, sumY = sumJ + j, sumY + y
			list[#list + 1] = {name = (gsub(key, "%-.*$", "")), jumps = j, yards = y, class = e.class}
		end
	end

	-- not attributable to a character (counted before the breakdown existed)
	local restJ, restY = acc.jumps - sumJ, acc.yards - sumY
	if restJ > 0.5 or restY > 0.5 then
		list[#list + 1] = {name = isDE and "Unzugeordnet" or "Unassigned", jumps = restJ, yards = restY, rest = true}
	end
	if #list == 0 then return end

	local field = kind == "jumps" and "jumps" or "yards"
	sort(list, function(a, b)
		if a[field] ~= b[field] then return a[field] > b[field] end
		return a.name < b.name
	end)

	DT.tooltip:AddLine(isDE and "Pro Charakter" or "Per character", 0.4, 0.8, 1)
	for _, e in ipairs(list) do
		local r, g, b = 1, 1, 1
		local c = e.class and _G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[e.class]
		if c then r, g, b = c.r, c.g, c.b elseif e.rest then r, g, b = 0.6, 0.6, 0.6 end

		local value
		if kind == "jumps" then
			value = FormatInt(e.jumps)
		elseif kind == "km" then
			value = FormatDist(e.yards * YARDS_TO_KM) .. " km"
		else
			value = FormatDist(e.yards * YARDS_TO_MI) .. " mi"
		end
		DT.tooltip:AddDoubleLine(e.name, value, r, g, b, 1, 1, 1)
	end
	DT.tooltip:AddLine(" ")
end

local function OnEnter(self, kind)
	DT:SetupTooltip(self)

	local char, acc = GetStores()
	DT.tooltip:AddLine(TXT.title)
	DT.tooltip:AddLine(" ")

	DT.tooltip:AddLine(TXT.char, 0.4, 0.8, 1)
	DT.tooltip:AddDoubleLine(TXT.jumps, FormatValue(char, "jumps"), 1, 1, 1, 1, 1, 1)
	DT.tooltip:AddDoubleLine(TXT.distance .. " (km)", FormatValue(char, "km"), 1, 1, 1, 1, 1, 1)
	DT.tooltip:AddDoubleLine(TXT.distance .. " (mi)", FormatValue(char, "mi"), 1, 1, 1, 1, 1, 1)
	DT.tooltip:AddLine(" ")

	DT.tooltip:AddLine(TXT.acc, 0.4, 0.8, 1)
	DT.tooltip:AddDoubleLine(TXT.jumps, FormatValue(acc, "jumps"), 1, 1, 1, 1, 1, 1)
	DT.tooltip:AddDoubleLine(TXT.distance .. " (km)", FormatValue(acc, "km"), 1, 1, 1, 1, 1, 1)
	DT.tooltip:AddDoubleLine(TXT.distance .. " (mi)", FormatValue(acc, "mi"), 1, 1, 1, 1, 1, 1)
	DT.tooltip:AddLine(" ")

	AddBreakdown(acc, kind)

	DT.tooltip:AddLine(TXT.own, 0.6, 0.6, 0.6)
	DT.tooltip:Show()
end

-- short form for narrow panels: 1234567 -> 1.2M, 12.34 km -> 12.3 km / 1234 km
local function FormatCompact(store, kind)
	local v = GetValue(store, kind)
	if kind == "jumps" then
		if v >= 1000000 then return format("%.1fM", v / 1000000) end
		if v >= 10000 then return format("%.0fk", v / 1000) end
		if v >= 1000 then return format("%.1fk", v / 1000) end
		return format("%d", v)
	end
	local unit = kind == "km" and " km" or " mi"
	if v >= 1000 then return format("%.0f%s", v, unit) end
	if v >= 100 then return format("%.0f%s", v, unit) end
	return format("%.1f%s", v, unit)
end

----------------------------------------------------------------------------------------------------
-- API for the options tab (ElvUI_OptionsUI/DataTexts.lua): custom labels + character list
----------------------------------------------------------------------------------------------------
local API = {rev = 0}
DT.TravelStats = API

-- label keys: jumps_char, jumps_acc, dist_char, dist_acc  (km and mi share the "dist" label)
function API.DefaultLabel(key)
	if key == "speed" then return "Speed" end
	local kind, scope = key:match("^(%a+)_(%a+)$")
	return (kind == "jumps" and TXT.jumps or TXT.distance) .. " " .. (scope == "char" and TXT.shortChar or TXT.shortAcc)
end

function API.GetLabel(key)
	local _, acc = GetStores()
	local custom = acc and type(acc.labels) == "table" and acc.labels[key]
	if type(custom) == "string" and custom ~= "" then return custom, true end
	return API.DefaultLabel(key), false
end

function API.SetLabel(key, text)
	local _, acc = GetStores()
	if not acc then return end
	if type(acc.labels) ~= "table" then acc.labels = {} end
	text = text and gsub(gsub(text, "^%s+", ""), "%s+$", "") or ""
	if text == "" or text == API.DefaultLabel(key) then text = nil end
	acc.labels[key] = text
	API.rev = API.rev + 1
end

-- returns sorted list {key, jumps, yards, class, current}
function API.GetChars()
	local char, acc = GetStores()
	GetCharEntry(char, acc)
	local list, current = {}, GetCharKey()
	if acc and type(acc.chars) == "table" then
		for key, e in pairs(acc.chars) do
			if type(e) == "table" then
				list[#list + 1] = {key = key, jumps = tonumber(e.jumps) or 0, yards = tonumber(e.yards) or 0,
					class = e.class, current = key == current}
			end
		end
	end
	sort(list, function(a, b) return a.key < b.key end)
	return list
end

function API.RemoveChar(key)
	local _, acc = GetStores()
	if not acc or type(acc.chars) ~= "table" or key == GetCharKey() then return end
	local e = acc.chars[key]
	if type(e) ~= "table" then return end
	-- the removed character no longer counts towards the account total
	acc.jumps = math.max(0, acc.jumps - (tonumber(e.jumps) or 0))
	acc.yards = math.max(0, acc.yards - (tonumber(e.yards) or 0))
	acc.chars[key] = nil
	API.rev = API.rev + 1
end

API.FormatInt, API.FormatDist = FormatInt, FormatDist
API.YARDS_TO_KM, API.YARDS_TO_MI = YARDS_TO_KM, YARDS_TO_MI

local function Register(name, kind, scope)
	local labelKey = (kind == "jumps" and "jumps_" or "dist_") .. scope
	local localized = format("%s (%s)", kind == "jumps" and TXT.jumps or (TXT.distance .. (kind == "km" and " km" or " mi")),
		scope == "char" and TXT.char or TXT.acc)

	local hex = "|cffffffff"
	local lastPanel

	-- picks the longest variant that fits the current width of the panel:
	-- "Distance Char: 12.34 km" -> "Distance: 12.34 km" -> "12.34 km" -> "12.3 km"
	local function Refresh(self)
		local char, acc = GetStores()
		local store = scope == "char" and char or acc
		local full = FormatValue(store, kind)
		local label, custom = API.GetLabel(labelKey)
		local base = kind == "jumps" and TXT.jumps or TXT.distance
		local variants = {
			format("%s: %s%s|r", label, hex, full),
			custom and format("%s%s|r", hex, full) or format("%s: %s%s|r", base, hex, full),
			format("%s%s|r", hex, full),
			format("%s%s|r", hex, FormatCompact(store, kind)),
		}

		local fs = self.text
		local width = self:GetWidth()
		local chosen = #variants
		if width and width > 0 then
			for i = 1, #variants do
				fs:SetText(variants[i])
				if fs:GetStringWidth() <= width - 6 then
					chosen = i
					break
				end
			end
		else
			chosen = 1
		end
		fs:SetText(variants[chosen])
	end

	local function OnUpdate(self, elapsed)
		self.__travelTimer = (self.__travelTimer or 0) + elapsed
		local w = self:GetWidth()
		if self.__travelTimer < 1 and w == self.__travelWidth and self.__travelRev == API.rev then return end
		self.__travelTimer = 0
		self.__travelRev = API.rev
		self.__travelWidth = w
		lastPanel = self
		Refresh(self)
	end

	local function ValueColorUpdate(newHex)
		hex = newHex
		if lastPanel ~= nil and lastPanel.name == name then
			Refresh(lastPanel)
		end
	end
	E.valueColorUpdateFuncs[ValueColorUpdate] = true

	DT:RegisterDatatext(name, nil, nil, OnUpdate, nil, function(self) OnEnter(self, kind) end, nil, localized)
end

Register("Jumps (Character)", "jumps", "char")
Register("Jumps (Account)", "jumps", "acc")
Register("Distance km (Character)", "km", "char")
Register("Distance km (Account)", "km", "acc")
Register("Distance mi (Character)", "mi", "char")
Register("Distance mi (Account)", "mi", "acc")

----------------------------------------------------------------------------------------------------
-- Movement speed (current speed; also while on flight paths / in vehicles)
----------------------------------------------------------------------------------------------------
local BASE_RUN = 7 -- yards / second at 100%

local function GetCurrentSpeed()
	local speed = GetUnitSpeed("player") or 0
	if UnitInVehicle("player") then
		local v = GetUnitSpeed("vehicle") or 0
		if v > speed then speed = v end
	end
	return speed
end

local function SpeedOnEnter(self)
	DT:SetupTooltip(self)
	local yps = GetCurrentSpeed()
	local _, run, flight, swim = GetUnitSpeed("player")
	DT.tooltip:AddLine("Movement speed")
	DT.tooltip:AddLine(" ")
	DT.tooltip:AddDoubleLine("Current", format("%s km/h", FormatDist(yps * 3600 * YARDS_TO_KM)), 1, 1, 1, 1, 1, 1)
	DT.tooltip:AddDoubleLine("Current", format("%s mph", FormatDist(yps * 3600 * YARDS_TO_MI)), 1, 1, 1, 1, 1, 1)
	DT.tooltip:AddDoubleLine("Percent of base run speed", format("%d%%", floor(yps / BASE_RUN * 100 + 0.5)), 1, 1, 1, 1, 1, 1)
	if run and run > 0 then
		DT.tooltip:AddDoubleLine("Run speed", format("%d%%", floor(run / BASE_RUN * 100 + 0.5)), 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
	end
	if flight and flight > 0 then
		DT.tooltip:AddDoubleLine("Flight speed", format("%d%%", floor(flight / BASE_RUN * 100 + 0.5)), 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
	end
	if swim and swim > 0 then
		DT.tooltip:AddDoubleLine("Swim speed", format("%d%%", floor(swim / BASE_RUN * 100 + 0.5)), 0.6, 0.6, 0.6, 0.6, 0.6, 0.6)
	end
	DT.tooltip:Show()
end

local function RegisterSpeed(name, unitKey, factor, suffix, localized)
	local hex = "|cffffffff"
	local lastPanel

	local function Refresh(self)
		local label, custom = API.GetLabel(unitKey)
		local value = format("%s %s", FormatDist(GetCurrentSpeed() * factor), suffix)
		local width = self:GetWidth()
		local full = format("%s: %s%s|r", label, hex, value)
		local fs = self.text
		fs:SetText(full)
		if width and width > 0 and fs:GetStringWidth() > width - 6 then
			fs:SetText(format("%s%s|r", hex, value))
		end
	end

	local function OnUpdate(self, elapsed)
		self.__travelTimer = (self.__travelTimer or 0) + elapsed
		if self.__travelTimer < 0.2 then return end
		self.__travelTimer = 0
		lastPanel = self
		Refresh(self)
	end

	local function ValueColorUpdate(newHex)
		hex = newHex
		if lastPanel ~= nil and lastPanel.name == name then Refresh(lastPanel) end
	end
	E.valueColorUpdateFuncs[ValueColorUpdate] = true

	DT:RegisterDatatext(name, nil, nil, OnUpdate, nil, SpeedOnEnter, nil, localized)
end

RegisterSpeed("Speed km/h", "speed", 3600 * YARDS_TO_KM, "km/h", "Speed (km/h)")
RegisterSpeed("Speed mph", "speed", 3600 * YARDS_TO_MI, "mph", "Speed (mph)")
