local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local UF = E:GetModule("UnitFrames")

--Lua functions
--WoW API / Variables

local RestingTextures = {
	["DEFAULT"] = [[Interface\CharacterFrame\UI-StateIcon]],
	["RESTING"] = E.Media.Textures.Resting,
	["MATERIAL_RESTING"] = E.Media.Textures.MaterialResting,
	["RESTING1"] = E.Media.Textures.Resting1
}

function UF:RestingIndicatorPostUpdate()
	local frame = self.__owner
	local db = frame and frame.db and frame.db.RestIcon
	if db and db.preview then
		self:Show()
	end
end

function UF:Construct_RestingIndicator(frame)
	local icon = frame.RaisedElementParent.TextureParent:CreateTexture(nil, "OVERLAY")
	icon.__owner = frame
	icon.PostUpdate = UF.RestingIndicatorPostUpdate
	return icon
end

function UF:Configure_RestingIndicator(frame)
	if not frame.VARIABLES_SET then return end

	local Icon = frame.RestingIndicator
	local db = frame.db.RestIcon
	local showPreview = db.preview == true

	if db.enable then
		if not frame:IsElementEnabled("RestingIndicator") then
			frame:EnableElement("RestingIndicator")
		end
	elseif frame:IsElementEnabled("RestingIndicator") then
		frame:DisableElement("RestingIndicator")
	end

	if db.enable or showPreview then
		Icon.__owner = frame

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
		elseif db.texture ~= "DEFAULT" and RestingTextures[db.texture] then
			Icon:SetTexture(RestingTextures[db.texture])
			Icon:SetTexCoord(0, 1, 0, 1)
		else
			Icon:SetTexture(RestingTextures.DEFAULT)
			Icon:SetTexCoord(0, .5, 0, .421875)
		end

		Icon:Size(db.size)
		Icon:ClearAllPoints()
		if frame.ORIENTATION ~= "RIGHT" and (frame.USE_PORTRAIT and not frame.USE_PORTRAIT_OVERLAY) then
			Icon:Point("CENTER", frame.Portrait, db.anchorPoint, db.xOffset, db.yOffset)
		else
			Icon:Point("CENTER", frame.Health, db.anchorPoint, db.xOffset, db.yOffset)
		end

		if showPreview then
			Icon:Show()
		elseif db.enable and Icon.ForceUpdate then
			Icon:ForceUpdate()
		else
			Icon:Hide()
		end
	else
		Icon:Hide()
	end
end
