local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB

--Lua functions
local ipairs, pcall, find = ipairs, pcall, string.find
--WoW API / Variables
local _G = _G
local GetMacroIndexByName, GetNumMacros, GetMacroIconInfo = GetMacroIndexByName, GetNumMacros, GetMacroIconInfo

-- GLOBALS: CreateMacro, EditMacro (looked up at call time, MacroIcons wraps them), UIErrorsFrame, ChatFrame_AddMessageEventFilter, MAX_ACCOUNT_MACROS

local SB = {}
E.SingleButton = SB

SB.MACRO_NAME = "SingleButton"
SB.MACRO_BODY = "/s .rotation"
SB.FILTER_TEXT = "Select a living enemy to attack or a friendly target to heal"
SB.DEFAULT_ICON = "default" -- the standard "?" icon (always first)

-- Position der Icons im Makro-Icon-Fenster: 1 = "?", danach die Custom Icons
function SB:GetIconIndex(iconKey)
	if iconKey and iconKey ~= SB.DEFAULT_ICON and E.MacroIcons and E.MacroIcons.icons then
		for i, icon in ipairs(E.MacroIcons.icons) do
			if icon.key == iconKey then return i + 1 end
		end
	end
	return 1
end

function SB:CreateMacro(iconKey)
	local index = self:GetIconIndex(iconKey)
	local existing = GetMacroIndexByName(self.MACRO_NAME)

	if existing and existing > 0 then
		local ok = pcall(_G.EditMacro, existing, self.MACRO_NAME, index, self.MACRO_BODY)
		if not ok then ok = pcall(_G.EditMacro, existing, self.MACRO_NAME, GetMacroIconInfo(index), self.MACRO_BODY) end
		E:Print(ok and "SingleButton macro updated." or "Could not update the SingleButton macro.")
		return
	end

	local numAccount = GetNumMacros()
	if numAccount and numAccount >= (MAX_ACCOUNT_MACROS or 36) then
		E:Print("No free general macro slot left.")
		return
	end

	local ok = pcall(_G.CreateMacro, self.MACRO_NAME, index, self.MACRO_BODY, nil)
	if not ok then ok = pcall(_G.CreateMacro, self.MACRO_NAME, GetMacroIconInfo(index), self.MACRO_BODY, nil) end
	E:Print(ok and "SingleButton macro created (general macros)." or "Could not create the macro.")
end

-- Chat-/Fehlermeldung ausblenden, wenn man ohne passendes Ziel den Button spammt
local function IsFilteredMessage(msg)
	return E.db and E.db.general and E.db.general.singleButtonFilter
		and type(msg) == "string" and find(msg, SB.FILTER_TEXT, 1, true)
end

local function ChatFilter(_, _, msg)
	if IsFilteredMessage(msg) then return true end
end

ChatFrame_AddMessageEventFilter("CHAT_MSG_SYSTEM", ChatFilter)
ChatFrame_AddMessageEventFilter("CHAT_MSG_SAY", ChatFilter)

if UIErrorsFrame then
	local origAddMessage = UIErrorsFrame.AddMessage
	UIErrorsFrame.AddMessage = function(self, msg, ...)
		if IsFilteredMessage(msg) then return end
		return origAddMessage(self, msg, ...)
	end
end
