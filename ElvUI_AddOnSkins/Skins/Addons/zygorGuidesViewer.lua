local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

-- Zygor Guides Viewer Remastered (Ordner "ZygorGuidesViewerRM") und das klassische "ZygorGuidesViewer"
local addonFolder
if AS:IsAddonLODorEnabled("ZygorGuidesViewerRM") then
	addonFolder = "ZygorGuidesViewerRM"
elseif AS:IsAddonLODorEnabled("ZygorGuidesViewer") then
	addonFolder = "ZygorGuidesViewer"
else
	return
end

local _G = _G
local unpack, ipairs, pcall, type = unpack, ipairs, pcall, type
local hooksecurefunc = hooksecurefunc

-- Skin: ElvUI-Look fuer das Zygor-Tracker-Fenster (RemasterFrames):
--   Rahmen, Kopfzeile, Toolbar-Buttons, Inhaltsflaeche, Scrollbar, Fortschrittsbalken, Action-Button-Leiste.
-- Zygor setzt seine Farben bei jedem ApplyRemasterSkin neu, deshalb werden die ElvUI-Farben
-- danach per hooksecurefunc erneut gesetzt. Die Logik des Addons bleibt unberuehrt
-- (die Schrittfarben "erledigt / offen" bleiben erhalten).

local function BackdropColor() return unpack(E.media.backdropfadecolor or E.media.backdropcolor) end
local function PanelColor() return unpack(E.media.backdropcolor) end
local function BorderColor() return unpack(E.media.bordercolor) end
local function AccentColor() return unpack(E.media.rgbvaluecolor) end

local function SetTex(tex, r, g, b, a)
	if not tex then return end
	if tex.SetColorTexture then
		tex:SetColorTexture(r, g, b, a or 1)
	else
		tex:SetTexture(r, g, b, a or 1)
	end
end

S:AddCallbackForAddon(addonFolder, "ZygorGuidesViewer", function()
	if not E.db or not E.db.addOnSkins or not E.db.addOnSkins.skins.ZygorGuidesViewer then return end

	local ZGV = _G.ZygorGuidesViewer
	if not ZGV then return end

	------------------------------------------------------------------
	-- Farben (werden nach jedem Zygor-Refresh erneut gesetzt)
	------------------------------------------------------------------
	local function ApplyColors()
		local f = ZGV.RemasterFrames
		if not f or not f.__AS_Zygor then return end

		f.root:SetBackdropColor(BackdropColor())
		f.root:SetBackdropBorderColor(BorderColor())
		f.content:SetBackdropColor(PanelColor())
		f.content:SetBackdropBorderColor(BorderColor())

		local pr, pg, pb = PanelColor()
		SetTex(f.headerBg, pr, pg, pb, 0.9)
		SetTex(f.toolbarBg, pr, pg, pb, 0.7)
		SetTex(f.footerBg, pr, pg, pb, 0.7)

		local br, bg, bb = BorderColor()
		SetTex(f.separator, br, bg, bb, 1)
		SetTex(f.footerSeparator, br, bg, bb, 1)

		if f.headerTitle then f.headerTitle:SetTextColor(AccentColor()) end
		if f.headerMeta then f.headerMeta:SetTextColor(0.8, 0.8, 0.8, 1) end
		if f.stepLabel then f.stepLabel:SetTextColor(1, 1, 1, 1) end

		local r, g, b = AccentColor()
		for _, btn in ipairs(f.__AS_Buttons) do
			-- Diese Felder benutzen Zygors eigene OnEnter/OnLeave-Handler
			btn.remasterBackColor = { pr, pg, pb, 1 }
			btn.remasterHoverColor = { r * 0.35 + pr * 0.65, g * 0.35 + pg * 0.65, b * 0.35 + pb * 0.65, 1 }
			btn.remasterBorderColor = { br, bg, bb, 1 }
			btn:SetBackdropColor(pr, pg, pb, 1)
			btn:SetBackdropBorderColor(br, bg, bb, 1)
		end
	end

	------------------------------------------------------------------
	-- Einmaliges Skinning der RemasterFrames
	------------------------------------------------------------------
	local function SkinFrames()
		local f = ZGV.RemasterFrames
		if not f or not f.root or f.__AS_Zygor then return end
		f.__AS_Zygor = true
		f.__AS_Buttons = {}

		-- Hauptrahmen + Inhaltsflaeche
		f.root:SetTemplate("Transparent")
		if f.root.CreateShadow then f.root:CreateShadow(5) end
		f.content:SetTemplate("Transparent")

		-- Schriften der Kopfzeile
		if f.headerTitle then f.headerTitle:FontTemplate(nil, 13, "OUTLINE") end
		if f.headerMeta then f.headerMeta:FontTemplate(nil, 11) end
		if f.stepLabel then f.stepLabel:FontTemplate(nil, 11) end

		-- Toolbar-Buttons (die Pfeil-/Symboltexturen von Zygor bleiben erhalten)
		local buttons = {
			f.guideButton, f.prevButton, f.nextButton,
			f.closeButton, f.settingsButton, f.miniButton, f.lockButton,
		}
		for _, btn in ipairs(buttons) do
			btn:SetTemplate("Default")
			btn:HookScript("OnEnter", function(self) self:SetBackdropBorderColor(AccentColor()) end)
			btn:HookScript("OnLeave", function(self) self:SetBackdropBorderColor(BorderColor()) end)
			local fs = btn:GetFontString()
			if fs then fs:FontTemplate(nil, 11) end
			f.__AS_Buttons[#f.__AS_Buttons + 1] = btn
		end

		-- Scrollbar der Schrittliste
		if _G.ZygorGuidesViewerFrameScrollScrollBar then
			pcall(S.HandleScrollBar, S, _G.ZygorGuidesViewerFrameScrollScrollBar)
		end

		ApplyColors()
	end

	------------------------------------------------------------------
	-- Fortschrittsbalken (unten im Tracker)
	------------------------------------------------------------------
	local function SkinProgress()
		local bar = ZGV.GuideProgressBar
		if not bar or not bar.fill or not bar.bg then return end
		local pr, pg, pb = PanelColor()
		SetTex(bar.bg, pr, pg, pb, 1)
		SetTex(bar.fill, AccentColor())
		if not bar.__AS_Zygor then
			bar.__AS_Zygor = true
			bar:SetTemplate("Default")
			bar:SetBackdropColor(0, 0, 0, 0)
			bar.fill:SetDrawLayer("ARTWORK")
		end
		bar:SetBackdropBorderColor(BorderColor())
	end

	------------------------------------------------------------------
	-- Action-Button-Leiste (Zauber-/Item-Buttons am Tracker)
	------------------------------------------------------------------
	local function SkinActionBar()
		local bar = ZGV.ActionButtonBar
		if not bar then return end
		if not bar.__AS_Zygor then
			bar.__AS_Zygor = true
			bar:SetTemplate("Transparent")
			if bar.CreateShadow then bar:CreateShadow(5) end
			for _, button in ipairs(bar.buttons or {}) do
				button:SetTemplate("Default")
				local overlay = button.overlay
				if overlay and overlay.icon then overlay.icon:SetTexCoord(unpack(E.TexCoords)) end
				if overlay and overlay.cooldown and E.RegisterCooldown then
					E:RegisterCooldown(overlay.cooldown)
				end
			end
			if bar.close and bar.close.x then
				bar.close.x:FontTemplate(nil, 12, "OUTLINE")
			end
		end
		bar:SetBackdropColor(BackdropColor())
		bar:SetBackdropBorderColor(BorderColor())
		for _, button in ipairs(bar.buttons or {}) do
			button:SetBackdropColor(0, 0, 0, 0)
			button:SetBackdropBorderColor(BorderColor())
		end
	end

	------------------------------------------------------------------
	-- Anwenden + Hooks auf die Zygor-Refresh-Funktionen
	------------------------------------------------------------------
	local function Refresh()
		SkinFrames()
		ApplyColors()
	end

	local function Hook(name, func)
		if type(ZGV[name]) == "function" then
			hooksecurefunc(ZGV, name, func)
		end
	end

	Hook("ApplyRemasterSkin", Refresh)
	Hook("UpdateGuideProgressWidgets", SkinProgress)
	Hook("ActionButtons_ApplyTheme", SkinActionBar)
	Hook("ActionButtons_Layout", SkinActionBar)

	if _G.ZygorGuidesViewerFrame then
		_G.ZygorGuidesViewerFrame:HookScript("OnShow", Refresh)
	end

	-- Falls der Tracker schon aufgebaut ist
	Refresh()
	SkinProgress()
	SkinActionBar()

	------------------------------------------------------------------
	-- Klassischer (nicht-Remaster) Viewer: einfacher Rahmen-Skin
	------------------------------------------------------------------
	local isRemaster = ZGV.IsRemasterSkin and ZGV:IsRemasterSkin()
	if _G.ZygorGuidesViewerFrame_Border and not isRemaster then
		_G.ZygorGuidesViewerFrame_Border:StripTextures()
		_G.ZygorGuidesViewerFrame:SetTemplate("Transparent")
		if _G.ZygorGuidesViewerFrameScrollScrollBar then
			pcall(S.HandleScrollBar, S, _G.ZygorGuidesViewerFrameScrollScrollBar)
		end
		for i = 1, 20 do
			local step = _G["ZygorGuidesViewerFrame_Step" .. i]
			if step then step:CreateBackdrop("Transparent") end
		end
	end
end)
