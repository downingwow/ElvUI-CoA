local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

if not AS:IsAddonLODorEnabled("Details") then return end

local _G = _G
local math_min = math.min
local math_max = math.max
local pairs = pairs
local type = type
local CreateFrame = CreateFrame

local Details

local function IsEnabled()
	return E.db and E.db.addOnSkins and E.db.addOnSkins.detailsClassGradient
end

local function AreBarShadowsEnabled()
	return E.db and E.db.addOnSkins and E.db.addOnSkins.detailsBarShadows
end

local function GetShadowDB()
	return E.db and E.db.frameShadows
end

local function EnsureDetailsBarShadow(bar)
	if not bar or not bar.GetFrameLevel or not bar.GetFrameStrata then return end
	if bar.__ElvUIAddOnSkinsDetailsShadow then
		return bar.__ElvUIAddOnSkinsDetailsShadow
	end

	local shadow = CreateFrame("Frame", nil, bar)
	shadow:EnableMouse(false)
	bar.__ElvUIAddOnSkinsDetailsShadow = shadow
	return shadow
end

local function StyleDetailsBarShadow(bar, show)
	if not bar then return end

	local shadow = EnsureDetailsBarShadow(bar)
	if not shadow then return end

	-- Details' `textura` is the actual colored/fill region. Anchor the shadow
	-- to it instead of the complete row frame so empty space after the current
	-- damage/healing fill does not receive a shadow. Anchors follow the texture
	-- automatically while Details changes its width.
	local fill = bar.textura
	local fillWidth = fill and fill.GetWidth and fill:GetWidth()
	local fillHeight = fill and fill.GetHeight and fill:GetHeight()

	local db = GetShadowDB()
	local active = show and AreBarShadowsEnabled() and (not db or db.enable ~= false)
	active = active and fill and fill.IsShown and fill:IsShown()
	active = active and fillWidth and fillHeight and fillWidth > 0.5 and fillHeight > 0.5
	if not active then
		shadow:Hide()
		return
	end

	local size = (db and db.size) or 5
	local color = (db and db.color) or {r = 0, g = 0, b = 0, a = 0.9}
	local LSM = E.Libs and E.Libs.LSM
	local edge = LSM and LSM:Fetch("border", "ElvUI GlowBorder")
	if not edge then
		shadow:Hide()
		return
	end

	shadow:ClearAllPoints()
	shadow:SetPoint("TOPLEFT", fill, "TOPLEFT", -size, size)
	shadow:SetPoint("BOTTOMRIGHT", fill, "BOTTOMRIGHT", size, -size)
	shadow:SetFrameStrata(bar:GetFrameStrata())
	shadow:SetFrameLevel(math_max((bar:GetFrameLevel() or 1) - 1, 0))
	shadow:SetBackdrop({edgeFile = edge, edgeSize = E:Scale(size)})
	shadow:SetBackdropColor(0, 0, 0, 0)
	shadow:SetBackdropBorderColor(color.r or 0, color.g or 0, color.b or 0, color.a or 0.9)
	shadow:Show()
end

local function GetActorClass(actor, bar)
	if type(actor) ~= "table" then
		actor = nil
	end

	if not actor and bar and type(bar.minha_tabela) == "table" then
		actor = bar.minha_tabela
	end

	local class = actor and (actor.classe or actor.class)

	-- Details can temporarily use UNGROUPPLAYER until it resolves the real class.
	if class == "UNGROUPPLAYER" and actor and actor.spec and DetailsFramework and DetailsFramework.GetSpecializationInfoByID then
		local _, _, _, _, _, specClass = DetailsFramework.GetSpecializationInfoByID(actor.spec)
		if specClass then class = specClass end
	end

	return class
end

local function GetElvUIClassGradient(class)
	if not class then return end

	local colors = E.db and E.db.unitframe and E.db.unitframe.colors
	if not colors then return end

	local bases = colors.healthGradientBaseColors
	bases = bases and bases.class
	local ends = colors.healthGradientColors
	ends = ends and ends.class

	local base = bases and bases[class]
	local finish = ends and ends[class]

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
		-- Same fallback used by ElvUI's UnitFrame class gradient.
		er = br + ((1 - br) * 0.18)
		eg = bg + ((1 - bg) * 0.18)
		eb = bb + ((1 - bb) * 0.18)
	end

	return br, bg, bb, er, eg, eb
end

local function ClearBarGradient(bar)
	if not bar or not bar.textura then return end

	local texture = bar.textura
	if texture.__ElvUIAddOnSkinsDetailsGradient then
		if texture.SetGradientAlpha then
			texture:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
		end
		texture.__ElvUIAddOnSkinsDetailsGradient = nil
		texture.__ElvUIAddOnSkinsDetailsClass = nil
	end
end

function AS:ApplyDetailsClassGradient(bar, actor, instance, alpha)
	if not IsEnabled() or not bar or not bar.textura then return end

	local class = GetActorClass(actor, bar)
	local br, bg, bb, er, eg, eb = GetElvUIClassGradient(class)
	if not br then
		-- Do not touch spell-school/custom/non-player rows.
		return
	end

	local texture = bar.textura
	if not texture.SetGradientAlpha then return end

	local a = alpha or 1

	-- Details sets its own normal class/fixed color first. This post-hook then
	-- applies the gradient in one atomic step. We never save white into Details.
	texture:SetVertexColor(1, 1, 1, a)
	texture:SetGradientAlpha("HORIZONTAL", br, bg, bb, a, er, eg, eb, a)
	texture.__ElvUIAddOnSkinsDetailsGradient = true
	texture.__ElvUIAddOnSkinsDetailsClass = class
end

function AS:ApplyDetailsClassGradientToInstance(instance)
	if not IsEnabled() or not instance or not instance.barras then return end

	for _, bar in pairs(instance.barras) do
		if bar and bar:IsShown() then
			self:ApplyDetailsClassGradient(bar, bar.minha_tabela, instance, 1)
		end
	end
end

function AS:ApplyDetailsBarShadowsToInstance(instance)
	if not instance or not instance.barras then return end

	for _, bar in pairs(instance.barras) do
		if bar then
			StyleDetailsBarShadow(bar, bar:IsShown())
		end
	end
end

local function ForEachDetailsInstance(callback)
	if not Details or not Details.ListInstances then return end

	for _, instance in Details:ListInstances() do
		if instance then
			callback(instance)
		end
	end
end

function AS:RefreshDetailsClassGradients()
	if not Details then
		Details = _G._details or _G._detalhes
	end
	if not Details then return end

	local enabled = IsEnabled()

	-- First clear our texture gradients. This is important when the option is
	-- switched off: Details then repaints the bars with its own untouched colors.
	ForEachDetailsInstance(function(instance)
		if instance.barras then
			for _, bar in pairs(instance.barras) do
				ClearBarGradient(bar)
			end
		end
	end)

	-- Force Details itself to repaint normally. Our SetBarColors post-hook below
	-- only reapplies a gradient when the AddOnSkins checkbox is enabled.
	ForEachDetailsInstance(function(instance)
		if instance.RefreshWindow then
			pcall(instance.RefreshWindow, instance, true)
		end
	end)

	if enabled then
		ForEachDetailsInstance(function(instance)
			AS:ApplyDetailsClassGradientToInstance(instance)
		end)
	end
end

function AS:RefreshDetailsBarShadows()
	if not Details then
		Details = _G._details or _G._detalhes
	end
	if not Details then return end

	ForEachDetailsInstance(function(instance)
		AS:ApplyDetailsBarShadowsToInstance(instance)
	end)
end

S:AddCallbackForAddon("Details", "Details", function()
	Details = _G._details or _G._detalhes
	if not Details or AS.__DetailsClassGradientHooked then return end
	AS.__DetailsClassGradientHooked = true

	-- This is the central Details function used by damage/healing/resources/
	-- utility/custom actor rows. Details applies its normal color first; we only
	-- overlay the ElvUI gradient afterwards.
	if Details.SetBarColors then
		hooksecurefunc(Details, "SetBarColors", function(actor, bar, instance, r, g, b, a)
			if IsEnabled() then
				AS:ApplyDetailsClassGradient(bar, actor, instance, a)
			end
			if AreBarShadowsEnabled() and bar then
				StyleDetailsBarShadow(bar, bar:IsShown())
			end
		end)
	end

	-- Re-apply after Details changes a row texture/layout in its own options.
	if Details.InstanceRefreshRows then
		hooksecurefunc(Details, "InstanceRefreshRows", function(selfOrInstance, explicitInstance)
			local instance = explicitInstance or selfOrInstance
			if IsEnabled() then
				AS:ApplyDetailsClassGradientToInstance(instance)
			end
			if AreBarShadowsEnabled() then
				AS:ApplyDetailsBarShadowsToInstance(instance)
			end
		end)
	end

	-- New/opened windows and profile changes can happen after the first load.
	if Details.CreateEventListener then
		local listener = Details:CreateEventListener()
		if listener then
			listener:RegisterEvent("DETAILS_INSTANCE_OPEN")
			listener:RegisterEvent("DETAILS_INSTANCE_CHANGEATTRIBUTE")
			listener:RegisterEvent("DETAILS_INSTANCE_CHANGESEGMENT")
			listener:RegisterEvent("DETAILS_INSTANCE_CHANGEMODE")
			listener:RegisterEvent("DETAILS_PROFILE_APPLYED")
			listener:RegisterEvent("DETAILS_OPTIONS_MODIFIED")

			function listener:OnDetailsEvent()
				if IsEnabled() or AreBarShadowsEnabled() then
					local function RefreshDetailsVisuals()
						if IsEnabled() then
							AS:RefreshDetailsClassGradients()
						end
						AS:RefreshDetailsBarShadows()
					end

					if E.Delay then
						E:Delay(0.05, RefreshDetailsVisuals)
					else
						RefreshDetailsVisuals()
					end
				end
			end
		end
	end

	-- Follow ElvUI's central shadow settings so master enable, color and size
	-- are propagated to Details without maintaining a second shadow configuration.
	if S.UpdateFrameShadows and not AS.__DetailsShadowManagerHooked and hooksecurefunc then
		AS.__DetailsShadowManagerHooked = true
		hooksecurefunc(S, "UpdateFrameShadows", function()
			if AreBarShadowsEnabled() then
				AS:RefreshDetailsBarShadows()
			end
		end)
	end

	-- Apply to bars which already existed before AddOnSkins installed its hook.
	local function InitialDetailsRefresh()
		AS:RefreshDetailsClassGradients()
		AS:RefreshDetailsBarShadows()
	end

	if E.Delay then
		E:Delay(0.10, InitialDetailsRefresh)
		E:Delay(1.00, InitialDetailsRefresh)
	else
		InitialDetailsRefresh()
	end
end)
