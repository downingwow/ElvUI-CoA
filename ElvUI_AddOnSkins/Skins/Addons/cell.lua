local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

if not AS:IsAddonLODorEnabled("Cell") then return end

local _G = _G
local type = type
local pairs = pairs
local UnitClass = UnitClass
local UnitExists = UnitExists
local UnitIsPlayer = UnitIsPlayer
local UnitIsConnected = UnitIsConnected
local UnitIsCharmed = UnitIsCharmed
local hooksecurefunc = hooksecurefunc

local Cell

local function IsEnabled()
	return E.db and E.db.addOnSkins and E.db.addOnSkins.cellGradient
end

local function GetElvUIClassGradient(class)
	if not class then return end

	local colors = E.db and E.db.unitframe and E.db.unitframe.colors
	if not colors then return end

	local bases = colors.healthGradientBaseColors
	bases = bases and bases.class
	local finishes = colors.healthGradientColors
	finishes = finishes and finishes.class

	local base = bases and bases[class]
	local finish = finishes and finishes[class]

	local fallback
	if E.ClassColor then
		fallback = E:ClassColor(class)
	end
	if not fallback and _G.CUSTOM_CLASS_COLORS then
		fallback = _G.CUSTOM_CLASS_COLORS[class]
	end
	if not fallback and _G.RAID_CLASS_COLORS then
		fallback = _G.RAID_CLASS_COLORS[class]
	end

	local br = base and base.r or fallback and fallback.r
	local bg = base and base.g or fallback and fallback.g
	local bb = base and base.b or fallback and fallback.b
	if br == nil or bg == nil or bb == nil then return end

	local er, eg, eb
	if finish then
		er, eg, eb = finish.r, finish.g, finish.b
	else
		-- Keep exactly the same default end-color rule as ElvUI UnitFrames.
		er = br + ((1 - br) * 0.18)
		eg = bg + ((1 - bg) * 0.18)
		eb = bb + ((1 - bb) * 0.18)
	end

	return br, bg, bb, er, eg, eb
end

local function GetButtonUnitAndClass(button)
	if not button or not button.states then return end

	local unit = button.states.displayedUnit or button.states.unit or button.unit
	if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) then return end
	if not UnitIsConnected(unit) or UnitIsCharmed(unit) or button.states.inVehicle then return end

	local class = button.states.class
	if not class then
		class = select(2, UnitClass(unit))
	end
	if not class then return end

	return unit, class
end

local function ClearCellGradient(button, r, g, b, a)
	local bar = button and button.widgets and button.widgets.healthBar
	local texture = bar and bar.GetStatusBarTexture and bar:GetStatusBarTexture()
	if not texture or not texture.__ElvUIAddOnSkinsCellGradient then return end

	local alpha = a or 1
	if texture.SetGradientAlpha then
		texture:SetGradientAlpha("HORIZONTAL", 1, 1, 1, alpha, 1, 1, 1, alpha)
	end
	if texture.SetVertexColor and r ~= nil and g ~= nil and b ~= nil then
		texture:SetVertexColor(r, g, b, alpha)
	end

	texture.__ElvUIAddOnSkinsCellGradient = nil
	texture.__ElvUIAddOnSkinsCellClass = nil
end

function AS:ApplyCellGradient(button, alpha, solidR, solidG, solidB)
	if not button or not button.widgets then return end

	local bar = button.widgets.healthBar
	local texture = bar and bar.GetStatusBarTexture and bar:GetStatusBarTexture()
	if not texture or not texture.SetGradientAlpha then return end

	if not IsEnabled() then
		ClearCellGradient(button, solidR, solidG, solidB, alpha)
		return
	end

	local _, class = GetButtonUnitAndClass(button)
	if not class then
		-- Disconnected/charmed/vehicle/pet/NPC frames keep Cell's own solid color.
		ClearCellGradient(button, solidR, solidG, solidB, alpha)
		return
	end

	local br, bg, bb, er, eg, eb = GetElvUIClassGradient(class)
	if not br then
		ClearCellGradient(button, solidR, solidG, solidB, alpha)
		return
	end

	local a = alpha or 1
	if texture.SetVertexColor then
		texture:SetVertexColor(1, 1, 1, a)
	end
	texture:SetGradientAlpha("HORIZONTAL", br, bg, bb, a, er, eg, eb, a)
	texture.__ElvUIAddOnSkinsCellGradient = true
	texture.__ElvUIAddOnSkinsCellClass = class
end

local function HookCellButton(button)
	if not button or button.__ElvUIAddOnSkinsCellGradientHooked then return end
	local bar = button.widgets and button.widgets.healthBar
	if not bar or not bar.SetStatusBarColor then return end

	button.__ElvUIAddOnSkinsCellGradientHooked = true

	-- Cell remains the owner of all health logic. We only repaint the fill texture
	-- after Cell has chosen its normal solid color.
	hooksecurefunc(bar, "SetStatusBarColor", function(_, r, g, b, a)
		AS:ApplyCellGradient(button, a, r, g, b)
	end)

	if button.HookScript then
		button:HookScript("OnShow", function()
			if IsEnabled() then
				AS:ApplyCellGradient(button)
			end
		end)
	end
end

local function ForEachCellButton(callback)
	if not Cell then Cell = _G.Cell end
	if not Cell then return end

	local F = Cell.funcs
	if F and F.IterateAllUnitButtons then
		pcall(F.IterateAllUnitButtons, callback, false, true)
	end
end

function AS:RefreshCellGradients()
	if not Cell then Cell = _G.Cell end
	if not Cell then return end

	local B = Cell.bFuncs
	ForEachCellButton(function(button)
		HookCellButton(button)

		-- Ask Cell to repaint normally first. Our StatusBarColor hook then applies
		-- the gradient only when the option is enabled, and restores solid Cell
		-- colors immediately when it is disabled.
		if B and B.UpdateHealth and button.states and button.states.displayedUnit then
			pcall(B.UpdateHealth, button)
		elseif IsEnabled() then
			AS:ApplyCellGradient(button)
		else
			ClearCellGradient(button)
		end
	end)
end

S:AddCallbackForAddon("Cell", "Cell", function()
	Cell = _G.Cell
	if not Cell or AS.__CellGradientHooked then return end
	AS.__CellGradientHooked = true

	-- Existing buttons.
	ForEachCellButton(HookCellButton)

	-- Secure raid headers can create additional Cell buttons later.
	if _G.CellUnitButton_OnLoad then
		hooksecurefunc("CellUnitButton_OnLoad", function(button)
			HookCellButton(button)
			if IsEnabled() then
				AS:ApplyCellGradient(button)
			end
		end)
	end

	-- Repaint Cell when ElvUI's UnitFrame color options/profile are refreshed.
	local UF = E:GetModule("UnitFrames", true)
	if UF and UF.Update_AllFrames then
		hooksecurefunc(UF, "Update_AllFrames", function()
			if IsEnabled() then
				AS:RefreshCellGradients()
			end
		end)
	end

	if E.Delay then
		E:Delay(0.10, function() AS:RefreshCellGradients() end)
		E:Delay(1.00, function() AS:RefreshCellGradients() end)
	else
		AS:RefreshCellGradients()
	end
end)
