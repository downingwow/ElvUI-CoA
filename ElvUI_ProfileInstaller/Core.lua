local ADDON_NAME = "ElvUI_ProfileInstaller"
local DISPLAY_NAME = "ProfileInstaller"
local PACK_PREFIX = "!EPI1!"

local E = unpack(ElvUI)
local EP = LibStub("LibElvUIPlugin-1.0")
local D = E:GetModule("Distributor")
local NP = E:GetModule("NamePlates", true)
local LibDeflate = E.Libs.Deflate

local _G = _G
local type, ipairs, pairs = type, ipairs, pairs
local strtrim = strtrim
local format = string.format
local tostring = tostring
local tonumber = tonumber
local floor = math.floor
local find = string.find
local sub = string.sub
local gsub = string.gsub

local Profiles = _G.ElvUI_ProfileInstaller_Profiles or {}
local selectedProfile
local exportText = ""
local lastExportMeta

-- AceGUI's standard MultiLineEditBox adds an Accept button. The exporter is
-- output-only, so hide that button while keeping the text selectable/copyable.
local function HideExporterAcceptButton()
    local AceGUI = E.Libs and E.Libs.AceGUI
    if not AceGUI or not AceGUI.GetWidgetCount then return end

    local count = AceGUI:GetWidgetCount("MultiLineEditBox") or 0
    for i = 1, count do
        local editBox = _G[format("MultiLineEditBox%dEdit", i)]
        local widget = editBox and editBox.obj
        if editBox and editBox:IsVisible() and widget and widget.GetText and widget.DisableButton then
            if widget:GetText() == exportText then
                widget:DisableButton(true)
            end
        end
    end
end

local function QueueHideExporterAcceptButton()
    if E.Delay then
        E:Delay(0.01, HideExporterAcceptButton)
        E:Delay(0.10, HideExporterAcceptButton)
    else
        HideExporterAcceptButton()
    end
end

local function FindProfile(name)
    if not name then return end
    for _, entry in ipairs(Profiles) do
        if entry.name == name then return entry end
    end
end

local function GetFirstProfileName()
    return Profiles[1] and Profiles[1].name
end

local function GetSelectedProfileName()
    if selectedProfile and FindProfile(selectedProfile) then return selectedProfile end
    selectedProfile = GetFirstProfileName()
    return selectedProfile
end

local function GetProfileValues()
    local values = {}
    for _, entry in ipairs(Profiles) do values[entry.name] = entry.name end
    return values
end

local function IsProfileNameUsed(name)
    return name and name ~= "" and ElvDB and ElvDB.profiles and ElvDB.profiles[name] ~= nil
end

local function MakeUniqueName(base)
    base = strtrim(base or "")
    if base == "" then base = "Imported Profile" end
    if not IsProfileNameUsed(base) then return base end
    local i = 2
    local candidate = base .. " " .. i
    while IsProfileNameUsed(candidate) do
        i = i + 1
        candidate = base .. " " .. i
    end
    return candidate
end

local function GetResolutionText()
    if E.resolution and E.resolution ~= "" then return tostring(E.resolution) end
    if GetScreenWidth and GetScreenHeight then
        return format("%dx%d", floor((GetScreenWidth() or 0) + 0.5), floor((GetScreenHeight() or 0) + 0.5))
    end
    return "Unknown"
end

local function GetUIScaleText()
    local scale = E.global and E.global.general and E.global.general.UIScale
    if not scale and UIParent and UIParent.GetEffectiveScale then scale = UIParent:GetEffectiveScale() end
    if not scale then return "Unknown" end
    return format("%.4f", tonumber(scale) or 0)
end

local function GetCurrentProfileName()
    local key = ElvDB and ElvDB.profileKeys and ElvDB.profileKeys[E.mynameRealm]
    return key or "ElvUI Profile"
end

local function GetProfileDateText()
    if date then
        return date("%d.%m.%Y %H:%M:%S")
    end
    return "Unknown"
end

local function BuildMeta()
    return {
        formatVersion = 1,
        profileName = GetCurrentProfileName(),
        elvuiVersion = E.version or (GetAddOnMetadata and GetAddOnMetadata("ElvUI", "Version")) or "Unknown",
        resolution = GetResolutionText(),
        uiScale = GetUIScaleText(),
        profileDate = GetProfileDateText(),
    }
end

local function ExportComponent(profileType)
    local _, code = D:ExportProfile(profileType, "text")
    return code
end

local function BuildFullPack()
    local meta = BuildMeta()
    local pack = {
        meta = meta,
        data = {
            profile = ExportComponent("profile"),
            private = ExportComponent("private"),
            global = ExportComponent("global"),
            auraFilters = ExportComponent("filters"),
            nameplateFilters = ExportComponent("styleFilters"),
        },
    }

    for key, value in pairs(pack.data) do
        if type(value) ~= "string" or value == "" then
            E:Print("ProfileInstaller: Could not export " .. tostring(key) .. ".")
            return
        end
    end

    local serialized = D:Serialize(pack)
    local compressed = LibDeflate:CompressDeflate(serialized, LibDeflate.compressLevel)
    local printable = compressed and LibDeflate:EncodeForPrint(compressed)
    if not printable then
        E:Print("ProfileInstaller: Failed to encode profile.")
        return
    end

    local header = {
        "# ElvUI ProfileInstaller Profile",
        "# Created with ElvUI " .. tostring(meta.elvuiVersion),
        "# Profile: " .. tostring(meta.profileName),
        "# Resolution: " .. tostring(meta.resolution),
        "# UI Scale: " .. tostring(meta.uiScale),
        "# Profile Date: " .. tostring(meta.profileDate),
        "# Includes: Profile, Private, Global, Aura Filters, Nameplate Filters",
        "# Generated automatically by ElvUI_ProfileInstaller",
        "",
    }

    lastExportMeta = meta
    return table.concat(header, "\n") .. PACK_PREFIX .. printable
end

local function DecodePack(text)
    if type(text) ~= "string" then return end
    local pos = find(text, PACK_PREFIX, 1, true)
    if not pos then return end

    local encoded = sub(text, pos + #PACK_PREFIX)
    encoded = gsub(encoded, "%s+$", "")
    local decoded = LibDeflate:DecodeForPrint(encoded)
    if not decoded then return end
    local decompressed = LibDeflate:DecompressDeflate(decoded)
    if not decompressed then return end

    local ok, pack = D:Deserialize(decompressed)
    if not ok or type(pack) ~= "table" or type(pack.data) ~= "table" then return end
    return pack
end

local function DecodeLegacyProfile(entry)
    if not entry or type(entry.code) ~= "string" or entry.code == "" then return end
    local profileType, _, profileData = D:Decode(entry.code)
    if profileType ~= "profile" or type(profileData) ~= "table" then return end
    return profileData
end

local function DecodeComponent(code, expectedType)
    if type(code) ~= "string" or code == "" then return end
    local profileType, profileKey, profileData = D:Decode(code)
    if profileType ~= expectedType or type(profileData) ~= "table" then return end
    return profileKey, profileData
end

local function FilterImportedData(profileType, data)
    if not data then return end
    if D.blacklistedKeys and D.blacklistedKeys[profileType] then
        return E:FilterTableFromBlacklist(data, D.blacklistedKeys[profileType])
    end
    return data
end

local function ReloadAfterInstall(targetName, legacy)
    if legacy then
        E:Print(format('ProfileInstaller: Legacy profile "%s" was installed and activated. Reloading UI...', targetName))
    else
        E:Print(format('ProfileInstaller: Profile "%s" was installed and activated. Reloading UI...', targetName))
    end

    -- Reload immediately after the new profile is active so Profile, Private,
    -- Global, Aura Filter and Nameplate Filter data are rebuilt from the newly
    -- installed SavedVariables state.
    if ReloadUI then ReloadUI() end
end

local function ApplyFullPack(pack, targetName, forceOverwrite)
    if not ElvDB or not ElvDB.profiles or not E.data then
        E:Print("ProfileInstaller: ElvUI database is not ready yet.")
        return
    end

    local data = pack.data or {}
    local _, profileData = DecodeComponent(data.profile, "profile")
    local _, privateData = DecodeComponent(data.private, "private")
    local _, globalData = DecodeComponent(data.global, "global")
    local _, filtersData = DecodeComponent(data.auraFilters, "filters")
    local _, styleData = DecodeComponent(data.nameplateFilters, "styleFilters")

    if not profileData then
        E:Print("ProfileInstaller: This profile does not contain a valid profile section.")
        return
    end

    profileData = FilterImportedData("profile", profileData)
    privateData = FilterImportedData("private", privateData)
    globalData = FilterImportedData("global", globalData)

    if forceOverwrite and E.data.keys and E.data.keys.profile == targetName then
        E.data.keys.profile = targetName .. "_ProfileInstallerTemp"
    end

    ElvDB.profiles[targetName] = profileData
    E.data:SetProfile(targetName)

    if privateData and E.private then E:CopyTable(E.private, privateData) end
    if globalData and E.global then E:CopyTable(E.global, globalData) end

    if filtersData and filtersData.unitframe and E.global and E.global.unitframe then
        if filtersData.unitframe.aurafilters then E.global.unitframe.aurafilters = E:CopyTable({}, filtersData.unitframe.aurafilters) end
        if filtersData.unitframe.aurawatch then E.global.unitframe.aurawatch = E:CopyTable({}, filtersData.unitframe.aurawatch) end
    end

    if styleData and E.global and E.global.nameplates then
        local source = styleData.nameplates or styleData.nameplate
        if source and source.filters then E.global.nameplates.filters = E:CopyTable({}, source.filters) end
    end

    ReloadAfterInstall(targetName, false)
end

local function ApplyLegacyProfile(entry, targetName, forceOverwrite)
    local profileData = DecodeLegacyProfile(entry)
    if not profileData then
        E:Print("ProfileInstaller: The selected text file is not a valid ProfileInstaller profile or ElvUI profile export.")
        return
    end

    profileData = FilterImportedData("profile", profileData)
    if forceOverwrite and E.data.keys and E.data.keys.profile == targetName then
        E.data.keys.profile = targetName .. "_ProfileInstallerTemp"
    end
    ElvDB.profiles[targetName] = profileData
    E.data:SetProfile(targetName)
    ReloadAfterInstall(targetName, true)
end

local function InstallEntry(entry, targetName, forceOverwrite)
    targetName = strtrim(targetName or "")
    if targetName == "" then
        E:Print("ProfileInstaller: Profile name cannot be empty.")
        return
    end

    if IsProfileNameUsed(targetName) and not forceOverwrite then
        E:StaticPopup_Show("ELVUI_PROFILEINSTALLER_EXISTS", nil, nil, { entry = entry, targetName = targetName })
        return
    end

    local pack = DecodePack(entry.code)
    if pack then
        ApplyFullPack(pack, targetName, forceOverwrite)
    else
        ApplyLegacyProfile(entry, targetName, forceOverwrite)
    end
end

E.PopupDialogs.ELVUI_PROFILEINSTALLER_EXISTS = {
    text = "A profile with this name already exists. What do you want to do?",
    button1 = "Overwrite",
    button2 = "Import with New Name",
    button3 = CANCEL,
    OnAccept = function(_, data)
        if data and data.entry then InstallEntry(data.entry, data.targetName, true) end
    end,
    OnCancel = function(_, data, reason)
        if reason == "clicked" and data and data.entry then
            E:StaticPopup_Show("ELVUI_PROFILEINSTALLER_NEWNAME", nil, nil, data)
        end
    end,
    OnAlt = function() end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = true,
    preferredIndex = 3,
}

E.PopupDialogs.ELVUI_PROFILEINSTALLER_NEWNAME = {
    text = "Enter a new name for the imported ElvUI profile:",
    button1 = ACCEPT,
    button2 = CANCEL,
    hasEditBox = 1,
    editBoxWidth = 350,
    maxLetters = 127,
    OnAccept = function(self, data)
        if not data or not data.entry then return end
        local newName = strtrim(self.editBox:GetText() or "")
        if newName == "" or IsProfileNameUsed(newName) then return end
        InstallEntry(data.entry, newName, false)
    end,
    EditBoxOnTextChanged = function(self)
        local text = strtrim(self:GetText() or "")
        local parent = self:GetParent()
        if text ~= "" and not IsProfileNameUsed(text) then parent.button1:Enable() else parent.button1:Disable() end
    end,
    OnShow = function(self, data)
        local baseName = data and data.targetName or "Imported Profile"
        self.editBox:SetText(MakeUniqueName(baseName))
        self.editBox:HighlightText()
        self.editBox:SetFocus()
    end,
    timeout = 0,
    whileDead = 1,
    hideOnEscape = true,
    preferredIndex = 3,
}

local function InstallSelected()
    local entry = FindProfile(GetSelectedProfileName())
    if not entry then
        E:Print("ProfileInstaller: No generated profiles are available. Add .txt files and run GenerateProfiles.bat first.")
        return
    end
    if IsProfileNameUsed(entry.name) then
        E:StaticPopup_Show("ELVUI_PROFILEINSTALLER_EXISTS", nil, nil, { entry = entry, targetName = entry.name })
    else
        InstallEntry(entry, entry.name, false)
    end
end

-- Farben fuer die Optionen
local BLUE, GREEN, YELLOW, RED, GREY, WHITE = "|cff1784d1", "|cff66ff99", "|cffffcc00", "|cffff5555", "|cff9d9d9d", "|cffffffff"
local function Label(text, value, color)
    return format("%s%s|r  %s%s|r", BLUE, text, color or WHITE, tostring(value))
end

local function GetEntryStatus()
    local entry = FindProfile(GetSelectedProfileName())
    if not entry then return "" end
    if IsProfileNameUsed(entry.name) then
        return format("%sA profile named \"%s\" already exists.|r %sYou will be asked to overwrite it or import it under a new name.|r", YELLOW, entry.name, GREY)
    end
    return format("%sReady to install.|r %sThe profile is activated and the UI reloads automatically.|r", GREEN, GREY)
end

local function GetEntryInfo()
    local entry = FindProfile(GetSelectedProfileName())
    if not entry then
        return format("%sNo generated profiles found.|r\n\n%sAdd .txt files to the profiles folder and run GenerateProfiles.bat.|r", RED, GREY)
    end

    local pack = DecodePack(entry.code)
    local file = entry.file or (entry.name .. ".txt")
    if not pack then
        return table.concat({
            Label("Source file", file, "|cff66ccff"),
            Label("Install name", entry.name),
            Label("Type", "Legacy ElvUI profile export", YELLOW),
            Label("Includes", "Profile only", WHITE),
        }, "\n\n")
    end

    local m = pack.meta or {}
    return table.concat({
        Label("Source file", file, "|cff66ccff"),
        Label("Install name", entry.name),
        Label("Created with", "ElvUI " .. tostring(m.elvuiVersion or "Unknown")),
        Label("Original profile", m.profileName or "Unknown"),
        Label("Profile date", m.profileDate or "Unknown", YELLOW),
        Label("Resolution", m.resolution or "Unknown"),
        Label("UI scale", m.uiScale or "Unknown"),
        Label("Includes", "Profile, Private, Global, Aura Filters, Nameplate Filters", GREEN),
    }, "\n\n")
end

local function Step(num, text)
    return format("%s%s.|r  %s", BLUE, num, text)
end

local function SetupOptions()
    if not E.Options or not E.Options.args then return end

    local pluginRoot = E.Options.args.plugins
    if not pluginRoot or type(pluginRoot.args) ~= "table" then
        pluginRoot = { order = -10, type = "group", name = "Plugins", args = {} }
        E.Options.args.plugins = pluginRoot
    end

    -- Ensure the plugin is only listed under Plugins and never as a root entry.
    E.Options.args.profileInstaller = nil
    E.Options.args.ElvUI_ProfileInstaller = nil

    pluginRoot.args.profileInstaller = {
        type = "group",
        name = DISPLAY_NAME,
        order = 60,
        childGroups = "tab",
        args = {
            installer = {
                type = "group",
                name = "Installer",
                order = 1,
                args = {
                    header = { type = "header", name = "Install a Profile", order = 1 },
                    description = {
                        type = "description",
                        fontSize = "medium",
                        order = 2,
                        name = function()
                            return format("Install complete ElvUI profiles from .txt files. %s%d profile(s) available.|r", GREEN, #Profiles)
                        end,
                    },
                    spacer1 = { type = "description", name = " ", order = 3 },
                    selectGroup = {
                        type = "group",
                        name = "1. Choose profile",
                        order = 10,
                        guiInline = true,
                        args = {
                            profile = {
                                type = "select",
                                name = "Profile",
                                desc = "Select a generated ProfileInstaller profile.",
                                order = 1,
                                width = "double",
                                values = GetProfileValues,
                                get = function() return GetSelectedProfileName() end,
                                set = function(_, value) selectedProfile = value end,
                                disabled = function() return #Profiles == 0 end,
                            },
                        },
                    },
                    detailsGroup = {
                        type = "group",
                        name = "2. Profile details",
                        order = 20,
                        guiInline = true,
                        args = {
                            source = { type = "description", fontSize = "medium", name = GetEntryInfo, order = 1 },
                        },
                    },
                    installGroup = {
                        type = "group",
                        name = "3. Install",
                        order = 30,
                        guiInline = true,
                        args = {
                            status = { type = "description", fontSize = "medium", name = GetEntryStatus, order = 1 },
                            spacer = { type = "description", name = " ", order = 2 },
                            install = {
                                type = "execute",
                                name = "Install Profile",
                                desc = "Install and activate the selected profile, then automatically reload the UI.",
                                order = 3,
                                width = "double",
                                func = InstallSelected,
                                disabled = function() return #Profiles == 0 end,
                            },
                        },
                    },
                },
            },
            exporter = {
                type = "group",
                name = "Exporter",
                order = 2,
                args = {
                    header = { type = "header", name = "Full Profile Exporter", order = 1 },
                    description = {
                        type = "description",
                        fontSize = "medium",
                        order = 2,
                        name = "Packs your current setup into one text: Profile, Private, Global, Aura Filters and Nameplate Filters. ElvUI version, resolution and UI scale are added automatically.",
                    },
                    spacer1 = { type = "description", name = " ", order = 3 },
                    generateGroup = {
                        type = "group",
                        name = "1. Generate",
                        order = 10,
                        guiInline = true,
                        args = {
                            generate = {
                                type = "execute",
                                name = "Generate Full Profile",
                                order = 1,
                                width = "double",
                                func = function()
                                    exportText = BuildFullPack() or ""
                                    QueueHideExporterAcceptButton()
                                    if exportText ~= "" then E:Print("ProfileInstaller: Full profile generated. Copy the text below into a .txt file in the profiles folder.") end
                                end,
                            },
                            metadata = {
                                type = "description",
                                fontSize = "medium",
                                order = 2,
                                name = function()
                                    local m = lastExportMeta
                                    if not m then return GREY .. "Nothing generated yet. Press the button above.|r" end
                                    return table.concat({
                                        Label("Profile", m.profileName or "Unknown"),
                                        Label("Date", m.profileDate or "Unknown", YELLOW),
                                        Label("ElvUI", m.elvuiVersion or "Unknown"),
                                        Label("Resolution", m.resolution or "Unknown"),
                                        Label("UI scale", m.uiScale or "Unknown"),
                                    }, "\n\n")
                                end,
                            },
                        },
                    },
                    copyGroup = {
                        type = "group",
                        name = "2. Copy the text",
                        order = 20,
                        guiInline = true,
                        args = {
                            hint = {
                                type = "description",
                                order = 1,
                                name = GREY .. "Select all (Ctrl+A), copy (Ctrl+C) and paste it into a new .txt file in ElvUI_ProfileInstaller\\profiles.|r",
                            },
                            export = {
                                type = "input",
                                name = "Export Text",
                                desc = "Copy this entire text into a .txt file in ElvUI_ProfileInstaller\\profiles.",
                                order = 2,
                                multiline = 16,
                                width = "full",
                                get = function()
                                    QueueHideExporterAcceptButton()
                                    return exportText
                                end,
                                set = function(_, value) exportText = value or "" end,
                            },
                        },
                    },
                },
            },
            help = {
                type = "group",
                name = "How To Use",
                order = 3,
                args = {
                    header = { type = "header", name = "How To Use", order = 1 },
                    createGroup = {
                        type = "group",
                        name = "Create a profile",
                        order = 10,
                        guiInline = true,
                        args = {
                            s1 = { type = "description", fontSize = "medium", order = 1, name = Step(1, "Open ElvUI -> Plugins -> ProfileInstaller -> " .. YELLOW .. "Exporter|r.") },
                            s2 = { type = "description", fontSize = "medium", order = 2, name = Step(2, "Click " .. YELLOW .. "Generate Full Profile|r. It includes Profile, Private, Global, Aura Filters and Nameplate Filters plus date, ElvUI version, resolution and UI scale.") },
                            s3 = { type = "description", fontSize = "medium", order = 3, name = Step(3, "Copy the complete text from the Export Text box.") },
                            s4 = { type = "description", fontSize = "medium", order = 4, name = Step(4, "Open " .. WHITE .. "Interface\\AddOns\\ElvUI_ProfileInstaller\\profiles\\|r and create a .txt file with the pasted text. The file name becomes the profile name (MyProfile.txt -> 'MyProfile').") },
                            s5 = { type = "description", fontSize = "medium", order = 5, name = Step(5, "Run " .. YELLOW .. "GenerateProfiles.bat|r in the ElvUI_ProfileInstaller folder. It rebuilds Profiles.lua from all .txt files.") },
                            s6 = { type = "description", fontSize = "medium", order = 6, name = Step(6, "Start WoW or use " .. YELLOW .. "/reload|r if the game is already running.") },
                        },
                    },
                    installGroup = {
                        type = "group",
                        name = "Install a profile",
                        order = 20,
                        guiInline = true,
                        args = {
                            s1 = { type = "description", fontSize = "medium", order = 1, name = Step(1, "Open ElvUI -> Plugins -> ProfileInstaller -> " .. YELLOW .. "Installer|r.") },
                            s2 = { type = "description", fontSize = "medium", order = 2, name = Step(2, "Select a profile. The details show date, ElvUI version, original name, resolution, UI scale and what is included.") },
                            s3 = { type = "description", fontSize = "medium", order = 3, name = Step(3, "Click " .. YELLOW .. "Install Profile|r. If the name already exists, choose Overwrite or Import with New Name.") },
                            s4 = { type = "description", fontSize = "medium", order = 4, name = Step(4, "The profile is activated and the UI reloads automatically. No manual /reload needed.") },
                        },
                    },
                    note = {
                        type = "description",
                        order = 30,
                        name = "\n" .. GREY .. "You can add, replace or delete .txt files at any time. Run GenerateProfiles.bat again after every change.|r",
                    },
                },
            },
        },
    }

    if E.Libs and E.Libs.AceConfigRegistry then E.Libs.AceConfigRegistry:NotifyChange("ElvUI") end
end

EP:RegisterPlugin(ADDON_NAME, SetupOptions)
