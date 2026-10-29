local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB

--Lua functions
local find, lower, type, ipairs = string.find, string.lower, type, ipairs
--WoW API / Variables
-- GLOBALS: ChatFrame_AddMessageEventFilter

-- Chat-Filter: blendet ganze Zeilen aus, wenn sie einen der eigenen Filter treffen.
-- Alle Filter werden im Profil gespeichert (E.db.chat.customFilters) und in den Optionen verwaltet.
local CF = {}
E.ChatMessageFilters = CF

-- Beim ersten Mal werden zwei bekannte Zeilen als normale (loeschbare) Filter eingetragen.
-- Der Haken entspricht dem alten Wert der entfernten Checkboxen (Standard: aus).
CF.seed = {
	{key = "squidbots", text = "[SquidBots] Need a healer, a tank or damage?"},
	{key = "xprate", text = "XP rate: pick your own with .xp"},
}

function CF:Seed()
	local chatDB = E.db and E.db.chat
	if not chatDB or chatDB.filtersSeeded then return end
	chatDB.filtersSeeded = true

	if not chatDB.customFilters then chatDB.customFilters = {} end
	for _, item in ipairs(CF.seed) do
		local enabled = chatDB.filters and chatDB.filters[item.key] or false
		chatDB.customFilters[#chatDB.customFilters + 1] = {text = item.text, enabled = enabled, mode = "contains", matchCase = false}
	end
	chatDB.filters = nil
end

local events = {
	"CHAT_MSG_SYSTEM", "CHAT_MSG_CHANNEL", "CHAT_MSG_SAY", "CHAT_MSG_YELL",
	"CHAT_MSG_WHISPER", "CHAT_MSG_MONSTER_SAY", "CHAT_MSG_MONSTER_WHISPER",
	"CHAT_MSG_MONSTER_YELL", "CHAT_MSG_RAID_WARNING", "CHAT_MSG_PARTY", "CHAT_MSG_GUILD",
}

-- Farbcodes und Links entfernen, damit eingefuegter Klartext trotzdem passt
local function Clean(msg)
	msg = msg:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", ""):gsub("|H.-|h(.-)|h", "%1")
	return msg
end

-- mehrfache Leerzeichen zu einem zusammenfassen, Raender abschneiden
local function Normalize(text)
	return (text:gsub("%s+", " "):gsub("^ ", ""):gsub(" $", ""))
end

local function Filter(_, _, msg)
	local chatDB = E.db and E.db.chat
	if not chatDB or type(msg) ~= "string" then return end

	if not chatDB.filtersSeeded then CF:Seed() end

	local custom = chatDB.customFilters
	if not custom or #custom == 0 then return end

	local clean = Clean(msg)

	-- eigene Filter (im Profil gespeichert)
	-- mode "contains": der Text muss genau so (Woerter in dieser Reihenfolge, direkt hintereinander) in der Nachricht vorkommen
	-- mode "exact":    die ganze Nachricht muss genau dem Text entsprechen
	if custom and #custom > 0 then
		local spaced = Normalize(clean)
		local lowered
		for _, entry in ipairs(custom) do
			if entry.enabled and entry.text and entry.text ~= "" then
				local needle = Normalize(entry.text)
				local hay = spaced
				if not entry.matchCase then
					lowered = lowered or lower(spaced)
					hay, needle = lowered, lower(needle)
				end

				if entry.mode == "exact" then
					if hay == needle then return true end
				elseif find(hay, needle, 1, true) then
					return true
				end
			end
		end
	end
end

for _, event in ipairs(events) do
	ChatFrame_AddMessageEventFilter(event, Filter)
end
