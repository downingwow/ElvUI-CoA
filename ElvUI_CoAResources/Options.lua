local E, L, V, P, G = unpack(ElvUI)
local CCB = E:GetModule("CoAResources")


local CLASS_DISPLAY_NAMES = {
    DEMONHUNTER = "Felsworn",
    SONOFARUGAL = "Bloodmage",
    SUNCLERIC = "Sun Cleric",
    FLESHWARDEN = "Knight of Xoroth",
    STORMBRINGER = "Stormbringer",
    CHRONOMANCER = "Chronomancer",
    BARBARIAN = "Barbarian",
    SPIRITMAGE = "Runemaster",
    STARCALLER = "Starcaller",
    WILDWALKER = "Primalist",
    PYROMANCER = "Pyromancer",
    NECROMANCER = "Necromancer",
    CULTIST = "Cultist",
    RANGER = "Ranger",
    TINKER = "Tinker",
    REAPER = "Reaper",
    PROPHET = "Venomancer",
    MONK = "Templar",
}

local function ClassColoredName(class)
    local display = CLASS_DISPLAY_NAMES[class] or class or "Unknown"
    local c = (_G.CUSTOM_CLASS_COLORS and _G.CUSTOM_CLASS_COLORS[class]) or (_G.RAID_CLASS_COLORS and _G.RAID_CLASS_COLORS[class])
    if not c then return display end
    local r = math.floor((c.r or 1) * 255 + 0.5)
    local g = math.floor((c.g or 1) * 255 + 0.5)
    local b = math.floor((c.b or 1) * 255 + 0.5)
    return string.format("|cff%02x%02x%02x%s|r", r, g, b, display)
end

local function Update()
    CCB:ProfileChanged()
end

local function CopyColorValue(c, fallback)
    local f = fallback or {r=1,g=1,b=1,a=1}
    c = c or f
    return {
        r = c.r ~= nil and c.r or f.r or 1,
        g = c.g ~= nil and c.g or f.g or 1,
        b = c.b ~= nil and c.b or f.b or 1,
        a = c.a ~= nil and c.a or f.a or 1,
    }
end

local function ApplyGlobalValue(field, value)
    local gdb = E.db.coaResources
    gdb.resourceSettings = gdb.resourceSettings or {}

    if type(value) == "table" then
        gdb[field] = CopyColorValue(value)
    else
        gdb[field] = value
    end

    for _, rdb in pairs(gdb.resourceSettings) do
        if type(rdb) == "table" then
            if type(value) == "table" then
                rdb[field] = CopyColorValue(value)
            else
                rdb[field] = value
            end
        end
    end

    Update()
end

local function GetResourceDB(entry, index)
    return CCB:GetResourceDB(entry, index)
end

local function ResetResource(entry, index)
    local key = CCB:GetResourceSettingKey(entry, index)
    E.db.coaResources.resourceSettings[key] = nil
    Update()
end

local function MakeResourcePage(entry, index)
    local function db() return GetResourceDB(entry, index) end

    return {
        type = "group",
        name = entry.name or ("Resource "..index),
        order = 20 + index,
        args = {
            title = {order=1,type="header",name=entry.name or ("Resource "..index)},
            display = {
                order=10,type="group",name="Display",inline=true,
                args={
                    enabled={order=1,type="toggle",name="Enable",get=function() return db().enable end,set=function(_,v) db().enable=v; Update() end},
                    combatOnly={order=1.5,type="toggle",name="Only in combat",desc="Hide this resource while out of combat.",get=function() return db().combatOnly == true end,set=function(_,v) db().combatOnly=v and true or false; Update() end},
                    mode={order=2,type="select",name="Display Style",values={AUTO="Automatic",PIPS="Bubbles / Segments",BAR="Status Bar"},get=function() return db().mode or entry.mode or "AUTO" end,set=function(_,v) db().mode=v; Update() end},
                    reset={order=20,type="execute",name="Reset This Resource",confirm=true,confirmText="Reset this resource to its default CoA Resources settings?",func=function() ResetResource(entry,index) end},
                }
            },

            layout = {
                order=20,type="group",name="Size & Position",inline=true,
                args={
                    width={order=1,type="range",name="Width",min=40,max=700,step=1,get=function() return db().width end,set=function(_,v) db().width=v; Update() end},
                    height={order=2,type="range",name="Height",min=4,max=80,step=1,get=function() return db().height end,set=function(_,v) db().height=v; Update() end},
                    spacing={order=3,type="range",name="Bubble Spacing",min=0,max=30,step=1,get=function() return db().spacing end,set=function(_,v) db().spacing=v; Update() end},
                    frameStrata={
                        order=4,type="select",name="Frame Layer",
                        desc="Controls which UI layer this resource is drawn on. LOW is recommended so maps and large UI windows stay above it.",
                        values={BACKGROUND="Background",LOW="Low",MEDIUM="Medium",HIGH="High"},
                        get=function() return db().frameStrata or "LOW" end,
                        set=function(_,v) db().frameStrata=v; Update() end
                    },
                    frameLevel={
                        order=5,type="range",name="Frame Level",min=0,max=50,step=1,
                        desc="Fine tuning inside the selected frame layer.",
                        get=function() return db().frameLevel or 5 end,
                        set=function(_,v) db().frameLevel=v; Update() end
                    },
                }
            },

            appearance = {
                order=30,type="group",name="Appearance",inline=true,
                args={
                    texture={order=1,type="select",dialogControl="LSM30_Statusbar",name="Fill Texture",values=AceGUIWidgetLSMlists.statusbar,get=function() return db().texture end,set=function(_,v) db().texture=v; Update() end},
                    backgroundTexture={order=2,type="select",dialogControl="LSM30_Statusbar",name="Background Texture",desc="Texture used for the empty area behind this resource.",values=AceGUIWidgetLSMlists.statusbar,get=function() return db().backgroundTexture or db().texture end,set=function(_,v) db().backgroundTexture=v; Update() end},
                    gradient={order=3,type="toggle",name="Gradient",desc="Enable a Base Color to Gradient Color transition for this resource.",get=function() return db().gradient == true end,set=function(_,v) db().gradient=v and true or false; Update() end},
                    color={order=4,type="color",name="Base Color",get=function() local c=db().color return c.r,c.g,c.b end,set=function(_,r,g,b) local c=db().color c.r,c.g,c.b=r,g,b; Update() end},
                    gradientColor={order=5,type="color",name="Gradient Color",disabled=function() return not db().gradient end,get=function() local c=db().gradientColor return c.r,c.g,c.b end,set=function(_,r,g,b) local c=db().gradientColor c.r,c.g,c.b=r,g,b; Update() end},
                    background={order=6,type="color",name="Background Color",hasAlpha=true,disabled=function() return db().transparent == true end,get=function() local c=db().background return c.r,c.g,c.b,c.a end,set=function(_,r,g,b,a) local c=db().background c.r,c.g,c.b,c.a=r,g,b,a; Update() end},
                    transparent={order=7,type="toggle",name="Transparent",desc="Hide the background of this resource while keeping the fill, gradient and border visible.",get=function() return db().transparent == true end,set=function(_,v) db().transparent=v and true or false; Update() end},
                    showBorder={order=8,type="toggle",name="Show Border",get=function() return db().showBorder end,set=function(_,v) db().showBorder=v; Update() end},
                    borderColor={order=9,type="color",name="Border Color",hasAlpha=true,disabled=function() return not db().showBorder end,get=function() local c=db().borderColor return c.r,c.g,c.b,c.a end,set=function(_,r,g,b,a) local c=db().borderColor c.r,c.g,c.b,c.a=r,g,b,a; Update() end},
                }
            },

            text = {
                order=40,type="group",name="Text",inline=true,
                args={
                    showName={order=1,type="toggle",name="Show Resource Name",get=function() return db().showName end,set=function(_,v) db().showName=v; Update() end},
                    showValue={order=2,type="toggle",name="Show Resource Value",get=function() return db().showValue end,set=function(_,v) db().showValue=v; Update() end},
                    textPosition={order=3,type="select",name="Text Position",values={ABOVE="Above Bar",OVERLAY="On Bar",BELOW="Below Bar"},get=function() return db().textPosition or "ABOVE" end,set=function(_,v) db().textPosition=v; Update() end},
                    valueFormat={order=4,type="select",name="Value Format",values={CURRENT_MAX="Current / Max",CURRENT="Current Only",PERCENT="Percent"},get=function() return db().valueFormat or "CURRENT_MAX" end,set=function(_,v) db().valueFormat=v; Update() end},
                    font={order=10,type="select",dialogControl="LSM30_Font",name="Font",values=AceGUIWidgetLSMlists.font,get=function() return db().font end,set=function(_,v) db().font=v; Update() end},
                    fontSize={order=11,type="range",name="Font Size",min=6,max=40,step=1,get=function() return db().fontSize end,set=function(_,v) db().fontSize=v; Update() end},
                    fontOutline={order=12,type="select",name="Font Outline",values={NONE="None",OUTLINE="Outline",SHADOWOUTLINE="Shadow Outline",THICKOUTLINE="Thick Outline",MONOCHROME="Monochrome",["MONOCHROME,OUTLINE"]="Monochrome Outline"},get=function() return db().fontOutline end,set=function(_,v) db().fontOutline=v; Update() end},
                    textColor={order=13,type="color",name="Text Color",get=function() local c=db().textColor return c.r,c.g,c.b end,set=function(_,r,g,b) local c=db().textColor c.r,c.g,c.b=r,g,b; Update() end},
                    nameAlign={order=14,type="select",name="Name Position",values={LEFT="Left",CENTER="Center",RIGHT="Right"},get=function() return db().nameAlign or "LEFT" end,set=function(_,v) db().nameAlign=v; Update() end},
                    nameX={order=15,type="range",name="Name X Offset",min=-300,max=300,step=1,get=function() return db().nameX or 0 end,set=function(_,v) db().nameX=v; Update() end},
                    nameY={order=16,type="range",name="Name Y Offset",min=-150,max=150,step=1,get=function() return db().nameY or 0 end,set=function(_,v) db().nameY=v; Update() end},
                    valueAlign={order=17,type="select",name="Value Position",values={LEFT="Left",CENTER="Center",RIGHT="Right"},get=function() return db().valueAlign or "RIGHT" end,set=function(_,v) db().valueAlign=v; Update() end},
                    valueX={order=18,type="range",name="Value X Offset",min=-300,max=300,step=1,get=function() return db().valueX or 0 end,set=function(_,v) db().valueX=v; Update() end},
                    valueY={order=19,type="range",name="Value Y Offset",min=-150,max=150,step=1,get=function() return db().valueY or 0 end,set=function(_,v) db().valueY=v; Update() end},
                }
            },
        }
    }
end

local function BuildResourceToggleArgs()
    local args = {}
    local resources = CCB:GetAllKnownResources()
    for i, info in ipairs(resources) do
        local key = info.key
        args["resourceToggle"..i] = {
            order = i,
            type = "toggle",
            name = ClassColoredName(info.class).." - "..info.name,
            desc = "Show or hide this CoA class resource. Enabled by default.",
            width = "full",
            get = function()
                E.db.coaResources.enabledResources = E.db.coaResources.enabledResources or {}
                local v = E.db.coaResources.enabledResources[key]
                if v == nil then return true end
                return v == true
            end,
            set = function(_, v)
                E.db.coaResources.enabledResources = E.db.coaResources.enabledResources or {}
                E.db.coaResources.enabledResources[key] = v and true or false
                Update()
                if LibStub and LibStub("AceConfigRegistry-3.0", true) then
                    LibStub("AceConfigRegistry-3.0"):NotifyChange("ElvUI")
                end
            end,
        }
    end
    return args
end

local function SetupOptions()
    if not E.Options or not E.Options.args then return false end

    local pages = {
        general = {
            type="group",name="General",order=1,
            args={
                header={order=1,type="header",name="CoA Resources"},
                settings={
                    order=10,type="group",name="General",inline=true,
                    args={
                        enable={order=1,type="toggle",name="Enable",get=function() return E.db.coaResources.enable end,set=function(_,v) E.db.coaResources.enable=v; Update() end},
                        combatOnly={order=2,type="toggle",name="Only in combat (all resources)",desc="Applies to every resource at once. Afterwards each resource tab can still be changed individually.",get=function() return E.db.coaResources.combatOnly end,set=function(_,v) ApplyGlobalValue("combatOnly", v and true or false) end},
                        hideOriginalFrames={order=3,type="toggle",name="Hide Original CoA Resource Frames",desc="Hide Ascension's original class resource frames so only CoA Class Bars is visible.",get=function() return E.db.coaResources.hideOriginalFrames end,set=function(_,v) E.db.coaResources.hideOriginalFrames=v; CCB:ApplyOriginalFrameVisibility(); Update() end},
                    }
                },
                globalAppearance={
                    order=15,type="group",name="Global Settings",inline=true,
                    args={
                        info={order=1,type="description",name="Changes here are applied immediately to every CoA resource bar. Individual resource tabs can still override these values afterwards.\n"},
                        font={
                            order=10,type="select",dialogControl="LSM30_Font",name="Font",values=AceGUIWidgetLSMlists.font,
                            get=function() return E.db.coaResources.font or "PT Sans Narrow" end,
                            set=function(_,v) ApplyGlobalValue("font", v) end,
                        },
                        fontSize={
                            order=11,type="range",name="Font Size",min=6,max=40,step=1,
                            get=function() return E.db.coaResources.fontSize or 12 end,
                            set=function(_,v) ApplyGlobalValue("fontSize", v) end,
                        },
                        fontOutline={
                            order=12,type="select",name="Font Outline",
                            values={NONE="None",OUTLINE="Outline",SHADOWOUTLINE="Shadow Outline",THICKOUTLINE="Thick Outline",MONOCHROME="Monochrome",["MONOCHROME,OUTLINE"]="Monochrome Outline"},
                            get=function() return E.db.coaResources.fontOutline or "OUTLINE" end,
                            set=function(_,v) ApplyGlobalValue("fontOutline", v) end,
                        },
                        texture={
                            order=20,type="select",dialogControl="LSM30_Statusbar",name="Fill Texture",values=AceGUIWidgetLSMlists.statusbar,
                            get=function() return E.db.coaResources.texture or "Norm Tex" end,
                            set=function(_,v) ApplyGlobalValue("texture", v) end,
                        },
                        backgroundTexture={
                            order=21,type="select",dialogControl="LSM30_Statusbar",name="Background Texture",values=AceGUIWidgetLSMlists.statusbar,
                            get=function() return E.db.coaResources.backgroundTexture or E.db.coaResources.texture or "Norm Tex" end,
                            set=function(_,v) ApplyGlobalValue("backgroundTexture", v) end,
                        },
                        gradient={
                            order=30,type="toggle",name="Gradient",desc="Enable or disable each resource's existing gradient colors on all bars.",
                            get=function() return E.db.coaResources.gradient == true end,
                            set=function(_,v) ApplyGlobalValue("gradient", v and true or false) end,
                        },
                        transparent={
                            order=31,type="toggle",name="Transparent",desc="Hide the background on every CoA resource while keeping fill, gradient and borders visible.",
                            get=function() return E.db.coaResources.transparent == true end,
                            set=function(_,v) ApplyGlobalValue("transparent", v and true or false) end,
                        },
                        showBorder={
                            order=32,type="toggle",name="Show Border",
                            get=function() return E.db.coaResources.showBorder ~= false end,
                            set=function(_,v) ApplyGlobalValue("showBorder", v and true or false) end,
                        },
                        background={
                            order=40,type="color",name="Background Color",hasAlpha=true,disabled=function() return E.db.coaResources.transparent == true end,
                            get=function() local c=E.db.coaResources.background or {r=.08,g=.08,b=.08,a=.75}; return c.r,c.g,c.b,c.a end,
                            set=function(_,r,g,b,a) ApplyGlobalValue("background", {r=r,g=g,b=b,a=a}) end,
                        },
                        borderColor={
                            order=41,type="color",name="Border Color",hasAlpha=true,disabled=function() return E.db.coaResources.showBorder == false end,
                            get=function() local c=E.db.coaResources.borderColor or {r=0,g=0,b=0,a=1}; return c.r,c.g,c.b,c.a end,
                            set=function(_,r,g,b,a) ApplyGlobalValue("borderColor", {r=r,g=g,b=b,a=a}) end,
                        },
                    }
                },
                resources={
                    order=20,type="group",name="Resources",inline=true,
                    args=BuildResourceToggleArgs(),
                },
                tools={
                    order=30,type="group",name="Tools",inline=true,
                    args={
                        mover={order=1,type="execute",name="Move Resource Bars",desc="Opens ElvUI move mode. Every class resource has its own mover.",func=function() if E.ToggleMoveMode then E:ToggleMoveMode() end end},
                        debug={order=2,type="execute",name="Print Detected Resources",func=function() CCB:DebugResources() end},
                    }
                },
            }
        },
    }

    local entries = CCB:GetFixedResourceEntries()
    if #entries > 0 then
        for i, entry in ipairs(entries) do pages["resource"..i] = MakeResourcePage(entry, i) end
    else
        pages.info={type="group",name="Resource",order=20,args={noFixed={order=1,type="description",name="No supported custom FrameXML resource is registered for this class, so CoA Resources stays hidden."}}}
    end

    E.Options.args.coaResources={
        type="group",name="|cffffb347CoA Resources|r",order=47,childGroups="tab",args=pages
    }
    return true
end

local optionsLoader = CreateFrame("Frame")
optionsLoader:RegisterEvent("ADDON_LOADED")
optionsLoader:RegisterEvent("PLAYER_LOGIN")
optionsLoader:SetScript("OnEvent", function(self, event, addon)
    if event == "ADDON_LOADED" and addon ~= "ElvUI_OptionsUI" then return end
    if SetupOptions() then
        if IsAddOnLoaded and IsAddOnLoaded("ElvUI_OptionsUI") then
            self:UnregisterEvent("ADDON_LOADED")
            self:UnregisterEvent("PLAYER_LOGIN")
        end
    end
end)

SetupOptions()
