local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

if not AS:IsAddonLODorEnabled("SquidBotsLite") then return end

local _G = _G
local ipairs, select, unpack = ipairs, select, unpack
local CreateFrame = CreateFrame

-- SquidBots Lite 1.9-beta, updated for 2.4 (Teams/Accounts, roster scroll, bot sheet)
-- Skin is intentionally implemented entirely from AddOnSkins. SquidBotsLite itself
-- is not modified and keeps ownership of all behavior, saved variables and layouts.
S:AddCallbackForAddon("SquidBotsLite", "SquidBotsLite", function()
	if not E.db.addOnSkins.skins.SquidBotsLite then return end

	local function SkinOrderButton(button)
		if not button or button.__AS_SquidBotsLite then return end
		if not button.icon or not button.caption then return end

		button:StyleButton(nil, nil, true)
		button:CreateBackdrop("Default")
		button.backdrop:SetAllPoints()

		button.icon:SetTexCoord(unpack(E.TexCoords))
		button.icon:SetInside(button.backdrop)

		-- Keep Squid's active/passive/order indicator functional, but pull the
		-- Blizzard ring closer to the newly skinned icon.
		if button.ring then
			button.ring:ClearAllPoints()
			button.ring:Point("CENTER", button, "CENTER")
			button.ring:Size(46, 46)
		end

		button.__AS_SquidBotsLite = true
	end

	-- SquidBots Lite 1.9 adds small role buttons to the Specializations
	-- window. They intentionally have no caption, so they cannot use the
	-- main-bar button detector above. Keep Squid's role texture and gold
	-- active ring, but give the button the same ElvUI icon treatment.
	local function SkinRoleButton(button)
		if not button or button.__AS_SquidBotsLite then return end
		if not button.icon then return end

		button:StyleButton(nil, nil, true)
		button:CreateBackdrop("Default")
		button.backdrop:SetAllPoints()

		button.icon:SetTexCoord(unpack(E.TexCoords))
		button.icon:SetInside(button.backdrop)

		if button.ring then
			local size = button:GetWidth() or 20
			button.ring:ClearAllPoints()
			button.ring:Point("CENTER", button, "CENTER")
			button.ring:Size(size + 10, size + 10)
		end

		button.__AS_SquidBotsLite = true
	end

	-- SquidBotsLite keeps the role only in the TexCoords of its role sprite.
	-- SquidBots Lite 2.5 switched to Ascension's 256x256 sprite (66 px icons),
	-- older versions used the 64x64 Blizzard layout. Both are recognised by the
	-- icon's position in the sprite: left column = tank, upper right = healer,
	-- lower right = damage. Anything that is not a quarter-size cell (question
	-- mark, class icons, ...) is ignored.
	local ROLE_TEXTURES = {
		tank = E.Media.Textures.Tank,
		heal = E.Media.Textures.Healer,
		dps = E.Media.Textures.DPS,
	}

	-- ElvUI's own role icons are always used (the original game icon is only a fallback
	-- while a role cannot be detected).
	local function GetRoleMode()
		return "elvui"
	end

	local function DetectSquidRole(texture)
		if not texture then return end

		-- 3.3.5 clients can return either the compact 4-value form
		-- (left, right, top, bottom) or 8 corner coordinates from
		-- GetTexCoord(). Normalize both forms to the same rectangle.
		local a, b, c, d, e, f, g, h = texture:GetTexCoord()
		local left, right, top, bottom
		if e ~= nil then
			-- UL(x,y), LL(x,y), UR(x,y), LR(x,y)
			left = ((a or 0) + (c or 0)) * 0.5
			right = ((e or 0) + (g or 0)) * 0.5
			top = ((b or 0) + (f or 0)) * 0.5
			bottom = ((d or 0) + (h or 0)) * 0.5
		else
			left, right, top, bottom = a, b, c, d
		end
		if not (left and right and top and bottom) then return end

		local width, height = right - left, bottom - top
		if width < 0.2 or width > 0.32 or height < 0.2 or height > 0.32 then return end

		if left < 0.15 then return "tank" end
		if top < 0.15 then return "heal" end
		return "dps"
	end

	-- Class name -> class color. SquidBots only gives the localized class name
	-- ("Witch Doctor"), so find the class token through ElvUI/Blizzard's class
	-- name tables. Unknown classes get a stable color derived from the name.
	local classTokenByName
	local function BuildClassLookup()
		classTokenByName = {}
		for _, tbl in ipairs({_G.LOCALIZED_CLASS_NAMES_MALE or {}, _G.LOCALIZED_CLASS_NAMES_FEMALE or {}}) do
			for token, name in pairs(tbl) do classTokenByName[name] = token end
		end
	end

	local function HashColor(name)
		local sum = 0
		for i = 1, #name do sum = (sum * 31 + name:byte(i)) % 360 end
		local hue, sat, val = sum / 60, 0.55, 1
		local i = math.floor(hue)
		local f = hue - i
		local p, q, t = val * (1 - sat), val * (1 - sat * f), val * (1 - sat * (1 - f))
		i = i % 6
		if i == 0 then return val, t, p elseif i == 1 then return q, val, p elseif i == 2 then return p, val, t
		elseif i == 3 then return p, q, val elseif i == 4 then return t, p, val else return val, p, q end
	end

	local function ClassColorByName(class)
		if not classTokenByName then BuildClassLookup() end
		local token = classTokenByName[class] or class:upper():gsub("%s+", "")
		local color = (_G.CUSTOM_CLASS_COLORS and _G.CUSTOM_CLASS_COLORS[token]) or (_G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[token])
		if color then return color.r, color.g, color.b end
		return HashColor(class)
	end

	-- Squid writes "|cffaaaaaaClass 60|r" into toast.info: color the class, keep the level white.
	local function ColorizeToastInfo(toast)
		local info = toast and toast.info
		if not info then return end
		local text = info:GetText()
		if not text or text:sub(1, 10) ~= "|cffaaaaaa" then return end

		local plain = (text:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""))
		local class, level = plain:match("^(.-)%s+(%d+)%s*$")
		if not class or class == "" then return end

		local r, g, b = ClassColorByName(class)
		info:SetText(format("|cff%02x%02x%02x%s|r |cffffffff%s|r", r * 255, g * 255, b * 255, class, level))
	end

	local function UpdateToastRole(toast)
		if not toast or not toast.role or not toast.__AS_SquidRoleIcon then return end

		-- The holder belongs to the invite toast, so keep the frame itself
		-- visible while the toast is visible.
		if toast:IsShown() then
			toast.__AS_SquidRoleHolder:Show()
		else
			toast.__AS_SquidRoleHolder:Hide()
		end

		local role = DetectSquidRole(toast.role)
		local texture = role and ROLE_TEXTURES[role]

		if GetRoleMode() == "elvui" and texture then
			toast.__AS_SquidRoleIcon:SetTexture(texture)
			toast.__AS_SquidRoleIcon:SetTexCoord(0, 1, 0, 1)
			toast.__AS_SquidRoleIcon:SetVertexColor(1, 1, 1, 1)
			toast.__AS_SquidRoleIcon:Show()
			-- Squid's original texture stays as the state source, just invisible.
			toast.role:SetAlpha(0)
		else
			-- "original" mode, or role not detected: show the game's own role icon.
			toast.__AS_SquidRoleIcon:Hide()
			toast.role:SetAlpha(1)
		end

		ColorizeToastInfo(toast)
	end

	local function SkinToast(toast)
		if not toast or toast.__AS_SquidBotsLite then return end
		if not toast.invite or not toast.close then return end

		toast:SetTemplate("Transparent")
		S:HandleButton(toast.invite)
		S:HandleCloseButton(toast.close)

		if toast.role then
			-- Do not position or draw SquidBotsLite's original role texture. It is
			-- only used as a role-state source. AddOnSkins creates its own icon so
			-- Tank / Heal / DPS always sit perfectly centered in the invite toast.
			local holder = CreateFrame("Frame", nil, toast)
			holder:Size(22, 22)
			holder:Point("LEFT", toast, "LEFT", 6, 0)
			holder:SetFrameLevel((toast:GetFrameLevel() or 1) + 5)
			holder:SetTemplate("Default")

			local icon = holder:CreateTexture(nil, "OVERLAY")
			icon:Size(18, 18)
			icon:Point("CENTER", holder, "CENTER", 0, 0)
			icon:SetTexCoord(0, 1, 0, 1)
			icon:Hide()

			toast.__AS_SquidRoleHolder = holder
			toast.__AS_SquidRoleIcon = icon

			if toast.text then
				toast.text:ClearAllPoints()
				toast.text:Point("TOPLEFT", toast, "TOPLEFT", 35, -4)
			end
			if toast.info then
				toast.info:ClearAllPoints()
				toast.info:Point("TOPLEFT", toast, "TOPLEFT", 35, -18)
			end

			-- Keep the original role texture as a readable fallback until the
			-- replacement icon has been identified successfully. Put it into
			-- the same visual slot so even the fallback is centered.
			toast.role:ClearAllPoints()
			toast.role:Point("CENTER", holder, "CENTER", 0, 0)
			toast.role:Size(18, 18)
			toast.role:SetAlpha(1)
			toast:HookScript("OnShow", function(self)
				UpdateToastRole(self)
			end)

			-- Squid rewrites the class/level line every refresh; recolor it right away.
			if toast.info then
				hooksecurefunc(toast.info, "SetText", function() ColorizeToastInfo(toast) end)
			end

			-- Offers can be recycled while the same toast frame stays visible, so
			-- refresh the replacement icon at a very low frequency while visible.
			toast.__AS_SquidRoleElapsed = 0
			toast:HookScript("OnUpdate", function(self, elapsed)
				self.__AS_SquidRoleElapsed = (self.__AS_SquidRoleElapsed or 0) + elapsed
				if self.__AS_SquidRoleElapsed < 0.10 then return end
				self.__AS_SquidRoleElapsed = 0
				UpdateToastRole(self)
			end)

			UpdateToastRole(toast)
		end

		toast.__AS_SquidBotsLite = true
	end

	local function SkinMainBar()
		local bar = _G.SquidBotsLiteBar
		if not bar then return false end

		-- Keep SquidBotsLite's main command bar completely background-free.
		-- AddOnSkins only styles the individual buttons; it does not add a
		-- template/backdrop to the bar container itself.

		for _, child in ipairs({bar:GetChildren()}) do
			if child:IsObjectType("Button") and child.icon and child.caption then
				SkinOrderButton(child)
			elseif child:IsObjectType("Frame") and child.invite and child.close then
				SkinToast(child)
			end
		end

		return true
	end

	-- Role badge shared by the party frame overlays and the raid-style (compact)
	-- frame overlays of SquidBots Lite 2.x: backdrop, trimmed icon and ElvUI's own
	-- role icon in place of Squid's sprite.
	local function SkinOverlay(child)
		if child.__AS_SquidBotsLite then return end
		child:CreateBackdrop("Default")
		child.backdrop:SetAllPoints()
		child.icon:SetTexCoord(unpack(E.TexCoords))
		child.icon:SetInside(child.backdrop)

		-- Squid sets the role sprite + TexCoords on every refresh. In "elvui"
		-- mode swap the recognised role for ElvUI's own icon right after.
		hooksecurefunc(child.icon, "SetTexCoord", function(self)
			if self.__AS_SquidBusy or GetRoleMode() ~= "elvui" then return end
			local role = DetectSquidRole(self)
			local texture = role and ROLE_TEXTURES[role]
			if texture then
				self.__AS_SquidBusy = true
				self:SetTexture(texture)
				self:SetTexCoord(0, 1, 0, 1)
				self.__AS_SquidBusy = nil
			end
		end)
		local font = E.LSM and E.db and E.db.general and E.db.general.font and E.LSM:Fetch("font", E.db.general.font)
		if font then
			for _, fs in ipairs({child.badge, child.spec}) do
				if fs and fs.GetFont then
					local _, size, flags = fs:GetFont()
					fs:SetFont(font, size or 10, flags or "")
				end
			end
		end
		child.__AS_SquidBotsLite = true
	end

	local function IsOverlay(child)
		return child:IsObjectType("Button") and child.icon and child.badge and child.unit ~= nil or
			(child:IsObjectType("Button") and child.icon and child.badge and child.frame ~= nil)
	end

	local function SkinPartyOverlays()
		for i = 1, 4 do
			local parent = _G["PartyMemberFrame"..i]
			if parent then
				for _, child in ipairs({parent:GetChildren()}) do
					if IsOverlay(child) then SkinOverlay(child) end
				end
			end
		end
	end

	-- Raid-style frames: Squid parents these overlays to UIParent and only anchors
	-- them to the (secure) compact frames. Scanning UIParent is cheap but not free,
	-- so it only runs every couple of seconds.
	local compactElapsed = 0
	local function SkinCompactOverlays(delta)
		compactElapsed = compactElapsed + (delta or 0)
		if delta and compactElapsed < 2 then return end
		compactElapsed = 0
		for _, child in ipairs({UIParent:GetChildren()}) do
			if not child.__AS_SquidBotsLite and not child:GetName() and IsOverlay(child) and child.frame then
				SkinOverlay(child)
			end
		end
	end

	local function SkinPopup(name)
		local popup = _G[name.."Popup"]
		if not popup or popup.__AS_SquidBotsLite then return end

		popup:SetTemplate("Transparent")
		local scroll = _G[name.."PopupScrollFrame"]
		if scroll then
			local scrollBar = _G[scroll:GetName().."ScrollBar"] or scroll.ScrollBar
			if scrollBar then S:HandleScrollBar(scrollBar) end
		end

		popup.__AS_SquidBotsLite = true
	end

	-- ---------------------------------------------------------------------
	-- Shared helpers (SquidBots Lite 2.x): its buttons are unnamed, so they
	-- are recognised by the Blizzard template art they were created with.
	-- ---------------------------------------------------------------------
	local function NormalPath(button)
		local normal = button.GetNormalTexture and button:GetNormalTexture()
		local path = normal and normal.GetTexture and normal:GetTexture()
		return type(path) == "string" and path:lower() or ""
	end

	local function IsPanelButton(button) return NormalPath(button):find("ui%-panel%-button") ~= nil end
	local function IsCloseButton(button) return NormalPath(button):find("minimizebutton") ~= nil end
	local function ScrollDirection(button)
		local path = NormalPath(button)
		if path:find("scrollupbutton") then return "up" end
		if path:find("scrolldownbutton") then return "down" end
	end

	local function GeneralFont()
		if E.LSM and E.db and E.db.general and E.db.general.font then
			return E.LSM:Fetch("font", E.db.general.font)
		end
	end

	local function ApplyFont(fs, size, outline)
		local font = GeneralFont()
		if not fs or not font or not fs.GetFont then return end
		local _, oldSize, oldFlags = fs:GetFont()
		fs:SetFont(font, size or oldSize or 12, outline or oldFlags or "")
	end

	local function StyleTitle(frame)
		ApplyFont(frame.title, 13, "OUTLINE")
		if frame.title then frame.title:SetTextColor(1, 1, 1) end
		if frame.status then
			ApplyFont(frame.status)
			frame.status:SetTextColor(0.8, 0.8, 0.8)
		end
		if frame.help then
			ApplyFont(frame.help)
			frame.help:SetTextColor(0.55, 0.55, 0.55)
		end
	end

	local function SkinPanelButton(button)
		if not button or button.__AS_SquidBotsLite then return end
		S:HandleButton(button)
		button.__AS_SquidBotsLite = true
	end

	local function SkinStatusBar(bar)
		if not bar or bar.__AS_SquidBotsLite then return end
		-- Re-texture the existing fill object: SquidBots anchors its rested-xp
		-- overlay to it, so the object itself must stay the same.
		local fill = bar:GetStatusBarTexture()
		if fill then fill:SetTexture(E.media.normTex) end
		if bar.rest then bar.rest:SetTexture(E.media.normTex) end
		if bar.bg then bar.bg:SetTexture(0, 0, 0, 0) end
		bar:CreateBackdrop("Default")
		bar.__AS_SquidBotsLite = true
	end

	local function SkinAltsFrame()
		local frame = _G.SquidBotsLiteAlts
		if not frame then return false end

		-- My Alts / bot roster window (2.4: Refresh, Teams, Accounts, a scroll
		-- list and per row Add/Remove, Summon and the bot sheet button).
		if not frame.__AS_SquidBotsLite then frame:SetTemplate("Transparent") end
		StyleTitle(frame)

		SkinPanelButton(frame.refresh)
		SkinPanelButton(frame.teams)
		SkinPanelButton(frame.accounts)

		local scrollBar = _G.SquidBotsLiteAltsScrollScrollBar
		if scrollBar and not scrollBar.__AS_SquidBotsLite then
			S:HandleScrollBar(scrollBar)
			scrollBar.__AS_SquidBotsLite = true
		end

		for _, child in ipairs({frame:GetChildren()}) do
			if child:IsObjectType("Button") then
				if IsCloseButton(child) and not child.__AS_SquidBotsLite then
					S:HandleCloseButton(child)
					child.__AS_SquidBotsLite = true
				elseif IsPanelButton(child) then
					SkinPanelButton(child)
				end
			elseif child ~= frame.scroll and not child:IsObjectType("ScrollFrame") and child:IsObjectType("Frame") then
				-- Roster row: Add/Remove, Summon and the bot sheet button.
				for _, button in ipairs({child:GetChildren()}) do
					if button:IsObjectType("Button") and IsPanelButton(button) then
						SkinPanelButton(button)
						if button.icon then
							-- Keep the portrait of the sheet button on top of the new backdrop.
							button.icon:SetDrawLayer("OVERLAY")
							button.icon:SetTexCoord(unpack(E.TexCoords))
						end
					end
				end
				if child.xp then SkinStatusBar(child.xp) end
				for _, region in ipairs({child:GetRegions()}) do
					if region and region.GetObjectType and region:GetObjectType() == "FontString" then
						ApplyFont(region)
					end
				end
			end
		end

		if not frame.__AS_SquidBotsLite then
			frame:HookScript("OnShow", function()
				frame.__AS_SquidNeedsRefresh = true
			end)
		end
		frame.__AS_SquidNeedsRefresh = nil
		frame.__AS_SquidBotsLite = true
		return true
	end

	-- ---------------------------------------------------------------------
	-- Bot sheet (SquidBots Lite 2.x, Manager.lua): gear, bags, quests,
	-- talents, mounts and info tabs of one bot.
	-- ---------------------------------------------------------------------
	local function SkinItemButton(button)
		if button.__AS_SquidBotsLite then return end
		button:SetNormalTexture("")
		button:CreateBackdrop("Default")
		button.backdrop:SetAllPoints()
		button.icon:SetTexCoord(unpack(E.TexCoords))
		button.icon:SetInside(button.backdrop)
		button:StyleButton()
		if button.count then
			button.count:ClearAllPoints()
			button.count:Point("BOTTOMRIGHT", -2, 2)
			button.count:FontTemplate(nil, nil, "OUTLINE")
		end
		button.__AS_SquidBotsLite = true
	end

	-- The active tab is marked with LockHighlight, which ElvUI buttons do not
	-- show; draw it as an accent-colored border instead.
	local function ShowActiveTab(button)
		if not button.backdrop and not button.SetBackdropBorderColor then return end
		local target = button.backdrop or button
		if button.__AS_SquidActive then
			target:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor or {1, 0.82, 0}))
		else
			target:SetBackdropBorderColor(unpack(E.media.bordercolor))
		end
	end

	local function SkinSheetTab(button)
		if button.__AS_SquidBotsLite then return end
		SkinPanelButton(button)
		hooksecurefunc(button, "LockHighlight", function(self) self.__AS_SquidActive = true; ShowActiveTab(self) end)
		hooksecurefunc(button, "UnlockHighlight", function(self) self.__AS_SquidActive = nil; ShowActiveTab(self) end)
		button:HookScript("OnLeave", ShowActiveTab)
	end

	local function SkinSheetChildren(parent)
		for _, child in ipairs({parent:GetChildren()}) do
			if child:IsObjectType("Button") then
				local direction = ScrollDirection(child)
				if child.icon and child.count and not IsPanelButton(child) then
					SkinItemButton(child)
				elseif IsCloseButton(child) then
					if not child.__AS_SquidBotsLite then
						S:HandleCloseButton(child)
						child.__AS_SquidBotsLite = true
					end
				elseif direction then
					if not child.__AS_SquidBotsLite then
						S:HandleNextPrevButton(child, direction)
						child.__AS_SquidBotsLite = true
					end
				elseif IsPanelButton(child) then
					SkinPanelButton(child)
				end
			elseif child:IsObjectType("StatusBar") then
				SkinStatusBar(child)
			end
			-- Rows (talents) hold their own +/- buttons; pages hold everything else.
			if not child:IsObjectType("PlayerModel") then
				SkinSheetChildren(child)
			end
			for _, region in ipairs({child:GetRegions()}) do
				if region and region.GetObjectType and region:GetObjectType() == "FontString" then
					ApplyFont(region)
				end
			end
		end
	end

	local function SkinSheet()
		local sheet = _G.SquidBotsLiteSheet
		if not sheet then return false end
		if sheet.__AS_SquidBotsLite then return true end

		sheet:SetTemplate("Transparent")
		-- SquidBots draws the sheet at 0.95. ElvUI's 1px borders need whole pixels:
		-- at 0.95 the left edge of the first button column (Follow, Open trade,
		-- the first item slots) lands on a half pixel and its border line drops out.
		sheet:SetScale(1)
		hooksecurefunc(sheet, "SetScale", function(self, scale)
			if scale ~= 1 then self:SetScale(1) end
		end)
		StyleTitle(sheet)
		ApplyFont(sheet.goldText)
		ApplyFont(sheet.specText)

		if sheet.tabs then
			for _, button in pairs(sheet.tabs) do SkinSheetTab(button) end
		end
		SkinPanelButton(sheet.refresh)
		if sheet.xp then
			SkinStatusBar(sheet.xp)
			if sheet.xp.text then sheet.xp.text:FontTemplate(nil, nil, "OUTLINE") end
		end
		SkinSheetChildren(sheet)

		for _, page in ipairs({sheet:GetChildren()}) do
			-- Hints are GameFontDisableSmall (dark grey); lift them to ElvUI's dim text color.
			if page.hint and page.hint.SetTextColor then page.hint:SetTextColor(0.7, 0.7, 0.7) end

			-- Bags tab: the hint sits at a fixed height right above Trade / Sell grey / Bank.
			-- With ElvUI's font it wraps to one more line and runs under the buttons, so the
			-- button row now hangs from the bottom of the hint (Sell grey and Bank follow Trade).
			if page.hint and page.trade and page.grey and page.bank then
				page.trade:ClearAllPoints()
				page.trade:SetPoint("TOPLEFT", page.hint, "BOTTOMLEFT", 0, -8)
			end
		end

		sheet.__AS_SquidBotsLite = true
		return true
	end

	local function SkinSpecsFrame()
		local frame = _G.SquidBotsLiteSpecs
		if not frame then return false end
		

		-- SquidBots Lite 1.9-beta: Specializations window. Keep all bot/spec
		-- logic inside SquidBotsLite and only replace Blizzard visuals here.
		if not frame.__AS_SquidBotsLite then frame:SetTemplate("Transparent") end

		local font
		if E.LSM and E.db and E.db.general and E.db.general.font then
			font = E.LSM:Fetch("font", E.db.general.font)
		end

		local function ApplyFont(fs, size, outline)
			if not fs or not font then return end
			local _, oldSize, oldFlags = fs:GetFont()
			fs:SetFont(font, size or oldSize or 12, outline or oldFlags or "")
		end

		ApplyFont(frame.title, 13, "OUTLINE")
		ApplyFont(frame.myRoleLabel)
		ApplyFont(frame.status)
		ApplyFont(frame.help)

		if frame.title then frame.title:SetTextColor(1, 1, 1) end
		if frame.status then frame.status:SetTextColor(0.8, 0.8, 0.8) end
		if frame.help then frame.help:SetTextColor(0.55, 0.55, 0.55) end

		if frame.myRole then
			for _, button in pairs(frame.myRole) do
				SkinRoleButton(button)
			end
		end

		if frame.balance and not frame.balance.__AS_SquidBotsLite then
			S:HandleButton(frame.balance)
			frame.balance.__AS_SquidBotsLite = true
		end
		if frame.refresh and not frame.refresh.__AS_SquidBotsLite then
			S:HandleButton(frame.refresh)
			frame.refresh.__AS_SquidBotsLite = true
		end

		-- The close button and specialization rows are unnamed. Discover them
		-- from the frame hierarchy so the skin does not depend on private locals.
		for _, child in ipairs({frame:GetChildren()}) do
			if child:IsObjectType("Button") then
				if child.icon then
					SkinRoleButton(child)
				elseif child ~= frame.balance and child ~= frame.refresh and not child.__AS_SquidBotsLite then
					S:HandleCloseButton(child)
					child.__AS_SquidBotsLite = true
				end
			elseif child:IsObjectType("Frame") then
				-- Each bot row contains three role buttons plus the Spec button.
				for _, region in ipairs({child:GetRegions()}) do
					if region and region.GetObjectType and region:GetObjectType() == "FontString" then
						ApplyFont(region)
					end
				end

				for _, button in ipairs({child:GetChildren()}) do
					if button:IsObjectType("Button") and not button.__AS_SquidBotsLite then
						if button.icon then
							SkinRoleButton(button)
						else
							S:HandleButton(button)
							button.__AS_SquidBotsLite = true
						end
					end
				end
			end
		end

		if not frame.__AS_SquidBotsLite then
			frame:HookScript("OnShow", function()
				-- A later refresh can create new row controls; revisit on the next watcher tick.
				frame.__AS_SquidNeedsRefresh = true
			end)
		end
		frame.__AS_SquidNeedsRefresh = nil
		frame.__AS_SquidBotsLite = true
		return true
	end

	local function SkinOptions()
		local panel = _G.SquidBotsLiteOptionsPanel
		if not panel then return false end

		for _, name in ipairs({
			"SquidBotsLiteCaptionFontDropDown",
			"SquidBotsLiteCaptionOutlineDropDown",
			"SquidBotsLiteTooltipFontDropDown",
		}) do
			local button = _G[name]
			if button and not button.__AS_SquidBotsLite then
				S:HandleButton(button)
				button.__AS_SquidBotsLite = true
			end
			SkinPopup(name)
		end

		for _, name in ipairs({
			"SquidBotsLiteCaptionSizeSlider",
			"SquidBotsLiteButtonGapSlider",
			"SquidBotsLiteTooltipSizeSlider",
		}) do
			local slider = _G[name]
			if slider and not slider.__AS_SquidBotsLite then
				S:HandleSliderFrame(slider)
				slider.__AS_SquidBotsLite = true
			end
		end

		-- The reset button is intentionally unnamed in SquidBotsLite.
		for _, child in ipairs({panel:GetChildren()}) do
			if child:IsObjectType("Button") and child.GetText and child:GetText() == "Reset appearance" and not child.__AS_SquidBotsLite then
				S:HandleButton(child)
				child.__AS_SquidBotsLite = true
			end
		end

		panel.__AS_SquidBotsLite = true
		return true
	end

	local function SkinAll(delta)
		SkinCompactOverlays(delta)
		local barReady = SkinMainBar()
		SkinOptions() -- Present in older SquidBotsLite builds; optional in 1.9-beta.
		local altsReady = SkinAltsFrame()
		local specsReady = SkinSpecsFrame()
		SkinSheet() -- Created the first time a bot sheet is opened (2.x).
		local expectsSpecs = _G.SquidBotsLite_Specs ~= nil
		SkinPartyOverlays()
		return barReady and altsReady and (not expectsSpecs or specsReady)
	end

	-- SquidBotsLite builds its runtime windows on PLAYER_LOGIN. Older releases
	-- also had an options panel created earlier. A short readiness watcher keeps
	-- both layouts compatible without replacing any SquidBotsLite functions.
	local watcher = CreateFrame("Frame")
	watcher:RegisterEvent("PLAYER_LOGIN")
	watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
	watcher:SetScript("OnEvent", function(self)
		SkinAll()
	end)

	local elapsed = 0
	watcher:SetScript("OnUpdate", function(self, delta)
		elapsed = elapsed + delta
		if elapsed < 0.2 then return end
		local passed = elapsed
		elapsed = 0
		SkinAll(passed)
	end)

	SkinAll()
end)
