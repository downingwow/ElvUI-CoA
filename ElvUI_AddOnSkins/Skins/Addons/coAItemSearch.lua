local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

if not AS:IsAddonLODorEnabled("CoAItemSearch") then return end

local _G = _G
local pcall, select, unpack = pcall, select, unpack

-- CoA Item Search 1.1
-- Appearance only: sizes, positions, scripts and the .additem logic stay untouched.
S:AddCallbackForAddon("CoAItemSearch", "CoAItemSearch", function()
	if not E.db or not E.db.addOnSkins or not E.db.addOnSkins.skins.CoAItemSearch then return end

	local frame = _G.CoAItemSearchFrame
	if not frame or frame.__AS_CoAItemSearch then return end
	frame.__AS_CoAItemSearch = true

	-- Main window: drop the Blizzard dialog border/background and the header plate
	frame:SetBackdrop(nil)

	for i = 1, select("#", frame:GetRegions()) do
		local region = select(i, frame:GetRegions())
		if region and region.GetObjectType and region:GetObjectType() == "Texture" then
			region:Hide()
		end
	end

	-- Apply the template only after the old textures are gone (backdrop textures are frame regions in 3.3.5)
	frame:SetTemplate("Transparent")
	frame:CreateShadow(5)

	-- Title text (was anchored to the header plate)
	for i = 1, select("#", frame:GetRegions()) do
		local region = select(i, frame:GetRegions())
		if region and region.GetObjectType and region:GetObjectType() == "FontString" and region:GetText() == "CoA Item Search" then
			region:ClearAllPoints()
			region:Point("TOP", frame, "TOP", 0, -8)
			region:FontTemplate(nil, 14)
			region:SetTextColor(unpack(E.media.rgbvaluecolor))
		end
	end

	-- Search box and scroll bar
	if _G.CoAItemSearchBox then
		S:HandleEditBox(_G.CoAItemSearchBox)
		_G.CoAItemSearchBox.backdrop:Point("TOPLEFT", -2, 0)
		_G.CoAItemSearchBox.backdrop:Point("BOTTOMRIGHT", 0, 0)
	end
	if _G.CoAItemSearchScrollScrollBar then
		S:HandleScrollBar(_G.CoAItemSearchScrollScrollBar)
	end

	-- Children: close button and the result rows
	local scroll, box = _G.CoAItemSearchScroll, _G.CoAItemSearchBox
	for i = 1, select("#", frame:GetChildren()) do
		local child = select(i, frame:GetChildren())

		if child.add and child.qty then -- result row
			-- Highlight
			child:SetHighlightTexture(E.Media.Textures.Highlight or E.media.blankTex)
			local hl = child:GetHighlightTexture()
			if hl then
				hl:SetTexture(E.media.blankTex)
				hl:SetVertexColor(1, 1, 1, 0.12)
				hl:SetAllPoints()
			end

			-- Icon with border
			if child.icon then
				child.icon:SetTexCoord(unpack(E.TexCoords))
				local border = CreateFrame("Frame", nil, child)
				border:SetTemplate("Default")
				border:SetBackdropColor(0, 0, 0, 0)
				border:Point("TOPLEFT", child.icon, -1, 1)
				border:Point("BOTTOMRIGHT", child.icon, 1, -1)
				border:SetFrameLevel(child:GetFrameLevel() + 2)
				child.__AS_iconBorder = border
			end

			-- Add item button
			S:HandleButton(child.add)

			-- Amount box (own tooltip-style backdrop -> ElvUI input look)
			child.qty:SetBackdrop(nil)
			child.qty:SetTemplate("Default")
			child.qty:SetBackdropColor(unpack(E.media.backdropcolor))
			child.qty:FontTemplate(nil, 12)
		elseif child ~= box and child ~= scroll and child:GetObjectType() == "Button" and not child:GetName() then
			S:HandleCloseButton(child, frame)
		end
	end
end)
