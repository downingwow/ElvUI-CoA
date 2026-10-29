local E, _, V, P, G = unpack(ElvUI); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local C, L = unpack(select(2, ...))
local DT = E:GetModule("DataTexts")
local Layout = E:GetModule("Layout")
local Chat = E:GetModule("Chat")
local Minimap = E:GetModule("Minimap")

local _G = _G
local pairs, ipairs, format = pairs, ipairs, string.format

local HideLeftChat = HideLeftChat
local HideRightChat = HideRightChat

local datatexts = {}

function DT:PanelLayoutOptions()
	for name, data in pairs(DT.RegisteredDataTexts) do
		datatexts[name] = data.localizedName or L[name]
	end
	datatexts[""] = L["NONE"]

	local order
	local table = E.Options.args.datatexts.args.panels.args
	for pointLoc, tab in pairs(P.datatexts.panels) do
		if not _G[pointLoc] then table[pointLoc] = nil return end
		if type(tab) == "table" then
			if pointLoc:find("Chat") then
				order = 15
			else
				order = 20
			end
			table[pointLoc] = {
				order = order,
				type = "group",
				name = L[pointLoc] or pointLoc,
				args = {}
			}
			for option in pairs(tab) do
				table[pointLoc].args[option] = {
					type = "select",
					name = L[option] or option:upper(),
					values = datatexts,
					get = function(info) return E.db.datatexts.panels[pointLoc][info[#info]] end,
					set = function(info, value) E.db.datatexts.panels[pointLoc][info[#info]] = value DT:LoadDataTexts() end
				}
			end
		elseif type(tab) == "string" then
			table.smallPanels.args[pointLoc] = {
				type = "select",
				name = L[pointLoc] or pointLoc,
				values = datatexts,
				get = function(info) return E.db.datatexts.panels[pointLoc] end,
				set = function(info, value) E.db.datatexts.panels[pointLoc] = value DT:LoadDataTexts() end
			}
		end
	end
end

E.Options.args.datatexts = {
	type = "group",
	name = L["DataTexts"],
	childGroups = "tab",
	get = function(info) return E.db.datatexts[info[#info]] end,
	set = function(info, value) E.db.datatexts[info[#info]] = value DT:LoadDataTexts() end,
	args = {
		intro = {
			order = 1,
			type = "description",
			name = L["DATATEXT_DESC"]
		},
		spacer = {
			order = 2,
			type = "description",
			name = ""
		},
		general = {
			order = 3,
			type = "group",
			name = L["General"],
			args = {
				header = {
					order = 1,
					type = "header",
					name = L["General"]
				},
				generalGroup = {
					order = 2,
					type = "group",
					guiInline = true,
					name = L["General"],
					args = {
						battleground = {
							order = 1,
							type = "toggle",
							name = L["Battleground Texts"],
							desc = L["When inside a battleground display personal scoreboard information on the main datatext bars."]
						},
						panelTransparency = {
							order = 2,
							name = L["Panel Transparency"],
							type = "toggle",
							set = function(info, value)
								E.db.datatexts[info[#info]] = value
								Layout:SetDataPanelStyle()
							end
						},
						panelBackdrop = {
							order = 3,
							type = "toggle",
							name = L["Backdrop"],
							set = function(info, value)
								E.db.datatexts[info[#info]] = value
								Layout:SetDataPanelStyle()
							end
						},
						noCombatClick = {
							order = 4,
							type = "toggle",
							name = L["Block Combat Click"],
							desc = L["Blocks all click events while in combat."]
						},
						noCombatHover = {
							order = 5,
							type = "toggle",
							name = L["Block Combat Hover"],
							desc = L["Blocks datatext tooltip from showing in combat."]
						},
						goldFormat = {
							order = 6,
							type = "select",
							name = L["Gold Format"],
							desc = L["The display format of the money text that is shown in the gold datatext and its tooltip."],
							values = {
								["SMART"] = L["Smart"],
								["FULL"] = L["Full"],
								["SHORT"] = L["SHORT"],
								["SHORTINT"] = L["Short (Whole Numbers)"],
								["CONDENSED"] = L["Condensed"],
								["BLIZZARD"] = L["Blizzard Style"]
							}
						},
						goldCoins = {
							order = 7,
							type = "toggle",
							name = L["Show Coins"],
							desc = L["Use coin icons instead of colored text."]
						}
					}
				},
				fontGroup = {
					order = 3,
					type = "group",
					guiInline = true,
					name = L["Fonts"],
					args = {
						font = {
							order = 1,
							type = "select", dialogControl = "LSM30_Font",
							name = L["Font"],
							values = AceGUIWidgetLSMlists.font
						},
						fontSize = {
							order = 2,
							type = "range",
							name = L["FONT_SIZE"],
							min = 4, max = 22, step = 1
						},
						fontOutline = {
							order = 3,
							type = "select",
							name = L["Font Outline"],
							desc = L["Set the font outline."],
							values = C.Values.FontFlags
						},
						wordWrap = {
							order = 4,
							type = "toggle",
							name = L["Word Wrap"]
						}
					}
				}
			}
		},
		panels = {
			type = "group",
			name = L["Panels"],
			order = 4,
			args = {
				header = {
					order = 1,
					type = "header",
					name = L["Panels"]
				},
				leftChatPanel = {
					order = 2,
					type = "toggle",
					name = L["Datatext Panel (Left)"],
					desc = L["Display data panels below the chat, used for datatexts."],
					set = function(info, value)
						E.db.datatexts[info[#info]] = value
						if E.db.LeftChatPanelFaded then
							E.db.LeftChatPanelFaded = true
							HideLeftChat()
						end
						Chat:UpdateAnchors()
						Layout:ToggleChatPanels()
					end
				},
				rightChatPanel = {
					order = 3,
					type = "toggle",
					name = L["Datatext Panel (Right)"],
					desc = L["Display data panels below the chat, used for datatexts."],
					set = function(info, value)
						E.db.datatexts[info[#info]] = value
						if E.db.RightChatPanelFaded then
							E.db.RightChatPanelFaded = true
							HideRightChat()
						end
						Chat:UpdateAnchors()
						Layout:ToggleChatPanels()
					end
				},
				minimapPanels = {
					order = 4,
					type = "toggle",
					name = L["Minimap Panels"],
					desc = L["Display minimap panels below the minimap, used for datatexts."],
					set = function(info, value)
						E.db.datatexts[info[#info]] = value
						Minimap:UpdateSettings()
					end
				},
				minimapTop = {
					order = 5,
					type = "toggle",
					name = L["TopMiniPanel"],
					set = function(info, value)
						E.db.datatexts[info[#info]] = value
						Minimap:UpdateSettings()
					end
				},
				minimapTopLeft = {
					order = 6,
					type = "toggle",
					name = L["TopLeftMiniPanel"],
					set = function(info, value)
						E.db.datatexts[info[#info]] = value
						Minimap:UpdateSettings()
					end
				},
				minimapTopRight = {
					order = 7,
					type = "toggle",
					name = L["TopRightMiniPanel"],
					set = function(info, value)
						E.db.datatexts[info[#info]] = value
						Minimap:UpdateSettings()
					end
				},
				minimapBottom = {
					order = 8,
					type = "toggle",
					name = L["BottomMiniPanel"],
					set = function(info, value)
						E.db.datatexts[info[#info]] = value
						Minimap:UpdateSettings()
					end
				},
				minimapBottomLeft = {
					order = 9,
					type = "toggle",
					name = L["BottomLeftMiniPanel"],
					set = function(info, value)
						E.db.datatexts[info[#info]] = value
						Minimap:UpdateSettings()
					end
				},
				minimapBottomRight = {
					order = 10,
					type = "toggle",
					name = L["BottomRightMiniPanel"],
					set = function(info, value)
						E.db.datatexts[info[#info]] = value
						Minimap:UpdateSettings()
					end
				},
				spacer = {
					order = 11,
					type = "description",
					name = "\n"
				},
				smallPanels = {
					order = 12,
					type = "group",
					name = L["Small Panels"],
					args = {}
				}
			}
		},
		time = {
			order = 5,
			type = "group",
			name = L["Time"],
			args = {
				header = {
					order = 1,
					type = "header",
					name = L["Time"],
				},
				timeFormat = {
					order = 2,
					type = "select",
					name = L["Time Format"],
					values = {
						[""] = L["NONE"],
						["%I:%M"] = "03:27",
						["%I:%M:%S"] = "03:27:32",
						["%I:%M %p"] = "03:27 PM",
						["%I:%M:%S %p"] = "03:27:32 PM",
						["%H:%M"] = "15:27",
						["%H:%M:%S"] = "15:27:32"
					}
				},
				dateFormat = {
					order = 3,
					type = "select",
					name = L["Date Format"],
					values = {
						[""] = L["NONE"],
						["%d/%m/%y "] = "DD/MM/YY",
						["%m/%d/%y "] = "MM/DD/YY",
						["%y/%m/%d "] = "YY/MM/DD",
						["%d.%m.%y "] = "DD.MM.YY",
						["%m.%d.%y "] = "MM.DD.YY",
						["%y.%m.%d "] = "YY.MM.DD"
					}
				},
				realmTime = {
					order = 4,
					type = "toggle",
					name = L["Realm Time"],
					desc = L["Displayed server time."]
				}
			}
		},
		friends = {
			order = 6,
			type = "group",
			name = L["FRIENDS"],
			args = {
				header = {
					order = 1,
					type = "header",
					name = L["FRIENDS"]
				},
				description = {
					order = 2,
					type = "description",
					name = L["Hide specific sections in the datatext tooltip."]
				},
				hideGroup = {
					order = 3,
					type = "group",
					guiInline = true,
					name = L["HIDE"],
					args = {
						hideAFK = {
							order = 1,
							type = "toggle",
							name = L["AFK"],
							get = function(info) return E.db.datatexts.friends.hideAFK end,
							set = function(info, value) E.db.datatexts.friends.hideAFK = value DT:LoadDataTexts() end
						},
						hideDND = {
							order = 2,
							type = "toggle",
							name = L["DND"],
							get = function(info) return E.db.datatexts.friends.hideDND end,
							set = function(info, value) E.db.datatexts.friends.hideDND = value DT:LoadDataTexts() end
						}
					}
				}
			}
		}
	}
}

DT:PanelLayoutOptions()

--------------------------------------------------------------------------
-- Eigene Datatext-Panels
--------------------------------------------------------------------------
local newPanelName = ""

local function GetDatatextValues()
	local values = {[""] = L["NONE"]}
	for name, data in pairs(DT.RegisteredDataTexts) do
		values[name] = data.localizedName or L[name] or name
	end
	return values
end

local function Notify()
	E.Libs.AceConfigRegistry:NotifyChange("ElvUI")
end

function DT:BuildCustomPanelOptions()
	local group = E.Options.args.datatexts.args.customPanels
	if not group then return end
	local args = group.args

	for key in pairs(args) do
		if key:find("^panel_") then args[key] = nil end
	end

	local panels = E.global.datatexts and E.global.datatexts.customPanels
	if not panels then return end

	local order = 10
	for id in pairs(panels) do
		local frameName = DT:GetCustomPanelFrameName(id)
		local function get(info) return E.global.datatexts.customPanels[id] and E.global.datatexts.customPanels[id][info[#info]] end
		local function set(info, value)
			E.global.datatexts.customPanels[id][info[#info]] = value
			DT:UpdateCustomPanels()
		end

		local panelArgs = {
			numPoints = {
				order = 1, type = "range", name = L["Slots"] or "Slots",
				desc = "Anzahl der Datatext-Slots dieses Panels.",
				min = 1, max = DT.MAX_CUSTOM_SLOTS, step = 1
			},
			width = { order = 2, type = "range", name = L["Width"], min = 40, max = 1200, step = 1 },
			height = { order = 3, type = "range", name = L["Height"], min = 8, max = 120, step = 1 },
			spacer1 = { order = 4, type = "description", name = "", width = "full" },
			backdrop = { order = 5, type = "toggle", name = L["Backdrop"] },
			border = { order = 6, type = "toggle", name = "Rahmen", disabled = function() return not get({"backdrop"}) end },
			transparent = { order = 7, type = "toggle", name = L["Transparent"] or "Transparent", disabled = function() return not get({"backdrop"}) end },
			alpha = { order = 8, type = "range", name = L["Alpha"] or "Alpha", isPercent = true, min = 0, max = 1, step = 0.01, disabled = function() return not get({"backdrop"}) end },
			texture = {
				order = 9, type = "select", dialogControl = "LSM30_Statusbar", name = L["Texture"] or "Texture",
				values = AceGUIWidgetLSMlists.statusbar,
				disabled = function() return not get({"backdrop"}) end
			},
			shadowGroup = {
				order = 10, type = "group", guiInline = true, name = "Schatten",
				args = {
					shadow = { order = 1, type = "toggle", name = L["Enable"] },
					shadowSize = { order = 2, type = "range", name = L["Size"] or "Size", min = 1, max = 20, step = 1, disabled = function() return not get({"shadow"}) end,
						get = function() return E.global.datatexts.customPanels[id].shadowSize end,
						set = function(_, value) E.global.datatexts.customPanels[id].shadowSize = value DT:UpdateCustomPanels() end },
				},
				get = function(info) return E.global.datatexts.customPanels[id][info[#info]] end,
				set = function(info, value) E.global.datatexts.customPanels[id][info[#info]] = value DT:UpdateCustomPanels() end
			},
			fontGroup = {
				order = 11, type = "group", guiInline = true, name = L["Fonts"],
				args = {
					font = { order = 1, type = "select", dialogControl = "LSM30_Font", name = L["Font"], values = AceGUIWidgetLSMlists.font },
					fontSize = { order = 2, type = "range", name = L["FONT_SIZE"], min = 4, max = 32, step = 1 },
					fontOutline = { order = 3, type = "select", name = L["Font Outline"], desc = L["Set the font outline."], values = C.Values.FontFlags },
				},
				get = function(info) return E.global.datatexts.customPanels[id][info[#info]] end,
				set = function(info, value) E.global.datatexts.customPanels[id][info[#info]] = value DT:UpdateCustomPanels() end
			},
			slotGroup = {
				order = 12, type = "group", guiInline = true, name = "Datatexts",
				args = {}
			},
			delete = {
				order = 20, type = "execute", name = L["Delete"] or "Delete",
				confirm = true, confirmText = format("Panel \"%s\" wirklich loeschen?", id),
				func = function()
					DT:DeleteCustomPanel(id)
					DT:BuildCustomPanelOptions()
					DT:LoadDataTexts()
					Notify()
				end
			}
		}

		for i = 1, DT.MAX_CUSTOM_SLOTS do
			local key = "slot"..i
			panelArgs.slotGroup.args[key] = {
				order = i, type = "select", name = "Slot "..i,
				values = GetDatatextValues,
				hidden = function() return i > (get({"numPoints"}) or 3) end,
				get = function()
					local t = E.db.datatexts.panels[frameName]
					return t and t[key] or ""
				end,
				set = function(_, value)
					if not E.db.datatexts.panels[frameName] then E.db.datatexts.panels[frameName] = {} end
					E.db.datatexts.panels[frameName][key] = value
					DT:LoadDataTexts()
				end
			}
		end

		args["panel_"..id] = {
			order = order,
			type = "group",
			name = id,
			get = get,
			set = set,
			args = panelArgs
		}
		order = order + 1
	end
end

E.Options.args.datatexts.args.customPanels = {
	order = 6,
	type = "group",
	name = "Custom Panels",
	childGroups = "select",
	get = function() end,
	set = function() end,
	args = {
		header = { order = 1, type = "header", name = "Custom Panels" },
		newName = {
			order = 3, type = "input", name = L["Name"] or "Name",
			get = function() return newPanelName end,
			set = function(_, value) newPanelName = (value or ""):gsub("^%s+", ""):gsub("%s+$", "") end
		},
		create = {
			order = 4, type = "execute", name = L["Create"] or "Create",
			func = function()
				local name = newPanelName
				if name == "" then E:Print("Bitte einen Namen eingeben.") return end
				local panels = E.global.datatexts.customPanels
				local frameName = DT:GetCustomPanelFrameName(name)
				for id in pairs(panels) do
					if DT:GetCustomPanelFrameName(id) == frameName then
						E:Print(format("Ein Panel mit dem Namen \"%s\" existiert bereits.", id))
						return
					end
				end
				local cfg = {}
				for key, value in pairs(DT.CustomPanelDefaults) do cfg[key] = value end
				panels[name] = cfg
				newPanelName = ""
				DT:UpdateCustomPanels()
				DT:BuildCustomPanelOptions()
				Notify()
			end
		}
	}
}

----------------------------------------------------------------------------------------------------
-- Travel statistics tab: custom texts + character list
----------------------------------------------------------------------------------------------------
local travelLabels = {
	{key = "jumps_char", name = "Jumps (Character)"},
	{key = "jumps_acc", name = "Jumps (Account)"},
	{key = "dist_char", name = "Distance km / mi (Character)"},
	{key = "dist_acc", name = "Distance km / mi (Account)"},
	{key = "speed", name = "Speed (km/h / mph)"},
}

function DT:BuildTravelStatsOptions()
	local API = DT.TravelStats
	local group = E.Options.args.datatexts.args.travelStats
	if not API or not group then return end
	local args = group.args

	for key in pairs(args) do
		if key:find("^char_") then args[key] = nil end
	end

	local order = 100
	for _, e in ipairs(API.GetChars()) do
		local color = e.class and RAID_CLASS_COLORS[e.class]
		local hex = color and format("|cff%02x%02x%02x", color.r * 255, color.g * 255, color.b * 255) or "|cffffffff"
		local key = e.key
		args["char_"..key] = {
			order = order, type = "description", width = "double", fontSize = "medium",
			name = format("%s%s|r  -  %s %s  |  %s km  |  %s mi", hex, key, API.FormatInt(e.jumps), "Jumps",
				API.FormatDist(e.yards * API.YARDS_TO_KM), API.FormatDist(e.yards * API.YARDS_TO_MI))
		}
		args["char_"..key.."_remove"] = {
			order = order + 1, type = "execute", width = "half", name = "Remove",
			disabled = e.current,
			confirm = true,
			confirmText = format("Remove %s? The values will also be subtracted from the account total.", key),
			func = function()
				API.RemoveChar(key)
				DT:BuildTravelStatsOptions()
				Notify()
			end
		}
		order = order + 2
	end
	Notify()
end

local function TravelLabelOption(index, info)
	return {
		order = index + 1, type = "input", width = "double",
		name = info.name,
		desc = function() return format("Default: %s", DT.TravelStats.DefaultLabel(info.key)) end,
		get = function() return (DT.TravelStats.GetLabel(info.key)) end,
		set = function(_, value) DT.TravelStats.SetLabel(info.key, value) end,
	}
end

E.Options.args.datatexts.args.travelStats = {
	order = 7,
	type = "group",
	name = "Travel",
	get = function() end,
	set = function() end,
	args = {
		labelHeader = { order = 1, type = "header", name = "Datatext Labels" },
		labelDesc = {
			order = 2, type = "description",
			name = "Customize the text in front of the value (e.g. \"walked\" instead of \"Distance Acc\"). Leave empty to use the default text."
		},
		charHeader = { order = 50, type = "header", name = "Characters" },
		charDesc = {
			order = 51, type = "description",
			name = "Remove deleted characters here. The current character cannot be removed."
		},
		charRefresh = {
			order = 52, type = "execute", name = "Refresh",
			func = function() DT:BuildTravelStatsOptions() end
		},
	}
}
for i, info in ipairs(travelLabels) do
	E.Options.args.datatexts.args.travelStats.args["label_"..info.key] = TravelLabelOption(2 + i, info)
end

DT:BuildCustomPanelOptions()
DT:BuildTravelStatsOptions()
