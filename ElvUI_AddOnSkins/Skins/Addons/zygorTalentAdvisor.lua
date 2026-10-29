local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

-- Zygor Talent Advisor: eigenes Addon ("ZygorTalentAdvisor") oder Teil von ZygorGuidesViewerRM
local addonFolder
if AS:IsAddonLODorEnabled("ZygorGuidesViewerRM") then
	addonFolder = "ZygorGuidesViewerRM"
elseif AS:IsAddonLODorEnabled("ZygorTalentAdvisor") then
	addonFolder = "ZygorTalentAdvisor"
else
	return
end

local _G = _G
local unpack, ipairs, pcall, select = unpack, ipairs, pcall, select
local hooksecurefunc = hooksecurefunc

-- Zygor Talent Advisor 2.0 (Wotlk-Popout) + CoA-Variante (ZygorTalentAdvisorCOAPopout am Skillbaum-Fenster)

S:AddCallbackForAddon(addonFolder, "ZygorTalentAdvisor", function()
	if not E.db.addOnSkins.skins.ZygorTalentAdvisor then return end

	if _G.ZygorTalentAdvisorPopout and _G.ZygorTalentAdvisorPopoutButton then
	ZygorTalentAdvisorPopoutButton:Point("TOPRIGHT", -40, -39)
	ZygorTalentAdvisorPopoutButton:Size(26, 32)
	ZygorTalentAdvisorPopoutButton:SetTemplate("Default")
	ZygorTalentAdvisorPopoutButton:GetNormalTexture():SetTexCoord(0.1875, 0.796875, 0.125, 0.890625)
	ZygorTalentAdvisorPopoutButton:GetNormalTexture():SetInside()
	ZygorTalentAdvisorPopoutButton:GetPushedTexture():SetTexCoord(0.1875, 0.796875, 0.125, 0.890625)
	ZygorTalentAdvisorPopoutButton:GetPushedTexture():SetInside()
	ZygorTalentAdvisorPopoutButton:GetHighlightTexture():SetTexture(1, 1, 1, 0.3)
	ZygorTalentAdvisorPopoutButton:GetHighlightTexture():SetInside()

	ZygorTalentAdvisorPopout:StripTextures()
	ZygorTalentAdvisorPopout:SetTemplate("Transparent")

	ZygorTalentAdvisorPopoutScroll:Point("TOPLEFT", 11, -70)
	ZygorTalentAdvisorPopoutScroll:Point("BOTTOMRIGHT", -32, 70)

	ZygorTalentAdvisorPopoutScrollScrollBar:Point("TOPLEFT", ZygorTalentAdvisorPopoutScroll, "TOPRIGHT", 6, -15)
	ZygorTalentAdvisorPopoutScrollScrollBar:Point("BOTTOMLEFT", ZygorTalentAdvisorPopoutScroll, "BOTTOMRIGHT", 6, 16)

	for i = 1, ZygorTalentAdvisorPopoutScroll:GetNumChildren() do
		local child = select(i, ZygorTalentAdvisorPopoutScroll:GetChildren())
		if child:IsObjectType("Frame") and not child:GetName() then
			child:SetBackdrop(nil)
			child:CreateBackdrop("Transparent")
			child.backdrop:Point("TOPLEFT", 2, 1)
			child.backdrop:Point("BOTTOMRIGHT", -22, 0)
		end
	end

	S:HandleCloseButton(ZygorTalentAdvisorPopoutCloseButton, ZygorTalentAdvisorPopout)

	S:HandleScrollBar(ZygorTalentAdvisorPopoutScrollScrollBar)

	ZygorTalentAdvisorPopoutAcceptButton:StripTextures()
	S:HandleButton(ZygorTalentAdvisorPopoutConfigureButton)
	S:HandleButton(ZygorTalentAdvisorPopoutPreviewButton)
	S:HandleButton(ZygorTalentAdvisorPopoutAcceptButton)

	hooksecurefunc("ZygorTalentAdvisorPopout_Reparent", function()
		if ZTA.db.profile.windowdocked then
			if PlayerSpecTab1 and PlayerSpecTab1:IsShown() then
				ZygorTalentAdvisorPopout:Point("TOPLEFT", PlayerTalentFrame, "TOPRIGHT", 6, -12)
			else
				ZygorTalentAdvisorPopout:Point("TOPLEFT", PlayerTalentFrame, "TOPRIGHT", -33, -12)
			end
		end
	end)
	end

	------------------------------------------------------------------
	-- CoA Talent Advisor (Panel neben dem CoATalentFrame)
	------------------------------------------------------------------
	local ZTAC = _G.ZygorTalentAdvisorCOA
	if not ZTAC then return end

	local function SkinRow(row)
		if row.__AS_Zygor then return end
		row.__AS_Zygor = true
		local hl = row:GetHighlightTexture()
		if hl then hl:SetTexture(1, 1, 1, 0.1) end
	end

	local function SkinPopout()
		local f = ZTAC.Popout
		if not f or f.__AS_Zygor then return end
		f.__AS_Zygor = true

		f:SetTemplate("Transparent")
		if f.CreateShadow then f:CreateShadow(5) end
		if f.fill then f.fill:SetAlpha(0) end -- eigener Hintergrund-Layer nicht mehr noetig

		-- Schliessen-Button (unbenannt): am Minimize-Button-Icon erkennen
		for i = 1, f:GetNumChildren() do
			local child = select(i, f:GetChildren())
			if child:IsObjectType("Button") then
				local nt = child:GetNormalTexture()
				local path = nt and nt:GetTexture()
				if path and tostring(path):find("MinimizeButton") then
					S:HandleCloseButton(child, f)
					break
				end
			end
		end

		if f.drop then pcall(S.HandleDropDownBox, S, f.drop, 180) end
		if _G.ZygorTalentAdvisorCOAPopoutScrollScrollBar then
			pcall(S.HandleScrollBar, S, _G.ZygorTalentAdvisorCOAPopoutScrollScrollBar)
		end
		if f.loadButton then S:HandleButton(f.loadButton) end
		if f.modeButton then S:HandleButton(f.modeButton) end

		-- Zeilen werden spaeter bei Bedarf erzeugt
		for _, row in ipairs(f.rows) do SkinRow(row) end
		local origGetRow = f.GetRow
		f.GetRow = function(self, i)
			local row = origGetRow(self, i)
			SkinRow(row)
			return row
		end
	end

	if type(ZTAC.GetPopout) == "function" then
		hooksecurefunc(ZTAC, "GetPopout", SkinPopout)
	end
	if type(ZTAC.ApplyPanelOpacity) == "function" then
		-- Optionsregler fuer die Deckkraft setzt den Layer erneut -> wieder ausblenden
		hooksecurefunc(ZTAC, "ApplyPanelOpacity", function()
			local f = ZTAC.Popout
			if f and f.__AS_Zygor and f.fill then f.fill:SetAlpha(0) end
		end)
	end
	SkinPopout()
end)
