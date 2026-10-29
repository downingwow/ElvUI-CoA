local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales
local B = E:GetModule("Blizzard")
local LSM = E.Libs.LSM

--Lua functions
local _G = _G
local pairs, ipairs, unpack, format = pairs, ipairs, unpack, string.format
--WoW API / Variables
local hooksecurefunc = hooksecurefunc

-- Mirror timers: the bars for Fatigue (EXHAUSTION), Breath (BREATH) and Feign Death.
-- Settings: General -> BlizzUI Improvements -> Mirror Timers (E.db.general.mirrorTimers)
-- Shadow:   Skins -> Shadows -> Mirror Timers
-- Mover:    MirrorTimer1Mover .. MirrorTimer3Mover

local NUM_TIMERS = _G.MIRRORTIMER_NUMTIMERS or 3

-- Timer name from the client -> settings key
local SETTINGS_KEY = {
	EXHAUSTION = "fatigue",
	BREATH = "breath",
	FEIGNDEATH = "feigndeath",
	DEATH = "feigndeath",
}

-- Blizzard's own colors, used for every timer type without own settings (Feign Death) and as fallback
local FALLBACK_COLOR = {
	EXHAUSTION = {r = 1, g = 0.9, b = 0},
	BREATH = {r = 0, g = 0.5, b = 1},
	DEATH = {r = 1, g = 0.7, b = 0},
	FEIGNDEATH = {r = 1, g = 0.7, b = 0},
}

local function GetDB()
	return E.db and E.db.general and E.db.general.mirrorTimers
end

local function GetTimerType(frame)
	return frame.timer or frame.coaMirrorType
end

-- Settings of the timer type shown by this bar (Fatigue settings for unknown types)
local function GetSettings(frame, db)
	local timer = GetTimerType(frame)
	local key = timer and SETTINGS_KEY[timer]
	return (key and db[key]) or db.fatigue, key
end

-- Size of the bar, position and font of its text, all per timer type
local function ApplyLayout(frame, db)
	local settings = GetSettings(frame, db)
	if not settings then return end

	local statusBar = _G[frame:GetName().."StatusBar"]
	local width, height = settings.width or 222, settings.height or 18

	frame:SetSize(width, height)
	if statusBar then statusBar:SetSize(width, height) end

	local mover = _G[frame:GetName().."Mover"]
	if mover then mover:SetSize(width, height) end

	local font = LSM:Fetch("font", settings.font)
	local size = settings.fontSize or 12
	local outline = settings.fontOutline or "OUTLINE"
	local x, y = settings.textX or 0, settings.textY or 0
	local anchor = statusBar or frame

	-- ElvUI skin: own text; without the skin: the Blizzard text of the bar
	local text = frame.TimerText or _G[frame:GetName().."Text"]
	if text then
		text:FontTemplate(font, size, outline)
		text:ClearAllPoints()
		text:SetPoint("CENTER", anchor, "CENTER", x, y)
	end
end

local function ApplyColor(frame, db)
	local statusBar = _G[frame:GetName().."StatusBar"]
	if not statusBar then return end

	local timer = GetTimerType(frame)
	local key = timer and SETTINGS_KEY[timer]
	local settings = key and db[key]
	local texture = statusBar:GetStatusBarTexture()

	if settings and settings.color then
		local c = settings.color
		if settings.gradient and settings.color2 and texture and texture.SetGradientAlpha then
			local c2 = settings.color2
			statusBar:SetStatusBarColor(1, 1, 1, 1)
			texture:SetGradientAlpha("HORIZONTAL", c.r, c.g, c.b, 1, c2.r, c2.g, c2.b, 1)
		else
			if texture and texture.SetGradientAlpha then
				texture:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
			end
			statusBar:SetStatusBarColor(c.r, c.g, c.b, 1)
		end
	else
		-- no own settings for this timer type: Blizzard color, no gradient
		if texture and texture.SetGradientAlpha then
			texture:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
		end
		local c = (timer and ((_G.MirrorTimerColors and _G.MirrorTimerColors[timer]) or FALLBACK_COLOR[timer])) or nil
		if c then
			statusBar:SetStatusBarColor(c.r, c.g, c.b, 1)
		end
	end
end

function B:UpdateMirrorTimers()
	local db = GetDB()
	if not db then return end

	for i = 1, NUM_TIMERS do
		local frame = _G["MirrorTimer"..i]
		if frame then
			ApplyLayout(frame, db)
			ApplyColor(frame, db)
		end
	end
end

-- Preview: shows a Fatigue bar (bar 1), a Breath bar (bar 2) and a Feign Death bar (bar 3) with sample values so the colors, the
-- gradient and the font can be configured without being exhausted or under water. Not saved.
-- Paused bars are not updated by the client (and not by the ElvUI skin), so the sample values stay.
local PREVIEW = {
	{timer = "EXHAUSTION", value = 40, max = 60, en = "Fatigue", de = "Ersch\195\182pfung"},
	{timer = "BREATH", value = 25, max = 60, en = "Breath", de = "Atem"},
	{timer = "FEIGNDEATH", value = 15, max = 30, en = "Feign Death", de = "Totstellen"},
}

function B:ToggleMirrorTimerPreview(enable)
	self.mirrorTimerPreview = enable and true or nil
	local isGerman = GetLocale() == "deDE"

	for i, data in ipairs(PREVIEW) do
		local frame = _G["MirrorTimer"..i]
		local statusBar = _G["MirrorTimer"..i.."StatusBar"]
		if frame and statusBar then
			if enable then
				-- never take over a bar that shows a real timer
				if not frame:IsShown() then
					local label = isGerman and data.de or data.en
					frame.coaPreview = true
					frame.paused = true
					frame.timer = data.timer
					frame.coaMirrorType = data.timer
					statusBar:SetMinMaxValues(0, data.max)
					statusBar:SetValue(data.value)

					local text = _G["MirrorTimer"..i.."Text"]
					if text then text:SetText(label) end
					if frame.TimerText then
						frame.TimerText:SetText(format("%s (%d:%02d)", label, data.value / 60, data.value % 60))
					end

					frame:Show()
				end
			elseif frame.coaPreview then
				frame.coaPreview = nil
				frame.paused = nil
				frame.timer = nil
				frame.coaMirrorType = nil
				frame:Hide()
			end
		end
	end

	self:UpdateMirrorTimers()
end

-- Movers: one per timer bar. Called by the skin (after it resized the bars) or, when the skin is
-- disabled, by Blizzard:Initialize. Safe to call more than once.
function B:CreateMirrorTimerMovers()
	for i = 1, NUM_TIMERS do
		local frame = _G["MirrorTimer"..i]
		local name = "MirrorTimer"..i.."Mover"
		if frame and not E.CreatedMovers[name] then
			E:CreateMover(frame, name, "Mirror Timer "..i.."", nil, nil, nil, "ALL,SOLO", nil, "general,timerBars")
		end
	end
end

local function SkinWillRun()
	return E.private.skins and E.private.skins.blizzard
		and E.private.skins.blizzard.enable and E.private.skins.blizzard.mirrorTimers
end

function B:InitializeMirrorTimers()
	if self.mirrorTimersHooked then return end
	self.mirrorTimersHooked = true

	-- The client colors the bar and sets the timer type when a timer starts. Remember which bar shows
	-- which timer (matched by the label, as the field name can differ between clients) and recolor.
	if _G.MirrorTimer_Show then
		hooksecurefunc("MirrorTimer_Show", function(timer, _, _, _, _, label)
			for i = 1, NUM_TIMERS do
				local frame = _G["MirrorTimer"..i]
				if frame and frame:IsShown() then
					local text = _G["MirrorTimer"..i.."Text"]
					if frame.timer == timer or (text and label and text:GetText() == label) then
						frame.coaMirrorType = timer
					end
				end
			end
			B:UpdateMirrorTimers()
		end)
	end

	for i = 1, NUM_TIMERS do
		local frame = _G["MirrorTimer"..i]
		if frame then
			frame:HookScript("OnShow", function() B:UpdateMirrorTimers() end)
		end
	end

	if not SkinWillRun() then
		self:CreateMirrorTimerMovers()
	end

	self:UpdateMirrorTimers()
end
