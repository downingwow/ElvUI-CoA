local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local UF = E:GetModule("UnitFrames")

--Lua functions
--WoW API / Variables

function UF:Construct_Cutaway(frame)
	local cutaway = {}
	local frameName = frame:GetName()

	if frame.Power then
		local powerTexture = frame.Power:GetStatusBarTexture()
		local cutawayPower = frame.Power:CreateTexture(frameName.."CutawayPower")
		cutawayPower:SetPoint("TOPLEFT", powerTexture, "TOPRIGHT")
		cutawayPower:SetPoint("BOTTOMLEFT", powerTexture, "BOTTOMRIGHT")
		cutawayPower:SetTexture(E.media.blankTex)
		cutaway.Power = cutawayPower
	end

	local healthTexture = frame.Health:GetStatusBarTexture()
	local cutawayHealth = frame.Health:CreateTexture(frameName.."CutawayHealth")
	cutawayHealth:SetPoint("TOPLEFT", healthTexture, "TOPRIGHT")
	cutawayHealth:SetPoint("BOTTOMLEFT", healthTexture, "BOTTOMRIGHT")
	cutawayHealth:SetTexture(E.media.blankTex)
	cutaway.Health = cutawayHealth

	return cutaway
end

local cutawayPoints = {
	[1] = {"TOPLEFT", "TOPRIGHT"},
	[2] = {"BOTTOMLEFT", "BOTTOMRIGHT"},
	[3] = {"BOTTOMLEFT", "TOPLEFT"},
	[4] = {"BOTTOMRIGHT", "TOPRIGHT"},
	-- Reverse Fill (Bar fuellt von rechts nach links bzw. von oben nach unten)
	[5] = {"TOPRIGHT", "TOPLEFT"},
	[6] = {"BOTTOMRIGHT", "BOTTOMLEFT"},
	[7] = {"TOPLEFT", "BOTTOMLEFT"},
	[8] = {"TOPRIGHT", "BOTTOMRIGHT"}
}

local DEFAULT_INDEX, VERT_INDEX = 1, 3
local REVERSE_INDEX, REVERSE_VERT_INDEX = 5, 7
function UF:GetPoints_Cutaway(db, reverse)
	local index
	local vertical = db and db.orientation == "VERTICAL"
	if reverse then
		index = vertical and REVERSE_VERT_INDEX or REVERSE_INDEX
	elseif vertical then
		index = VERT_INDEX
	else
		index = DEFAULT_INDEX
	end

	return cutawayPoints[index], cutawayPoints[index + 1]
end

function UF:Configure_Cutaway(frame)
	local db = frame.db and frame.db.cutaway
	local healthDB, powerDB = db and db.health, db and db.power
	local healthEnabled = healthDB and healthDB.enabled
	local powerEnabled = powerDB and powerDB.enabled
	if healthEnabled or powerEnabled then
		if not frame:IsElementEnabled("Cutaway") then
			frame:EnableElement("Cutaway")
		end

		frame.Cutaway:UpdateConfigurationValues(db)
		local health = frame.Cutaway.Health
		if health and healthEnabled then
			local point1, point2 = UF:GetPoints_Cutaway(frame.db.health, UF:IsReverseFill(frame))
			local barTexture = frame.Health:GetStatusBarTexture()

			health:ClearAllPoints()
			health:SetPoint(point1[1], barTexture, point1[2])
			health:SetPoint(point2[1], barTexture, point2[2])

			frame.Health:PostUpdateColor(frame.unit)
		end

		local power = frame.Cutaway.Power
		local powerUsable = powerEnabled and frame.USE_POWERBAR
		if power and powerUsable then
			local point1, point2 = UF:GetPoints_Cutaway(frame.db.power, frame.db.power and frame.db.power.reverseFill)
			local barTexture = frame.Power:GetStatusBarTexture()

			power:ClearAllPoints()
			power:SetPoint(point1[1], barTexture, point1[2])
			power:SetPoint(point2[1], barTexture, point2[2])

			frame.Power:PostUpdateColor()
		end
	elseif frame:IsElementEnabled("Cutaway") then
		frame:DisableElement("Cutaway")
	end
end