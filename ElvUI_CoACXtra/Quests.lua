local E = unpack(ElvUI)
E.CoACXtra = E.CoACXtra or {}

local GetNumQuestLogEntries, GetQuestLogTitle = GetNumQuestLogEntries, GetQuestLogTitle
local SelectQuestLogEntry, SetAbandonQuest, AbandonQuest = SelectQuestLogEntry, SetAbandonQuest, AbandonQuest
local GetQuestLogSelection, ExpandQuestHeader = GetQuestLogSelection, ExpandQuestHeader
local pcall = pcall

local function Print(text)
	if DEFAULT_CHAT_FRAME then
		DEFAULT_CHAT_FRAME:AddMessage("|cffffd200CoAC Xtra:|r " .. text)
	end
end

function E.CoACXtra.CountOpenQuests()
	pcall(ExpandQuestHeader, 0) -- 0 = expand all headers, collapsed zones hide their quests
	local count = 0
	for i = 1, GetNumQuestLogEntries() do
		local _, _, _, _, isHeader = GetQuestLogTitle(i)
		if not isHeader then count = count + 1 end
	end
	return count
end

function E.CoACXtra.AbandonAllQuests()
	pcall(ExpandQuestHeader, 0)

	local abandoned = 0
	for i = GetNumQuestLogEntries(), 1, -1 do
		local _, _, _, _, isHeader = GetQuestLogTitle(i)
		if not isHeader then
			SelectQuestLogEntry(i)
			SetAbandonQuest()
			if pcall(AbandonQuest) then
				abandoned = abandoned + 1
			end
		end
	end

	Print(abandoned == 0 and "No open quests." or (abandoned .. " quest(s) abandoned."))
	return abandoned
end

StaticPopupDialogs["COACXTRA_ABANDON_ALL_QUESTS"] = {
	text = "Abandon ALL %s open quests?\n\nThis cannot be undone.",
	button1 = YES,
	button2 = NO,
	OnAccept = function() E.CoACXtra.AbandonAllQuests() end,
	timeout = 0,
	whileDead = 1,
	hideOnEscape = 1,
	preferredIndex = 3,
}

function E.CoACXtra.ConfirmAbandonAllQuests()
	local count = E.CoACXtra.CountOpenQuests()
	if count == 0 then
		Print("No open quests.")
		return
	end
	StaticPopup_Show("COACXTRA_ABANDON_ALL_QUESTS", count)
end

SLASH_COACXTRAABANDON1 = "/abandonquests"
SlashCmdList["COACXTRAABANDON"] = function()
	E.CoACXtra.ConfirmAbandonAllQuests()
end
