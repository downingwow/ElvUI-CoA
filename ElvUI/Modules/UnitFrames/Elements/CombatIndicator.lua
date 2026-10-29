local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local UF = E:GetModule("UnitFrames")

--Lua functions
--WoW API / Variables

local CombatTextures = {
	["COMBAT"] = E.Media.Textures.Combat,
	["MATERIAL_COMBAT"] = E.Media.Textures.MaterialCombat,
	["DEFAULT"] = [[Interface\CharacterFrame\UI-StateIcon]],
	["ATTACK"] = [[Interface\CURSOR\Attack]],
	["ALERT"] = [[Interface\DialogFrame\UI-Dialog-Icon-AlertNew]],
	["ALERT2"] = [[Interface\OptionsFrame\UI-OptionsFrame-NewFeatureIcon]],
	["ARTHAS"] = [[Interface\LFGFRAME\UI-LFR-PORTRAIT]],
	["SKULL"] = [[Interface\LootFrame\LootPanel-Icon]],
}

function UF:CombatIndicatorPostUpdate()
	local frame = self.__owner
	local db = frame and frame.db and frame.db.CombatIcon
	if db and db.preview then
		self:Show()
	end
end

function UF:Construct_CombatIndicator(frame)
	local icon = frame.RaisedElementParent.TextureParent:CreateTexture(nil, "OVERLAY")
	icon.__owner = frame
	icon.PostUpdate = UF.CombatIndicatorPostUpdate
	return icon
end

function UF:Configure_CombatIndicator(frame)
	if not frame.VARIABLES_SET then return end
	local Icon = frame.CombatIndicator
	local db = frame.db.CombatIcon
	local showPreview = db.preview == true

	Icon.__owner = frame
	Icon:ClearAllPoints()
	Icon:Point("CENTER", frame.Health, db.anchorPoint, db.xOffset, db.yOffset)
	Icon:Size(db.size)

	if db.defaultColor then
		Icon:SetVertexColor(1, 1, 1, 1)
		Icon:SetDesaturated(false)
	else
		Icon:SetVertexColor(db.color.r, db.color.g, db.color.b, db.color.a)
		Icon:SetDesaturated(true)
	end

	if db.texture == "CUSTOM" and db.customTexture then
		Icon:SetTexture(db.customTexture)
		Icon:SetTexCoord(0, 1, 0, 1)
	elseif db.texture ~= "DEFAULT" and CombatTextures[db.texture] then
		Icon:SetTexture(CombatTextures[db.texture])
		Icon:SetTexCoord(0, 1, 0, 1)
	else
		Icon:SetTexture(CombatTextures.DEFAULT)
		Icon:SetTexCoord(.5, 1, 0, .49)
	end

	if db.enable and not frame:IsElementEnabled("CombatIndicator") then
		frame:EnableElement("CombatIndicator")
	elseif not db.enable and frame:IsElementEnabled("CombatIndicator") then
		frame:DisableElement("CombatIndicator")
	end

	if showPreview then
		Icon:Show()
	elseif db.enable and Icon.ForceUpdate then
		Icon:ForceUpdate()
	elseif not db.enable then
		Icon:Hide()
	end
end
