local E, L, V, P, G = unpack(select(2, ...))
local UF = E:GetModule("UnitFrames")

local CreateFrame = CreateFrame
local UnitExists = UnitExists
local UnitHealthMax = UnitHealthMax
local UnitGetTotalAbsorbs = UnitGetTotalAbsorbs
local min, max = math.min, math.max
local pairs = pairs

local LSM = E.Libs.LSM

UF.absorbFrames = UF.absorbFrames or setmetatable({}, {__mode = "k"})

local function GetAbsorbDB(frame)
	return frame and frame.db and frame.db.absorb
end

local function GetAbsorbTexture(db)
	if db and db.texture and LSM then
		local texture = LSM:Fetch("statusbar", db.texture, true)
		if texture then return texture end
	end
	return E.media.normTex or E.media.blankTex
end

local function ApplyAbsorbAppearance(absorb, db)
	if not absorb or not db then return end

	local base = db.color or {r = 183/255, g = 1, b = 231/255, a = 0.85}
	local finish = db.gradientColor or {r = 0.20, g = 0.65, b = 1.00, a = 0.85}
	local r, g, b, a = base.r or 1, base.g or 1, base.b or 1, base.a or 0.85
	local er, eg, eb, ea = finish.r or r, finish.g or g, finish.b or b, finish.a or a
	local texture = absorb:GetStatusBarTexture()

	if db.gradient and texture and texture.SetGradientAlpha then
		absorb:SetStatusBarColor(1, 1, 1)
		absorb:SetAlpha(1)
		if absorb.__reverse then
			texture:SetGradientAlpha("HORIZONTAL", er, eg, eb, ea, r, g, b, a)
		else
			texture:SetGradientAlpha("HORIZONTAL", r, g, b, a, er, eg, eb, ea)
		end
	else
		-- Clear a previously applied gradient before returning to a solid base color.
		if texture and texture.SetGradientAlpha then
			texture:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
		end
		absorb:SetStatusBarColor(r, g, b)
		absorb:SetAlpha(a)
	end
end

function UF:Construct_AbsorbOverlay(frame)
	if not frame or not frame.Health or frame.AbsorbOverlay then return frame and frame.AbsorbOverlay end

	local absorb = CreateFrame("StatusBar", nil, frame.Health)
	absorb:EnableMouse(false)
	absorb:SetMinMaxValues(0, 1)
	absorb:SetValue(1)
	absorb:SetStatusBarTexture(E.media.normTex or E.media.blankTex)
	absorb:SetFrameLevel((frame.Health:GetFrameLevel() or 10) + 1)
	absorb:Hide()

	absorb.__owner = frame
	frame.AbsorbOverlay = absorb
	UF.absorbFrames[frame] = true

	return absorb
end

function UF:Configure_AbsorbOverlay(frame)
	local absorb = frame and frame.AbsorbOverlay
	local health = frame and frame.Health
	local db = GetAbsorbDB(frame)
	if not absorb or not health or not db then return end

	absorb:SetParent(health)
	absorb:SetFrameLevel((health:GetFrameLevel() or 10) + 1)
	absorb:ClearAllPoints()
	-- Bei umgekehrter Fuellrichtung sitzt das Absorb-Overlay an der linken Kante
	absorb.__reverse = UF:IsReverseFill(frame)
	if absorb.__reverse then
		absorb:SetPoint("TOPLEFT", health, "TOPLEFT", 0, 0)
		absorb:SetPoint("BOTTOMLEFT", health, "BOTTOMLEFT", 0, 0)
	else
		absorb:SetPoint("TOPRIGHT", health, "TOPRIGHT", 0, 0)
		absorb:SetPoint("BOTTOMRIGHT", health, "BOTTOMRIGHT", 0, 0)
	end
	absorb:SetStatusBarTexture(GetAbsorbTexture(db))
	ApplyAbsorbAppearance(absorb, db)

	if not db.enable then
		absorb:Hide()
		return
	end

	UF:UpdateAbsorbOverlay(frame)
end

function UF:UpdateAbsorbOverlay(frame)
	local absorb = frame and frame.AbsorbOverlay
	local health = frame and frame.Health
	local db = GetAbsorbDB(frame)
	if not absorb or not health or not db or not db.enable or not UnitGetTotalAbsorbs then
		if absorb then absorb:Hide() end
		return
	end

	local unit = frame.unit
	if not unit or not frame:IsShown() or not UnitExists(unit) then
		absorb:Hide()
		return
	end

	local amount = UnitGetTotalAbsorbs(unit) or 0
	local maxHealth = UnitHealthMax(unit) or 0
	if amount <= 0 or maxHealth <= 0 then
		absorb:Hide()
		return
	end

	local healthWidth = health:GetWidth() or 0
	if healthWidth <= 0 then
		absorb:Hide()
		return
	end

	local ratio = min(amount / maxHealth, 1)
	absorb:SetMinMaxValues(0, 1)
	absorb:SetValue(1)
	absorb:SetWidth(max(1, healthWidth * ratio))

	ApplyAbsorbAppearance(absorb, db)
	absorb:Show()
end

local updater = CreateFrame("Frame")
local elapsed = 0
updater:SetScript("OnUpdate", function(_, delta)
	elapsed = elapsed + delta
	if elapsed < 0.08 then return end
	elapsed = 0

	for frame in pairs(UF.absorbFrames) do
		UF:UpdateAbsorbOverlay(frame)
	end
end)
