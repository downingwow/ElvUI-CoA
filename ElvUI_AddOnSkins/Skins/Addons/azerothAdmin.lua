local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

if not AS:IsAddonLODorEnabled("AzerothAdmin") then return end

local _G = _G
local pairs, ipairs, pcall, select, unpack, tonumber = pairs, ipairs, pcall, select, unpack, tonumber
local hooksecurefunc = hooksecurefunc

-- AzerothAdmin (AzerothCore GM addon, 3.3.5)
-- Everything is built with FrameLib: panels and buttons are plain frames with a solid color
-- texture (AzerothAdmin's own "style" colors). This skin hides those color textures and gives the
-- frames ElvUI templates. It changes appearance only; sizes, positions and scripts stay untouched.
-- Note: with the skin enabled, the color/transparency settings on AzerothAdmin's Misc page have no
-- visible effect any more.

-- Outer windows
local WINDOWS = {
	ma_bgframe = true, ma_popupframe = true, ma_popup2frame = true, ma_minibgframe = true,
}
-- Panels inside the windows (their FrameLib color texture is removed)
local PANELS = {
	ma_menubgframe = true, ma_topframe = true, ma_midframe = true, ma_leftframe = true, ma_rightframe = true,
	ma_popmenubgframe = true, ma_popuptopframe = true, ma_popupmidframe = true, ma_popupbottomframe = true,
	ma_popup2cframe = true, ma_miniframe = true,
}
-- Lists and graphs that sit on a black 70% texture: they become ElvUI insets
local INSETS = {
	ma_ContScrollBar = true, ma_ZoneScrollBar = true, ma_SubzoneScrollBar = true,
	ma_ticketscrollframe = true, ma_ticketdetailscrollframe = true,
	ma_PopupScrollBar = true, ma_popup2ScrollBar = true,
	ma_netgraphframe = true, ma_netgraphframe2 = true,
}
-- Color swatches on the Misc page: their texture IS the content, keep it and only add a border
local SWATCHES = {
	ma_bgcolorshowbutton = true, ma_frmcolorshowbutton = true, ma_btncolorshowbutton = true,
	ma_linkifiercolorbutton = true,
}
-- Buttons whose FrameLib texture is an icon file, not a color
local ICON_BUTTONS = {
	ma_mm_logoframe = true,
}

local function Try(label, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok then
		geterrorhandler()(("AddOnSkins AzerothAdmin (%s): %s"):format(tostring(label), tostring(err)))
	end
end

-- FrameLib:BuildFrame creates its color texture as the first, unnamed region of the frame.
local function KillFrameLibTexture(frame)
	local region = frame.GetRegions and (frame:GetRegions())
	if region and region.GetObjectType and region:GetObjectType() == "Texture" and not region:GetName() then
		region:Kill()
	end
end

-- Tab buttons: AzerothAdmin marks the active tab via SetGradientAlpha on the button texture
-- (start alpha 1 = active, 0 = inactive). The texture is hidden, so mirror that state on an overlay.
local function AddTabIndicator(button, texture)
	if button.__AS_AA_Tab then return end
	local overlay = button:CreateTexture(nil, "BORDER")
	overlay:SetTexture(E.media.blankTex or "Interface\\Buttons\\WHITE8X8")
	local r, g, b = unpack(E.media.rgbvaluecolor)
	overlay:SetVertexColor(r, g, b, 0.3)
	overlay:SetInside(button)
	overlay:Hide()
	button.__AS_AA_Tab = overlay

	hooksecurefunc(texture, "SetGradientAlpha", function(_, _, _, _, _, startAlpha)
		if (tonumber(startAlpha) or 0) >= 1 then overlay:Show() else overlay:Hide() end
	end)
end

local function IsTabButton(name)
	return name and (name:find("^ma_tabbutton_") or name:find("^ma_ptabbutton_"))
end

local function SkinWindow(frame)
	KillFrameLibTexture(frame)
	frame:SetTemplate("Transparent")
end

local function SkinPanel(frame)
	KillFrameLibTexture(frame)
	frame:SetTemplate("Transparent")
end

local function SkinInset(frame)
	KillFrameLibTexture(frame)
	frame:SetTemplate("Default")
end

local function SkinScrollBar(scrollFrame)
	local name = scrollFrame:GetName()
	local bar = scrollFrame.ScrollBar or (name and _G[name.."ScrollBar"])
	if bar and not bar.__AS_AA then
		bar.__AS_AA = true
		S:HandleScrollBar(bar)
	end
end

local function SkinColorButton(button, texture)
	if IsTabButton(button:GetName()) then
		AddTabIndicator(button, texture)
	end
	texture:Kill()
	S:HandleButton(button)
end

local function SkinItemButton(button)
	local name = button:GetName()
	local icon = _G[name.."IconTexture"]
	local colorTex = _G[name.."_texture"]
	if colorTex then colorTex:Kill() end

	button:SetNormalTexture("")
	button:SetTemplate("Default", true)
	if button.StyleButton then button:StyleButton() end
	if icon then
		icon:SetTexCoord(unpack(E.TexCoords))
		icon:SetInside()
		icon:SetDrawLayer("ARTWORK")
	end
end

local function SkinSwatch(button)
	if button.CreateBackdrop then button:CreateBackdrop("Default") end
end

local function SkinEditBox(box)
	local name = box:GetName()
	if name and _G[name.."Left"] and _G[name.."Middle"] then
		-- InputBoxTemplate
		S:HandleEditBox(box)
	elseif name and _G[name.."_texture"] then
		-- FrameLib editbox on a (button colored) texture: mail text, GO info boxes
		_G[name.."_texture"]:Kill()
		box:SetTemplate("Default")
		box:SetTextColor(1, 1, 1)
	elseif box.GetBackdrop and box:GetBackdrop() then
		-- Hand-made editboxes with a ChatFrameBackground backdrop
		box:SetTemplate("Default")
	end
end

-- AzerothAdmin styles its dropdowns itself (backdrop, "v" arrow, hover texture, nil arrow textures).
-- Undo that first so the regular ElvUI dropdown skin applies cleanly.
local function SkinDropDown(drop)
	local name = drop:GetName()
	local button = _G[name.."Button"]
	if drop.SetBackdrop then drop:SetBackdrop(nil) end
	if button then
		if button.arrow then button.arrow:Hide() end
		if button.hoverTexture then button.hoverTexture:Kill() end
		button:SetNormalTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Up")
		button:SetPushedTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Down")
		button:SetDisabledTexture("Interface\\ChatFrame\\UI-ChatIcon-ScrollDown-Disabled")
		button:SetHighlightTexture("Interface\\Buttons\\UI-Common-MouseHilight", "ADD")
	end
	S:HandleDropDownBox(drop, drop:GetWidth())
end

local function IsDropDown(frame)
	local name = frame:GetName()
	return name and _G[name.."Button"] and _G[name.."Text"] and _G[name.."Middle"] and true or false
end

local function SkinObject(obj)
	if not obj or obj.__AS_AA or not obj.GetObjectType then return end
	local objType = obj:GetObjectType()
	if objType == "FontString" or objType == "Texture" then return end
	obj.__AS_AA = true

	local name = obj:GetName()

	if name and WINDOWS[name] then
		Try(name, SkinWindow, obj)
	elseif name and PANELS[name] then
		Try(name, SkinPanel, obj)
	elseif objType == "CheckButton" then
		Try(name, S.HandleCheckBox, S, obj)
	elseif objType == "Slider" then
		-- scroll bars are handled through their scroll frame
		if not (name and name:find("ScrollBar$")) then
			Try(name, S.HandleSliderFrame, S, obj)
		end
	elseif objType == "EditBox" then
		Try(name, SkinEditBox, obj)
	elseif objType == "ScrollFrame" then
		if name and INSETS[name] then Try(name, SkinInset, obj) end
		Try(name, SkinScrollBar, obj)
	elseif objType == "Button" then
		if not name or ICON_BUTTONS[name] then return end
		if SWATCHES[name] then
			Try(name, SkinSwatch, obj)
		elseif _G[name.."IconTexture"] and _G[name.."NormalTexture"] then
			Try(name, SkinItemButton, obj)
		elseif _G[name.."_texture"] then
			Try(name, SkinColorButton, obj, _G[name.."_texture"])
		end
	elseif objType == "Frame" then
		if name and INSETS[name] then
			Try(name, SkinInset, obj)
		elseif IsDropDown(obj) then
			Try(name, SkinDropDown, obj)
		end
	end
end

local function Visit(frame, depth)
	if not frame or depth > 10 or not frame.GetChildren then return end
	for i = 1, select("#", frame:GetChildren()) do
		local child = select(i, frame:GetChildren())
		SkinObject(child)
		Visit(child, depth + 1)
	end
end

-- The right-click menu of search results is a plain frame with its own backdrop and text buttons.
local function SkinContextMenu()
	local menu = _G.ma_popupContextMenu
	if not menu or menu.__AS_AA then return end
	menu.__AS_AA = true
	menu:SetTemplate("Transparent")
	for _, btnName in ipairs({ "ma_ctxFavButton", "ma_ctxRemoveFavButton", "ma_ctxCopyIdButton", "ma_ctxCopyNameButton" }) do
		local btn = _G[btnName]
		if btn and btn.StyleButton then btn:StyleButton() end
	end
end

-- AzerothAdmin also gives every DropDownList (UI-wide) its own backdrop on top of ElvUI's skin.
-- Remove that backdrop again; AzerothAdmin's hooks run before ours, so this always comes last.
local function CleanDropDownList(level)
	local list = _G["DropDownList"..(tonumber(level) or 1)]
	if list and list.styledBackdrop and list.SetBackdrop and not list.__AS_AA_Clean then
		list.__AS_AA_Clean = true
		list:SetBackdrop(nil)
	end
end

local function SkinAll()
	local FrameLib = _G.FrameLib or (LibStub and LibStub("FrameLib-1.0", true))
	if FrameLib and FrameLib.group then
		for _, group in pairs(FrameLib.group) do
			for _, obj in ipairs(group) do
				SkinObject(obj)
			end
		end
	end

	-- anything not registered in a FrameLib group
	for _, root in ipairs({ "ma_bgframe", "ma_popupframe", "ma_popup2frame", "ma_minibgframe" }) do
		local frame = _G[root]
		if frame then
			SkinObject(frame)
			Visit(frame, 0)
		end
	end

	SkinContextMenu()

	for level = 1, (UIDROPDOWNMENU_MAXLEVELS or 2) do
		CleanDropDownList(level)
	end
end

local skinned
local function Run()
	if skinned or not _G.ma_bgframe then return end
	skinned = true
	SkinAll()

	hooksecurefunc("UIDropDownMenu_CreateFrames", function(level) CleanDropDownList(level) end)
	hooksecurefunc("ToggleDropDownMenu", function(level) CleanDropDownList(level) end)
end

S:AddCallbackForAddon("AzerothAdmin", "AzerothAdmin", function()
	if not E.db or not E.db.addOnSkins or not E.db.addOnSkins.skins.AzerothAdmin then return end
	local AA = _G.AzerothAdmin
	if not AA then return end

	if _G.ma_bgframe then
		Run()
	else
		-- AzerothAdmin builds its frames in OnInitialize (CreateFrames + dropdown/slider setup)
		hooksecurefunc(AA, "OnInitialize", Run)
	end
end)
