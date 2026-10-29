local E, L, V, P, G = unpack(select(2, ...))
local S = E:GetModule("Skins")
local AB = E:GetModule("ActionBars")
local A = E:GetModule("Auras")
local UF = E:GetModule("UnitFrames")
local TT = E:GetModule("Tooltip")
local LSM = E.Libs.LSM

local _G = _G
local pairs, ipairs, max, min = pairs, ipairs, math.max, math.min

local MICRO_BUTTONS = {
	"CharacterMicroButton",
	"SpellbookMicroButton",
	"TalentMicroButton",
	"AchievementMicroButton",
	"QuestLogMicroButton",
	"SocialsMicroButton",
	"LFDMicroButton",
	"PathToAscensionMicroButton",
	"ChallengesMicroButton",
	"MainMenuMicroButton",
	"HelpMicroButton"
}
local CreateFrame = CreateFrame
local GetTime = GetTime

-- Multiple names are allowed for targets which differ between ElvUI builds.
local targets = {
	actionbar1 = {"ElvUI_Bar1"}, actionbar2 = {"ElvUI_Bar2"}, actionbar3 = {"ElvUI_Bar3"},
	actionbar4 = {"ElvUI_Bar4"}, actionbar5 = {"ElvUI_Bar5"}, actionbar6 = {"ElvUI_Bar6"},
	actionbar7 = {"ElvUI_Bar7"}, actionbar8 = {"ElvUI_Bar8"}, actionbar9 = {"ElvUI_Bar9"},
	actionbar10 = {"ElvUI_Bar10"},
	petbar = {"ElvUI_BarPet"}, stancebar = {"ElvUI_StanceBar"},
	totembar = {"ElvUI_BarTotem", "ElvUI_TotemBar"}, microbar = {"ElvUI_MicroBar"},

	player = {"ElvUF_Player"}, target = {"ElvUF_Target"}, targettarget = {"ElvUF_TargetTarget"},
	focus = {"ElvUF_Focus"}, pet = {"ElvUF_Pet"},
	guardians = {}, -- Guardian bars (UnitFrames -> Guardians), handled in ApplyGuardians
	playerclassbar = {}, combobar = {},
	playerpowerbar = {}, targetpowerbar = {},
	wildcardenergy = {}, wildcardrage = {},
	party = {"ElvUF_Party"}, raid = {"ElvUF_Raid"}, raid40 = {"ElvUF_Raid40"},
	boss = {"BossHeader"}, arena = {"ArenaHeader"},

	experience = {"ElvUI_ExperienceBar"}, reputation = {"ElvUI_ReputationBar"},
	petexperience = {"ElvUI_PetExperienceBar"}, minimap = {"MMHolder"},
	toppanel = {"ElvUI_TopPanel"}, bottompanel = {"ElvUI_BottomPanel"},
	leftchat = {"LeftChatPanel"}, rightchat = {"RightChatPanel"},
	bags = {"ElvUI_ContainerFrame"}, bank = {"ElvUI_BankContainerFrame"},
	buffs = {"ElvUIPlayerBuffs"}, debuffs = {"ElvUIPlayerDebuffs"},
	threat = {"ElvUI_ThreatBar"},
	lootframe = {"ElvLootFrame"},
	lootroll = {},
	mirrortimers = {}, -- Fatigue / Breath bars (MirrorTimer1..3), handled in ApplyMirrorTimerShadows

	-- Unit-frame cast bars. Party and boss are handled as collections below.
	playercastbar = {"ElvUF_Player"}, targetcastbar = {"ElvUF_Target"},
	petcastbar = {"ElvUF_Pet"}, partycastbar = {"ElvUF_Party"},
	bosscastbar = {"BossHeader"},

	-- Unit-frame aura icons. These are handled dynamically below.
	ufplayerbuffs = {}, ufplayerdebuffs = {},
	uftargetbuffs = {}, uftargetdebuffs = {},
	ufpartybuffs = {}, ufpartydebuffs = {},
	ufbossbuffs = {}, ufbossdebuffs = {},

	-- Optional ElvUI_CoAResources integration. The actual row frames are
	-- discovered lazily from the CoAResources module when the addon is loaded.
	coaresources = {},

	-- Optional ElvUI_DTBars2 integration. Panels are discovered dynamically.
	dtbars2 = {},

	-- Native Minimap Button Frame integration.
	minimapbuttonbar = {},

	-- Optional ElvUI_Enhanced Minimap Button Grabber integration.
	enhancedminimapbar = {},

	-- Optional SquidBotsLite command button integration.
	squidbotslite = {},

	-- Dynamic world/UI frames. These are collected by their modules below.
	tooltips = {},

	-- Blizzard/Ascension windows (resolved lazily by BLIZZARD_WINDOWS below).
	blizzcharacter = {}, blizzspellbook = {}, blizzfriends = {}, blizzescape = {},
	blizzquestlog = {}, blizzdungeon = {}, blizzhelp = {}, blizzworldmap = {},

	-- Nameplate elements (handled by the region shadows below).
	nameplatehealth = {}, nameplatecastbar = {}, nameplatecasticon = {},
	nameplatebuffs = {}, nameplatedebuffs = {},
}

local StyleRegionShadow -- defined further below (nameplate region shadows)

local function GetDB()
	return E.db and E.db.frameShadows
end

local function GetTarget(name)
	local names = targets[name]
	if not names then return end
	for _, globalName in ipairs(names) do
		local frame = _G[globalName]
		if frame then return frame end
	end
end

local function EnsureShadow(frame)
	if frame.pdySkinShadow then return frame.pdySkinShadow end
	if not frame.GetFrameLevel or not frame.GetFrameStrata then return end

	local shadow = CreateFrame("Frame", nil, frame)
	shadow:SetFrameStrata(frame:GetFrameStrata())
	shadow:SetFrameLevel(max((frame:GetFrameLevel() or 1) - 1, 0))
	shadow:SetBackdrop({edgeFile = LSM:Fetch("border", "ElvUI GlowBorder"), edgeSize = E:Scale(5)})
	shadow:SetBackdropColor(0, 0, 0, 0)
	shadow:EnableMouse(false)
	frame.pdySkinShadow = shadow
	return shadow
end

local function GroupHasVisibleUnit(key)
	if key == "boss" then
		for i = 1, 5 do
			local unit = _G["ElvUF_Boss"..i]
			if unit and unit:IsShown() then return true end
		end
		return false
	elseif key == "arena" then
		for i = 1, 5 do
			local unit = _G["ElvUF_Arena"..i]
			if unit and unit:IsShown() then return true end
		end
		return false
	end
	return true
end

local function StyleShadow(frame, enabled, db)
	if not frame then return end
	local shadow = EnsureShadow(frame)
	if not shadow then return end

	if not db.enable or not enabled then
		shadow:Hide()
		shadow:SetScript("OnUpdate", nil)
		return shadow
	end

	local size = db.size or 5
	local color = db.color or {r = 0, g = 0, b = 0, a = 0.9}

	shadow:ClearAllPoints()
	shadow:SetPoint("TOPLEFT", frame, "TOPLEFT", -size, size)
	shadow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", size, -size)
	shadow:SetFrameStrata(frame:GetFrameStrata())
	shadow:SetFrameLevel(max((frame:GetFrameLevel() or 1) - 1, 0))
	shadow:SetBackdrop({edgeFile = LSM:Fetch("border", "ElvUI GlowBorder"), edgeSize = E:Scale(size)})
	shadow:SetBackdropColor(0, 0, 0, 0)
	shadow:SetBackdropBorderColor(color.r or 0, color.g or 0, color.b or 0, color.a or 0.9)
	shadow:SetScript("OnUpdate", nil)
	shadow:SetAlpha(1)
	shadow:Show()
	return shadow
end

-- Aura icons can sit extremely close together in UnitFrame config/preview mode.
-- Using the normal shadow size as both glow thickness and outside spacing makes
-- neighboring preview shadows overlap and look noisy. Keep the configured glow
-- thickness/color, but use only a one-border outside gap while the frame is
-- force-showing auras. Live UnitFrames keep the normal Shadow spacing.
local function StyleAuraIconShadow(frame, enabled, db, compactPreview)
	if not compactPreview then
		return StyleShadow(frame, enabled, db)
	end
	if not frame then return end
	local shadow = EnsureShadow(frame)
	if not shadow then return end

	if not db.enable or not enabled then
		shadow:Hide()
		shadow:SetScript("OnUpdate", nil)
		return shadow
	end

	local size = db.size or 5
	local color = db.color or {r = 0, g = 0, b = 0, a = 0.9}
	local gap = E.Border or E.mult or 1

	shadow:ClearAllPoints()
	shadow:SetPoint("TOPLEFT", frame, "TOPLEFT", -gap, gap)
	shadow:SetPoint("BOTTOMRIGHT", frame, "BOTTOMRIGHT", gap, -gap)
	shadow:SetFrameStrata(frame:GetFrameStrata())
	shadow:SetFrameLevel(max((frame:GetFrameLevel() or 1) - 1, 0))
	shadow:SetBackdrop({edgeFile = LSM:Fetch("border", "ElvUI GlowBorder"), edgeSize = E:Scale(size)})
	shadow:SetBackdropColor(0, 0, 0, 0)
	shadow:SetBackdropBorderColor(color.r or 0, color.g or 0, color.b or 0, color.a or 0.9)
	shadow:SetScript("OnUpdate", nil)
	shadow:SetAlpha(1)
	shadow:Show()
	return shadow
end

local function HideActionButtonShadows(bar)
	if not bar or not bar.buttons then return end
	for _, button in ipairs(bar.buttons) do
		local target = button.backdrop or button
		if target and target.pdySkinShadow then target.pdySkinShadow:Hide() end
	end
end

local function ApplyActionBar(key, enabled, db)
	local id = tonumber(key:match("^actionbar(%d+)$"))
	if not id then return false end

	local bar = GetTarget(key)
	if not bar then return true end
	local barDB = E.db and E.db.actionbar and E.db.actionbar["bar"..id]
	local useBackdrop = barDB and barDB.backdrop

	if useBackdrop then
		HideActionButtonShadows(bar)
		StyleShadow(bar, enabled, db)
	else
		-- No actionbar backdrop: the bar-wide shadow would look like an empty rectangle.
		-- Put the same configured shadow around each visible action button instead.
		StyleShadow(bar, false, db)
		if bar.buttons then
			local buttonCount = (barDB and barDB.buttons) or #bar.buttons
			for i, button in ipairs(bar.buttons) do
				local target = button.backdrop or button
				local show = db.enable and enabled and i <= buttonCount and button:IsShown()
				StyleShadow(target, show, db)
			end
		end
	end

	return true
end

local function HidePetButtonShadows()
	for i = 1, (NUM_PET_ACTION_SLOTS or 10) do
		local button = _G["PetActionButton"..i]
		local target = button and (button.backdrop or button)
		if target and target.pdySkinShadow then target.pdySkinShadow:Hide() end
	end
end

local function ApplyPetBar(enabled, db)
	local bar = _G.ElvUI_BarPet
	if not bar then return end

	local barDB = E.db and E.db.actionbar and E.db.actionbar.barPet
	local useBackdrop = barDB and barDB.backdrop
	local isEnabled = barDB and barDB.enabled

	if useBackdrop then
		HidePetButtonShadows()
		StyleShadow(bar, enabled and isEnabled, db)
	else
		StyleShadow(bar, false, db)
		local buttonCount = (barDB and barDB.buttons) or (NUM_PET_ACTION_SLOTS or 10)
		for i = 1, (NUM_PET_ACTION_SLOTS or 10) do
			local button = _G["PetActionButton"..i]
			if button then
				local target = button.backdrop or button
				local show = db.enable and enabled and isEnabled and i <= buttonCount and button:GetScale() > 0.01
				StyleShadow(target, show, db)
			end
		end
	end
end

-- Stance bar: with a bar backdrop the shadow goes around the whole bar frame,
-- without one around each visible stance button (same behavior as action/pet bars).
local function ApplyStanceBar(enabled, db)
	local bar = _G.ElvUI_StanceBar
	if not bar then return end

	local barDB = E.db and E.db.actionbar and E.db.actionbar.stanceBar
	local useBackdrop = barDB and barDB.backdrop
	local isEnabled = barDB and barDB.enabled
	local buttons = bar.buttons or {}

	if useBackdrop then
		HideActionButtonShadows(bar)
		StyleShadow(bar, enabled and isEnabled, db)
	else
		StyleShadow(bar, false, db)
		local buttonCount = (barDB and barDB.buttons) or #buttons
		for i, button in ipairs(buttons) do
			local target = button.backdrop or button
			local show = db.enable and enabled and isEnabled and i <= buttonCount and button:IsShown()
			StyleShadow(target, show, db)
		end
	end
end

local function ApplyMicroBar(enabled, db)
	local bar = _G.ElvUI_MicroBar
	if not bar then return end

	-- The microbar should mirror the action-button behavior: no large shadow
	-- around the full bar container, only one shadow per visible micro button.
	StyleShadow(bar, false, db)

	for _, name in ipairs(MICRO_BUTTONS) do
		local button = _G[name]
		if button then
			local target = button.backdrop or button
			StyleShadow(target, db.enable and enabled and bar:IsShown() and button:IsShown(), db)
		end
	end
end

local function ApplyTotemBars(enabled, db)
	-- Both independent totem systems follow the actionbar shadow rule:
	-- a visible bar backdrop gets one outer shadow; without it, each visible
	-- icon gets its own shadow instead of an empty rectangle.
	local classBar = _G.ElvUI_TotemBar
	if classBar then
		local hasVisibleTotem = false
		local useBackdrop = classBar.backdrop and classBar.backdrop:IsShown()
		for i = 1, 4 do
			local button = classBar[i] or _G["ElvUI_TotemBarTotem"..i]
			if button then
				local visible = classBar:IsShown() and button:IsShown()
				if visible then hasVisibleTotem = true end
				StyleShadow(button.backdrop or button, enabled and visible and not useBackdrop, db)
			end
		end
		StyleShadow(classBar, enabled and hasVisibleTotem and useBackdrop, db)
	end

	local actionBar = _G.ElvUI_BarTotem
	if actionBar then
		local multiCast = _G.MultiCastActionBarFrame
		local w, h = actionBar:GetWidth() or 0, actionBar:GetHeight() or 0
		local hasLiveBar = actionBar:IsShown() and multiCast and multiCast:IsShown() and w > 20 and h > 20
		local barDB = E.db and E.db.actionbar and E.db.actionbar.barTotem
		local useBackdrop = (barDB and barDB.backdrop) or (actionBar.backdrop and actionBar.backdrop:IsShown())
		StyleShadow(actionBar, enabled and hasLiveBar and useBackdrop, db)

		-- ActionBar Totems store buttons in a keyed table (not a numeric array).
		-- Only currently visible icons receive shadows; this also handles the
		-- extra MultiCast summon/recall and flyout buttons.
		if actionBar.buttons then
			for button in pairs(actionBar.buttons) do
				if button and button.IsShown then
					local visible = hasLiveBar and button:IsShown()
					StyleShadow(button.backdrop or button, enabled and visible and not useBackdrop, db)
				end
			end
		end
	end
end

local function ApplyPlayerClassBar(enabled, db)
	local frame = _G.ElvUF_Player
	if not frame or not frame.ClassBar then return end

	local bars = frame[frame.ClassBar]
	if not bars then return end

	-- Detached class/resource bars live in their own holder/mover. Give that
	-- complete detached block one shadow so it stays visible outside the
	-- Player frame as well. Attached bars keep the existing per-bar behavior.
	if frame.CLASSBAR_DETACHED then
		StyleShadow(bars, false, db)
		if bars.backdrop then StyleShadow(bars.backdrop, false, db) end

		local maxBars = frame.MAX_CLASS_BAR or #bars or 0
		for i = 1, maxBars do
			local segment = bars[i]
			if segment then
				StyleShadow(segment.backdrop or segment, false, db)
			end
		end

		local holder = bars.Holder or frame.ClassBarHolder
		if holder then
			-- The holder itself is only a positioning frame. Mirror the detached
			-- bar's draw layer so the holder shadow sits directly behind the bar.
			if holder.SetFrameStrata and bars.GetFrameStrata then
				holder:SetFrameStrata(bars:GetFrameStrata())
			end
			if holder.SetFrameLevel and bars.GetFrameLevel then
				holder:SetFrameLevel(bars:GetFrameLevel())
			end

			local active = db.enable and enabled and frame.USE_CLASSBAR and bars:IsShown()
			local shadow = StyleShadow(holder, active, db)
			if shadow then
				-- Parent the glow to the real resource bar, not the always-present
				-- holder. This makes Auto Hide and element visibility work naturally.
				shadow:SetParent(bars)
			end
		end
		return
	end

	-- A previously detached holder shadow must not survive after the bar is
	-- attached to the Player frame again.
	local holder = bars.Holder or frame.ClassBarHolder
	if holder and holder.pdySkinShadow then
		holder.pdySkinShadow:Hide()
		holder.pdySkinShadow:SetParent(holder)
	end

	-- Attached segmented resources (Runes/Pips) receive one shadow per segment,
	-- matching the behavior used for CoA bubbles and other pip based elements.
	if frame.ClassBar == "Runes" then
		StyleShadow(bars, false, db)
		if bars.backdrop then StyleShadow(bars.backdrop, false, db) end

		local maxBars = frame.MAX_CLASS_BAR or #bars or 0
		for i = 1, maxBars do
			local segment = bars[i]
			if segment then
				local target = segment.backdrop or segment
				-- Keep the shadow prepared even if the segment is currently hidden;
				-- as a child it follows the segment's real visibility automatically.
				StyleShadow(target, db.enable and enabled, db)
			end
		end
	else
		-- Continuous attached classbars (AdditionalPower and compatible custom
		-- resources) use one shadow around the visible bar/backdrop.
		local target = bars.backdrop or bars
		StyleShadow(target, db.enable and enabled, db)
	end
end

-- Shadow the real ComboPoints backdrop only when detached. Avoid changing
-- the holder's parent, layer, or strata: those belong to UnitFrames.
local function ApplyDetachedComboBar(enabled, db)
    local frame = _G.ElvUF_Target
    if not frame or not frame.ComboPoints then return end
    local bars = frame.ComboPoints
    local target = bars.backdrop or bars
    local active = db.enable and enabled and frame.USE_CLASSBAR
        and frame.CLASSBAR_DETACHED
    StyleShadow(target, active, db)
end

local function ApplyWildcardResourceBar(resource, enabled, db)
	local frame = _G.ElvUF_Player
	if not frame then return end

	local bar = frame[resource]
	if not bar then return end

	local isEnergy = resource == "Energy"
	local useBar = isEnergy and frame.USE_ENERGYBAR or frame.USE_RAGEBAR
	local detached = isEnergy and frame.ENERGYBAR_DETACHED or frame.RAGEBAR_DETACHED
	local active = db.enable and enabled and useBar and bar:IsShown()

	if detached and bar.Holder then
		-- Detached Wildcard resource: one clean shadow around its mover/holder.
		local attachedTarget = bar.backdrop or bar
		if attachedTarget and attachedTarget.pdySkinShadow then
			attachedTarget.pdySkinShadow:Hide()
		end

		local holder = bar.Holder
		if holder.SetFrameStrata and bar.GetFrameStrata then
			holder:SetFrameStrata(bar:GetFrameStrata())
		end
		if holder.SetFrameLevel and bar.GetFrameLevel then
			holder:SetFrameLevel(bar:GetFrameLevel())
		end

		local shadow = StyleShadow(holder, active, db)
		if shadow then
			shadow:SetParent(bar)
		end
	else
		-- Attached Wildcard resource: shadow only the resource bar itself.
		if bar.Holder and bar.Holder.pdySkinShadow then
			bar.Holder.pdySkinShadow:Hide()
			bar.Holder.pdySkinShadow:SetParent(bar.Holder)
		end

		local target = bar.backdrop or bar
		StyleShadow(target, active, db)
	end
end

local function ApplyDetachedPowerBar(frame, enabled, db)
	if not frame or not frame.Power then return end

	local power = frame.Power
	local holder = power.Holder

	if frame.POWERBAR_DETACHED and frame.USE_POWERBAR and holder then
		-- A detached Power bar is positioned by its own Holder/Mover. Shadow the
		-- complete detached block instead of the original UnitFrame.
		local active = db.enable and enabled and power:IsShown()
		local shadow = StyleShadow(holder, active, db)
		if shadow then
			-- Keep visibility tied to the actual Power element. This also prevents
			-- a detached shadow remaining visible when ElvUI hides the Power bar.
			shadow:SetParent(power)
		end
	else
		-- Hide a shadow left on the detached holder as soon as the Power bar is
		-- attached to the UnitFrame again.
		if holder and holder.pdySkinShadow then
			holder.pdySkinShadow:Hide()
			holder.pdySkinShadow:SetParent(holder)
		end
	end
end

-- Guardians (UnitFrames -> Guardians): one shadow per visible guardian bar.
local function ApplyGuardians(enabled, db)
	local GF = E:GetModule("Guardians", true)
	if not GF then return end

	for _, bar in ipairs(GF.framePool or {}) do
		StyleShadow(bar, db.enable and enabled and bar:IsShown(), db)
	end
	for _, bar in ipairs(GF.inactiveFramePool or {}) do
		StyleShadow(bar, false, db)
	end
end

local function ApplyCastbarFrame(frame, enabled, db)
	if not frame or not frame.Castbar then return end
	local castbar = frame.Castbar
	local target = castbar.backdrop or castbar
	StyleShadow(target, enabled, db)
end

local function ApplyCastbarTree(frame, enabled, db, depth)
	if not frame or (depth or 0) > 4 then return end
	ApplyCastbarFrame(frame, enabled, db)
	if not frame.GetChildren then return end
	local children = {frame:GetChildren()}
	for _, child in ipairs(children) do
		ApplyCastbarTree(child, enabled, db, (depth or 0) + 1)
	end
end

local function ApplyCastbars(key, enabled, db)
	if key == "playercastbar" then
		ApplyCastbarFrame(_G.ElvUF_Player, enabled, db)
	elseif key == "targetcastbar" then
		ApplyCastbarFrame(_G.ElvUF_Target, enabled, db)
	elseif key == "petcastbar" then
		ApplyCastbarFrame(_G.ElvUF_Pet, enabled, db)
	elseif key == "partycastbar" then
		ApplyCastbarTree(_G.ElvUF_Party, enabled, db, 0)
	elseif key == "bosscastbar" then
		for i = 1, 5 do
			ApplyCastbarFrame(_G["ElvUF_Boss"..i], enabled, db)
		end
	end
end

local function ApplyCoAResources(enabled, db)
	if not IsAddOnLoaded or not IsAddOnLoaded("ElvUI_CoAResources") then return end
	local module = E:GetModule("CoAResources", true)
	if not module or not module.rows then return end

	-- Keep shadows in sync when CoA switches between BAR and PIPS/AUTO at runtime.
	-- Hook only once; this does not alter the CoA addon itself.
	if not module.__ElvUIFrameShadowHooked and hooksecurefunc then
		module.__ElvUIFrameShadowHooked = true
		hooksecurefunc(module, "Update", function()
			if S.Initialized then S:UpdateFrameShadow("coaresources") end
		end)
	end

	for _, row in ipairs(module.rows) do
		if row then
			local rowEnabled = db.enable and enabled and row:IsShown()
			local barVisible = row.bar and row.bar:IsShown()

			if barVisible then
				-- Continuous resource: one shadow around the complete bar/row.
				StyleShadow(row, rowEnabled, db)
			else
				-- Bubble/PIP resource: never draw the large row rectangle.
				StyleShadow(row, false, db)
			end

			-- In PIPS mode each visible bubble gets its own shadow. In BAR mode
			-- these are explicitly hidden so stale shadows cannot remain behind.
			for _, pip in ipairs(row.pips or {}) do
				local target = pip.backdrop or pip
				local showPipShadow = rowEnabled and not barVisible and pip:IsShown()
				StyleShadow(target, showPipShadow, db)
			end
		end
	end
end


local function ApplyUnitFrameAuraIcons(frame, auraType, enabled, db)
	if not frame then return end
	local auras = frame[auraType]
	if not auras then return end

	-- Never shadow the complete Buffs/Debuffs container.
	StyleShadow(auras, false, db)

	-- Do not gate on IsShown() here. oUF can call PostUpdateIcon before the
	-- aura button/container becomes visible (notably Target Debuffs). The shadow
	-- is parented to the aura button, so WoW will hide it automatically whenever
	-- the button itself is hidden.
	local active = db.enable and enabled
	local compactPreview = frame.forceShowAuras and true or false
	local seen = {}

	-- oUF normally exposes aura buttons numerically, but some builds recycle
	-- debuff buttons only as children of the aura container. Support both paths.
	for i = 1, 80 do
		local button = auras[i]
		if button then
			seen[button] = true
			StyleAuraIconShadow(button, active, db, compactPreview)
		end
	end

	if auras.GetChildren then
		local children = {auras:GetChildren()}
		for _, button in ipairs(children) do
			if button and not seen[button] and button.GetObjectType and button:GetObjectType() == "Button" then
				seen[button] = true
				StyleAuraIconShadow(button, active, db, compactPreview)
			end
		end
	end
end

function S:UpdateUnitFrameAuraButton(button)
	if not button or not button.GetParent then return end
	local auras = button:GetParent()
	local frame = auras and auras.GetParent and auras:GetParent()
	local auraKind = auras and auras.type
	local unitType = frame and frame.unitframeType

	-- Nameplate aura icons: own switches, region shadow.
	if auraKind and auras.isNamePlate and not unitType then
		local npDB = GetDB()
		if not npDB or not npDB.frames then return end
		local npKey = auraKind == "buffs" and "nameplatebuffs" or "nameplatedebuffs"
		StyleRegionShadow(button, npDB.enable and npDB.frames[npKey], npDB)
		return
	end

	if not auraKind or not unitType then return end

	local suffix = auraKind == "buffs" and "buffs" or "debuffs"
	local key
	if unitType == "player" then key = "ufplayer"..suffix
	elseif unitType == "target" then key = "uftarget"..suffix
	elseif unitType == "party" then key = "ufparty"..suffix
	elseif unitType == "boss" then key = "ufboss"..suffix end
	if not key then return end

	local db = GetDB()
	if not db or not db.frames then return end
	StyleAuraIconShadow(button, db.frames[key], db, frame.forceShowAuras and true or false)
end

local function ApplyUnitFrameAuraTree(root, unitType, auraType, enabled, db, depth)
	if not root or (depth or 0) > 8 then return end
	if root.unitframeType == unitType then
		ApplyUnitFrameAuraIcons(root, auraType, enabled, db)
	end
	if root.GetChildren then
		local children = {root:GetChildren()}
		for _, child in ipairs(children) do
			ApplyUnitFrameAuraTree(child, unitType, auraType, enabled, db, (depth or 0) + 1)
		end
	end
end

local function ApplyUnitFrameAuras(key, enabled, db)
	local auraType = key:match("buffs$") and "Buffs" or "Debuffs"
	if key:match("^ufplayer") then
		ApplyUnitFrameAuraIcons(_G.ElvUF_Player, auraType, enabled, db)
	elseif key:match("^uftarget") then
		ApplyUnitFrameAuraIcons(_G.ElvUF_Target, auraType, enabled, db)
	elseif key:match("^ufparty") then
		ApplyUnitFrameAuraTree(_G.ElvUF_Party, "party", auraType, enabled, db, 0)
	elseif key:match("^ufboss") then
		for i = 1, 5 do
			ApplyUnitFrameAuraIcons(_G["ElvUF_Boss"..i], auraType, enabled, db)
		end
	end
end

local function ApplyDTBars2(enabled, db)
	if not IsAddOnLoaded or not IsAddOnLoaded("ElvUI_DTBars2") then return end

	local module = E:GetModule("DTBars2", true)
	local dataTexts = E:GetModule("DataTexts", true)
	if not module or not dataTexts or not dataTexts.RegisteredPanels then return end

	if not module.__ElvUIFrameShadowHooked and hooksecurefunc then
		module.__ElvUIFrameShadowHooked = true
		local function RefreshDTBars2Shadows()
			if S.Initialized then S:UpdateFrameShadow("dtbars2") end
		end
		if module.CreateFrames then hooksecurefunc(module, "CreateFrames", RefreshDTBars2Shadows) end
		if module.ExtraDataBarSetup then hooksecurefunc(module, "ExtraDataBarSetup", RefreshDTBars2Shadows) end
		if module.Resize then hooksecurefunc(module, "Resize", RefreshDTBars2Shadows) end
		if module.MouseOver then hooksecurefunc(module, "MouseOver", RefreshDTBars2Shadows) end
	end

	for panelName, panel in pairs(dataTexts.RegisteredPanels) do
		if type(panelName) == "string" and panelName:match("^DTB2_") and panel then
			local panelDB = E.db and E.db.dtbars and E.db.dtbars[panelName]
			local showShadow = db.enable and enabled and panelDB and panelDB.enable and not panelDB.hide and panel:IsShown()
			StyleShadow(panel, showShadow, db)
		end
	end
end


local function ApplyMinimapButtonBar(enabled, db)
	local module = E:GetModule("MinimapButtons", true)
	if not module or not module.frame then return end

	if not module.__ElvUIFrameShadowHooked and hooksecurefunc then
		module.__ElvUIFrameShadowHooked = true
		local function RefreshMinimapButtonShadow()
			if S.Initialized then S:UpdateFrameShadow("minimapbuttonbar") end
		end
		if module.UpdateLayout then hooksecurefunc(module, "UpdateLayout", RefreshMinimapButtonShadow) end
		if module.UpdatePosition then hooksecurefunc(module, "UpdatePosition", RefreshMinimapButtonShadow) end
		if module.ScanButtons then hooksecurefunc(module, "ScanButtons", RefreshMinimapButtonShadow) end
	end

	local frame = module.frame
	local frameDB = E.db and E.db.general and E.db.general.minimap and E.db.general.minimap.buttonFrame
	local active = db.enable and enabled and frameDB and frameDB.enable and frame:IsShown()
	local backdrop = frame.backdrop
	local useBackdrop = active and frameDB.backdrop and backdrop and backdrop:IsShown()

	StyleShadow(backdrop, useBackdrop, db)
	StyleShadow(frame, false, db)

	for _, button in ipairs(module.buttons or {}) do
		if button then
			local target = button.backdrop or button
			StyleShadow(target, active and not useBackdrop and button:IsShown(), db)
		end
	end
end

local function ApplyEnhancedMinimapBar(enabled, db)
	if not IsAddOnLoaded or not IsAddOnLoaded("ElvUI_Enhanced") then return end

	local module = E:GetModule("Enhanced_MinimapButtonGrabber", true)
	if not module or not module.frame then return end

	if not module.__ElvUIFrameShadowHooked and hooksecurefunc then
		module.__ElvUIFrameShadowHooked = true
		local function RefreshEnhancedMinimapShadow()
			if S.Initialized then S:UpdateFrameShadow("enhancedminimapbar") end
		end
		if module.UpdateLayout then hooksecurefunc(module, "UpdateLayout", RefreshEnhancedMinimapShadow) end
		if module.UpdatePosition then hooksecurefunc(module, "UpdatePosition", RefreshEnhancedMinimapShadow) end
		if module.GrabMinimapButtons then hooksecurefunc(module, "GrabMinimapButtons", RefreshEnhancedMinimapShadow) end
	end

	local frame = module.frame
	local grabberDB = E.db and E.db.enhanced and E.db.enhanced.minimap and E.db.enhanced.minimap.buttonGrabber
	local privateDB = E.db and E.db.enhanced and E.db.enhanced.private
	local insideMinimap = grabberDB and grabberDB.insideMinimap and grabberDB.insideMinimap.enable
	local active = db.enable and enabled and grabberDB and privateDB and privateDB.minimapButtonGrabber and not insideMinimap and frame:IsShown()

	-- If Enhanced draws a bar backdrop, shadow that exact visible panel.
	-- Without a backdrop, mirror ActionBars/MicroBar behavior and shadow
	-- each visible grabbed minimap button individually instead.
	local backdrop = frame.backdrop
	local useBackdrop = active and grabberDB.backdrop and backdrop and backdrop:IsShown()
	StyleShadow(backdrop, useBackdrop, db)
	StyleShadow(frame, false, db)

	for _, button in ipairs(module.skinnedButtons or {}) do
		if button then
			local target = button.backdrop or button
			StyleShadow(target, active and not useBackdrop and button:IsShown(), db)
		end
	end
end

local function ApplySquidBotsLite(enabled, db)
	if not IsAddOnLoaded or not IsAddOnLoaded("SquidBotsLite") then return end

	local bar = _G.SquidBotsLiteBar
	if not bar or not bar.GetChildren then return end

	-- SquidBotsLite keeps its command buttons unnamed, so detect the real order
	-- buttons by their icon/caption/ring fields. Toast buttons are ignored.
	for _, button in ipairs({bar:GetChildren()}) do
		if button and button.IsObjectType and button:IsObjectType("Button") and button.icon and button.caption and button.ring then
			local active = db.enable and enabled and bar:IsShown() and button:IsShown()

			-- AddOnSkins creates a backdrop on the button. Prefer it when present so
			-- the shadow follows the exact ElvUI-styled button border. If AddOnSkins
			-- is not installed/enabled, fall back to the original Squid button.
			if button.backdrop then
				StyleShadow(button, false, db)
				StyleShadow(button.backdrop, active, db)
			else
				StyleShadow(button, active, db)
			end
		end
	end
end

local function ApplyAuraIconShadows(key, enabled, db)
	local header = GetTarget(key)
	if not header then return end

	-- Player aura shadows belong to the actual aura icons, never the header/container.
	StyleShadow(header, false, db)

	local prefix = key == "buffs" and "ElvUIPlayerBuffs" or "ElvUIPlayerDebuffs"
	local seen = {}
	if header.GetChildren then
		local children = {header:GetChildren()}
		for _, child in ipairs(children) do
			local name = child.GetName and child:GetName()
			if name and (name:match("^"..prefix.."AuraButton%d+$") or name:match("^"..prefix.."TempEnchant%d+$")) then
				seen[child] = true
				StyleShadow(child, enabled and child:IsShown(), db)
			end
		end
	end

	-- Hide stale icon shadows when an aura button is recycled or reparented.
	for i = 1, 80 do
		local button = _G[prefix.."AuraButton"..i]
		if button and not seen[button] then StyleShadow(button, false, db) end
	end
	if key == "buffs" then
		for i = 1, 3 do
			local button = _G[prefix.."TempEnchant"..i]
			if button and not seen[button] then StyleShadow(button, false, db) end
		end
		for _, button in ipairs({_G.ElvuiVanityBuffs, _G.ElvuiConsolidatedBuffs}) do
			if button then StyleShadow(button, enabled and button:IsShown(), db) end
		end
	end
end

local TOOLTIP_NAMES = {
	"GameTooltip",
	"ItemRefTooltip",
	"ItemRefShoppingTooltip1", "ItemRefShoppingTooltip2", "ItemRefShoppingTooltip3",
	"ShoppingTooltip1", "ShoppingTooltip2", "ShoppingTooltip3",
	"FriendsTooltip", "ConsolidatedBuffsTooltip", "VanityBuffsTooltip",
	"WorldMapTooltip", "WorldMapCompareTooltip1", "WorldMapCompareTooltip2", "WorldMapCompareTooltip3",
	"DatatextTooltip",
}

local function ApplyTooltipFrame(frame, enabled, db)
	if not frame then return end
	-- Tooltips are frequently hidden when settings are refreshed. Keep the shadow
	-- prepared as a child of the tooltip; parent visibility controls rendering.
	StyleShadow(frame, db.enable and enabled, db)
end

local function ApplyTooltipHealthBar(enabled, db)
	local statusBar = _G.GameTooltipStatusBar
	if not statusBar then return end

	-- The health bar belongs to the Tooltip shadow switch. Keep its glow on the
	-- actual status bar so it follows height/position changes and automatically
	-- disappears whenever Blizzard/ElvUI hides the bar.
	StyleShadow(statusBar, db.enable and enabled, db)
end

local function ApplyTooltips(enabled, db)
	for _, name in ipairs(TOOLTIP_NAMES) do
		ApplyTooltipFrame(_G[name], enabled, db)
	end
	ApplyTooltipHealthBar(enabled, db)
end

-- Public helper: gives any frame (e.g. a dropdown menu) the same shadow as tooltips.
-- Follows Skins -> Shadows -> Tooltips, no separate setting.
function S:ApplyTooltipShadow(frame, show)
	local db = GetDB()
	if not frame or not db then return end
	StyleShadow(frame, show and db.enable and db.frames and db.frames.tooltips, db)
end

local function HideContainerShadow(frame, db)
	if frame then StyleShadow(frame, false, db) end
end

local function RegisterGroupedFrameShadowOnShow(frame, key)
	if not frame or frame.__ElvUIGroupedShadowOnShow then return end
	frame.__ElvUIGroupedShadowOnShow = true
	frame:HookScript("OnShow", function(self)
		local current = GetDB()
		if not current or not current.frames then return end
		StyleShadow(self, current.enable and current.frames[key], current)
	end)
end

local function ApplyUnitFrameTree(root, unitType, enabled, db, depth)
	if not root or (depth or 0) > 8 then return end
	if root.unitframeType == unitType then
		RegisterGroupedFrameShadowOnShow(root, unitType)
		StyleShadow(root, enabled and root:IsShown(), db)
	end
	if root.GetChildren then
		local children = {root:GetChildren()}
		for _, child in ipairs(children) do
			ApplyUnitFrameTree(child, unitType, enabled, db, (depth or 0) + 1)
		end
	end
end

local function ApplyGroupedUnitFrames(key, enabled, db)
	if key == "party" then
		local root = _G.ElvUF_Party
		HideContainerShadow(root, db)
		ApplyUnitFrameTree(root, "party", db.enable and enabled, db, 0)
	elseif key == "raid" then
		local root = _G.ElvUF_Raid
		HideContainerShadow(root, db)
		ApplyUnitFrameTree(root, "raid", db.enable and enabled, db, 0)
	elseif key == "raid40" then
		local root = _G.ElvUF_Raid40
		HideContainerShadow(root, db)
		ApplyUnitFrameTree(root, "raid40", db.enable and enabled, db, 0)
	elseif key == "boss" then
		HideContainerShadow(_G.BossHeader, db)
		for i = 1, 5 do
			local frame = _G["ElvUF_Boss"..i]
			if frame then
				RegisterGroupedFrameShadowOnShow(frame, "boss")
				StyleShadow(frame, db.enable and enabled and frame:IsShown(), db)
			end
		end
	elseif key == "arena" then
		HideContainerShadow(_G.ArenaHeader, db)
		for i = 1, 5 do
			local frame = _G["ElvUF_Arena"..i]
			if frame then
				RegisterGroupedFrameShadowOnShow(frame, "arena")
				StyleShadow(frame, db.enable and enabled and frame:IsShown(), db)
			end
		end
	end
end

local function ApplyLootRollFrameShadow(frame, enabled, db)
	if not frame then return end

	-- Main loot-roll bar.
	StyleShadow(frame, enabled, db)

	-- The item icon sits outside the main bar frame. Give its own backdrop/frame
	-- the exact same ElvUI shadow so the icon is visually part of the loot roll
	-- without drawing one large shadow rectangle across the intentional gap.
	local itemButton = frame.itemButton
	if itemButton then
		local iconTarget = itemButton.backdrop or itemButton
		StyleShadow(iconTarget, enabled, db)
	end
end

local function ApplyLootRollShadows(enabled, db)
	local M = E:GetModule("Misc", true)
	if not M then return end

	-- Live group-loot roll frames.
	for _, frame in ipairs(M.RollBars or {}) do
		ApplyLootRollFrameShadow(frame, enabled, db)
	end

	-- Configuration preview frames (full / half / empty).
	for _, frame in ipairs(M.lootRollPreviews or {}) do
		ApplyLootRollFrameShadow(frame, enabled, db)
	end
end


-- ---------------------------------------------------------------------------
-- Nameplate shadows (region mode)
-- The shadow pieces are textures owned by the nameplate element itself
-- (BACKGROUND layer). They therefore share the element's frame level and draw
-- order exactly. When nameplates overlap, the shadow of a plate in the back
-- disappears behind the elements of the plate in front, like the real elements.
-- A separate child frame with its own level would not follow level changes.
-- ---------------------------------------------------------------------------
local SOFT_TEXTURES = "Interface\\AddOns\\ElvUI\\Media\\Textures\\"
local REGION_PIECES = {"top", "bottom", "left", "right", "topLeft", "topRight", "bottomLeft", "bottomRight"}
local regionShadows = {}

local function RegionShow(self) for _, t in pairs(self.pieces) do t:Show() end self._shown = true end
local function RegionHide(self) for _, t in pairs(self.pieces) do t:Hide() end self._shown = false end

local function GetRegionShadow(frame)
	local shadow = regionShadows[frame]
	if shadow then return shadow end
	shadow = {pieces = {}, Show = RegionShow, Hide = RegionHide}
	for _, key in ipairs(REGION_PIECES) do
		local piece = frame:CreateTexture(nil, "BACKGROUND")
		if key == "top" or key == "bottom" then
			piece:SetTexture(SOFT_TEXTURES.."softShadowEdgeV.tga")
		elseif key == "left" or key == "right" then
			piece:SetTexture(SOFT_TEXTURES.."softShadowEdgeH.tga")
		else
			piece:SetTexture(SOFT_TEXTURES.."softShadowCorner.tga")
		end
		if key == "bottom" or key == "bottomLeft" then
			piece:SetTexCoord(0, 1, 1, 0)
		elseif key == "right" or key == "topRight" then
			piece:SetTexCoord(1, 0, 0, 1)
		elseif key == "bottomRight" then
			piece:SetTexCoord(1, 0, 1, 0)
		end
		shadow.pieces[key] = piece
	end
	regionShadows[frame] = shadow
	return shadow
end

function StyleRegionShadow(frame, enabled, db, anchor)
	if not frame or not frame.CreateTexture then return end
	local shadow = regionShadows[frame]
	if not enabled or not db or not db.enable then
		if shadow then shadow:Hide() end
		return
	end

	shadow = GetRegionShadow(frame)
	anchor = anchor or frame
	local c = db.color or {r = 0, g = 0, b = 0, a = 0.9}
	local size = max(1, min(16, db.size or 5))
	local thickness = E:Scale(size)
	local key = anchor:GetName() or tostring(anchor)
	key = key..":"..size..":"..tostring(c.r)..":"..tostring(c.g)..":"..tostring(c.b)..":"..tostring(c.a)

	if shadow._settings ~= key then
		local p = shadow.pieces
		for _, t in pairs(p) do t:ClearAllPoints() end
		p.top:SetHeight(thickness)
		p.top:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", 0, 0)
		p.top:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", 0, 0)
		p.bottom:SetHeight(thickness)
		p.bottom:SetPoint("TOPLEFT", anchor, "BOTTOMLEFT", 0, 0)
		p.bottom:SetPoint("TOPRIGHT", anchor, "BOTTOMRIGHT", 0, 0)
		p.left:SetWidth(thickness)
		p.left:SetPoint("TOPRIGHT", anchor, "TOPLEFT", 0, 0)
		p.left:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMLEFT", 0, 0)
		p.right:SetWidth(thickness)
		p.right:SetPoint("TOPLEFT", anchor, "TOPRIGHT", 0, 0)
		p.right:SetPoint("BOTTOMLEFT", anchor, "BOTTOMRIGHT", 0, 0)
		p.topLeft:SetWidth(thickness) p.topLeft:SetHeight(thickness)
		p.topLeft:SetPoint("BOTTOMRIGHT", anchor, "TOPLEFT", 0, 0)
		p.topRight:SetWidth(thickness) p.topRight:SetHeight(thickness)
		p.topRight:SetPoint("BOTTOMLEFT", anchor, "TOPRIGHT", 0, 0)
		p.bottomLeft:SetWidth(thickness) p.bottomLeft:SetHeight(thickness)
		p.bottomLeft:SetPoint("TOPRIGHT", anchor, "BOTTOMLEFT", 0, 0)
		p.bottomRight:SetWidth(thickness) p.bottomRight:SetHeight(thickness)
		p.bottomRight:SetPoint("TOPLEFT", anchor, "BOTTOMRIGHT", 0, 0)
		for _, t in pairs(p) do
			t:SetVertexColor(c.r or 0, c.g or 0, c.b or 0, c.a or 0.9)
		end
		shadow._settings = key
	end

	shadow:Show()
end

local function GetNamePlateModule()
	return E:GetModule("NamePlates", true)
end

local function ApplyNamePlateAuraIcons(container, enabled, db)
	if not container then return end
	-- Never shadow the container, only the real icons.
	StyleRegionShadow(container, false, db)
	local i = 1
	while container[i] do
		StyleRegionShadow(container[i], enabled, db)
		i = i + 1
	end
end

local function ApplyOneNamePlate(plate, key, enabled, db)
	if not plate then return end
	if key == "nameplatehealth" then
		local health = plate.Health
		if health then StyleRegionShadow(health, enabled, db, health.backdrop or health) end
	elseif key == "nameplatecastbar" then
		local castbar = plate.Castbar
		if castbar then StyleRegionShadow(castbar, enabled, db, castbar.backdrop or castbar) end
	elseif key == "nameplatecasticon" then
		local castbar = plate.Castbar
		if castbar and castbar.Button then StyleRegionShadow(castbar.Button, enabled, db) end
	elseif key == "nameplatebuffs" then
		ApplyNamePlateAuraIcons(plate.Buffs_ or plate.Buffs, enabled, db)
	elseif key == "nameplatedebuffs" then
		ApplyNamePlateAuraIcons(plate.Debuffs_ or plate.Debuffs, enabled, db)
	end
end

local NAMEPLATE_KEYS = {"nameplatehealth", "nameplatecastbar", "nameplatecasticon", "nameplatebuffs", "nameplatedebuffs"}

local function ApplyNamePlates(key, enabled, db)
	local NP = GetNamePlateModule()
	if not NP or not NP.Plates then return end
	local active = db.enable and enabled
	for plate in pairs(NP.Plates) do
		ApplyOneNamePlate(plate, key, active, db)
	end
end

local function ApplyAllNamePlateKeys(plate)
	local db = GetDB()
	if not db or not db.frames then return end
	for _, key in ipairs(NAMEPLATE_KEYS) do
		ApplyOneNamePlate(plate, key, db.enable and db.frames[key], db)
	end
end

-- Blizzard/Ascension windows. Every entry returns the skinned window (its ElvUI
-- backdrop) plus the tabs that belong to it, so the shadow follows the visible
-- ElvUI rectangle and not the oversized Blizzard frame.
local function AddShadowTarget(list, frame, requireBackdrop)
	if not frame then return end
	local target = frame.backdrop or (not requireBackdrop and frame)
	if target then list[#list + 1] = target end
end

local function AddTabSystem(list, system)
	if not system or not system.tabs then return end
	for _, tab in pairs(system.tabs) do AddShadowTarget(list, tab) end
end

local function AddNamedTabs(list, prefix, count)
	for i = 1, count do AddShadowTarget(list, _G[prefix..i], true) end
end

local BLIZZARD_WINDOWS = {
	blizzcharacter = {
		main = "AscensionCharacterFrame",
		collect = function(list)
			AddShadowTarget(list, _G.AscensionCharacterFrame, true)
			AddTabSystem(list, _G.AscensionCharacterFrame)
			AddTabSystem(list, _G.AscensionCharacterFrameRightInset)
		end,
	},
	blizzspellbook = { -- includes the Professions page
		main = "AscensionSpellbookFrame",
		collect = function(list)
			AddShadowTarget(list, _G.AscensionSpellbookFrame, true)
			AddNamedTabs(list, "AscensionSpellbookFrameTab", 3)
			for i = 1, (_G.MAX_SKILLLINE_TABS or 8) do
				AddShadowTarget(list, _G["AscensionSpellbookFrameSideBarTab"..i])
			end
		end,
	},
	blizzfriends = {
		main = "FriendsFrame",
		collect = function(list)
			AddShadowTarget(list, _G.FriendsFrame, true)
			AddNamedTabs(list, "FriendsFrameTab", 5)
			AddNamedTabs(list, "FriendsTabHeaderTab", 2)
		end,
	},
	blizzescape = {
		main = "EscapeMenu",
		collect = function(list)
			AddShadowTarget(list, _G.EscapeMenu, true)
		end,
	},
	blizzquestlog = {
		main = "QuestLogFrame",
		collect = function(list)
			AddShadowTarget(list, _G.QuestLogFrame, true)
		end,
	},
	blizzdungeon = {
		main = "AscensionLFGFrame",
		collect = function(list)
			AddShadowTarget(list, _G.AscensionLFGFrame, true)
			AddNamedTabs(list, "AscensionLFGFrameTab", 4)
		end,
	},
	blizzworldmap = {
		main = "WorldMapFrame",
		collect = function(list)
			AddShadowTarget(list, _G.WorldMapFrame, true)
		end,
	},
	blizzhelp = {
		main = "HelpMenuFrame",
		collect = function(list)
			AddShadowTarget(list, _G.HelpMenuFrame, true)
			AddTabSystem(list, _G.HelpMenuFrame and _G.HelpMenuFrame.LeftInset)
		end,
	},
}

local function ApplyBlizzardWindow(key, enabled, db)
	local info = BLIZZARD_WINDOWS[key]
	if not info then return end

	local list = {}
	info.collect(list)
	for _, target in ipairs(list) do
		StyleShadow(target, db.enable and enabled, db)
	end

	-- Re-apply whenever the window opens (late skinning, LoadOnDemand windows).
	local main = _G[info.main]
	if main and main.HookScript and not main.__ElvUIWindowShadowHook then
		main.__ElvUIWindowShadowHook = true
		main:HookScript("OnShow", function()
			if not S.Initialized then return end
			S:UpdateFrameShadow(key)
		end)
	end
end

local function ApplyMirrorTimerShadows(enabled, db)
	-- The visible bar is the status bar (with its ElvUI backdrop), not the larger Blizzard frame around it,
	-- so the shadow goes around the bar. It is a child of the bar and follows its visibility.
	for i = 1, (_G.MIRRORTIMER_NUMTIMERS or 3) do
		local bar = _G["MirrorTimer"..i.."StatusBar"]
		if bar then StyleShadow(bar.backdrop or bar, enabled, db) end
	end
end

local function ApplyOne(key, enabled, db)
	if key == "mirrortimers" then
		ApplyMirrorTimerShadows(enabled, db)
		return
	end

	if key:match("^nameplate") then
		ApplyNamePlates(key, enabled, db)
		return
	end

	if key == "guardians" then
		ApplyGuardians(enabled, db)
		return
	end

	if key == "playerclassbar" then
		ApplyPlayerClassBar(enabled, db)
		return
	end
	if key == "combobar" then
		ApplyDetachedComboBar(enabled, db)
		return
	end


	-- Wildcard HERO resource bars have independent shadow switches.
	if key == "wildcardenergy" then
		ApplyWildcardResourceBar("Energy", enabled, db)
		return
	elseif key == "wildcardrage" then
		ApplyWildcardResourceBar("Rage", enabled, db)
		return
	end

	-- Detached power bars have their own Shadow switches. They are deliberately
	-- independent from the Player/Target UnitFrame shadow toggles.
	if key == "playerpowerbar" then
		ApplyDetachedPowerBar(_G.ElvUF_Player, enabled, db)
		return
	elseif key == "targetpowerbar" then
		ApplyDetachedPowerBar(_G.ElvUF_Target, enabled, db)
		return
	end

	if key == "party" or key == "raid" or key == "raid40" or key == "boss" or key == "arena" then
		ApplyGroupedUnitFrames(key, enabled, db)
		return
	end

	if key == "buffs" or key == "debuffs" then
		ApplyAuraIconShadows(key, enabled, db)
		return
	end

	if key:match("^ufplayer") or key:match("^uftarget") or key:match("^ufparty") or key:match("^ufboss") then
		ApplyUnitFrameAuras(key, enabled, db)
		return
	end

	if key == "tooltips" then
		ApplyTooltips(enabled, db)
		return
	end

	if BLIZZARD_WINDOWS[key] then
		ApplyBlizzardWindow(key, enabled, db)
		return
	end

	if key == "coaresources" then
		ApplyCoAResources(enabled, db)
		return
	end

	if key == "dtbars2" then
		ApplyDTBars2(enabled, db)
		return
	end

	if key == "minimapbuttonbar" then
		ApplyMinimapButtonBar(enabled, db)
		return
	end

	if key == "enhancedminimapbar" then
		ApplyEnhancedMinimapBar(enabled, db)
		return
	end

	if key == "squidbotslite" then
		ApplySquidBotsLite(enabled, db)
		return
	end

	if key == "lootroll" then
		ApplyLootRollShadows(enabled, db)
		return
	end

	if key == "playercastbar" or key == "targetcastbar" or key == "petcastbar" or key == "partycastbar" or key == "bosscastbar" then
		ApplyCastbars(key, enabled, db)
		return
	end

	if key == "totembar" then
		ApplyTotemBars(enabled, db)
		return
	end

	if key == "microbar" then
		ApplyMicroBar(enabled, db)
		return
	end

	if key == "petbar" then
		ApplyPetBar(enabled, db)
		return
	end

	if key == "stancebar" then
		ApplyStanceBar(enabled, db)
		return
	end

	if ApplyActionBar(key, enabled, db) then return end

	local frame = GetTarget(key)
	if not frame then return end

	-- Player and Target can detach their Power bars to independent movers. Keep
	-- those glows controlled by their dedicated switches instead of the main
	-- UnitFrame shadow setting. Calling it here also refreshes the detached glow
	-- immediately when the UnitFrame itself is reconfigured.
	if key == "player" then
		ApplyDetachedPowerBar(frame, db.frames.playerpowerbar, db)
	elseif key == "target" then
		ApplyDetachedPowerBar(frame, db.frames.targetpowerbar, db)
	end

	local shadow = StyleShadow(frame, enabled, db)
	if not shadow or not db.enable or not enabled then return end

	if key == "boss" or key == "arena" then
		shadow._nextVisibilityCheck = 0
		shadow:SetScript("OnUpdate", function(self)
			local now = GetTime()
			if now < (self._nextVisibilityCheck or 0) then return end
			self._nextVisibilityCheck = now + 0.2
			if GroupHasVisibleUnit(key) then self:SetAlpha(1) else self:SetAlpha(0) end
		end)
		shadow:Show()
		if GroupHasVisibleUnit(key) then shadow:SetAlpha(1) else shadow:SetAlpha(0) end
	else
		shadow:SetScript("OnUpdate", nil)
		shadow:SetAlpha(1)
		shadow:Show()
	end
end

function S:UpdateFrameShadows()
	local db = GetDB()
	if not db or not db.frames then return end
	for key in pairs(targets) do
		ApplyOne(key, db.frames[key], db)
	end
end

function S:UpdateFrameShadow(key)
	local db = GetDB()
	if not db or not db.frames then return end
	ApplyOne(key, db.frames[key], db)
end

local function RefreshGroupFrameShadows()
	if not S.Initialized then return end
	S:UpdateFrameShadow("party")
	S:UpdateFrameShadow("raid")
	S:UpdateFrameShadow("raid40")
	S:UpdateFrameShadow("boss")
	S:UpdateFrameShadow("arena")
end

local function QueueGroupFrameShadowRefresh()
	RefreshGroupFrameShadows()
	if E.Delay then
		E:Delay(0.05, RefreshGroupFrameShadows)
		E:Delay(0.20, RefreshGroupFrameShadows)
		E:Delay(0.50, RefreshGroupFrameShadows)
		E:Delay(1.00, RefreshGroupFrameShadows)
	end
end

local eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
eventFrame:RegisterEvent("RAID_ROSTER_UPDATE")
eventFrame:RegisterEvent("BAG_UPDATE")
eventFrame:RegisterEvent("BANKFRAME_OPENED")
eventFrame:RegisterEvent("PLAYER_TOTEM_UPDATE")
eventFrame:RegisterEvent("ADDON_LOADED")
eventFrame:SetScript("OnEvent", function(_, event, addon)
	if event == "ADDON_LOADED" and addon ~= "ElvUI_CoAResources" and addon ~= "ElvUI_DTBars2" and addon ~= "ElvUI_Enhanced" and addon ~= "SquidBotsLite" then return end
	if not S.Initialized then return end

	if event == "PARTY_MEMBERS_CHANGED" or event == "RAID_ROSTER_UPDATE" then
		QueueGroupFrameShadowRefresh()
	else
		S:UpdateFrameShadows()
	end
end)

-- Secure group headers can create/show their unit buttons after the roster event.
-- Refresh again after ElvUI itself rebuilds a group so the very first party member
-- receives its shadow without requiring a second invite or /reload.
if UF and UF.CreateAndUpdateHeaderGroup then
	hooksecurefunc(UF, "CreateAndUpdateHeaderGroup", function(_, group)
		if S.Initialized and (group == "party" or group == "raid" or group == "raid40") then
			if E.Delay then E:Delay(0.05, RefreshGroupFrameShadows) else RefreshGroupFrameShadows() end
		end
	end)
end

if UF and UF.CreateAndUpdateUFGroup then
	hooksecurefunc(UF, "CreateAndUpdateUFGroup", function(_, group)
		if S.Initialized and (group == "boss" or group == "arena") then
			if E.Delay then E:Delay(0.05, RefreshGroupFrameShadows) else RefreshGroupFrameShadows() end
		end
	end)
end

-- Profile changes/imports and ElvUI-wide updates should immediately refresh shadows.
hooksecurefunc(E, "UpdateAll", function()
	if S.Initialized then S:UpdateFrameShadows() end
end)

-- Switching an actionbar backdrop on/off changes whether its shadow belongs to
-- the whole bar or to the individual buttons. Refresh immediately after layout updates.
if AB and AB.PositionAndSizeBar then
	hooksecurefunc(AB, "PositionAndSizeBar", function(_, barName)
		if not S.Initialized or not barName then return end
		local id = tonumber(barName:match("^bar(%d+)$"))
		if id then S:UpdateFrameShadow("actionbar"..id) end
	end)
end

local TOTEMS = E:GetModule("Totems", true)
if TOTEMS and TOTEMS.UpdateTotem then
	hooksecurefunc(TOTEMS, "UpdateTotem", function()
		if S.Initialized then S:UpdateFrameShadow("totembar") end
	end)
end

if AB and AB.PositionAndSizeBarTotem then
	hooksecurefunc(AB, "PositionAndSizeBarTotem", function()
		if S.Initialized then S:UpdateFrameShadow("totembar") end
	end)
end

if AB and AB.UpdateMicroPositionDimensions then
	hooksecurefunc(AB, "UpdateMicroPositionDimensions", function()
		if S.Initialized then S:UpdateFrameShadow("microbar") end
	end)
end

if AB and AB.PositionAndSizeBarShapeShift then
	hooksecurefunc(AB, "PositionAndSizeBarShapeShift", function()
		if S.Initialized then S:UpdateFrameShadow("stancebar") end
	end)
end

if AB and AB.AdjustMaxStanceButtons then
	hooksecurefunc(AB, "AdjustMaxStanceButtons", function()
		if S.Initialized then S:UpdateFrameShadow("stancebar") end
	end)
end

if AB and AB.PositionAndSizeBarPet then
	hooksecurefunc(AB, "PositionAndSizeBarPet", function()
		if S.Initialized then S:UpdateFrameShadow("petbar") end
	end)
end


-- Classbar layout/parent/size can change when class settings are edited.
-- Refresh the shadow immediately after ElvUI reconfigures the player classbar.
if UF and UF.Configure_ClassBar then
	hooksecurefunc(UF, "Configure_ClassBar", function(_, frame)
		if S.Initialized and frame == _G.ElvUF_Player then
			S:UpdateFrameShadow("playerclassbar")
		end
	end)
end


-- Target ComboBar can switch between attached and detached layouts.
if UF and UF.Configure_ComboPoints then
	hooksecurefunc(UF, "Configure_ComboPoints", function(_, frame)
		if S.Initialized and frame == _G.ElvUF_Target then
			S:UpdateFrameShadow("combobar")
		end
	end)
end

-- HERO Wildcard Energy/Rage can be attached or detached independently.
if UF and UF.Configure_Energy then
	hooksecurefunc(UF, "Configure_Energy", function(_, frame)
		if S.Initialized and frame == _G.ElvUF_Player then
			S:UpdateFrameShadow("wildcardenergy")
		end
	end)
end

if UF and UF.Configure_Rage then
	hooksecurefunc(UF, "Configure_Rage", function(_, frame)
		if S.Initialized and frame == _G.ElvUF_Player then
			S:UpdateFrameShadow("wildcardrage")
		end
	end)
end

-- Power layout/parent/size changes when a UnitFrame Power bar is detached or
-- attached. Refresh its shadow immediately after ElvUI reconfigures it.
if UF and UF.Configure_Power then
	hooksecurefunc(UF, "Configure_Power", function(_, frame)
		if not S.Initialized or not frame then return end

		local key
		if frame == _G.ElvUF_Player then
			key = "player"
		elseif frame == _G.ElvUF_Target then
			key = "target"
		elseif frame == _G.ElvUF_Pet then
			key = "pet"
		elseif frame == _G.ElvUF_Focus then
			key = "focus"
		elseif frame == _G.ElvUF_TargetTarget then
			key = "targettarget"
		end

		if key then S:UpdateFrameShadow(key) end
	end)
end

-- Player aura buttons are created/reused dynamically. Refresh their individual
-- shadows after ElvUI rebuilds either aura header.
if A and A.UpdateHeader then
	hooksecurefunc(A, "UpdateHeader", function(_, header)
		if not S.Initialized or not header then return end
		if header == _G.ElvUIPlayerBuffs then
			S:UpdateFrameShadow("buffs")
		elseif header == _G.ElvUIPlayerDebuffs then
			S:UpdateFrameShadow("debuffs")
		end
	end)
end

-- Most game tooltips flow through Tooltip:SetStyle. This catches newly shown
-- tooltips while ApplyTooltips covers the standard tooltip frames on profile changes.
if TT and TT.SetStyle then
	hooksecurefunc(TT, "SetStyle", function(_, tooltip)
		if not S.Initialized or not tooltip then return end
		local db = GetDB()
		if db and db.frames then
			ApplyTooltipFrame(tooltip, db.frames.tooltips, db)
			if tooltip == _G.GameTooltip then
				ApplyTooltipHealthBar(db.frames.tooltips, db)
			end
		end
	end)
end

-- The GameTooltip health bar can be shown/hidden independently of the tooltip.
-- Refresh its shadow on every show so the current Tooltip shadow setting is used.
if _G.GameTooltipStatusBar and _G.GameTooltipStatusBar.HookScript then
	_G.GameTooltipStatusBar:HookScript("OnShow", function()
		if not S.Initialized then return end
		local db = GetDB()
		if db and db.frames then ApplyTooltipHealthBar(db.frames.tooltips, db) end
	end)
end

-- Unit-frame aura icons call S:UpdateUnitFrameAuraButton directly from
-- UnitFrames/Elements/Auras.lua. This is intentional: oUF stores PostUpdateIcon
-- as a copied function reference, so hooking UF.PostUpdateAura later is unreliable.

-- Run once when the Skins module is ready. Delay passes catch frames created by other modules.
S:AddCallback("FrameShadowManager_Init", function()
	local NP = GetNamePlateModule()
	if NP and not NP.__ElvUIFrameShadowHooked then
		NP.__ElvUIFrameShadowHooked = true
		-- New plates: elements exist after StylePlate; aura icons are handled
		-- in S:UpdateUnitFrameAuraButton (PostUpdateIcon).
		hooksecurefunc(NP, "StylePlate", function(_, plate)
			if S.Initialized then ApplyAllNamePlateKeys(plate) end
		end)
		if NP.Configure_Auras then
			hooksecurefunc(NP, "Configure_Auras", function(_, plate)
				if S.Initialized then
					S:UpdateFrameShadow("nameplatebuffs")
					S:UpdateFrameShadow("nameplatedebuffs")
				end
			end)
		end
	end
	-- LoadOnDemand Blizzard/Ascension windows (e.g. Ascension_HelpUI) are skinned after they load.
	local loadWatcher = CreateFrame("Frame")
	loadWatcher:RegisterEvent("ADDON_LOADED")
	loadWatcher:SetScript("OnEvent", function()
		if not S.Initialized or not E.Delay then return end
		E:Delay(0.5, function()
			for key in pairs(BLIZZARD_WINDOWS) do S:UpdateFrameShadow(key) end
		end)
	end)

	S:UpdateFrameShadows()
	if E.Delay then
		E:Delay(0.5, function() S:UpdateFrameShadows() end)
		E:Delay(2, function() S:UpdateFrameShadows() end)
	end
end)
