local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

local _G = _G
local select, unpack, pcall = select, unpack, pcall
local CreateFrame = CreateFrame

-- Ghost buttons (FrameXML/GhostFrame): "Return to Graveyard" (GhostFrame) and
-- "Resurrect in closest town" (ClosestResFrame), shown at the top of the screen while dead.
-- Appearance only: sizes, anchors (the frames position themselves in OnShow/OnHide), scripts and
-- the resurrect logic stay untouched.

local function HideRegions(frame)
	for i = 1, select("#", frame:GetRegions()) do
		local region = select(i, frame:GetRegions())
		if region and region.GetObjectType and region:GetObjectType() == "Texture" then
			region:SetTexture(nil)
			region:SetAlpha(0)
		end
	end
	for _, getter in ipairs({"GetNormalTexture", "GetPushedTexture", "GetDisabledTexture", "GetHighlightTexture"}) do
		local tex = frame[getter] and frame[getter](frame)
		if tex then
			tex:SetTexture(nil)
			tex:SetAlpha(0)
		end
	end
end

local function SkinGhostButton(button)
	if not button or button.__AS_GhostFrame then return end
	button.__AS_GhostFrame = true

	HideRegions(button)
	button:SetTemplate("Transparent")
	button:CreateShadow(5)
	if button.StyleButton then pcall(button.StyleButton, button) end

	local contents = button.ContentsFrame
	if contents then
		local text = contents.Text
		if text then
			text:FontTemplate(nil, 12)
			text:SetTextColor(1, 1, 1)
		end

		local icon = contents.Icon
		if icon then
			icon:SetTexCoord(unpack(E.TexCoords))
			-- bordered icon: the frame sits below the contents (and thus below the icon texture)
			local border = CreateFrame("Frame", nil, button)
			border:SetFrameLevel(button:GetFrameLevel())
			border:SetTemplate("Default")
			border:Point("TOPLEFT", icon, "TOPLEFT", -1, 1)
			border:Point("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 1, -1)
			button.__AS_IconBorder = border
		end
	end

	button:HookScript("OnEnter", function(self)
		self:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor))
		if self.ContentsFrame and self.ContentsFrame.Text then
			self.ContentsFrame.Text:SetTextColor(unpack(E.media.rgbvaluecolor))
		end
	end)
	button:HookScript("OnLeave", function(self)
		self:SetBackdropBorderColor(unpack(E.media.bordercolor))
		if self.ContentsFrame and self.ContentsFrame.Text then
			self.ContentsFrame.Text:SetTextColor(1, 1, 1)
		end
	end)
end

local function LoadSkin()
	if not E.db or not E.db.addOnSkins or not E.db.addOnSkins.skins.GhostFrame then return end
	SkinGhostButton(_G.GhostFrame)
	SkinGhostButton(_G.ClosestResFrame)
end

if S.AddCallback then
	S:AddCallback("AS_GhostFrame", LoadSkin)
else
	local f = CreateFrame("Frame")
	f:RegisterEvent("PLAYER_LOGIN")
	f:SetScript("OnEvent", function(self) self:UnregisterAllEvents(); LoadSkin() end)
end
