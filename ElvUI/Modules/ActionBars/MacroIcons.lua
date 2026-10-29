local E = unpack(select(2, ...)) --Import: Engine
local LAB = E.Libs.LAB
local _G = _G
local floor, unpack = math.floor, unpack

-- Eigene Makro-Icons ---------------------------------------------------------
-- Neue Icons hier eintragen (Datei nach Media\MacroIcons\ legen, 64x64 TGA).
-- Die Icons erscheinen im Makro-Icon-Fenster direkt nach dem Standard-"?".
local P = [[Interface\AddOns\ElvUI\Media\MacroIcons\]]
local CUSTOM_ICONS = {
	{ key = "Reset", path = P.."Reset.tga" },
	{ key = "Undo", path = P.."Undo.tga" },
	{ key = "Redo", path = P.."Redo.tga" },
}
-------------------------------------------------------------------------------

local MI = {}
E.MacroIcons = MI
MI.icons = CUSTOM_ICONS

local PLACEHOLDER_PATH = [[Interface\Icons\INV_Misc_QuestionMark]]
local numCustom = #CUSTOM_ICONS
local byKey, byPath = {}, {}
for _, icon in ipairs(CUSTOM_ICONS) do
	byKey[icon.key] = icon.path
	byPath[icon.path:lower()] = icon.key
end

local origGetNum, origGetInfo = GetNumMacroIcons, GetMacroIconInfo
local origCreate, origEdit = CreateMacro, EditMacro
local GetMacroInfo, GetActionInfo = GetMacroInfo, GetActionInfo

local function DB()
	E.global.macroIcons = E.global.macroIcons or {}
	return E.global.macroIcons
end

-- Liefert Key des Custom-Icons und das (unverschobene) Icon fuer das Original
local function Resolve(icon)
	if type(icon) == "number" then
		-- Position 1 bleibt das Standard-"?", Custom-Icons folgen ab Position 2
		if icon >= 2 and icon <= numCustom + 1 then
			return CUSTOM_ICONS[icon - 1].key, 1 -- Platzhalter: Standard-"?"
		elseif icon > numCustom + 1 then
			return nil, icon - numCustom
		end
		return nil, icon
	elseif type(icon) == "string" then
		local key = byPath[icon:lower()]
		if key then return key, PLACEHOLDER_PATH end
	end
	return nil, icon
end

local function RefreshButtons()
	for button in pairs(LAB:GetAllButtons()) do
		if button.Update then button:Update() end
	end
	if MacroFrame and MacroFrame:IsShown() and MacroFrame_Update then
		MacroFrame_Update()
	end
end

function MI:GetCustomTexture(name)
	local key = name and DB()[name]
	return key and byKey[key]
end

-- Icon-Liste: Standard-"?" zuerst, dann die Custom-Icons
function GetNumMacroIcons()
	return numCustom + origGetNum()
end

function GetMacroIconInfo(index)
	if index and index >= 2 and index <= numCustom + 1 then
		return CUSTOM_ICONS[index - 1].path
	elseif index and index > numCustom + 1 then
		index = index - numCustom
	end
	return origGetInfo(index)
end

function CreateMacro(name, icon, ...)
	local key, real = Resolve(icon)
	local db = DB()
	db[name] = key
	local id = origCreate(name, real, ...)
	RefreshButtons()
	return id
end

function EditMacro(index, name, icon, ...)
	local oldName = GetMacroInfo(index)
	local newName = name or oldName
	local db = DB()
	local key, real = Resolve(icon)
	if icon ~= nil then
		if oldName and oldName ~= newName then db[oldName] = nil end
		db[newName] = key
	elseif oldName and oldName ~= newName and db[oldName] then
		db[newName], db[oldName] = db[oldName], nil
	end
	local id = origEdit(index, name, real, ...)
	RefreshButtons()
	return id
end

-- Anzeige auf den ElvUI-Aktionsleisten
local function ButtonUpdate(_, button)
	local action = button._state_action
	if button._state_type ~= "action" or not action then return end
	local kind, id = GetActionInfo(action)
	if kind ~= "macro" or not id then return end
	local texture = MI:GetCustomTexture((GetMacroInfo(id)))
	if texture and button.icon then
		button.icon:SetTexture(texture)
	end
end
LAB.RegisterCallback(MI, "OnButtonUpdate", ButtonUpdate)

-- Anzeige im Makro-Fenster
local function SetMacroFrameIcons()
	if not MacroFrame or not MacroFrame:IsShown() then return end
	local base = MacroFrame.macroBase or 0
	for i = 1, (MAX_ACCOUNT_MACROS or 36) do
		local icon = _G["MacroButton"..i.."Icon"]
		if icon then
			local texture = MI:GetCustomTexture((GetMacroInfo(base + i)))
			if texture then icon:SetTexture(texture) end
		end
	end
	local selected = MacroFrame.selectedMacro
	if selected and MacroFrameSelectedMacroButtonIcon then
		local texture = MI:GetCustomTexture((GetMacroInfo(selected)))
		if texture then MacroFrameSelectedMacroButtonIcon:SetTexture(texture) end
	end
end

-- Groesserer Icon-Picker im Makro-Fenster ------------------------------------
local PICKER_COLS, PICKER_ROWS = 7, 8     -- Standard: 5 x 4
local PICKER_BUTTON, PICKER_PITCH = 36, 40

local function EnlargeIconPicker()
	local popup = MacroPopupFrame
	if not popup or popup.iconPickerEnlarged then return end
	popup.iconPickerEnlarged = true

	local total = PICKER_COLS * PICKER_ROWS
	local skinned = MacroPopupButton1 and MacroPopupButton1.template ~= nil

	-- Blizzard-Variablen, die MacroPopupFrame_Update/Scrollen auswerten
	NUM_MACRO_ICONS_SHOWN = total
	NUM_ICONS_PER_ROW = PICKER_COLS
	NUM_ICON_ROWS = PICKER_ROWS
	MACRO_ICON_ROW_HEIGHT = PICKER_PITCH

	for i = 1, total do
		local button = _G["MacroPopupButton"..i]
		if not button then
			button = CreateFrame("CheckButton", "MacroPopupButton"..i, popup, "MacroPopupButtonTemplate")
			button:SetID(i)
			if skinned then
				local icon = _G[button:GetName().."Icon"]
				button:StripTextures()
				button:SetTemplate("Default")
				button:StyleButton(nil, true)
				if icon then
					icon:SetInside()
					icon:SetTexCoord(unpack(E.TexCoords))
				end
			end
		end

		local col, row = (i - 1) % PICKER_COLS, floor((i - 1) / PICKER_COLS)
		button:ClearAllPoints()
		button:Point("TOPLEFT", popup, "TOPLEFT", 31 + col * PICKER_PITCH, -82 - row * PICKER_PITCH)
		button:Size(PICKER_BUTTON, PICKER_BUTTON)
	end

	local gridW, gridH = PICKER_COLS * PICKER_PITCH, PICKER_ROWS * PICKER_PITCH
	popup:Size(31 + gridW + 62, 82 + gridH + 60)

	if MacroPopupScrollFrame then
		MacroPopupScrollFrame:ClearAllPoints()
		MacroPopupScrollFrame:Point("TOPLEFT", popup, "TOPLEFT", 28, -78)
		MacroPopupScrollFrame:Size(gridW + 6, gridH + 4)
	end

	if MacroPopupFrame_Update then MacroPopupFrame_Update() end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:SetScript("OnEvent", function(self, _, addon)
	if addon == "Blizzard_MacroUI" then
		hooksecurefunc("MacroFrame_Update", SetMacroFrameIcons)
		if MacroPopupFrame then
			MacroPopupFrame:HookScript("OnShow", EnlargeIconPicker)
			if MacroPopupFrame:IsShown() then EnlargeIconPicker() end
		end
		if MacroFrame_SelectMacro then hooksecurefunc("MacroFrame_SelectMacro", SetMacroFrameIcons) end
		self:UnregisterEvent("ADDON_LOADED")
	end
end)
if IsAddOnLoaded("Blizzard_MacroUI") then
	frame:GetScript("OnEvent")(frame, "ADDON_LOADED", "Blizzard_MacroUI")
end
