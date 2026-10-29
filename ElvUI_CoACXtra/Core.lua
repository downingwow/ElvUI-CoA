local E, L, V, P, G = unpack(ElvUI)
local EP = LibStub("LibElvUIPlugin-1.0")
local ACR = LibStub("AceConfigRegistry-3.0", true)
local addonName = ...

local SI = E:NewModule("ServerInfo", "AceEvent-3.0")
E.ServerInfo = SI

local find, lower, match, gsub, gmatch, format = string.find, string.lower, string.match, string.gsub, string.gmatch, string.format
local concat = table.concat
local type, ipairs, pairs, tonumber = type, ipairs, pairs, tonumber
local date, time, min = date, time, math.min
local CreateFrame = CreateFrame
local ChatFrame_AddMessageEventFilter = ChatFrame_AddMessageEventFilter

-- Profile settings
P.coaCXtra = {
	who = {enable = true},
	itemFix = {enable = true},
}

P.serverInfo = {
	enable = true,
	hideChat = true,
	toast = true,
	toastOnlyOnChange = true,
	toastDuration = 15,
	toastWidth = 380,
	triggerZones = "[Test Zones]",
	triggerServer = "[SERVER]",
	triggerHotspot = "XP Hotspot:",
	batchDelay = 2.5,
	restartToastMin = 10,
	zonesEnable = true,
	serverEnable = true,
	hotspotEnable = true,

	restartBar = {
		enable = true,
		hideOriginal = true,
		label = "Server restart in %s",
		width = 300,
		height = 22,
		texture = "ElvUI Norm",
		font = "PT Sans Narrow",
		fontSize = 13,
		outline = "OUTLINE",
		textPosition = "CENTER",
		colorByTime = true,
		color = {1, 0.55, 0.1},
		gradient = true,
		gradientDirection = "VERTICAL",
		gradientStrength = 0.45,
		shadow = true,
		shadowSize = 4,
	},
}

local COLOR_TITLE = "|cffffd200"
local COLOR_ZONE = "|cffe5e3e3"
local COLOR_DIM = "|cff909090"
local COLOR_ALERT = "|cffff5555"

local EVENTS = {
	"CHAT_MSG_SYSTEM", "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL",
	"CHAT_MSG_WHISPER", "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_YELL",
	"CHAT_MSG_MONSTER_WHISPER", "CHAT_MSG_MONSTER_EMOTE", "CHAT_MSG_RAID_WARNING",
	"CHAT_MSG_PARTY", "CHAT_MSG_GUILD", "CHAT_MSG_RAID", "CHAT_MSG_BATTLEGROUND",
}

local RATE_COLORS = {
	{"xp", "|cff55ff55"},
	{"rune", "|cffb07cff"},
	{"token", "|cffffd200"},
	{"gold", "|cffffd200"},
	{"honor", "|cffff8040"},
	{"loot", "|cff4db8ff"},
	{"drop", "|cff4db8ff"},
}
local DEFAULT_RATE_COLOR = "|cff4db8ff"

local function RateColor(label)
	local l = lower(label or "")
	for _, entry in ipairs(RATE_COLORS) do
		if find(l, entry[1], 1, true) then return entry[2] end
	end
	return DEFAULT_RATE_COLOR
end

--------------------------------------------------------------------------------
-- Text processing
--------------------------------------------------------------------------------

local function Clean(msg)
	msg = gsub(msg, "|c%x%x%x%x%x%x%x%x", "")
	msg = gsub(msg, "|r", "")
	msg = gsub(msg, "|H.-|h(.-)|h", "%1")
	msg = gsub(msg, "%s+", " ")
	msg = gsub(msg, "^ ", "")
	msg = gsub(msg, " $", "")
	return msg
end

local function Trim(s)
	s = gsub(s, "^%s+", "")
	s = gsub(s, "%s+$", "")
	return s
end

local function SplitList(str)
	str = gsub(str, "%s+&%s+", ",")
	str = gsub(str, "%s+and%s+", ",")
	local out = {}
	for part in gmatch(str, "[^,]+") do
		part = Trim(part)
		part = gsub(part, "%.$", "")
		if part ~= "" then out[#out + 1] = part end
	end
	return out
end

local function SplitTag(text)
	local tag, body = match(text, "^%[(.-)%]%s*(.*)$")
	if not tag then return "", text end
	return tag, body
end

function SI:ParseZones(msg)
	local text = Clean(msg)
	local tag, body = SplitTag(text)
	local data = {tag = tag, raw = text, zones = {}, rates = {}}

	local zonesStr = match(body, "[Zz]ones?%s+are:?%s*(.-)%s+with%s") or match(body, ":%s*(.-)%s+with%s")
	if zonesStr then data.zones = SplitList(zonesStr) end

	local ratesStr = match(body, "%s+with%s+(.-)%.?$")
	if ratesStr then
		for _, piece in ipairs(SplitList(ratesStr)) do
			local value, label = match(piece, "^(%d+%.?%d*)%%%s*(.+)$")
			if value then
				data.rates[#data.rates + 1] = {value = value .. "%", label = Trim(label)}
			end
		end
	end
	return data
end

local function UnitMultiplier(unit)
	local u = lower(unit or "")
	if find(u, "^h") then return 3600 end
	if find(u, "^m") then return 60 end
	if find(u, "^s") then return 1 end
end

function SI:ParseServer(msg)
	local text = Clean(msg)
	local tag, body = SplitTag(text)
	local data = {tag = tag, raw = text, body = body}

	local after = match(body, "[Rr]estart%a*%s+in%s+(.*)$") or match(body, "%f[%w]in%s+(%d.*)$")
	if after then
		local pos, total, lastEnd = 1, 0, nil
		while true do
			local from = pos
			local _, andEnd = find(after, "^%s+and%s+", pos)
			if andEnd then from = andEnd + 1 end
			local s, e, num, unit = find(after, "^[%s,]*(%d+)%s*(%a+)", from)
			if not s then break end
			local mult = UnitMultiplier(unit)
			if not mult then break end
			total = total + tonumber(num) * mult
			local _, optEnd = find(after, "^%(s%)", e + 1) -- "Minute(s)"
			if optEnd then e = optEnd end
			pos, lastEnd = e + 1, e
		end
		if lastEnd then
			data.seconds = total
			data.timeText = Trim(after:sub(1, lastEnd))
		end
	end
	return data
end

local function ServerBody(data)
	local body = data.body or data.raw or ""
	if data.timeText then
		local s, e = find(body, data.timeText, 1, true)
		if s then
			body = body:sub(1, s - 1) .. COLOR_ALERT .. body:sub(s, e) .. "|r" .. body:sub(e + 1)
		end
	end
	return body
end

function SI:ParseHotspot(msg)
	local text = Clean(msg)
	local body = match(text, "[Hh]otspot:%s*(.*)$") or text
	local data = {tag = "XP Hotspot", raw = text}

	local location, rest = match(body, "^(.-)%s+[\226\128\148%-]+%s+(.*)$")
	if not location then location, rest = match(body, "^(.-)%s+(%+%d.*)$") end
	data.location = Trim(location or body)
	data.id = data.location

	if rest then
		local bonus, what, amount, unit = match(rest, "%+?(%d+%.?%d*)%%%s*(.-)%s+for%s+(%d+)%s*(%a+)")
		if bonus then
			data.bonus, data.what = bonus, Trim(what)
			amount = tonumber(amount)
			local u = lower(unit)
			local mult = 60
			if find(u, "^h") then mult = 3600 elseif find(u, "^s") then mult = 1 end
			data.duration = amount * mult
			data.durationText = amount .. " " .. unit
		else
			data.what = Trim(gsub(rest, "%.$", ""))
		end
	end
	return data
end

local function SameData(a, b)
	if not a or not b then return false end
	return a.raw == b.raw
end


local CATEGORIES = {
	{key = "zones", name = "Test Zones", trigger = "triggerZones", enable = "zonesEnable", parse = "ParseZones", accent = {1, 0.82, 0}},
	{key = "hotspot", name = "XP Hotspot", trigger = "triggerHotspot", enable = "hotspotEnable", parse = "ParseHotspot", accent = {0.33, 1, 0.5}, multi = true},
	{key = "server", name = "Server Message", trigger = "triggerServer", enable = "serverEnable", parse = "ParseServer", accent = {1, 0.33, 0.33}},
}
local CATEGORY_BY_KEY = {}
for _, cat in ipairs(CATEGORIES) do CATEGORY_BY_KEY[cat.key] = cat end

local function DB()
	ElvUI_ServerInfoDB = ElvUI_ServerInfoDB or {}
	local db = ElvUI_ServerInfoDB
	if not db.multi then db.multi = {} end
	if not db.cats then
		db.cats = {}
		if db.last then -- migrate
			db.cats.zones = db.last
			db.last = nil
		end
	end
	return db
end

function SI:GetData(key)
	return DB().cats[key]
end

local function IsRestartCancel(text)
	local l = lower(Clean(text))
	return find(l, "restart", 1, true) and find(l, "cancel", 1, true) and true or false
end

local function FindCategory(msg)
	local cfg = E.db and E.db.serverInfo
	if not cfg or not cfg.enable or type(msg) ~= "string" then return end
	local clean = lower(Clean(msg))
	for _, cat in ipairs(CATEGORIES) do
		local trigger = cfg[cat.trigger]
		if cfg[cat.enable] and trigger and trigger ~= "" and find(clean, lower(trigger), 1, true) == 1 then
			return cat
		end
	end
	if cfg.serverEnable and (find(clean, "^restart") or find(clean, "^server restart")) and IsRestartCancel(clean) then
		return CATEGORY_BY_KEY.server
	end
end

local function ChatFilter(_, _, msg)
	local cfg = E.db and E.db.serverInfo
	if cfg and cfg.hideChat and FindCategory(msg) then
		return true
	end
end

function SI:OnChatEvent(_, msg)
	local cat = FindCategory(msg)
	if not cat then return end
	local data = self[cat.parse](self, msg)
	data.time = time()
	self:Update(cat, data)

	if cat.key == "server" then
		if IsRestartCancel(msg) then
			self:CancelRestart()
		elseif data.seconds and find(lower(data.body or ""), "restart", 1, true) and E.db.serverInfo.restartBar.enable then
			self:StartRestart(data.seconds)
		end
	end
end

function SI:Update(cat, data)
	local db = DB()
	local previous = db.cats[cat.key]
	if cat.multi then
		db.multi[cat.key] = db.multi[cat.key] or {}
		previous = db.multi[cat.key][data.id]
		if data.duration then data.expires = data.time + data.duration end
		db.multi[cat.key][data.id] = data
	end
	local changed = not SameData(previous, data)
	self.shown = self.shown or {}
	local seen = self.shown[cat.key .. (cat.multi and data.id or "")]
	db.cats[cat.key] = data

	if ACR then ACR:NotifyChange("ElvUI") end

	local cfg = E.db.serverInfo
	local tooShort = cat.key == "server" and data.seconds and data.seconds < (cfg.restartToastMin or 10)
	if cfg.toast and not tooShort and (changed or not cfg.toastOnlyOnChange or not seen) then
		self.shown[cat.key .. (cat.multi and data.id or "")] = true
		if cat.multi then
			self:QueueBatch(cat, data, changed)
		else
			self:ShowToast(cat, data, changed)
		end
	end
end

--------------------------------------------------------------------------------
-- Toast
--------------------------------------------------------------------------------

local toast

local function ToastOnUpdate(self, elapsed)
	if not self.state then return end
	self.t = self.t + elapsed

	if self.state == "in" then
		local p = min(self.t / 0.35, 1)
		self:SetAlpha(p)
		self:ClearAllPoints()
		self:SetPoint("TOP", self.holder, "TOP", 0, (1 - p) * 40)
		if p >= 1 then self.state, self.t = "hold", 0 end
	elseif self.state == "hold" then
		local hold = (#SI.queue > 0) and min(self.duration, 6) or self.duration
		if not self.hover and self.t >= hold then self.state, self.t = "out", 0 end
	elseif self.state == "out" then
		local p = min(self.t / 0.6, 1)
		self:SetAlpha(1 - p)
		if p >= 1 then
			self:Hide()
			self.state = nil
			SI:NextToast()
		end
	end
end

local function CreateToast()
	local holder = CreateFrame("Frame", "ElvUI_ServerInfoToastHolder", E.UIParent)
	holder:SetSize(380, 90)
	holder:SetPoint("TOP", E.UIParent, "TOP", 0, -130)

	local f = CreateFrame("Frame", "ElvUI_ServerInfoToast", E.UIParent)
	f:SetFrameStrata("DIALOG")
	f:SetSize(380, 90)
	f:SetTemplate("Transparent")
	f:EnableMouse(true)
	f:Hide()
	f.holder = holder

	f.accent = f:CreateTexture(nil, "OVERLAY")
	f.accent:SetTexture(E.media.blankTex)
	f.accent:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
	f.accent:SetPoint("BOTTOMLEFT", f, "BOTTOMLEFT", 2, 2)
	f.accent:SetWidth(3)

	f.title = f:CreateFontString(nil, "OVERLAY")
	f.title:FontTemplate(nil, 14, "OUTLINE")
	f.title:SetPoint("TOPLEFT", f, "TOPLEFT", 14, -8)
	f.title:SetJustifyH("LEFT")

	f.badge = f:CreateFontString(nil, "OVERLAY")
	f.badge:FontTemplate(nil, 10, "OUTLINE")
	f.badge:SetPoint("TOPRIGHT", f, "TOPRIGHT", -8, -10)
	f.badge:SetJustifyH("RIGHT")

	f.text = f:CreateFontString(nil, "OVERLAY")
	f.text:FontTemplate(nil, 12)
	f.text:SetJustifyH("LEFT")
	f.text:SetJustifyV("TOP")
	f.text:SetPoint("TOPLEFT", f.title, "BOTTOMLEFT", 0, -6)

	f.rates = f:CreateFontString(nil, "OVERLAY")
	f.rates:FontTemplate(nil, 12, "OUTLINE")
	f.rates:SetJustifyH("LEFT")
	f.rates:SetJustifyV("TOP")

	f:SetScript("OnEnter", function(self) self.hover = true end)
	f:SetScript("OnLeave", function(self) self.hover = false end)
	f:SetScript("OnMouseUp", function(self) self.state, self.t = "out", 0 end)
	f:SetScript("OnUpdate", ToastOnUpdate)

	E:CreateMover(holder, "ServerInfoToastMover", "Server Info Toast", nil, nil, nil, "ALL,GENERAL")
	return f
end

SI.queue = {}

SI.batch = {}
local batchWait = 0
local batchFrame = CreateFrame("Frame")
batchFrame:Hide()
batchFrame:SetScript("OnUpdate", function(self, elapsed)
	batchWait = batchWait - elapsed
	if batchWait <= 0 then
		self:Hide()
		SI:FlushBatch()
	end
end)

function SI:QueueBatch(cat, data, changed)
	local b = self.batch[cat.key]
	if not b then
		b = {cat = cat, list = {}, changed = false}
		self.batch[cat.key] = b
	end
	local replaced
	for i, d in ipairs(b.list) do
		if d.id == data.id then b.list[i] = data; replaced = true end
	end
	if not replaced then b.list[#b.list + 1] = data end
	b.changed = b.changed or changed
	batchWait = (E.db.serverInfo.batchDelay or 2.5)
	batchFrame:Show()
end

function SI:FlushBatch()
	local batches = self.batch
	self.batch = {}
	for _, b in pairs(batches) do
		if #b.list == 1 then
			self:ShowToast(b.cat, b.list[1], b.changed)
		elseif #b.list > 1 then
			self:ShowToast(b.cat, {tag = "XP Hotspots", list = b.list, raw = ""}, b.changed)
		end
	end
end

function SI:ShowToast(cat, data, changed)
	if toast and toast.state then
		self.queue[#self.queue + 1] = {cat, data, changed}
		return
	end
	self:DisplayToast(cat, data, changed)
end

function SI:NextToast()
	local nextItem = table.remove(self.queue, 1)
	if nextItem then self:DisplayToast(nextItem[1], nextItem[2], nextItem[3]) end
end

function SI:DisplayToast(cat, data, changed)
	if not toast then toast = CreateToast() end
	local cfg = E.db.serverInfo
	local width = cfg.toastWidth or 380
	local pad = 14

	toast:SetWidth(width)
	toast.holder:SetWidth(width)
	toast.accent:SetVertexColor(cat.accent[1], cat.accent[2], cat.accent[3])

	local title = (data.tag ~= "" and data.tag) or cat.name
	toast.title:SetText(COLOR_TITLE .. title .. "|r")
	toast.badge:SetText(changed and "|cff55ff55NEW / CHANGED|r" or COLOR_DIM .. "Reminder|r")

	local innerW = width - pad - 10
	local y = 8 + toast.title:GetStringHeight() + 6
	local rateParts = {}

	toast.text:SetWidth(innerW)
	if cat.key == "zones" then
		if #data.zones > 0 then
			local zoneLines = {}
			for _, z in ipairs(data.zones) do zoneLines[#zoneLines + 1] = COLOR_ZONE .. z .. "|r" end
			toast.text:SetText(concat(zoneLines, COLOR_DIM .. "   |   |r"))
		else
			toast.text:SetText(COLOR_ZONE .. (data.raw or "") .. "|r")
		end
		for _, r in ipairs(data.rates) do
			rateParts[#rateParts + 1] = RateColor(r.label) .. r.value .. "|r " .. r.label
		end
	elseif cat.key == "hotspot" then
		local list = data.list or {data}
		local first = list[1]
		local same = true
		for _, d in ipairs(list) do
			if d.bonus ~= first.bonus or d.what ~= first.what or d.durationText ~= first.durationText then same = false end
		end
		local lines = {}
		for _, d in ipairs(list) do
			local line = COLOR_ZONE .. d.location .. "|r"
			if not same and d.bonus then
				line = line .. "  |cff55ff55+" .. d.bonus .. "%|r " .. (d.what or "") .. (d.durationText and (COLOR_DIM .. " (" .. d.durationText .. ")|r") or "")
			end
			lines[#lines + 1] = line
		end
		toast.text:SetText(concat(lines, "\n"))
		if #list > 1 then toast.title:SetText(COLOR_TITLE .. "XP Hotspots (" .. #list .. ")|r") end
		if same then
			if first.bonus then
				rateParts[1] = "|cff55ff55+" .. first.bonus .. "%|r " .. (first.what or "")
				if first.durationText then rateParts[2] = COLOR_DIM .. "for " .. first.durationText .. "|r" end
			elseif first.what then
				rateParts[1] = first.what
			end
		end
	else
		toast.text:SetText(COLOR_ZONE .. ServerBody(data) .. "|r")
	end
	y = y + toast.text:GetStringHeight() + 8

	toast.rates:ClearAllPoints()
	toast.rates:SetPoint("TOPLEFT", toast.text, "BOTTOMLEFT", 0, -8)
	if #rateParts > 0 then
		toast.rates:SetWidth(innerW)
		toast.rates:SetText(concat(rateParts, "    "))
		toast.rates:Show()
		y = y + toast.rates:GetStringHeight() + 6
	else
		toast.rates:SetText("")
		toast.rates:Hide()
	end

	toast:SetHeight(y + 8)
	toast.holder:SetHeight(y + 8)

	toast:ClearAllPoints()
	toast:SetPoint("TOP", toast.holder, "TOP", 0, 40)
	toast.duration = cfg.toastDuration or 15
	toast.t, toast.state, toast.hover = 0, "in", false
	toast:SetAlpha(0)
	toast:Show()
end

local SAMPLES = {
	zones = "[Test Zones] The official test zones are: Duskwood, Pale Reach, Redridge Mountains, The Barrens & Westfall with 150% XP, 200% Runes and 200% Bazaar Tokens.",
	server = "[SERVER] Server restart in 20 minutes.",
	hotspot = "XP Hotspot: Deadwind Pass \226\128\148 +150% monster-kill XP for 60 minutes.",
}

function SI:TestToast(key)
	local cat = CATEGORY_BY_KEY[key]
	local data = self:GetData(key) or self[cat.parse](self, SAMPLES[key])
	self:ShowToast(cat, data, false)
end


local bar

local function FormatTime(sec)
	sec = math.max(0, math.ceil(sec))
	local h = math.floor(sec / 3600)
	local m = math.floor((sec % 3600) / 60)
	local s = sec % 60
	if h > 0 then return format("%d:%02d:%02d", h, m, s) end
	return format("%d:%02d", m, s)
end

local function BarColor(cfg, remaining)
	if cfg.colorByTime then
		if remaining <= 0 then return 1, 0.2, 0.2 end
		if remaining > 600 then return 0.3, 0.9, 0.3 end
		if remaining > 180 then return 1, 0.65, 0.1 end
		return 1, 0.25, 0.2
	end
	local c = cfg.color or {1, 0.55, 0.1}
	return c[1], c[2], c[3]
end

local function ApplyBarColor(r, g, b)
	local cfg = E.db.serverInfo.restartBar
	local tex = bar.status:GetStatusBarTexture()
	if cfg.gradient then
		local f = cfg.gradientStrength or 0.45
		bar.status:SetStatusBarColor(1, 1, 1)
		if tex and tex.SetGradientAlpha then
			tex:SetGradientAlpha(cfg.gradientDirection or "VERTICAL", r, g, b, 1, r * f, g * f, b * f, 1)
		end
	else
		if tex and tex.SetGradientAlpha then tex:SetGradientAlpha("VERTICAL", 1, 1, 1, 1, 1, 1, 1, 1) end
		bar.status:SetStatusBarColor(r, g, b)
	end
	bar.lastColor = format("%.2f%.2f%.2f", r, g, b)
end

local function ApplyShadow(cfg)
	if cfg.shadow then
		if not bar.shadow and bar.CreateShadow then bar:CreateShadow(cfg.shadowSize or 4) end
		if bar.shadow then
			local size = cfg.shadowSize or 4
			bar.shadow:SetOutside(bar, size, size)
			bar.shadow:SetBackdrop({edgeFile = E.LSM:Fetch("border", "ElvUI GlowBorder"), edgeSize = E:Scale(size)})
			bar.shadow:SetBackdropColor(0, 0, 0, 0)
			bar.shadow:SetBackdropBorderColor(0, 0, 0, 0.9)
			bar.shadow:Show()
		end
	elseif bar.shadow then
		bar.shadow:Hide()
	end
end

local function BarOnUpdate(self, elapsed)
	self.throttle = (self.throttle or 0) - elapsed
	if self.throttle > 0 then return end
	self.throttle = 0.05

	local cfg = E.db.serverInfo.restartBar
	local remaining = self.endGT - GetTime()

	if remaining < -120 then
		SI:CancelRestart()
		return
	end

	self.status:SetMinMaxValues(0, math.max(self.total, 1))
	self.status:SetValue(math.max(remaining, 0))

	if remaining > 0 then
		local label = cfg.label or "Server restart in %s"
		local t = FormatTime(remaining)
		self.text:SetText((gsub(label, "%%s", function() return t end)))
	else
		self.text:SetText("Server restarting...")
	end

	local r, g, b = BarColor(cfg, remaining)
	if format("%.2f%.2f%.2f", r, g, b) ~= self.lastColor then ApplyBarColor(r, g, b) end
end

local function CreateBar()
	local f = CreateFrame("Frame", "ElvUI_ServerInfoRestartBar", E.UIParent)
	f:SetFrameStrata("MEDIUM")
	f:SetSize(300, 22)
	f:SetPoint("TOP", E.UIParent, "TOP", 0, -60)
	f:SetTemplate("Transparent")

	f.status = CreateFrame("StatusBar", nil, f)
	f.status:SetPoint("TOPLEFT", f, "TOPLEFT", 2, -2)
	f.status:SetPoint("BOTTOMRIGHT", f, "BOTTOMRIGHT", -2, 2)
	f.status:SetMinMaxValues(0, 1)
	f.status:SetValue(1)

	f.text = f.status:CreateFontString(nil, "OVERLAY")
	f.text:FontTemplate(nil, 13, "OUTLINE")

	f:SetScript("OnUpdate", BarOnUpdate)
	f:Hide()

	bar = f
	E:CreateMover(f, "ServerInfoRestartBarMover", "Server Restart Bar", nil, nil, nil, "ALL,GENERAL")
	return f
end

function SI:UpdateOriginalFrame()
	local orig = _G.RestartTimerFrame
	if not orig then return end
	local db = E.db and E.db.serverInfo
	local cfg = db and db.restartBar
	if not self.origHooked then
		self.origHooked = true
		orig:HookScript("OnShow", function(f)
			local d = E.db and E.db.serverInfo
			if d and d.enable and d.restartBar and d.restartBar.enable and d.restartBar.hideOriginal then
				f:Hide()
			end
		end)
	end
	if db and db.enable and cfg and cfg.enable and cfg.hideOriginal and orig:IsShown() then
		orig:Hide()
	end
end

function SI:UpdateRestartBar()
	local cfg = E.db and E.db.serverInfo and E.db.serverInfo.restartBar
	if not cfg then return end
	self:UpdateOriginalFrame()
	if not bar then CreateBar() end

	bar:SetSize(cfg.width or 300, cfg.height or 22)
	bar.status:SetStatusBarTexture(E.LSM:Fetch("statusbar", cfg.texture or "ElvUI Norm") or E.media.normTex)

	bar.text:FontTemplate(E.LSM:Fetch("font", cfg.font or "PT Sans Narrow"), cfg.fontSize or 13, cfg.outline or "OUTLINE")
	bar.text:ClearAllPoints()
	local pos = cfg.textPosition or "CENTER"
	if pos == "LEFT" then
		bar.text:SetPoint("LEFT", bar.status, "LEFT", 6, 0)
	elseif pos == "RIGHT" then
		bar.text:SetPoint("RIGHT", bar.status, "RIGHT", -6, 0)
	else
		bar.text:SetPoint("CENTER", bar.status, "CENTER", 0, 0)
	end

	ApplyShadow(cfg)

	local state = DB().restart
	local active = E.db.serverInfo.enable and cfg.enable and state and bar.endGT
	if active then
		local r, g, b = BarColor(cfg, bar.endGT - GetTime())
		ApplyBarColor(r, g, b)
		bar.throttle = 0
		bar:Show()
	else
		bar:Hide()
	end
end

function SI:StartRestart(seconds)
	if not seconds or seconds <= 0 then return end
	local db = DB()
	local total = seconds
	if db.restart and db.restart.endEpoch > time() then
		total = math.max(seconds, db.restart.total or seconds) -- keep the first announced length
	end
	db.restart = {endEpoch = time() + seconds, total = total}
	if not bar then CreateBar() end
	bar.endGT, bar.total = GetTime() + seconds, total
	self:UpdateRestartBar()
end

function SI:CancelRestart()
	DB().restart = nil
	if bar then
		bar.endGT = nil
		bar:Hide()
	end
end

function SI:PreviewRestart(seconds)
	self:StartRestart(seconds or 90)
end

-- After a relog / reload
function SI:RestoreRestart()
	local db = DB()
	local state = db.restart
	if not state then return end
	local remaining = state.endEpoch - time()
	if remaining <= 0 then
		db.restart = nil
		return
	end
	if not bar then CreateBar() end
	bar.endGT, bar.total = GetTime() + remaining, state.total or math.max(remaining, 1)
	self:UpdateRestartBar()
end

local function EmptyText()
	return COLOR_DIM .. "No message received yet.|r"
end

local function InfoZones()
	local data = SI:GetData("zones")
	if not data then return EmptyText() end
	if #data.zones == 0 then return COLOR_ZONE .. (data.raw or "") .. "|r" end
	local lines = {}
	for _, z in ipairs(data.zones) do
		lines[#lines + 1] = "  " .. COLOR_TITLE .. ">|r  " .. COLOR_ZONE .. z .. "|r"
	end
	return concat(lines, "\n")
end

local function InfoRates()
	local data = SI:GetData("zones")
	if not data or #data.rates == 0 then return " " end
	local lines = {}
	for _, r in ipairs(data.rates) do
		lines[#lines + 1] = "  " .. RateColor(r.label) .. r.value .. "|r   " .. r.label
	end
	return concat(lines, "\n")
end

local function InfoServer()
	local data = SI:GetData("server")
	if not data then return EmptyText() end
	return "  " .. COLOR_ZONE .. ServerBody(data) .. "|r"
end

local function InfoHotspots()
	local multi = DB().multi.hotspot
	local now = time()
	local lines = {}
	if multi then
		local list = {}
		for id, d in pairs(multi) do
			if not d.expires or d.expires > now then list[#list + 1] = d end
		end
		table.sort(list, function(a, b) return (a.expires or 0) < (b.expires or 0) end)
		for _, d in ipairs(list) do
			local left = ""
			if d.expires then left = COLOR_DIM .. "  (" .. math.ceil((d.expires - now) / 60) .. " min left)|r" end
			local bonus = d.bonus and ("  |cff55ff55+" .. d.bonus .. "%|r " .. (d.what or "")) or ""
			lines[#lines + 1] = "  " .. COLOR_TITLE .. ">|r  " .. COLOR_ZONE .. d.location .. "|r" .. bonus .. left
		end
	end
	if #lines == 0 then return COLOR_DIM .. "No active hotspot.|r" end
	return concat(lines, "\n")
end

local function InfoTime(key)
	return function()
		local data = SI:GetData(key)
		if not data or not data.time then return " " end
		return COLOR_DIM .. "Last received: " .. date("%d.%m.%Y %H:%M", data.time) .. "|r"
	end
end

local function InfoRaw(key)
	return function()
		local data = SI:GetData(key)
		if not data then return " " end
		return COLOR_DIM .. "Original text: " .. (data.raw or "") .. "|r"
	end
end

function SI:InsertOptions()
	local function disabledToast() return not E.db.serverInfo.toast end

	local serverInfoTab = {
		order = 2,
		type = "group",
		name = COLOR_TITLE .. "Server Info|r",
		get = function(info) return E.db.serverInfo[info[#info]] end,
		set = function(info, value) E.db.serverInfo[info[#info]] = value end,
		args = {
			header = {order = 1, type = "header", name = "Server Info"},
			zonesPanel = {
				order = 2, type = "group", inline = true, name = "Test Zones",
				args = {
					zonesHeader = {order = 1, type = "description", fontSize = "medium", name = COLOR_DIM .. "Zones|r"},
					zones = {order = 2, type = "description", fontSize = "large", name = InfoZones},
					spacer1 = {order = 3, type = "description", name = " "},
					ratesHeader = {order = 4, type = "description", fontSize = "medium", name = COLOR_DIM .. "Rates|r"},
					rates = {order = 5, type = "description", fontSize = "large", name = InfoRates},
					spacer2 = {order = 6, type = "description", name = " "},
					time = {order = 7, type = "description", fontSize = "small", name = InfoTime("zones")},
					raw = {order = 8, type = "description", fontSize = "small", name = InfoRaw("zones")},
				},
			},
			hotspotPanel = {
				order = 2.5, type = "group", inline = true, name = "XP Hotspots",
				args = {
					list = {order = 1, type = "description", fontSize = "large", name = InfoHotspots},
					spacer = {order = 2, type = "description", name = " "},
					note = {order = 3, type = "description", fontSize = "small", name = COLOR_DIM .. "Hotspots disappear from this list when their time runs out. Reopen the settings to refresh the minutes.|r"},
				},
			},
			serverPanel = {
				order = 3, type = "group", inline = true, name = "Server Message",
				args = {
					message = {order = 1, type = "description", fontSize = "large", name = InfoServer},
					spacer = {order = 2, type = "description", name = " "},
					time = {order = 3, type = "description", fontSize = "small", name = InfoTime("server")},
				},
			},
			restartBar = {
				order = 3.5, type = "group", inline = true, name = "Restart Bar",
				get = function(info) return E.db.serverInfo.restartBar[info[#info]] end,
				set = function(info, value) E.db.serverInfo.restartBar[info[#info]] = value; SI:UpdateRestartBar() end,
				args = {
					enable = {
						order = 1, type = "toggle", name = "Enable",
						desc = "Shows a permanent countdown bar while a server restart is announced. It disappears when the restart is cancelled.",
					},
					hideOriginal = {
						order = 1.5, type = "toggle", name = "Hide Original CoA Frame",
						desc = "Hides the original Conquest of Azeroth restart bar at the top of the screen while this bar is enabled.",
					},
					preview = {order = 2, type = "execute", name = "Preview (90 s)", func = function() SI:PreviewRestart(90) end},
					hide = {order = 3, type = "execute", name = "Hide Bar", func = function() SI:CancelRestart() end},
					move = {order = 4, type = "execute", name = "Move Bar", func = function() E:ToggleMoveMode() end},
					label = {
						order = 5, type = "input", width = "full", name = "Label Text",
						desc = "%s is replaced by the remaining time (e.g. 14:32).",
					},
					width = {order = 6, type = "range", name = "Width", min = 100, max = 800, step = 1},
					height = {order = 7, type = "range", name = "Height", min = 8, max = 80, step = 1},
					texture = {
						order = 8, type = "select", dialogControl = "LSM30_Statusbar", name = "Texture",
						values = _G.AceGUIWidgetLSMlists and _G.AceGUIWidgetLSMlists.statusbar or {},
					},
					colorByTime = {
						order = 9, type = "toggle", name = "Color By Time",
						desc = "Green above 10 min, orange above 3 min, red below.",
					},
					color = {
						order = 10, type = "color", name = "Bar Color",
						disabled = function() return E.db.serverInfo.restartBar.colorByTime end,
						get = function()
							local c = E.db.serverInfo.restartBar.color
							return c[1], c[2], c[3]
						end,
						set = function(_, r, g, b)
							E.db.serverInfo.restartBar.color = {r, g, b}
							SI:UpdateRestartBar()
						end,
					},
					gradient = {order = 11, type = "toggle", name = "Gradient"},
					gradientDirection = {
						order = 12, type = "select", name = "Gradient Direction",
						values = {VERTICAL = "Vertical", HORIZONTAL = "Horizontal"},
						disabled = function() return not E.db.serverInfo.restartBar.gradient end,
					},
					gradientStrength = {
						order = 13, type = "range", name = "Gradient Darkness", min = 0, max = 1, step = 0.05, isPercent = true,
						desc = "Brightness of the darker end relative to the bar color.",
						disabled = function() return not E.db.serverInfo.restartBar.gradient end,
					},
					shadow = {order = 14, type = "toggle", name = "Shadow"},
					shadowSize = {
						order = 15, type = "range", name = "Shadow Size", min = 1, max = 16, step = 1,
						disabled = function() return not E.db.serverInfo.restartBar.shadow end,
					},
					font = {
						order = 16, type = "select", dialogControl = "LSM30_Font", name = "Font",
						values = _G.AceGUIWidgetLSMlists and _G.AceGUIWidgetLSMlists.font or {},
					},
					fontSize = {order = 17, type = "range", name = "Font Size", min = 6, max = 32, step = 1},
					outline = {
						order = 18, type = "select", name = "Font Outline",
						values = {
							NONE = "None", OUTLINE = "Outline", MONOCHROMEOUTLINE = "Monochrome Outline",
							THICKOUTLINE = "Thick Outline", SHADOWOUTLINE = "Shadow Outline",
						},
					},
					textPosition = {
						order = 19, type = "select", name = "Text Position",
						values = {LEFT = "Left", CENTER = "Center", RIGHT = "Right"},
					},
				},
			},
			settings = {
				order = 4, type = "group", inline = true, name = "Settings",
				args = {
					enable = {order = 1, type = "toggle", name = "Enable", desc = "Turns catching the server messages on/off."},
					zonesEnable = {
						order = 2, type = "toggle", name = "Test Zones",
						desc = "Catch the Test Zones message.",
						disabled = function() return not E.db.serverInfo.enable end,
					},
					serverEnable = {
						order = 3, type = "toggle", name = "Server Messages",
						desc = "Catch [SERVER] messages such as restart warnings.",
						disabled = function() return not E.db.serverInfo.enable end,
					},
					hotspotEnable = {
						order = 3.5, type = "toggle", name = "XP Hotspots",
						desc = "Catch XP Hotspot messages.",
						disabled = function() return not E.db.serverInfo.enable end,
					},
					hideChat = {order = 4, type = "toggle", name = "Hide in Chat", desc = "Caught messages no longer appear in the chat window."},
					toast = {order = 5, type = "toggle", name = "Show Toast", desc = "Shows caught messages as a popup on screen."},
					toastOnlyOnChange = {
						order = 6, type = "toggle", name = "Toast Only On Change",
						desc = "If the server repeats the exact same message, no new toast is shown (still once per session).",
						disabled = disabledToast,
					},
					toastDuration = {order = 7, type = "range", name = "Toast Duration (sec)", min = 3, max = 60, step = 1, disabled = disabledToast},
					toastWidth = {order = 8, type = "range", name = "Toast Width", min = 260, max = 700, step = 10, disabled = disabledToast},
					batchDelay = {
						order = 8.5, type = "range", name = "Group XP Hotspot Lines (sec)",
						desc = "Hotspot lines that arrive within this time of each other are shown together in one toast.",
						min = 0.5, max = 10, step = 0.5, disabled = disabledToast,
					},
					restartToastMin = {
						order = 8.7, type = "range", name = "Restart Toast Minimum (sec)",
						desc = "Restart warnings with less time than this left get no toast (the restart bar still shows them). 0 = always.",
						min = 0, max = 120, step = 1, disabled = disabledToast,
					},
					triggerZones = {
						order = 9, type = "input", width = "full", name = "Trigger Text: Test Zones",
						desc = "Messages that START with this text are treated as Test Zones (case-insensitive).",
					},
					triggerServer = {
						order = 10, type = "input", width = "full", name = "Trigger Text: Server Message",
						desc = "Messages that START with this text are treated as server messages (case-insensitive).",
					},
					triggerHotspot = {
						order = 10.5, type = "input", width = "full", name = "Trigger Text: XP Hotspot",
						desc = "Messages that START with this text are treated as XP Hotspots (case-insensitive).",
					},
					testHotspot = {order = 11.5, type = "execute", name = "Hotspot Toast", func = function() SI:TestToast("hotspot") end},
					testZones = {order = 11, type = "execute", name = "Test Zones Toast", func = function() SI:TestToast("zones") end},
					testServer = {order = 12, type = "execute", name = "Server Toast", func = function() SI:TestToast("server") end},
					move = {
						order = 13, type = "execute", name = "Move Toast",
						desc = "Opens the ElvUI mover mode.",
						func = function() E:ToggleMoveMode() end,
					},
					clear = {
						order = 14, type = "execute", name = "Clear Saved Messages",
						func = function()
							DB().cats = {}
							DB().multi = {}
							SI.shown = {}
							if ACR then ACR:NotifyChange("ElvUI") end
						end,
					},
				},
			},
		},
	}

	E.Options.args.coaCXtra = {
		order = 90,
		type = "group",
		childGroups = "tab",
		name = "|cffffd200CoAC Xtra|r",
		args = {
			general = {
				order = 1,
				type = "group",
				name = "General",
				args = {
					header = {order = 1, type = "header", name = "CoAC Xtra"},
					modules = {
						order = 2, type = "group", inline = true, name = "Modules",
						args = {
							whoEnable = {
								order = 1, type = "toggle", name = "Who Search (Who+)",
								desc = "Enables or disables the ElvUI styled CoA Who search (Who+ button on the friends frame, /coawho, /ewho).",
								get = function() return E.db.coaCXtra.who.enable end,
								set = function(_, value)
									E.db.coaCXtra.who.enable = value
									if E.CoACXtra and E.CoACXtra.UpdateWho then E.CoACXtra.UpdateWho() end
								end,
							},
							itemFixEnable = {
								order = 2, type = "toggle", name = "Item Error Spam Fix",
								desc = "Fixes the \"attempt to concatenate a nil value\" errors in CharacterItemSlotButton.lua. When an item icon is not cached yet, a question mark icon is used instead of nil. Takes effect immediately.",
								get = function() return E.db.coaCXtra.itemFix.enable end,
								set = function(_, value) E.db.coaCXtra.itemFix.enable = value end,
							},
						},
					},
					quests = {
						order = 3, type = "group", inline = true, name = "Quests",
						args = {
							abandonAll = {
								order = 1, type = "execute", name = "Abandon all open quests",
								desc = "Abandons every quest in your quest log. This cannot be undone. Also available as /abandonquests.",
								confirm = function()
									local count = E.CoACXtra and E.CoACXtra.CountOpenQuests and E.CoACXtra.CountOpenQuests() or 0
									return "Abandon ALL " .. count .. " open quests? This cannot be undone."
								end,
								func = function()
									if E.CoACXtra and E.CoACXtra.AbandonAllQuests then E.CoACXtra.AbandonAllQuests() end
								end,
							},
						},
					},
				},
			},
			serverInfo = serverInfoTab,
		},
	}
end

function SI:Initialize()
	EP:RegisterPlugin(addonName, SI.InsertOptions)

	for _, event in ipairs(EVENTS) do
		ChatFrame_AddMessageEventFilter(event, ChatFilter)
		self:RegisterEvent(event, "OnChatEvent")
	end

	self:UpdateRestartBar()
	self:RestoreRestart()
end

E:RegisterModule(SI:GetName())
