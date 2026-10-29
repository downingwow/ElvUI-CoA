local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

if not AS:IsAddonLODorEnabled("Ascension_AddonPanel") then return end

local _G = _G
local pcall, select, unpack, type, ipairs = pcall, select, unpack, type, ipairs
local hooksecurefunc = hooksecurefunc
local CreateFrame = CreateFrame
local IsAddOnLoaded = IsAddOnLoaded

-- Ascension Addon Panel 1.0.0 (frame "AddonPanel")
-- Appearance only: sizes, anchors, scripts, preset logic and the list/scroll logic stay untouched.
-- Rows of the addon list are created lazily by the scroll list, so they are (re)skinned and refreshed
-- every time the list or the window refreshes.

local function Kill(obj)
	if not obj then return end
	if obj.Kill then obj:Kill() else obj:Hide() end
end

local function ResetTexture(tex, r, g, b, a)
	-- Atlas textures (SetAtlas) are replaced by a plain colour texture
	tex:SetTexture(E.media.blankTex)
	tex:SetTexCoord(0, 1, 0, 1)
	tex:SetVertexColor(r, g, b, a)
end

----------------------------------------------------------------------------------------------------
-- Checkboxes
-- The Ascension check button template (atlas based) does not work with ElvUI's HandleCheckBox:
-- the checked texture never became visible. So the original art is hidden completely and the box
-- (border + fill) is drawn by the skin itself on a child frame. The fill simply follows
-- check:GetChecked(); for the list rows the checked state is set to "addon is loaded" (see RefreshRow).
----------------------------------------------------------------------------------------------------
local function HideTex(tex)
	if tex and tex.SetAlpha then tex:SetAlpha(0) end
end

local function SkinCheck(check)
	if check.__AS_AddonPanelBox then return end

	-- hide every bit of the original art, but keep the textures alive: the addon calls
	-- check:GetCheckedTexture():SetVertexColor(...) on every row update
	for i = 1, select("#", check:GetRegions()) do
		local region = select(i, check:GetRegions())
		if region and region.GetObjectType and region:GetObjectType() == "Texture" then
			region:SetAlpha(0)
		end
	end
	HideTex(check.GetNormalTexture and check:GetNormalTexture())
	HideTex(check.GetPushedTexture and check:GetPushedTexture())
	HideTex(check.GetHighlightTexture and check:GetHighlightTexture())
	HideTex(check.GetDisabledTexture and check:GetDisabledTexture())
	HideTex(check.GetCheckedTexture and check:GetCheckedTexture())
	HideTex(check.GetDisabledCheckedTexture and check:GetDisabledCheckedTexture())

	local box = CreateFrame("Frame", nil, check)
	box:SetFrameLevel(check:GetFrameLevel() + 1)
	box:SetAllPoints(check)
	box:SetTemplate("Default")

	local fill = box:CreateTexture(nil, "OVERLAY")
	fill:SetTexture(E.media.blankTex)
	fill:Point("TOPLEFT", box, "TOPLEFT", 3, -3)
	fill:Point("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
	local c = E.media.rgbvaluecolor
	fill:SetVertexColor(c[1], c[2], c[3])
	fill:Hide()

	check.__AS_AddonPanelBox = box
	check.__AS_AddonPanelFill = fill

	local function Sync(self)
		if self:GetChecked() then fill:Show() else fill:Hide() end
	end

	hooksecurefunc(check, "SetChecked", Sync)
	check:HookScript("OnClick", Sync)
	check:HookScript("OnShow", Sync)
	Sync(check)
end

-- list row: filled = addon is loaded (or enabled and loadable / load on demand), empty = not loaded. A change made in this panel session
-- (enabled ~= initialState) is shown as it was clicked, so there is feedback before the reload.
local function RefreshRow(item)
	local check = item.Check
	if not check or not check.__AS_AddonPanelFill then return end

	local addon = item.parent and item.parent.addons and item.parent.addons[item.index]
	if not addon then return end

	if not (InGlue and InGlue()) then
		local shown
		if addon.enabled ~= addon.initialState then
			shown = addon.enabled and true or false
		else
			-- same "ok" states the panel itself uses for its green/loaded colouring
			local reason = addon.reason
			local ok = addon.loadable or reason == "DEMAND_LOADED" or reason == "DEP_DEMAND_LOADED"
			shown = (addon.loaded or IsAddOnLoaded(addon.name or addon.id) or (addon.enabled and ok)) and true or false
		end
		check:SetChecked(shown)
	end

	-- the addon colours the checked texture red for error states and white otherwise
	local fill = check.__AS_AddonPanelFill
	local tex = check.GetCheckedTexture and check:GetCheckedTexture()
	local r, g, b
	if tex then r, g, b = tex:GetVertexColor() end
	if r and not (r > 0.99 and g > 0.99 and b > 0.99) then
		fill:SetVertexColor(r, g, b)
	else
		local c = E.media.rgbvaluecolor
		fill:SetVertexColor(c[1], c[2], c[3])
	end
end

----------------------------------------------------------------------------------------------------
-- List rows
----------------------------------------------------------------------------------------------------
local function SkinItem(item)
	if item.__AS_AddonPanel then return end
	item.__AS_AddonPanel = true

	-- header plate (atlas "addons_categoryheader_2") -> none, hover -> flat highlight
	item:SetNormalTexture("")
	item:SetHighlightTexture(E.media.blankTex)
	local hl = item:GetHighlightTexture()
	if hl then
		hl:SetTexCoord(0, 1, 0, 1)
		hl:SetVertexColor(1, 1, 1, 0.12)
		hl:ClearAllPoints()
		hl:Point("TOPLEFT", item, "TOPLEFT", 1, -1)
		hl:Point("BOTTOMRIGHT", item, "BOTTOMRIGHT", -1, 1)
	end

	if item.Check then SkinCheck(item.Check) end

	if type(item.Update) == "function" then
		hooksecurefunc(item, "Update", RefreshRow)
	end
end

local function ScanItems(frame, depth)
	for i = 1, frame:GetNumChildren() do
		local child = select(i, frame:GetChildren())
		if child then
			if child.Check and child.Text then
				SkinItem(child)
				RefreshRow(child)
			elseif depth > 0 then
				ScanItems(child, depth - 1)
			end
		end
	end
end

local function FindScrollBar(list)
	local bar = list.ScrollBar or list.scrollBar or list.Slider
	if bar then return bar end

	local function scan(frame, depth)
		for i = 1, frame:GetNumChildren() do
			local child = select(i, frame:GetChildren())
			if child then
				if child.GetObjectType and child:GetObjectType() == "Slider" then
					return child
				end
				if depth > 0 then
					local found = scan(child, depth - 1)
					if found then return found end
				end
			end
		end
	end

	return scan(list, 2)
end

local function SkinInfoText(block)
	if not block or block.__AS_AddonPanel then return end
	block.__AS_AddonPanel = true

	-- atlas divider line -> 1px line in ElvUI's border colour
	local divider = block.Divider
	if divider then
		local c = E.media.bordercolor
		ResetTexture(divider, c[1], c[2], c[3], 1)
		divider:SetHeight(1)
	end
end

----------------------------------------------------------------------------------------------------
-- Window
----------------------------------------------------------------------------------------------------
S:AddCallbackForAddon("Ascension_AddonPanel", "Ascension_AddonPanel", function()
	if not E.db or not E.db.addOnSkins or not E.db.addOnSkins.skins.Ascension_AddonPanel then return end

	local frame = _G.AddonPanel
	if not frame or frame.__AS_AddonPanel then return end
	frame.__AS_AddonPanel = true

	-- NineSlice border/background pieces -> removed (title text stays)
	local nine = frame.NineSlice
	if nine then
		for i = 1, select("#", nine:GetRegions()) do
			local region = select(i, nine:GetRegions())
			if region and region.GetObjectType and region:GetObjectType() == "Texture" then
				Kill(region)
			end
		end
		if nine.Title then
			nine.Title:FontTemplate(nil, 14)
			nine.Title:SetTextColor(unpack(E.media.rgbvaluecolor))
		end
	end

	frame:SetTemplate("Transparent")
	if frame.CreateShadow then frame:CreateShadow(5) end

	-- inner list/info area (atlas "addons_innerframe") -> own bordered panel
	if frame.InnerFrameTexture then
		Kill(frame.InnerFrameTexture)
		local inner = CreateFrame("Frame", nil, frame)
		inner:SetFrameLevel(frame:GetFrameLevel())
		inner:Point("TOPLEFT", frame, "TOPLEFT", 12, -58)
		inner:Point("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -12, 32)
		inner:SetTemplate("Default")
		frame.__AS_InnerFrame = inner
	end

	if frame.ClosePanelButton then
		S:HandleCloseButton(frame.ClosePanelButton, frame)
	end

	for _, key in ipairs({ "CloseButton", "ApplyButton", "DisableAllButton", "EnableAllButton", "ShowPresets" }) do
		if frame[key] then S:HandleButton(frame[key]) end
	end

	-- search box (SearchBoxTemplate): drop the template art, keep the search icon
	local box = frame.SearchBox
	if box then
		for i = 1, select("#", box:GetRegions()) do
			local region = select(i, box:GetRegions())
			if region and region ~= box.SearchIcon and region.GetObjectType and region:GetObjectType() == "Texture" then
				region:SetAlpha(0)
			end
		end
		pcall(S.HandleEditBox, S, box)
		if not box.backdrop and box.CreateBackdrop then
			box:CreateBackdrop("Default")
		end
		if box.backdrop then
			box.backdrop:ClearAllPoints()
			box.backdrop:Point("TOPLEFT", box, "TOPLEFT", -2, 0)
			box.backdrop:Point("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
		end
	end

	-- addon list: selection bar, scroll bar, rows
	local list = frame.AddonList
	if list then
		local selected = list.GetSelectedHighlight and list:GetSelectedHighlight()
		if selected then
			local c = E.media.rgbvaluecolor
			ResetTexture(selected, c[1], c[2], c[3], 0.25)
		end

		local bar = FindScrollBar(list)
		if bar and not bar.__AS_AddonPanel then
			bar.__AS_AddonPanel = true
			pcall(S.HandleScrollBar, S, bar)
		end

		ScanItems(list, 3)
		if type(list.RefreshScrollFrame) == "function" then
			hooksecurefunc(list, "RefreshScrollFrame", function() ScanItems(list, 3) end)
		end
	end

	-- info pane
	local info = frame.AddonInfo
	if info then
		for _, key in ipairs({ "Name", "Dependencies", "Loadable", "Author", "Version", "Notes", "DisabledFor" }) do
			SkinInfoText(info[key])
		end
		if info.LoadOutOfDate then SkinCheck(info.LoadOutOfDate) end
		if info.LoadUnknown then SkinCheck(info.LoadUnknown) end
	end

	-- dragging: forward drags from the title strip, the info pane and the inner panel to the window
	local function MakeDragHandle(target)
		if not target then return end
		target:EnableMouse(true)
		target:RegisterForDrag("LeftButton")
		target:SetScript("OnDragStart", function()
			frame.__AS_Moving = true
			frame:StartMoving()
		end)
		target:SetScript("OnDragStop", function()
			frame:StopMovingOrSizing()
			frame.__AS_Moving = nil
			frame.__AS_UserMoved = true
			frame.__AS_SavePosition()
		end)
	end

	local header = CreateFrame("Frame", nil, frame)
	header:SetFrameLevel(frame:GetFrameLevel() + 2)
	header:Point("TOPLEFT", frame, "TOPLEFT", 0, 0)
	header:Point("BOTTOMRIGHT", frame, "TOPRIGHT", -30, -58)
	MakeDragHandle(header)
	MakeDragHandle(frame.__AS_InnerFrame)
	MakeDragHandle(frame.AddonInfo)
	frame:SetMovable(true)
	frame:SetClampedToScreen(true)

	-- Remember the window position.
	-- AddonPanel is a UIPanel ("center" area): the client puts it back to its default spot every time it is
	-- opened, so a dragged position was lost. The position (offset of the window centre from the screen
	-- centre) is stored in the AddOnSkins profile, applied on every show and re-applied whenever the panel
	-- manager changes the anchors again. Saved on drag stop and on hide, whatever moved the window.
	local function GetSaved()
		local db = E.db.addOnSkins
		return db and db.addonPanelPosition
	end

	local function IsAtSavedPosition(pos)
		if frame:GetNumPoints() ~= 1 then return false end
		local point, relativeTo, relativePoint, x, y = frame:GetPoint(1)
		return point == "CENTER" and relativeTo == UIParent and relativePoint == "CENTER"
			and math.abs((x or 0) - pos.x) < 0.5 and math.abs((y or 0) - pos.y) < 0.5
	end

	local function ApplyPosition()
		local pos = GetSaved()
		if not pos or frame.__AS_Moving or frame.__AS_Applying then return end
		if InCombatLockdown() and frame.IsProtected and frame:IsProtected() then return end
		if IsAtSavedPosition(pos) then return end

		frame.__AS_Applying = true
		frame:ClearAllPoints()
		frame:SetPoint("CENTER", UIParent, "CENTER", pos.x, pos.y)
		frame.__AS_Applying = nil
	end

	frame.__AS_SavePosition = function()
		local cx, cy = frame:GetCenter()
		local ux, uy = UIParent:GetCenter()
		if not (cx and ux and E.db.addOnSkins) then return end

		-- GetCenter is in the frame's own scale, the anchor offset is in the scale of the frame as well
		local ratio = frame:GetEffectiveScale() / UIParent:GetEffectiveScale()
		E.db.addOnSkins.addonPanelPosition = { x = cx - ux / ratio, y = cy - uy / ratio }
	end

	hooksecurefunc(frame, "SetPoint", function()
		if frame.__AS_Applying or frame.__AS_Moving then return end
		ApplyPosition()
	end)
	frame:HookScript("OnShow", function()
		ApplyPosition()
		if E.Delay then E:Delay(0, function() if frame:IsShown() then ApplyPosition() end end) end
	end)
	frame:HookScript("OnHide", function()
		-- only once the window was really moved (by our drag or by ElvUI's window mover)
		if not frame.__AS_Moving and (frame.__AS_UserMoved or frame.__ElvUIWindowMoverHasPosition) then
			frame.__AS_SavePosition()
		end
	end)
	if frame:IsShown() then ApplyPosition() end

	-- rows can be created or updated during a refresh; catch them there and on every show
	if type(frame.RefreshAddonList) == "function" then
		hooksecurefunc(frame, "RefreshAddonList", function()
			if list then ScanItems(list, 3) end
		end)
	end
	frame:HookScript("OnShow", function()
		if list then ScanItems(list, 3) end
	end)
end)
