local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

if not AS:IsAddonLODorEnabled("AtlasLoot") then return end

local _G = _G
local select, unpack, type, pairs, ipairs, pcall = select, unpack, type, pairs, ipairs, pcall
local find, match = string.find, string.match
local rawget = rawget
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc

-- AtlasLoot Ascension Edition - works with both UI generations:
--   7.x : main window AtlasLoot.mainUI, advanced search panel AtlasLoot.searchPanel
--   8.x : main window AtlasLoot.ui with the tabs Loot / Map / Wishlist / Search (AtlasLoot.ui.tabs)
-- Appearance only: sizes, anchors, scripts, tables and search logic stay untouched.
--
-- AtlasLoot builds its whole UI in OnEnable (PLAYER_LOGIN) and has its own skin switcher
-- (Options -> Skin: Modern / Old AtlasLoot / ElvUI Dark) which re-applies backdrops, NineSlice pieces and
-- button textures. So the skin is installed right after AtlasLoot:InitializeSkins() and AtlasLoot:SetSkin()
-- is wrapped, so the ElvUI look wins whichever AtlasLoot skin is selected.

local DROP_PIECES = {
	"TopLeft", "TopRight", "BottomLeft", "BottomRight",
	"TopMiddle", "MiddleLeft", "MiddleRight", "BottomMiddle", "MiddleMiddle",
}
local NINE_PIECES = {
	"RightEdge", "LeftEdge", "BottomEdge", "TopEdge",
	"BottomRightCorner", "BottomLeftCorner", "TopRightCorner", "TopLeftCorner",
}

local function Alpha0(tex)
	if tex and tex.SetAlpha then tex:SetAlpha(0) end
end

local function GetUI(AL)
	return AL.ui or AL.mainUI
end

local function FindCloseButton(parent)
	for i = 1, parent:GetNumChildren() do
		local child = select(i, parent:GetChildren())
		if child and child:GetObjectType() == "Button" then
			local normal = child:GetNormalTexture()
			local tex = normal and normal:GetTexture()
			if type(tex) == "string" and find(tex, "MinimizeButton") then
				return child
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Check boxes
-- Ascension's check button templates are atlas based, so the original art is hidden and a plain
-- ElvUI box is drawn instead. The fill follows check:GetChecked().
----------------------------------------------------------------------------------------------------
local function SkinCheck(check)
	if not check or check.__AS_AtlasLootBox then return end

	for i = 1, select("#", check:GetRegions()) do
		local region = select(i, check:GetRegions())
		if region and region.GetObjectType and region:GetObjectType() == "Texture" then
			region:SetAlpha(0)
		end
	end
	Alpha0(check.GetNormalTexture and check:GetNormalTexture())
	Alpha0(check.GetPushedTexture and check:GetPushedTexture())
	Alpha0(check.GetHighlightTexture and check:GetHighlightTexture())
	Alpha0(check.GetDisabledTexture and check:GetDisabledTexture())
	Alpha0(check.GetCheckedTexture and check:GetCheckedTexture())
	Alpha0(check.GetDisabledCheckedTexture and check:GetDisabledCheckedTexture())

	local box = CreateFrame("Frame", nil, check)
	box:SetFrameLevel(check:GetFrameLevel() + 1)
	box:Size(18, 18)
	box:Point("CENTER", check, "CENTER", 0, 0)
	box:SetTemplate("Default")

	local fill = box:CreateTexture(nil, "OVERLAY")
	fill:SetTexture(E.media.blankTex)
	fill:Point("TOPLEFT", box, "TOPLEFT", 3, -3)
	fill:Point("BOTTOMRIGHT", box, "BOTTOMRIGHT", -3, 3)
	local c = E.media.rgbvaluecolor
	fill:SetVertexColor(c[1], c[2], c[3])
	fill:Hide()

	check.__AS_AtlasLootBox = box

	local function Sync(self)
		if self:GetChecked() then fill:Show() else fill:Hide() end
	end
	hooksecurefunc(check, "SetChecked", Sync)
	check:HookScript("OnClick", Sync)
	check:HookScript("OnShow", Sync)
	Sync(check)
end

----------------------------------------------------------------------------------------------------
-- Buttons
----------------------------------------------------------------------------------------------------
-- AtlasLootDropMenuTemplate (nine-slice "filter dropdown" button) -> flat ElvUI button, arrow icon kept
local function SkinDropButton(btn)
	if not btn or btn.__AS_AtlasLootBtn then return end
	btn.__AS_AtlasLootBtn = true

	for _, key in ipairs(DROP_PIECES) do
		Alpha0(btn[key])
	end

	btn:SetTemplate("Default")
	btn:HookScript("OnEnter", function(self)
		if self:IsEnabled() then
			self:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor))
		end
	end)
	btn:HookScript("OnLeave", function(self)
		self:SetBackdropBorderColor(unpack(E.media.bordercolor))
	end)
end

local function SkinButton(btn)
	if not btn or btn.__AS_AtlasLootBtn then return end
	btn.__AS_AtlasLootBtn = true
	S:HandleButton(btn)
end

-- InputBoxTemplate (7.x) and SearchBoxTemplate (8.x) edit boxes
local function SkinInput(box)
	if not box or box.__AS_AtlasLootInput then return end
	box.__AS_AtlasLootInput = true

	local searchTemplate = box.Left and box.Middle and box.Right
	if searchTemplate then
		-- hide the template art, keep the search icon
		for i = 1, select("#", box:GetRegions()) do
			local region = select(i, box:GetRegions())
			if region and region ~= box.SearchIcon and region ~= box.searchIcon
				and region.GetObjectType and region:GetObjectType() == "Texture" then
				region:SetAlpha(0)
			end
		end
	end

	pcall(S.HandleEditBox, S, box)
	if not box.backdrop and box.CreateBackdrop then
		box:CreateBackdrop("Default")
	end

	if box.backdrop then
		box.backdrop:ClearAllPoints()
		if box:GetHeight() > 28 then
			-- the addon's small number boxes are 35px high, the art only fills the middle ~20px
			box.backdrop:Point("TOPLEFT", box, "TOPLEFT", -2, -7)
			box.backdrop:Point("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 7)
		else
			box.backdrop:Point("TOPLEFT", box, "TOPLEFT", -2, 0)
			box.backdrop:Point("BOTTOMRIGHT", box, "BOTTOMRIGHT", 0, 0)
		end
	end
end

local function SkinScrollBar(scroll)
	if not scroll or scroll.__AS_AtlasLootScroll then return end
	scroll.__AS_AtlasLootScroll = true
	local name = scroll.GetName and scroll:GetName()
	local bar = scroll.ScrollBar or (name and _G[name .. "ScrollBar"])
	if bar then pcall(S.HandleScrollBar, S, bar) end
end

----------------------------------------------------------------------------------------------------
-- Tabs (8.x: Loot / Map / Wishlist / Search, AtlasLootTabTemplate)
----------------------------------------------------------------------------------------------------
local function SkinTab(tab)
	local btn = tab and tab.tabButton
	if not btn or btn.__AS_AtlasLootTab then return end
	btn.__AS_AtlasLootTab = true

	-- tab art (retail TabSystem textures) -> hidden, the atlas icon is kept
	for i = 1, select("#", btn:GetRegions()) do
		local region = select(i, btn:GetRegions())
		if region and region ~= btn.IconAtlas and region.GetObjectType and region:GetObjectType() == "Texture" then
			region:SetAlpha(0)
		end
	end
	for _, getter in ipairs({ "GetNormalTexture", "GetPushedTexture", "GetHighlightTexture", "GetDisabledTexture", "GetCheckedTexture" }) do
		local tex = btn[getter] and btn[getter](btn)
		if tex and tex ~= btn.IconAtlas then Alpha0(tex) end
	end

	btn:SetTemplate("Default")

	local function Sync(self)
		if self:GetChecked() then
			self:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor))
		else
			self:SetBackdropBorderColor(unpack(E.media.bordercolor))
		end
	end
	hooksecurefunc(btn, "SetChecked", Sync)
	if btn.UpdateButton then hooksecurefunc(btn, "UpdateButton", Sync) end
	btn:HookScript("OnEnter", function(self)
		self:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor))
	end)
	btn:HookScript("OnLeave", Sync)
	Sync(btn)
end

----------------------------------------------------------------------------------------------------
-- Item list buttons (AtlasLootItemTemplate)
-- 7.x: itemframe.buttons[column][row]   8.x: itemframe.buttons[i]
----------------------------------------------------------------------------------------------------
local function SkinItemButton(btn)
	if not btn or btn.__AS_AtlasLootItem or not btn.Icon then return end
	btn.__AS_AtlasLootItem = true

	-- flat hover highlight instead of the quest-title glow
	btn:SetHighlightTexture(E.media.blankTex, "ADD")
	local hl = btn:GetHighlightTexture()
	if hl then
		hl:SetVertexColor(1, 1, 1, 0.12)
		hl:ClearAllPoints()
		hl:SetAllPoints(btn)
	end

	btn.Icon:SetTexCoord(unpack(E.TexCoords))
	local border = CreateFrame("Frame", nil, btn)
	border:SetFrameLevel(btn:GetFrameLevel() + 2)
	border:SetTemplate("Default")
	border:SetBackdropColor(0, 0, 0, 0)
	border:Point("TOPLEFT", btn.Icon, -1, 1)
	border:Point("BOTTOMRIGHT", btn.Icon, 1, -1)
	btn.__AS_AtlasLootBorder = border

	-- icon border follows the item quality: AtlasLoot prefixes the name with the quality colour code
	if btn.Name then
		hooksecurefunc(btn.Name, "SetText", function(_, text)
			local r, g, b = unpack(E.media.bordercolor)
			if type(text) == "string" then
				local hr, hg, hb = match(text, "^|c%x%x(%x%x)(%x%x)(%x%x)")
				if hr and not (hr == "ff" and hg == "ff" and hb == "ff") and not (hr == "ff" and hg == "d2" and hb == "00") then
					r, g, b = tonumber(hr, 16) / 255, tonumber(hg, 16) / 255, tonumber(hb, 16) / 255
				end
			end
			border:SetBackdropBorderColor(r, g, b)
		end)
	end
end

local function ForEachItemButton(AL, func)
	local buttons = AL.itemframe and AL.itemframe.buttons
	if not buttons then return end
	for _, entry in pairs(buttons) do
		if type(entry) == "table" and entry.GetObjectType then
			func(entry)
		elseif type(entry) == "table" then
			for _, btn in pairs(entry) do func(btn) end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Rows of the difficulty list and the loot-table list (created lazily by the addon)
----------------------------------------------------------------------------------------------------
local function SkinRow(row)
	if not row or row.__AS_AtlasLootRow then return end
	row.__AS_AtlasLootRow = true

	row:SetHighlightTexture(E.media.blankTex, "ADD")
	local hl = row:GetHighlightTexture()
	if hl then
		hl:SetVertexColor(1, 1, 1, 0.12)
		hl:SetAllPoints(row)
	end
	-- the addon re-sets the quest-title highlight on every list update; keep ours
	row.SetHighlightTexture = E.noop

	row:SetCheckedTexture(E.media.blankTex)
	local ct = row:GetCheckedTexture()
	if ct then
		local c = E.media.rgbvaluecolor
		ct:SetVertexColor(c[1], c[2], c[3], 0.25)
		ct:SetAllPoints(row)
	end
end

local function SkinRows(rows, count, create)
	if not rows then return end
	for i = 1, count do
		local row = create and rows[i] or rawget(rows, i)
		if row then SkinRow(row) end
	end
end

----------------------------------------------------------------------------------------------------
-- Wishlist "add / edit" dialog (created once by the wishlist code)
----------------------------------------------------------------------------------------------------
local function SkinWishlistAdd()
	local f = _G.AtlasLootWishList_AddFrame
	if not f or f.__AS_AtlasLoot then return end
	f.__AS_AtlasLoot = true

	f:SetBackdrop(nil)
	f:SetTemplate("Transparent")
	if f.CreateShadow then f:CreateShadow(5) end

	local close = FindCloseButton(f)
	if close then S:HandleCloseButton(close, f) end

	SkinInput(_G.AtlasLootWishListNewName)

	local scroll = _G.AtlasLootWishlistAddFrameIconList
	if scroll then
		SkinScrollBar(scroll)
		for i = 1, scroll:GetNumChildren() do
			local child = select(i, scroll:GetChildren())
			if child and child:GetObjectType() == "Button" then
				SkinButton(child)
			end
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Parts the AtlasLoot skin switcher touches: re-applied after every AtlasLoot:SetSkin()
----------------------------------------------------------------------------------------------------
local function ApplyChrome(AL)
	local ui = GetUI(AL)
	if not ui then return end

	-- retail-style portrait frame pieces
	if ui.NineSlice then
		for _, key in ipairs(NINE_PIECES) do
			local piece = ui.NineSlice[key]
			if piece and piece.Hide then piece:Hide() end
		end
		if ui.NineSlice.Hide then ui.NineSlice:Hide() end
	end
	for _, key in ipairs({ "portrait", "Bg", "TitleBg", "TopTileStreaks", "Inset" }) do
		local obj = ui[key]
		if obj and obj.Hide then obj:Hide() end
	end

	ui:SetBackdrop(nil)
	ui:SetTemplate("Transparent")

	-- close button and title
	if ui.CloseButton then
		ui.CloseButton:ClearAllPoints()
		ui.CloseButton:Point("TOPRIGHT", ui, "TOPRIGHT", 2, 2)
	end
	if ui.TitleText then
		ui.TitleText:FontTemplate(nil, 14, "OUTLINE")
		ui.TitleText:SetTextColor(unpack(E.media.rgbvaluecolor))
	end

	-- AtlasLootFrameTemplate frames (loot area, lists, popups): Blizzard tooltip backdrop -> ElvUI
	for _, frame in pairs(AL.skin.frames) do
		frame:SetBackdrop(nil)
		frame:SetTemplate("Transparent")
	end

	-- 8.x: the Loot and Search tab frames carry their own Blizzard backdrop
	if ui.tabs then
		for _, name in ipairs({ "Loot", "Search" }) do
			local tab = ui.tabs[name]
			if tab and tab.SetBackdrop then
				tab:SetBackdrop(nil)
				tab:SetTemplate("Transparent")
			end
		end
	end

	-- AtlasLootDropMenuTemplate buttons: SetSkin() re-textures the nine slices, keep them invisible
	for _, btn in pairs(AL.skin.buttons) do
		for _, key in ipairs(DROP_PIECES) do
			Alpha0(btn[key])
		end
	end

	-- search boxes: SetSkin() swaps the template textures/atlases, keep them invisible
	local box = ui.searchbox or (ui.tabs and ui.tabs.Search and ui.tabs.Search.searchbox)
	if box then
		for _, key in ipairs({ "Left", "Right", "Middle" }) do
			Alpha0(box[key])
		end
	end
end

----------------------------------------------------------------------------------------------------
-- Install
----------------------------------------------------------------------------------------------------
local function Install(AL)
	local ui = AL and GetUI(AL)
	if not ui or AL.__AS_AtlasLoot then return end
	if not E.db or not E.db.addOnSkins or not E.db.addOnSkins.skins.AtlasLoot then return end
	AL.__AS_AtlasLoot = true

	------------------------------------------------------------------
	-- Main window
	------------------------------------------------------------------
	ui:StripTextures()
	if ui.CreateShadow then ui:CreateShadow(5) end
	if ui.CloseButton then S:HandleCloseButton(ui.CloseButton, ui) end
	ApplyChrome(AL)

	-- keep ElvUI's look when the user changes AtlasLoot's own skin in the options
	local origSetSkin = AL.SetSkin
	if type(origSetSkin) == "function" then
		AL.SetSkin = function(self, ...)
			origSetSkin(self, ...)
			ApplyChrome(self)
		end
	end

	-- tabs (8.x)
	if ui.tabs then
		for _, tab in pairs(ui.tabs) do
			if type(tab) == "table" then SkinTab(tab) end
		end
	end

	------------------------------------------------------------------
	-- Buttons
	------------------------------------------------------------------
	for _, btn in pairs(AL.skin.buttons) do
		SkinDropButton(btn)
	end

	-- 7.x: panel buttons use button templates; in 8.x they are atlas icon buttons and stay as they are
	SkinButton(ui.backbutton)
	if not ui.tabs then
		SkinButton(ui.learnSpellbtn)
		SkinButton(ui.wishlistOptionsButton)
		SkinButton(ui.wishlistLockButton)
		SkinButton(ui.wishlistShareButton)
		SkinButton(ui.wishlistLearnVanityButton)
	end

	-- page arrows: drop the round Blizzard bezel, keep the arrows
	for _, key in ipairs({ "nextbutton", "prevbutton" }) do
		local arrow = ui[key]
		if arrow and arrow.texture then arrow.texture:SetAlpha(0) end
	end

	SkinCheck(ui.filterButton)

	-- main search box (7.x: on the window, 8.x: on the Search tab)
	SkinInput(ui.searchbox)

	------------------------------------------------------------------
	-- Item list
	------------------------------------------------------------------
	if AL.itemframe then
		SkinScrollBar(AL.itemframe.scrollBar) -- 7.x only
		ForEachItemButton(AL, SkinItemButton)
	end

	------------------------------------------------------------------
	-- Lists and scroll bars
	------------------------------------------------------------------
	local diff = ui.difficultyScrollFrame
	local loot = ui.lootTableScrollFrame or (ui.tabs and ui.tabs.Loot and ui.tabs.Loot.TableScrollFrame)
	local lootRows = loot and (loot.maxRows or 26) or 26
	if diff then
		SkinScrollBar(diff.scrollSlider)
		SkinRows(diff.rows, 5, false)
	end
	if loot then
		SkinScrollBar(loot.scrollSlider)
		SkinRows(loot.rows, lootRows, false)
	end

	-- rows are created on demand: skin them as the lists fill
	if AL.ScrollFrameUpdate and diff then
		hooksecurefunc(AL, "ScrollFrameUpdate", function()
			SkinRows(diff.rows, 5, true)
		end)
	end
	if AL.SubTableScrollFrameUpdate and loot then
		hooksecurefunc(AL, "SubTableScrollFrameUpdate", function()
			SkinRows(loot.rows, lootRows, true)
		end)
	end

	------------------------------------------------------------------
	-- Search panel (7.x: AtlasLoot.searchPanel = advanced search, 8.x: Search tab)
	------------------------------------------------------------------
	local sp = AL.searchPanel or (ui.tabs and ui.tabs.Search)
	if sp then
		if sp.closebtn then S:HandleCloseButton(sp.closebtn, sp) end

		SkinInput(sp.searchbox)
		SkinInput(sp.levelmin)
		SkinInput(sp.levelmax)
		SkinInput(sp.ilevelmin)
		SkinInput(sp.ilevelmax)
		SkinCheck(sp.useleveltick)

		-- no-ops for buttons that already got the drop-menu look
		SkinButton(sp.searchCategory)
		SkinButton(sp.equipbtn)
		if sp.equipbtn then SkinButton(sp.equipbtn.subbtn) end
		SkinButton(sp.addArg)
		SkinButton(sp.remArg)
		SkinButton(sp.searchbtn)
		SkinButton(sp.clearbtn)
		SkinButton(sp.searchButton)
		SkinButton(sp.searchResetButton)
		for i = 1, #(sp.main or {}) do
			SkinButton(sp.main[i])
			SkinButton(sp.sub and sp.sub[i])
			SkinInput(sp.value and sp.value[i])
		end
	end

	------------------------------------------------------------------
	-- Wishlist dialog, dropdown menus
	------------------------------------------------------------------
	SkinWishlistAdd()
	if AL.CreateWishlistOptions then -- 7.x
		hooksecurefunc(AL, "CreateWishlistOptions", SkinWishlistAdd)
	end

	local def = AS.libSkins and AS.libSkins["Dewdrop-2.0"]
	if def and AL.Dewdrop and not AS.skinnedLibs["Dewdrop-2.0"] then
		local ok, done = pcall(def.func, AL.Dewdrop, "Dewdrop-2.0")
		if ok and done then AS.skinnedLibs["Dewdrop-2.0"] = true end
	end
end

S:AddCallbackForAddon("AtlasLoot", "AtlasLoot", function()
	if not E.db or not E.db.addOnSkins or not E.db.addOnSkins.skins.AtlasLoot then return end

	local AL = _G.ATLASLOOT
	if not AL and LibStub then
		local aceAddon = LibStub("AceAddon-3.0", true)
		AL = aceAddon and aceAddon:GetAddon("AtlasLoot", true)
	end
	if not AL then return end

	-- UI already built (AddOnSkins loaded late)?
	if GetUI(AL) and AL.SetSkin then
		Install(AL)
		return
	end

	-- otherwise wait for AtlasLoot:OnEnable -> InitializeSkins()
	if AL.InitializeSkins then
		hooksecurefunc(AL, "InitializeSkins", function(self)
			Install(self)
		end)
	end
end)
