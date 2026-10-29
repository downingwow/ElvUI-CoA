-- ElvUI_CoACXtra - Item Error Spam Fix
-- Fixes "attempt to concatenate a nil value" in CharacterItemSlotButton.lua (and similar places):
-- GetItemIconInstant returns nil for an item that is not cached yet, the Ascension UI then
-- concatenates that nil. The wrapper returns a question mark icon instead.
-- Switch: ElvUI -> CoAC Xtra -> General -> Item Error Spam Fix (checked on every call, no reload needed).

local E = unpack(ElvUI)

local FALLBACK = "INV_Misc_QuestionMark"

local function IsEnabled()
	local db = E.db and E.db.coaCXtra and E.db.coaCXtra.itemFix
	if not db then return true end -- profile not loaded yet: default is enabled
	return db.enable ~= false
end

local orig = _G.GetItemIconInstant
if type(orig) == "function" and not _G.CoACXtraItemFixApplied then
	_G.CoACXtraItemFixApplied = true
	_G.GetItemIconInstant = function(...)
		local icon = orig(...)
		if icon == nil and IsEnabled() then return FALLBACK end
		return icon
	end
end
