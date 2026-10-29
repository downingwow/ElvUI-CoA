local addonName = ...
local E = unpack(ElvUI)
local S = E:GetModule("Skins")

local _G = _G
local CreateFrame = CreateFrame
local GetNumWhoResults = GetNumWhoResults
local GetWhoInfo = GetWhoInfo
local SendWho = SendWho
local SetWhoToUI = SetWhoToUI
local HideUIPanel = HideUIPanel
local FauxScrollFrame_GetOffset = FauxScrollFrame_GetOffset
local FauxScrollFrame_OnVerticalScroll = FauxScrollFrame_OnVerticalScroll
local FauxScrollFrame_Update = FauxScrollFrame_Update
local format = string.format
local lower = string.lower
local find = string.find
local tonumber = tonumber
local tostring = tostring
local sort = table.sort
local tinsert = table.insert
local unpack = unpack
local type = type

local ROWS = 14
local ROW_HEIGHT = 20
local PANEL_WIDTH = 780
local PANEL_HEIGHT = 480
local HEADER_DRAG_HEIGHT = 36
local DEFAULT_MAX_LEVEL = _G.MAX_PLAYER_LEVEL or 80

local addon = CreateFrame("Frame")

local function WhoEnabled()
    local db = E.db and E.db.coaCXtra and E.db.coaCXtra.who
    if db and db.enable == false then return false end
    return true
end
local panel, toggleButton, scrollFrame, statusText
local initialized = false
local awaitingResults = false
local selectedName = nil
local results = {}
local rows = {}
local filters = {}
local sortKey = "level"
local sortAscending = false


local mediaFonts = {}
local mediaHighlights = {}
local mediaHooked = false

local COMBO_ROWS = 12
local COMBO_ROW_HEIGHT = 20

local CLASS_CHOICES = {
    { label = "All Classes", value = "" },
    { label = "Necromancer", value = "Necromancer", colorKey = "NECROMANCER" },
    { label = "Pyromancer", value = "Pyromancer", colorKey = "PYROMANCER" },
    { label = "Cultist", value = "Cultist", colorKey = "CULTIST" },
    { label = "Starcaller", value = "Starcaller", colorKey = "STARCALLER" },
    { label = "Sun Cleric", value = "Sun Cleric", colorKey = "SUNCLERIC" },
    { label = "Tinker", value = "Tinker", colorKey = "TINKER" },
    { label = "Runemaster", value = "Runemaster", colorKey = "SPIRITMAGE" },
    { label = "Primalist", value = "Primalist", colorKey = "WILDWALKER" },
    { label = "Reaper", value = "Reaper", colorKey = "REAPER" },
    { label = "Venomancer", value = "Venomancer", colorKey = "PROPHET" },
    { label = "Chronomancer", value = "Chronomancer", colorKey = "CHRONOMANCER" },
    { label = "Bloodmage", value = "Bloodmage", colorKey = "SONOFARUGAL" },
    { label = "Guardian", value = "Guardian", colorKey = "GUARDIAN" },
    { label = "Stormbringer", value = "Stormbringer", colorKey = "STORMBRINGER" },
    { label = "Felsworn", value = "Felsworn", colorKey = "DEMONHUNTER" },
    { label = "Barbarian", value = "Barbarian", colorKey = "BARBARIAN" },
    { label = "Witch Doctor", value = "Witch Doctor", colorKey = "WITCHDOCTOR" },
    { label = "Witch Hunter", value = "Witch Hunter", colorKey = "WITCHHUNTER" },
    { label = "Knight of Xoroth", value = "Knight of Xoroth", colorKey = "FLESHWARDEN" },
    { label = "Templar", value = "Templar", colorKey = "MONK" },
    { label = "Ranger", value = "Ranger", colorKey = "RANGER" },
}

local RACE_FACTION = {
    ["human"] = "Alliance", ["dwarf"] = "Alliance", ["gnome"] = "Alliance",
    ["night elf"] = "Alliance", ["draenei"] = "Alliance", ["worgen"] = "Alliance",
    ["void elf"] = "Alliance", ["lightforged draenei"] = "Alliance", ["dark iron dwarf"] = "Alliance",
    ["kul tiran"] = "Alliance", ["mechagnome"] = "Alliance",
    ["orc"] = "Horde", ["undead"] = "Horde", ["scourge"] = "Horde", ["tauren"] = "Horde",
    ["troll"] = "Horde", ["blood elf"] = "Horde", ["goblin"] = "Horde", ["nightborne"] = "Horde",
    ["highmountain tauren"] = "Horde", ["mag'har orc"] = "Horde", ["zandalari troll"] = "Horde",
    ["vulpera"] = "Horde",
}

local FACTION_ICON = {
    Alliance = "Interface\\TargetingFrame\\UI-PVP-Alliance",
    Horde = "Interface\\TargetingFrame\\UI-PVP-Horde",
}

local FACTION_CHOICES = {
    { label = "All Factions", value = "" },
    { label = "Alliance", value = "Alliance" },
    { label = "Horde", value = "Horde" },
}

local function GetFactionForRace(race)
    return RACE_FACTION[lower(tostring(race or ""))]
end

local zoneChoices
local knownZones = {}
local openComboPopup

local function Trim(text)
    text = tostring(text or "")
    text = text:gsub("^%s+", "")
    text = text:gsub("%s+$", "")
    return text
end

local function CleanQueryText(text)
    text = Trim(text)
    text = text:gsub('"', "")
    return text
end

local function Contains(haystack, needle)
    needle = lower(Trim(needle))
    if needle == "" then return true end
    haystack = lower(tostring(haystack or ""))
    return find(haystack, needle, 1, true) ~= nil
end

local function AddKnownZone(zone)
    zone = Trim(zone)
    if zone == "" then return end

    local key = lower(zone)
    if not knownZones[key] then
        knownZones[key] = zone
    end

    if zoneChoices then
        local alreadyListed = false
        for i = 1, #zoneChoices do
            if lower(zoneChoices[i].value or "") == key then
                alreadyListed = true
                break
            end
        end

        if not alreadyListed then
            tinsert(zoneChoices, { label = zone, value = zone })
            sort(zoneChoices, function(a, b)
                if a.value == "" then return true end
                if b.value == "" then return false end
                return lower(a.label) < lower(b.label)
            end)
        end
    end
end

local function BuildZoneChoices()
    if zoneChoices then return zoneChoices end

    zoneChoices = { { label = "All Zones", value = "" } }

    if _G.GetMapContinents and _G.GetMapZones then
        local continents = { _G.GetMapContinents() }
        for continentIndex = 1, #continents do
            local zones = { _G.GetMapZones(continentIndex) }
            for i = 1, #zones do
                AddKnownZone(zones[i])
            end
        end
    end

    -- Keep custom/CoA zones that were learned from earlier Who results too.
    for _, zone in pairs(knownZones) do
        AddKnownZone(zone)
    end

    return zoneChoices
end

local function GetZoneChoices()
    return BuildZoneChoices()
end

local function GetClassChoices()
    return CLASS_CHOICES
end

-- Colours the text of the Class filter in the selected class colour; empty ("All Classes") stays white.
local function UpdateClassFilterColor()
    local edit = filters.class
    if not edit then return end

    local text = lower(Trim(edit:GetText()))
    if text ~= "" then
        for i = 1, #CLASS_CHOICES do
            local choice = CLASS_CHOICES[i]
            if choice.colorKey and lower(choice.value) == text then
                local color = E:ClassColor(choice.colorKey)
                if color then
                    edit:SetTextColor(color.r, color.g, color.b)
                    return
                end
            end
        end
    end

    edit:SetTextColor(1, 1, 1)
end

local function GetFactionChoices()
    return FACTION_CHOICES
end

local function EnsureDB()
    -- Migrate settings from the old ElvUI_Who addon name once.
    if type(ElvUICoAWhoDB) ~= "table" then
        if type(_G.ElvUIWhoDB) == "table" then
            ElvUICoAWhoDB = _G.ElvUIWhoDB
            _G.ElvUIWhoDB = nil
        else
            ElvUICoAWhoDB = {}
        end
    end
    if ElvUICoAWhoDB.name == nil then ElvUICoAWhoDB.name = "" end
    if ElvUICoAWhoDB.zone == nil then ElvUICoAWhoDB.zone = "" end
    if ElvUICoAWhoDB.guild == nil then ElvUICoAWhoDB.guild = "" end
    if ElvUICoAWhoDB.class == nil then ElvUICoAWhoDB.class = "" end
    if ElvUICoAWhoDB.faction == nil then ElvUICoAWhoDB.faction = "" end
    if ElvUICoAWhoDB.minLevel == nil then ElvUICoAWhoDB.minLevel = "" end
    if ElvUICoAWhoDB.maxLevel == nil then ElvUICoAWhoDB.maxLevel = "" end
    if ElvUICoAWhoDB.posX == nil then ElvUICoAWhoDB.posX = 0 end
    if ElvUICoAWhoDB.posY == nil then ElvUICoAWhoDB.posY = 0 end
end

local function SaveFilters()
    EnsureDB()
    ElvUICoAWhoDB.name = filters.name and filters.name:GetText() or ""
    ElvUICoAWhoDB.zone = filters.zone and filters.zone:GetText() or ""
    ElvUICoAWhoDB.guild = filters.guild and filters.guild:GetText() or ""
    ElvUICoAWhoDB.class = filters.class and filters.class:GetText() or ""
    ElvUICoAWhoDB.faction = filters.faction and filters.faction:GetText() or ""
    ElvUICoAWhoDB.minLevel = filters.minLevel and filters.minLevel:GetText() or ""
    ElvUICoAWhoDB.maxLevel = filters.maxLevel and filters.maxLevel:GetText() or ""
end

local function GetFilterValues()
    local minLevel = filters.minLevel and tonumber(filters.minLevel:GetText()) or nil
    local maxLevel = filters.maxLevel and tonumber(filters.maxLevel:GetText()) or nil

    if minLevel and minLevel < 1 then minLevel = 1 end
    if maxLevel and maxLevel < 1 then maxLevel = 1 end
    if minLevel and maxLevel and minLevel > maxLevel then
        minLevel, maxLevel = maxLevel, minLevel
        filters.minLevel:SetText(minLevel)
        filters.maxLevel:SetText(maxLevel)
    end

    return {
        name = filters.name and Trim(filters.name:GetText()) or "",
        zone = filters.zone and Trim(filters.zone:GetText()) or "",
        guild = filters.guild and Trim(filters.guild:GetText()) or "",
        class = filters.class and Trim(filters.class:GetText()) or "",
        faction = filters.faction and Trim(filters.faction:GetText()) or "",
        minLevel = minLevel,
        maxLevel = maxLevel,
    }
end

local function SetButtonEnabled(button, enabled)
    if not button then return end
    if enabled then
        button:Enable()
        if button.text then button.text:SetTextColor(1, 1, 1) end
    else
        button:Disable()
        if button.text then button.text:SetTextColor(0.45, 0.45, 0.45) end
    end
end

local function UpdateSelectionButtons()
    local enabled = selectedName ~= nil and selectedName ~= ""
    SetButtonEnabled(panel and panel.whisperButton, enabled)
    SetButtonEnabled(panel and panel.inviteButton, enabled)
    SetButtonEnabled(panel and panel.friendButton, enabled)
end

local function SortResults()
    sort(results, function(a, b)
        local av = a[sortKey]
        local bv = b[sortKey]

        if sortKey == "level" then
            av = tonumber(av) or 0
            bv = tonumber(bv) or 0
        else
            av = lower(tostring(av or ""))
            bv = lower(tostring(bv or ""))
        end

        if av == bv then
            local an = lower(tostring(a.name or ""))
            local bn = lower(tostring(b.name or ""))
            return an < bn
        end

        if sortAscending then
            return av < bv
        else
            return av > bv
        end
    end)
end

local function UpdateRows()
    if not scrollFrame then return end

    SortResults()
    FauxScrollFrame_Update(scrollFrame, #results, ROWS, ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(scrollFrame) or 0

    for i = 1, ROWS do
        local row = rows[i]
        local data = results[offset + i]
        if data then
            row.data = data
            row.level:SetText(data.level or "")
            row.name:SetText(data.name or "")
            row.class:SetText(data.class or "")
            row.zone:SetText(data.zone or "")

            -- class icon (CoA class icons live in Interface\\Icons\\classicon_<class>)
            local classFile = data.classFileName and lower(tostring(data.classFileName))
            if classFile and classFile ~= "" then
                row.classIcon:SetTexture("Interface\\Icons\\classicon_" .. classFile)
                row.classIcon:Show()
            else
                row.classIcon:Hide()
            end

            -- faction icon
            local factionIcon = data.faction and FACTION_ICON[data.faction]
            if factionIcon then
                row.factionIcon:SetTexture(factionIcon)
                row.factionIcon:Show()
            else
                row.factionIcon:Hide()
            end
            row.guild:SetText(data.guild or "")

            local color = data.classFileName and E:ClassColor(data.classFileName)
            if color then
                row.class:SetTextColor(color.r, color.g, color.b)
            else
                row.class:SetTextColor(0.85, 0.85, 0.85)
            end

            if selectedName and selectedName == data.name then
                row:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor))
            else
                row:SetBackdropBorderColor(unpack(E.media.bordercolor))
            end
            row:Show()
        else
            row.data = nil
            row:Hide()
        end
    end
end

local function SetSort(key)
    if sortKey == key then
        sortAscending = not sortAscending
    else
        sortKey = key
        sortAscending = (key ~= "level")
    end
    UpdateRows()
end

local function FilterCurrentResults(numResults, totalResults)
    local values = GetFilterValues()
    results = {}
    selectedName = nil

    for i = 1, numResults do
        local name, guild, level, race, class, zone, classFileName = GetWhoInfo(i)
        level = tonumber(level) or 0
        AddKnownZone(zone)

        if Contains(name, values.name)
            and Contains(zone, values.zone)
            and Contains(guild, values.guild)
            and Contains(class, values.class)
            and Contains(GetFactionForRace(race) or "", values.faction)
            and (not values.minLevel or level >= values.minLevel)
            and (not values.maxLevel or level <= values.maxLevel) then
            tinsert(results, {
                name = name or "",
                guild = guild or "",
                level = level,
                race = race or "",
                class = class or "",
                zone = zone or "",
                classFileName = classFileName,
                faction = GetFactionForRace(race),
            })
        end
    end

    local total = tonumber(totalResults) or numResults
    if total > numResults then
        statusText:SetText(format("%d shown / %d returned (%d total)", #results, numResults, total))
    else
        statusText:SetText(format("%d result%s", #results, #results == 1 and "" or "s"))
    end

    UpdateSelectionButtons()
    UpdateRows()
end

local function BuildQuery()
    local values = GetFilterValues()
    local query = {}

    local minLevel = values.minLevel
    local maxLevel = values.maxLevel
    if minLevel or maxLevel then
        minLevel = minLevel or 1
        maxLevel = maxLevel or DEFAULT_MAX_LEVEL
        tinsert(query, format("%d-%d", minLevel, maxLevel))
    end

    local name = CleanQueryText(values.name)
    local zone = CleanQueryText(values.zone)
    local guild = CleanQueryText(values.guild)
    local class = CleanQueryText(values.class)

    if name ~= "" then tinsert(query, 'n-"' .. name .. '"') end
    if zone ~= "" then tinsert(query, 'z-"' .. zone .. '"') end
    if guild ~= "" then tinsert(query, 'g-"' .. guild .. '"') end
    if class ~= "" then tinsert(query, 'c-"' .. class .. '"') end

    if #query == 0 then
        tinsert(query, format("1-%d", DEFAULT_MAX_LEVEL))
    end

    return table.concat(query, " ")
end

local function SearchWho()
    if not panel or not initialized then return end

    SaveFilters()
    selectedName = nil
    UpdateSelectionButtons()
    statusText:SetText("Searching...")
    awaitingResults = true

    SetWhoToUI(1)
    SendWho(BuildQuery())

    SetButtonEnabled(panel.searchButton, false)
    if E.Delay then
        E:Delay(1.2, function()
            if panel and panel.searchButton then SetButtonEnabled(panel.searchButton, true) end
        end)
    else
        SetButtonEnabled(panel.searchButton, true)
    end
end

local function ClearFilters()
    if not initialized then return end
    filters.name:SetText("")
    filters.zone:SetText("")
    filters.guild:SetText("")
    filters.class:SetText("")
    filters.faction:SetText("")
    filters.minLevel:SetText("")
    filters.maxLevel:SetText("")
    SaveFilters()
    SearchWho()
end

local function GetElvUIFontSize(referenceSize)
    local baseSize = 12
    if E.db and E.db.general and tonumber(E.db.general.fontSize) then
        baseSize = tonumber(E.db.general.fontSize)
    end

    -- The old layout was designed around ElvUI's default size 12. Preserve
    -- the hierarchy (title larger, hints smaller) while following the user's
    -- configured global font size.
    local size = baseSize + ((tonumber(referenceSize) or 12) - 12)
    if size < 8 then size = 8 end
    return size
end

local function ApplyMediaFont(object, referenceSize)
    if not object or not object.FontTemplate then return end

    local font = E.media and E.media.normFont or nil
    local outline = (E.db and E.db.general and E.db.general.fontStyle) or "OUTLINE"
    object:FontTemplate(font, GetElvUIFontSize(referenceSize), outline)
end

local function RegisterMediaFont(object, referenceSize)
    mediaFonts[#mediaFonts + 1] = { object = object, size = referenceSize or 11 }
    ApplyMediaFont(object, referenceSize or 11)
    return object
end

local function ApplyMediaHighlight(texture)
    if not texture then return end

    local mediaTexture = E.media and (E.media.normTex or E.media.blankTex)
    if mediaTexture then
        texture:SetTexture(mediaTexture)
    else
        texture:SetTexture(1, 1, 1, 1)
    end

    local color = E.media and E.media.rgbvaluecolor
    if color then
        texture:SetVertexColor(color[1] or 1, color[2] or 1, color[3] or 1)
    else
        texture:SetVertexColor(1, 1, 1)
    end
    texture:SetAlpha(0.16)
    texture:SetBlendMode("ADD")
end

local function RegisterMediaHighlight(texture)
    mediaHighlights[#mediaHighlights + 1] = texture
    ApplyMediaHighlight(texture)
    return texture
end

local function ApplyElvUIMedia()
    local i
    for i = 1, #mediaFonts do
        local entry = mediaFonts[i]
        ApplyMediaFont(entry.object, entry.size)
    end

    for i = 1, #mediaHighlights do
        ApplyMediaHighlight(mediaHighlights[i])
    end
end

local function HookElvUIMedia()
    if mediaHooked then return end
    mediaHooked = true

    if _G.hooksecurefunc and E and E.UpdateMedia then
        local ok = pcall(_G.hooksecurefunc, E, "UpdateMedia", function()
            ApplyElvUIMedia()
        end)
        if not ok then mediaHooked = false end
    end
end

local function MakeText(parent, text, size)
    local fs = parent:CreateFontString(nil, "OVERLAY")
    RegisterMediaFont(fs, size or 11)
    fs:SetText(text or "")
    return fs
end

local function MakeButton(parent, text, width, height)
    local button = CreateFrame("Button", nil, parent)
    button:SetSize(width, height or 22)
    button:SetTemplate("Default", true)

    local fs = MakeText(button, text, 11)
    fs:SetPoint("CENTER", 0, 0)
    fs:SetTextColor(1, 1, 1)
    button.text = fs

    button:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor))
    end)
    button:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(unpack(E.media.bordercolor))
    end)
    return button
end

local function MakeLabel(parent, text, x, y, width)
    local fs = MakeText(parent, text, 10)
    fs:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y)
    fs:SetWidth(width or 100)
    fs:SetJustifyH("LEFT")
    fs:SetTextColor(0.72, 0.72, 0.72)
    return fs
end

local function MakeEditBox(parent, key, x, y, width, label, maxLetters)
    MakeLabel(parent, label, x, y, width)

    local edit = CreateFrame("EditBox", nil, parent)
    edit:SetAutoFocus(false)
    edit:SetSize(width, 21)
    edit:SetPoint("TOPLEFT", parent, "TOPLEFT", x, y - 15)
    edit:SetMaxLetters(maxLetters or 64)
    edit:SetTextInsets(5, 5, 0, 0)
    RegisterMediaFont(edit, 11)
    edit:SetTemplate("Default", true)
    edit:SetTextColor(1, 1, 1)

    edit:SetScript("OnEnterPressed", function(self)
        self:ClearFocus()
        SearchWho()
    end)
    edit:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
    end)
    edit:SetScript("OnEditFocusGained", function(self)
        self:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor))
    end)
    edit:SetScript("OnEditFocusLost", function(self)
        self:SetBackdropBorderColor(unpack(E.media.bordercolor))
    end)

    filters[key] = edit
    return edit
end

local function UpdateComboPopup(popup)
    if not popup or not popup.provider then return end

    popup.items = popup.provider() or {}

    local visibleRows = #popup.items
    if visibleRows > COMBO_ROWS then visibleRows = COMBO_ROWS end
    if visibleRows < 1 then visibleRows = 1 end
    popup:SetHeight((visibleRows * COMBO_ROW_HEIGHT) + 8)

    FauxScrollFrame_Update(popup.scrollFrame, #popup.items, COMBO_ROWS, COMBO_ROW_HEIGHT)
    local offset = FauxScrollFrame_GetOffset(popup.scrollFrame) or 0

    for i = 1, COMBO_ROWS do
        local row = popup.rows[i]
        local item = popup.items[offset + i]
        if item then
            row.value = item.value or ""
            row.text:SetText(item.label or item.value or "")

            if item.colorKey then
                local color = E:ClassColor(item.colorKey)
                if color then
                    row.text:SetTextColor(color.r, color.g, color.b)
                else
                    row.text:SetTextColor(0.92, 0.92, 0.92)
                end
            else
                row.text:SetTextColor(0.92, 0.92, 0.92)
            end

            row:Show()
        else
            row.value = nil
            row.text:SetTextColor(0.92, 0.92, 0.92)
            row:Hide()
        end
    end
end

local function HideOpenComboPopup()
    if openComboPopup then
        openComboPopup:Hide()
        openComboPopup = nil
    end
end

local function CreateComboPopup(edit, key, totalWidth, provider)
    local popup = CreateFrame("Frame", "ElvUICoAWho" .. key .. "ComboPopup", UIParent)
    popup:SetFrameStrata("TOOLTIP")
    popup:SetFrameLevel(200)
    popup:SetSize(totalWidth, (COMBO_ROWS * COMBO_ROW_HEIGHT) + 8)
    popup:SetTemplate("Transparent", true)
    popup:Hide()
    popup.provider = provider
    popup.rows = {}

    popup.scrollFrame = CreateFrame("ScrollFrame", "ElvUICoAWho" .. key .. "ComboScrollFrame", popup, "FauxScrollFrameTemplate")
    popup.scrollFrame:SetPoint("TOPLEFT", popup, "TOPLEFT", 4, -4)
    popup.scrollFrame:SetPoint("BOTTOMRIGHT", popup, "BOTTOMRIGHT", -24, 4)
    popup.scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, COMBO_ROW_HEIGHT, function() UpdateComboPopup(popup) end)
    end)

    for i = 1, COMBO_ROWS do
        local row = CreateFrame("Button", nil, popup)
        row:SetHeight(COMBO_ROW_HEIGHT)
        row:SetPoint("TOPLEFT", popup, "TOPLEFT", 5, -5 - ((i - 1) * COMBO_ROW_HEIGHT))
        row:SetPoint("RIGHT", popup, "RIGHT", -25, 0)

        local highlight = row:CreateTexture(nil, "HIGHLIGHT")
        highlight:SetAllPoints(row)
        RegisterMediaHighlight(highlight)

        row.text = MakeText(row, "", 10)
        row.text:SetPoint("LEFT", row, "LEFT", 5, 0)
        row.text:SetPoint("RIGHT", row, "RIGHT", -4, 0)
        row.text:SetJustifyH("LEFT")
        row.text:SetTextColor(0.92, 0.92, 0.92)

        row:SetScript("OnClick", function(self)
            edit:SetText(self.value or "")
            edit:ClearFocus()
            HideOpenComboPopup()
            SaveFilters()
        end)

        popup.rows[i] = row
    end

    if _G["ElvUICoAWho" .. key .. "ComboScrollFrameScrollBar"] and S and S.HandleScrollBar then
        pcall(S.HandleScrollBar, S, _G["ElvUICoAWho" .. key .. "ComboScrollFrameScrollBar"])
    end

    popup:SetScript("OnShow", function(self)
        UpdateComboPopup(self)
    end)

    edit.comboPopup = popup
    return popup
end

local function MakeComboEditBox(parent, key, x, y, width, label, provider)
    local arrowWidth = 22
    local gap = 2
    local edit = MakeEditBox(parent, key, x, y, width - arrowWidth - gap, label)

    local arrow = MakeButton(parent, "v", arrowWidth, 21)
    arrow:SetPoint("LEFT", edit, "RIGHT", gap, 0)

    local popup = CreateComboPopup(edit, key, width, provider)
    arrow:SetScript("OnClick", function()
        if popup:IsShown() then
            HideOpenComboPopup()
            return
        end

        HideOpenComboPopup()
        popup:ClearAllPoints()
        popup:SetPoint("TOPLEFT", edit, "BOTTOMLEFT", 0, -2)
        openComboPopup = popup
        popup:Show()
    end)

    edit:SetScript("OnTextChanged", function(self, userInput)
        if userInput then SaveFilters() end
    end)

    edit.comboButton = arrow
    return edit
end

local function CreateHeader(parent, text, key, x, width)
    local button = MakeButton(parent, text, width, 20)
    button:SetPoint("TOPLEFT", parent, "TOPLEFT", x, -128)
    button:SetScript("OnClick", function() SetSort(key) end)
    return button
end

local function CreateRow(parent, index)
    local row = CreateFrame("Button", nil, parent)
    row:SetSize(730, ROW_HEIGHT)
    row:SetPoint("TOPLEFT", parent, "TOPLEFT", 14, -152 - ((index - 1) * ROW_HEIGHT))
    row:SetTemplate("Default", true)

    local highlight = row:CreateTexture(nil, "HIGHLIGHT")
    highlight:SetAllPoints(row)
    RegisterMediaHighlight(highlight)
    row.whoHighlight = highlight

    local function Font(x, width, justify)
        local fs = MakeText(row, "", 10)
        fs:SetPoint("LEFT", row, "LEFT", x, 0)
        fs:SetWidth(width)
        fs:SetJustifyH(justify or "LEFT")
        fs:SetTextColor(0.9, 0.9, 0.9)
        return fs
    end

    row.level = Font(4, 42, "CENTER")

    row.factionIcon = row:CreateTexture(nil, "OVERLAY")
    row.factionIcon:SetSize(16, 16)
    row.factionIcon:SetPoint("LEFT", row, "LEFT", 50, 0)
    row.factionIcon:SetTexCoord(0, 0.59375, 0, 0.59375)

    row.classIcon = row:CreateTexture(nil, "OVERLAY")
    row.classIcon:SetSize(14, 14)
    row.classIcon:SetPoint("LEFT", row, "LEFT", 244, 0)
    row.classIcon:SetTexCoord(0.08, 0.92, 0.08, 0.92)

    row.name = Font(70, 170)
    row.class = Font(263, 104)
    row.zone = Font(372, 158)
    row.guild = Font(542, 184)

    row:RegisterForClicks("LeftButtonUp", "RightButtonUp")
    row:SetScript("OnClick", function(self, button)
        if not self.data then return end
        selectedName = self.data.name
        UpdateSelectionButtons()
        UpdateRows()

        if button == "RightButton" and selectedName and selectedName ~= "" then
            ChatFrame_SendTell(selectedName)
        end
    end)
    row:SetScript("OnDoubleClick", function(self)
        if self.data and self.data.name and self.data.name ~= "" then
            ChatFrame_SendTell(self.data.name)
        end
    end)

    return row
end

local function CloseBlizzardWhoUI()
    if _G.WhoFrame and _G.WhoFrame:IsShown() then
        _G.WhoFrame:Hide()
    end

    if _G.FriendsFrame then
        if HideUIPanel then
            HideUIPanel(_G.FriendsFrame)
        end
        _G.FriendsFrame:Hide()
    end
end

local function PositionToggleButton()
    if not toggleButton or not _G.FriendsFrame then return end
    toggleButton:ClearAllPoints()

    if _G.FriendsFrameTab5 and _G.FriendsFrameTab5:IsShown() then
        toggleButton:SetPoint("LEFT", _G.FriendsFrameTab5, "RIGHT", -3, 0)
    else
        toggleButton:SetPoint("BOTTOMRIGHT", _G.FriendsFrame, "BOTTOMRIGHT", -32, 51)
    end
end

local function PositionPanel()
    if not panel then return end
    EnsureDB()
    panel:ClearAllPoints()
    panel:SetPoint("CENTER", UIParent, "CENTER", tonumber(ElvUICoAWhoDB.posX) or 0, tonumber(ElvUICoAWhoDB.posY) or 0)
end

local function SavePanelPosition()
    if not panel then return end
    EnsureDB()

    local panelX, panelY = panel:GetCenter()
    local uiX, uiY = UIParent:GetCenter()
    if panelX and panelY and uiX and uiY then
        ElvUICoAWhoDB.posX = panelX - uiX
        ElvUICoAWhoDB.posY = panelY - uiY
        panel:ClearAllPoints()
        panel:SetPoint("CENTER", UIParent, "CENTER", ElvUICoAWhoDB.posX, ElvUICoAWhoDB.posY)
    end
end

local function CreateUI()
    if initialized or not _G.FriendsFrame or not WhoEnabled() then return end

    EnsureDB()

    toggleButton = CreateFrame("Button", "ElvUICoAWhoToggleButton", _G.FriendsFrame)
    toggleButton:SetSize(58, 27)
    toggleButton:SetFrameLevel(_G.FriendsFrame:GetFrameLevel() + 20)
    toggleButton:SetTemplate("Default", true)
    toggleButton.text = MakeText(toggleButton, "Who+", 10)
    toggleButton.text:SetPoint("CENTER")
    toggleButton.text:SetTextColor(1, 1, 1)
    toggleButton:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor))
    end)
    toggleButton:SetScript("OnLeave", function(self)
        if panel and panel:IsShown() then
            self:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor))
        else
            self:SetBackdropBorderColor(unpack(E.media.bordercolor))
        end
    end)
    PositionToggleButton()

    panel = CreateFrame("Frame", "ElvUICoAWhoPanel", UIParent)
    panel:SetSize(PANEL_WIDTH, PANEL_HEIGHT)
    panel:SetFrameStrata("DIALOG")
    panel:SetFrameLevel(20)
    panel:SetClampedToScreen(true)
    panel:SetMovable(true)
    panel:SetTemplate("Transparent", true)
    panel:Hide()
    PositionPanel()
    if _G.UISpecialFrames then
        tinsert(_G.UISpecialFrames, "ElvUICoAWhoPanel")
    end

    local title = MakeText(panel, "CoAC Who", 14)
    title:SetPoint("TOPLEFT", 14, -12)
    title:SetTextColor(unpack(E.media.rgbvaluecolor))

    panel.dragArea = CreateFrame("Frame", nil, panel)
    panel.dragArea:SetPoint("TOPLEFT", panel, "TOPLEFT", 4, -4)
    panel.dragArea:SetPoint("TOPRIGHT", panel, "TOPRIGHT", -40, -4)
    panel.dragArea:SetHeight(HEADER_DRAG_HEIGHT)
    panel.dragArea:EnableMouse(true)
    panel.dragArea:RegisterForDrag("LeftButton")
    panel.dragArea:SetScript("OnDragStart", function()
        panel:StartMoving()
    end)
    panel.dragArea:SetScript("OnDragStop", function()
        panel:StopMovingOrSizing()
        SavePanelPosition()
    end)

    statusText = MakeText(panel, "Ready", 10)
    statusText:SetPoint("TOPRIGHT", -44, -15)
    statusText:SetTextColor(0.68, 0.68, 0.68)

    panel.closeButton = MakeButton(panel, "X", 22, 22)
    panel.closeButton:SetPoint("TOPRIGHT", -10, -8)
    panel.closeButton:SetScript("OnClick", function() panel:Hide() end)

    MakeEditBox(panel, "name", 14, -40, 190, "Name")
    MakeComboEditBox(panel, "zone", 212, -40, 170, "Zone", GetZoneChoices)
    MakeEditBox(panel, "guild", 390, -40, 190, "Guild")
    MakeComboEditBox(panel, "class", 588, -40, 178, "Class", GetClassChoices)
    filters.class:HookScript("OnTextChanged", UpdateClassFilterColor)
    MakeComboEditBox(panel, "faction", 588, -82, 178, "Faction", GetFactionChoices)
    MakeEditBox(panel, "minLevel", 14, -82, 70, "Level Min", 3)
    MakeEditBox(panel, "maxLevel", 92, -82, 70, "Level Max", 3)

    filters.name:SetText(ElvUICoAWhoDB.name or "")
    filters.zone:SetText(ElvUICoAWhoDB.zone or "")
    filters.guild:SetText(ElvUICoAWhoDB.guild or "")
    filters.class:SetText(ElvUICoAWhoDB.class or "")
    filters.faction:SetText(ElvUICoAWhoDB.faction or "")
    UpdateClassFilterColor()
    filters.minLevel:SetText(ElvUICoAWhoDB.minLevel or "")
    filters.maxLevel:SetText(ElvUICoAWhoDB.maxLevel or "")

    panel.searchButton = MakeButton(panel, "Search", 92, 22)
    panel.searchButton:SetPoint("TOPLEFT", panel, "TOPLEFT", 184, -97)
    panel.searchButton:SetScript("OnClick", SearchWho)

    panel.clearButton = MakeButton(panel, "Clear", 78, 22)
    panel.clearButton:SetPoint("LEFT", panel.searchButton, "RIGHT", 6, 0)
    panel.clearButton:SetScript("OnClick", ClearFilters)

    local help = MakeText(panel, "Enter also searches.", 9)
    help:SetPoint("LEFT", panel.clearButton, "RIGHT", 12, 0)
    help:SetTextColor(0.52, 0.52, 0.52)

    CreateHeader(panel, "Level", "level", 14, 46)
    CreateHeader(panel, "Name", "name", 62, 190)
    CreateHeader(panel, "Class", "class", 254, 124)
    CreateHeader(panel, "Zone", "zone", 380, 162)
    CreateHeader(panel, "Guild", "guild", 548, 190)

    for i = 1, ROWS do
        rows[i] = CreateRow(panel, i)
    end

    scrollFrame = CreateFrame("ScrollFrame", "ElvUICoAWhoScrollFrame", panel, "FauxScrollFrameTemplate")
    scrollFrame:SetPoint("TOPLEFT", panel, "TOPLEFT", 14, -152)
    scrollFrame:SetPoint("BOTTOMRIGHT", panel, "BOTTOMRIGHT", -34, 44)
    scrollFrame:SetScript("OnVerticalScroll", function(self, offset)
        FauxScrollFrame_OnVerticalScroll(self, offset, ROW_HEIGHT, UpdateRows)
    end)
    if _G.ElvUICoAWhoScrollFrameScrollBar and S and S.HandleScrollBar then
        pcall(S.HandleScrollBar, S, _G.ElvUICoAWhoScrollFrameScrollBar)
    end

    panel.whisperButton = MakeButton(panel, "Whisper", 100, 22)
    panel.whisperButton:SetPoint("BOTTOMLEFT", 14, 14)
    panel.whisperButton:SetScript("OnClick", function()
        if selectedName then ChatFrame_SendTell(selectedName) end
    end)

    panel.inviteButton = MakeButton(panel, "Invite", 100, 22)
    panel.inviteButton:SetPoint("LEFT", panel.whisperButton, "RIGHT", 6, 0)
    panel.inviteButton:SetScript("OnClick", function()
        if selectedName then InviteUnit(selectedName) end
    end)

    panel.friendButton = MakeButton(panel, "Add Friend", 100, 22)
    panel.friendButton:SetPoint("LEFT", panel.inviteButton, "RIGHT", 6, 0)
    panel.friendButton:SetScript("OnClick", function()
        if selectedName then AddFriend(selectedName) end
    end)

    local hint = MakeText(panel, "Right-click / double-click a player: whisper", 9)
    hint:SetPoint("BOTTOMRIGHT", -14, 18)
    hint:SetTextColor(0.52, 0.52, 0.52)

    initialized = true
    ApplyElvUIMedia()
    HookElvUIMedia()
    UpdateSelectionButtons()

    toggleButton:SetScript("OnClick", function()
        CloseBlizzardWhoUI()
        PositionPanel()
        panel:Show()
        if #results == 0 then SearchWho() end

        if E.Delay then
            E:Delay(0.05, CloseBlizzardWhoUI)
        else
            CloseBlizzardWhoUI()
        end
    end)

    panel:SetScript("OnShow", function()
        PositionPanel()
        ApplyElvUIMedia()
        if toggleButton then
            toggleButton:SetBackdropBorderColor(unpack(E.media.rgbvaluecolor))
        end
    end)
    panel:SetScript("OnHide", function()
        HideOpenComboPopup()
        if toggleButton then
            toggleButton:SetBackdropBorderColor(unpack(E.media.bordercolor))
        end
    end)

    _G.FriendsFrame:HookScript("OnShow", function()
        if not WhoEnabled() then return end
        PositionToggleButton()
        toggleButton:Show()
    end)

    if _G.FriendsFrame_Update then
        hooksecurefunc("FriendsFrame_Update", function()
            if not WhoEnabled() then return end
            PositionToggleButton()
            toggleButton:Show()
        end)
    end
end

local function OpenWhoPanel()
    if not WhoEnabled() then return end
    if not _G.FriendsFrame then return end
    if not initialized then CreateUI() end
    if not initialized or not panel then return end

    CloseBlizzardWhoUI()
    PositionPanel()
    panel:Show()
    SearchWho()

    if E.Delay then
        E:Delay(0.05, CloseBlizzardWhoUI)
    else
        CloseBlizzardWhoUI()
    end
end

_G.SLASH_ELVUICOAWHO1 = "/coawho"
_G.SLASH_ELVUICOAWHO2 = "/ewho"
_G.SLASH_ELVUICOAWHO3 = "/elvwho"
_G.SlashCmdList["ELVUICOAWHO"] = function()
    OpenWhoPanel()
end

E.CoACXtra = E.CoACXtra or {}
function E.CoACXtra.UpdateWho()
    if WhoEnabled() then
        if not initialized and _G.FriendsFrame then CreateUI() end
        if toggleButton and _G.FriendsFrame and _G.FriendsFrame:IsShown() then
            PositionToggleButton()
            toggleButton:Show()
        end
    else
        if panel then panel:Hide() end
        if toggleButton then toggleButton:Hide() end
    end
end

addon:RegisterEvent("PLAYER_LOGIN")
addon:RegisterEvent("ADDON_LOADED")
addon:RegisterEvent("WHO_LIST_UPDATE")
addon:SetScript("OnEvent", function(self, event, arg1)
    if event == "PLAYER_LOGIN" then
        if _G.FriendsFrame then CreateUI() end
    elseif event == "ADDON_LOADED" then
        if arg1 == "Blizzard_FriendsUI" or arg1 == addonName then
            if _G.FriendsFrame then CreateUI() end
        end
    elseif event == "WHO_LIST_UPDATE" then
        if not awaitingResults or not panel or not panel:IsShown() then return end
        awaitingResults = false
        local numResults, totalResults = GetNumWhoResults()
        numResults = tonumber(numResults) or 0
        totalResults = tonumber(totalResults) or numResults
        FilterCurrentResults(numResults, totalResults)
        SetButtonEnabled(panel.searchButton, true)
        CloseBlizzardWhoUI()
    end
end)
