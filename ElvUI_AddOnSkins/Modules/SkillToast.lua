local E, L, V, P, G = unpack(ElvUI)
local AS = E:GetModule("AddOnSkins")

local _G = _G
local unpack, wipe, tremove, ipairs = unpack, wipe, table.remove, ipairs
local CreateFrame = CreateFrame
local GetSpellInfo, GetSpellLink, GetTime = GetSpellInfo, GetSpellLink, GetTime
local GetNumSpellTabs, GetSpellTabInfo, GetSpellName = GetNumSpellTabs, GetSpellTabInfo, GetSpellName

-- New Skill Toast (part of ElvUI AddOnSkins)
-- Shows a frame at the bottom center when a new skill has been learned.
-- Settings: ElvUI > AddOnSkins > New Skill Toast  |  Position: /moveui "New Skill Toast"
-- Trigger: client event LEARNED_NEW_SPELL (C_Spell -> C_Hook), fallback: SPELLS_CHANGED.

local ST = {}
AS.SkillToast = ST

local queue, current, frame, holder = {}, nil, nil, nil
local loginGrace = true
local known = {}
local useHook = false

local SAMPLES = {
	{ name = "Fireball",    icon = "Interface\\Icons\\Spell_Fire_FlameBolt" },
	{ name = "Frost Nova",  icon = "Interface\\Icons\\Spell_Frost_FrostNova" },
	{ name = "Shadow Bolt", icon = "Interface\\Icons\\Spell_Shadow_ShadowBolt" },
}

local function cfg() return E.db.addOnSkins.skillToast end

---------------------------------------------------------------------------
-- Frame (ElvUI look)
---------------------------------------------------------------------------
local function CreateToast()
	local c = cfg()

	holder = CreateFrame("Frame", "NewSkillToastHolder", E.UIParent)
	holder:Size(c.width, c.height)
	holder:Point("BOTTOM", E.UIParent, "BOTTOM", 0, 170)

	frame = CreateFrame("Frame", "NewSkillToastFrame", E.UIParent)
	frame:Size(c.width, c.height)
	frame:SetFrameStrata("HIGH")
	frame:Point("CENTER", holder, "CENTER", 0, 0)
	frame:SetTemplate("Transparent")
	if frame.CreateShadow then frame:CreateShadow(5) end
	frame:EnableMouse(true)
	frame:Hide()

	local iconHolder = CreateFrame("Frame", nil, frame)
	iconHolder:SetFrameLevel(frame:GetFrameLevel() + 1)
	iconHolder:Size(c.height - 18, c.height - 18)
	iconHolder:Point("LEFT", frame, "LEFT", 9, 0)
	iconHolder:SetTemplate("Default")
	frame.iconHolder = iconHolder

	frame.icon = iconHolder:CreateTexture(nil, "ARTWORK")
	frame.icon:Point("TOPLEFT", iconHolder, "TOPLEFT", 2, -2)
	frame.icon:Point("BOTTOMRIGHT", iconHolder, "BOTTOMRIGHT", -2, 2)
	frame.icon:SetTexCoord(unpack(E.TexCoords))

	frame.title = frame:CreateFontString(nil, "OVERLAY")
	frame.title:FontTemplate(nil, 12, "OUTLINE")
	frame.title:Point("TOPLEFT", iconHolder, "TOPRIGHT", 10, -4)
	frame.title:Point("RIGHT", frame, "RIGHT", -12, 0)
	frame.title:SetJustifyH("LEFT")
	frame.title:SetText("New skill learned!")
	frame.title:SetTextColor(unpack(E.media.rgbvaluecolor))

	frame.name = frame:CreateFontString(nil, "OVERLAY")
	frame.name:FontTemplate(nil, 16, "OUTLINE")
	frame.name:Point("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -6)
	frame.name:Point("RIGHT", frame, "RIGHT", -12, 0)
	frame.name:SetJustifyH("LEFT")
	frame.name:SetTextColor(1, 1, 1)

	frame:SetScript("OnEnter", function(self)
		if self.spell then
			GameTooltip:SetOwner(self, "ANCHOR_TOP")
			if self.spellID then
				GameTooltip:SetHyperlink("spell:" .. self.spellID)
			else
				GameTooltip:SetText(self.spell)
			end
			GameTooltip:Show()
		end
		self.hover = true
	end)
	frame:SetScript("OnLeave", function(self) GameTooltip:Hide(); self.hover = nil end)
	frame:SetScript("OnMouseUp", function(self, button)
		if self.sticky then return end
		if button == "RightButton" then wipe(queue) end
		self.elapsed = 1e9
	end)
	frame:SetScript("OnUpdate", ST.OnUpdate)
end

---------------------------------------------------------------------------
-- Display / queue
---------------------------------------------------------------------------
local function Next()
	current = nil
	local e = tremove(queue, 1)
	if e then ST.Show(e) end
end

function ST.Show(entry)
	local c = cfg()
	current = entry
	frame.spell, frame.spellID = entry.name, entry.id
	frame.name:SetText(entry.name)
	frame.icon:SetTexture(entry.icon or "Interface\\Icons\\INV_Misc_QuestionMark")
	frame:SetScale(c.scale)
	holder:SetScale(c.scale)
	frame.elapsed = 0
	frame:SetAlpha(0)
	frame:Show()
	if c.sound then PlaySound("igQuestLogOpen") end
end

function ST.OnUpdate(self, dt)
	if self.sticky then self:SetAlpha(1) return end
	local c = cfg()
	self.elapsed = (self.elapsed or 0) + dt
	local t, fin, hold, fout = self.elapsed, c.fadeIn, c.holdTime, c.fadeOut
	if t < fin then
		self:SetAlpha(t / fin)
	elseif t < fin + hold or self.hover then
		if self.hover then self.elapsed = fin + hold - 0.01 end
		self:SetAlpha(1)
	elseif t < fin + hold + fout then
		self:SetAlpha(1 - (t - fin - hold) / fout)
	else
		self:Hide()
		Next()
	end
end

local function Enqueue(spellName)
	if loginGrace or not spellName or not cfg().enable then return end
	local name, _, icon = GetSpellInfo(spellName)
	local id
	if GetSpellLink then
		local link = GetSpellLink(spellName)
		id = link and tonumber(link:match("spell:(%d+)"))
	end
	local entry = { name = name or spellName, icon = icon, id = id }
	if current then queue[#queue + 1] = entry else ST.Show(entry) end
end

---------------------------------------------------------------------------
-- Preview
---------------------------------------------------------------------------
function ST.Preview()
	if not frame then return end
	frame.sticky = nil
	local e = SAMPLES[math.random(#SAMPLES)]
	local entry = { name = e.name, icon = e.icon }
	if current then queue[#queue + 1] = entry else ST.Show(entry) end
end

-- Persistent preview while the ElvUI movers are visible
function ST.SetStickyPreview(on)
	if not frame then return end
	if on then
		wipe(queue)
		frame.sticky = true
		ST.Show({ name = SAMPLES[1].name, icon = SAMPLES[1].icon })
		frame:SetAlpha(1)
	elseif frame.sticky then
		frame.sticky, frame.hover = nil, nil
		frame:Hide()
		Next()
	end
end

-- Called when size/scale options change
function ST.Update()
	if not frame then return end
	local c = cfg()
	holder:Size(c.width, c.height)
	frame:Size(c.width, c.height)
	frame.iconHolder:Size(c.height - 18, c.height - 18)
	frame:SetScale(c.scale)
	holder:SetScale(c.scale)
	if _G.NewSkillToastMover then _G.NewSkillToastMover:SetSize(holder:GetSize()) end
end

---------------------------------------------------------------------------
-- Events
---------------------------------------------------------------------------
local function BuildKnown()
	wipe(known)
	for tab = 1, GetNumSpellTabs() do
		local _, _, off, num = GetSpellTabInfo(tab)
		for i = off + 1, off + num do
			local n = GetSpellName(i, BOOKTYPE_SPELL)
			if n then known[n] = true end
		end
	end
end

local ev = CreateFrame("Frame")
ev:SetScript("OnEvent", function(self, event)
	if event == "PLAYER_ENTERING_WORLD" then
		-- the client reports many spells as "new" on login/zone change -> ignore briefly
		loginGrace = true
		local waited = 0
		self:SetScript("OnUpdate", function(s, dt)
			waited = waited + dt
			if waited >= 6 then
				s:SetScript("OnUpdate", nil)
				loginGrace = false
				if not useHook then BuildKnown() end
			end
		end)
	elseif event == "SPELLS_CHANGED" and not useHook and not loginGrace then
		for tab = 1, GetNumSpellTabs() do
			local _, _, off, num = GetSpellTabInfo(tab)
			for i = off + 1, off + num do
				local n = GetSpellName(i, BOOKTYPE_SPELL)
				if n and not known[n] then
					known[n] = true
					Enqueue(n)
				end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- Hide the default "You have learned ..." chat messages (optional)
---------------------------------------------------------------------------
local patterns = {}
for _, g in ipairs({ "ERR_LEARN_SPELL_S", "ERR_LEARN_ABILITY_S", "ERR_LEARN_PASSIVE_S" }) do
	local fmt = _G[g]
	if fmt then
		patterns[#patterns + 1] = "^" .. fmt:gsub("([%^%$%(%)%.%[%]%*%+%-%?])", "%%%1"):gsub("%%s", ".+")
	end
end

local function ChatFilter(_, _, message)
	if not cfg().hideDefault then return false end
	for _, pat in ipairs(patterns) do
		if message:find(pat) then return true end
	end
	return false
end

---------------------------------------------------------------------------
-- Init (called from AS:Initialize)
---------------------------------------------------------------------------
function AS:InitSkillToast()
	if frame or not E.db.addOnSkins.skillToast then return end
	CreateToast()

	E:CreateMover(holder, "NewSkillToastMover", "New Skill Toast", nil, nil, nil, "ALL,GENERAL")
	local mover = _G.NewSkillToastMover
	if mover then
		mover:HookScript("OnShow", function() ST.SetStickyPreview(true) end)
		mover:HookScript("OnHide", function() ST.SetStickyPreview(false) end)
	end

	ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", ChatFilter)

	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	if C_Hook and C_Hook.Register then
		useHook = true
		C_Hook:Register(ev, "LEARNED_NEW_SPELL", function(spellName) Enqueue(spellName) end)
	else
		ev:RegisterEvent("SPELLS_CHANGED")
	end
end

SLASH_ASSKILLTOAST1 = "/nst"
SLASH_ASSKILLTOAST2 = "/newskill"
SlashCmdList["ASSKILLTOAST"] = function(msg)
	if not frame then print("New Skill Toast: not initialized (is ElvUI AddOnSkins enabled?)") return end
	msg = (msg or ""):lower()
	if msg == "hide" or msg == "show" then
		local c = cfg()
		c.enable = (msg == "show")
		print("New Skill Toast: " .. (c.enable and "shown" or "hidden"))
		if not c.enable and frame.sticky ~= true then
			frame:Hide(); current = nil; wipe(queue)
		end
	elseif msg == "test" then
		local was = loginGrace; loginGrace = false
		Enqueue("Auto Shot"); Enqueue("Hearthstone")
		loginGrace = was
	else
		ST.Preview()
	end
end
