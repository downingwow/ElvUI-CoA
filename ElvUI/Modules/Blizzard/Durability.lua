local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales
local B = E:GetModule("Blizzard")

--Lua functions
local _G = _G
local ipairs = ipairs
--WoW API / Variables
local hooksecurefunc = hooksecurefunc

local MOVER_NAME = "DurabilityFrameMover"
local BASE_WIDTH, BASE_HEIGHT = 70, 80 -- size of the armor figure at scale 1.0 (weapon icons overlap the edges)

local previewParts = {
	{"DurabilityHead", 1, 0.1, 0.1}, {"DurabilityShoulders", 1, 0.8, 0}, {"DurabilityChest", 1, 0.1, 0.1},
	{"DurabilityWrists", 1, 0.8, 0}, {"DurabilityHands", 1, 0.1, 0.1}, {"DurabilityWaist", 1, 0.8, 0},
	{"DurabilityLegs", 1, 0.1, 0.1}, {"DurabilityFeet", 1, 0.8, 0}, {"DurabilityWeapon", 1, 0.1, 0.1},
	{"DurabilityShield", 1, 0.8, 0}, {"DurabilityRanged", 1, 0.1, 0.1}
}

local function IsEnabled()
	return E.db.general.durability.enable
end

local function IsDetached()
	return E.db.general.durability.enable and E.db.general.durability.detach
end

-- Keeps the Blizzard frame where we want it: on the minimap (default) or inside our holder (popped out)
local function UpdateAnchor(self)
	if B.durabilitySettingPoint then return end
	B.durabilitySettingPoint = true

	self:ClearAllPoints()

	if IsDetached() and B.durabilityHolder then
		self:Point("CENTER", B.durabilityHolder, "CENTER", 0, 0)
	elseif DurabilityShield:IsShown() or DurabilityOffWeapon:IsShown() or DurabilityRanged:IsShown() then
		self:Point("RIGHT", Minimap, "RIGHT", -7, 0)
	else
		self:Point("RIGHT", Minimap, "RIGHT", 8, 0)
	end

	B.durabilitySettingPoint = nil
end

function B:ShowDurabilityPreview()
	DurabilityFrame:Show()

	for _, part in ipairs(previewParts) do
		local texture = _G[part[1]]
		if texture then
			texture:SetVertexColor(part[2], part[3], part[4])
			texture:Show()
		end
	end
end

function B:ToggleDurabilityPreview(value)
	self.durabilityPreview = value

	if value and IsEnabled() then
		self:ShowDurabilityPreview()
		UpdateAnchor(DurabilityFrame)
	elseif DurabilityFrame_SetAlerts then
		DurabilityFrame_SetAlerts() -- restores the real state (hides everything when nothing is damaged)
		if not IsEnabled() then DurabilityFrame:Hide() end
	end
end

function B:UpdateDurabilityFrame()
	if not self.durabilityHolder then return end

	local db = E.db.general.durability
	local scale = db.scale or 0.6

	DurabilityFrame:SetScale(scale)
	DurabilityFrame:SetAlpha(db.alpha or 1)

	self.durabilityHolder:Size(BASE_WIDTH * scale, BASE_HEIGHT * scale)
	if _G[MOVER_NAME] then
		_G[MOVER_NAME]:Size(BASE_WIDTH * scale, BASE_HEIGHT * scale)
	end

	-- the mover only exists while the figure is enabled AND popped out
	if E.CreatedMovers[MOVER_NAME] or E.DisabledMovers[MOVER_NAME] then
		if IsDetached() then
			E:EnableMover(MOVER_NAME)
		else
			E:DisableMover(MOVER_NAME)
		end
	end

	UpdateAnchor(DurabilityFrame)

	if not db.enable then
		DurabilityFrame:Hide()
	elseif self.durabilityPreview then
		self:ShowDurabilityPreview()
	elseif DurabilityFrame_SetAlerts then
		DurabilityFrame_SetAlerts()
	end
end

function B:PositionDurabilityFrame()
	if self.durabilityHooked then
		self:UpdateDurabilityFrame()
		return
	end

	DurabilityFrame:SetFrameStrata("HIGH")

	DurabilityWeapon:Point("RIGHT", DurabilityWrists, "LEFT", 6, 0)
	DurabilityShield:Point("LEFT", DurabilityWrists, "RIGHT", -6, 10)
	DurabilityOffWeapon:Point("LEFT", DurabilityWrists, "RIGHT", -6, 0)
	DurabilityRanged:Point("TOP", DurabilityShield, "BOTTOM", -1, 0)

	local holder = CreateFrame("Frame", "DurabilityFrameHolder", E.UIParent)
	holder:Size(BASE_WIDTH * 0.6, BASE_HEIGHT * 0.6)
	holder:Point("TOPRIGHT", E.UIParent, "TOPRIGHT", -220, -230)
	self.durabilityHolder = holder

	E:CreateMover(holder, MOVER_NAME, "Durability Frame", nil, nil, nil, "ALL,GENERAL", nil, "general,durability")

	hooksecurefunc(DurabilityFrame, "SetPoint", UpdateAnchor)

	DurabilityFrame:HookScript("OnShow", function(self)
		if not IsEnabled() then
			self:Hide()
		elseif B.durabilityPreview then
			B:ShowDurabilityPreview()
		end
		UpdateAnchor(self)
	end)

	-- Blizzard re-shows/hides the figure and recolors the parts on every durability change
	if DurabilityFrame_SetAlerts then
		hooksecurefunc("DurabilityFrame_SetAlerts", function()
			if not IsEnabled() then
				DurabilityFrame:Hide()
			elseif B.durabilityPreview then
				B:ShowDurabilityPreview()
			end
			UpdateAnchor(DurabilityFrame)
		end)
	end

	self.durabilityHooked = true
	self:UpdateDurabilityFrame()
end
