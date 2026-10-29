local E, _, V, P, G = unpack(ElvUI); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local C, L = unpack(select(2, ...))
local Misc = E:GetModule("Misc")
local Layout = E:GetModule("Layout")
local Totems = E:GetModule("Totems")
local Blizzard = E:GetModule("Blizzard")
local Threat = E:GetModule("Threat")
local AFK = E:GetModule("AFK")

local _G = _G

local FCF_GetNumActiveChatFrames = FCF_GetNumActiveChatFrames

local function GetChatWindowInfo()
	local ChatTabInfo = {}
	for i = 1, FCF_GetNumActiveChatFrames() do
		if i ~= 2 then
			ChatTabInfo["ChatFrame"..i] = _G["ChatFrame"..i.."Tab"]:GetText()
		end
	end

	return ChatTabInfo
end

E.Options.args.general = {
	order = 1,
	type = "group",
	name = L["General"],
	childGroups = "tab",
	get = function(info) return E.db.general[info[#info]] end,
	set = function(info, value) E.db.general[info[#info]] = value end,
	args = {
		intro = {
			order = 1,
			type = "description",
			name = L["ELVUI_DESC"]
		},
		general = {
			order = 2,
			type = "group",
			name = L["General"],
			args = {
				generalHeader = {
					order = 1,
					type = "header",
					name = L["General"]
				},
				messageRedirect = {
					order = 2,
					type = "select",
					name = L["Chat Output"],
					desc = L["This selects the Chat Frame to use as the output of ElvUI messages."],
					values = GetChatWindowInfo()
				},
				AutoScale = {
					order = 3,
					type = "execute",
					name = L["Auto Scale"],
					func = function()
						E.global.general.UIScale = E:PixelBestSize()
						E:StaticPopup_Show("UISCALE_CHANGE")
					end
				},
				UIScale = {
					order = 4,
					type = "range",
					name = L["UI_SCALE"],
					min = 0.1, max = 1.25, step = 0.0000000000000001,
					softMin = 0.40, softMax = 1.15, bigStep = 0.01,
					get = function(info) return E.global.general.UIScale end,
					set = function(info, value)
						E.global.general.UIScale = value
						E:StaticPopup_Show("UISCALE_CHANGE")
					end
				},
				ignoreScalePopup = {
					order = 5,
					type = "toggle",
					name = L["Ignore UI Scale Popup"],
					desc = L["This will prevent the UI Scale Popup from being shown when changing the game window size."],
					get = function(info) return E.global.general.ignoreScalePopup end,
					set = function(info, value) E.global.general.ignoreScalePopup = value end
				},
				pixelPerfect = {
					order = 6,
					type = "toggle",
					name = L["Thin Border Theme"],
					desc = L["The Thin Border Theme option will change the overall apperance of your UI. Using Thin Border Theme is a slight performance increase over the traditional layout."],
					get = function(info) return E.private.general.pixelPerfect end,
					set = function(info, value) E.private.general.pixelPerfect = value E:StaticPopup_Show("PRIVATE_RL") end
				},
				eyefinity = {
					order = 7,
					type = "toggle",
					name = L["Multi-Monitor Support"],
					desc = L["Attempt to support eyefinity/nvidia surround."],
					get = function(info) return E.global.general.eyefinity end,
					set = function(info, value) E.global.general.eyefinity = value E:StaticPopup_Show("GLOBAL_RL") end
				},
				taintLog = {
					order = 8,
					type = "toggle",
					name = L["Log Taints"],
					desc = L["Send ADDON_ACTION_BLOCKED errors to the Lua Error frame. These errors are less important in most cases and will not effect your game performance. Also a lot of these errors cannot be fixed. Please only report these errors if you notice a Defect in gameplay."]
				},
				autoRepair = {
					order = 8.1,
					type = "select",
					name = "Auto Repair",
					desc = "Automatically repair all your equipment when you open a vendor that can repair. If you cannot afford everything, the most important slots are repaired first.\n\nPlayer = pay with your own gold.\nGuild = use the guild bank first (if your guild allows it and has enough), otherwise your own gold.",
					values = {
						NONE = "Off",
						PLAYER = "Player",
						GUILD = "Guild"
					},
					get = function()
						local v = E.db.general.autoRepair
						if v == true then return "GUILD" elseif not v then return "NONE" end
						return v
					end,
					set = function(_, value) E.db.general.autoRepair = value end
				},
				screenPanels = {
					order = 9,
					type = "group",
					name = "Screen Panels",
					guiInline = true,
					args = {
						topPanelGroup = {
							order = 1,
							type = "group",
							name = "Top Panel",
							guiInline = true,
							args = {
								enable = {
									order = 1, type = "toggle", name = L["Enable"],
									get = function() return E.db.general.topPanel end,
									set = function(_, value) E.db.general.topPanel = value Layout:TopPanelVisibility() end,
								},
								texture = {
									order = 2, type = "select", dialogControl = "LSM30_Statusbar", name = "Texture",
									values = AceGUIWidgetLSMlists.statusbar,
									get = function() return E.db.general.topPanelSettings.texture end,
									set = function(_, value) E.db.general.topPanelSettings.texture = value Layout:TopPanelVisibility() end,
									disabled = function() return not E.db.general.topPanel end,
								},
								alpha = {
									order = 3, type = "range", name = "Opacity", isPercent = true,
									min = 0, max = 1, step = 0.05,
									get = function() return E.db.general.topPanelSettings.alpha end,
									set = function(_, value) E.db.general.topPanelSettings.alpha = value Layout:TopPanelVisibility() end,
									disabled = function() return not E.db.general.topPanel end,
								},
								height = {
									order = 4, type = "range", name = "Height",
									min = 2, max = 100, step = 1,
									get = function() return E.db.general.topPanelSettings.height end,
									set = function(_, value) E.db.general.topPanelSettings.height = value Layout:TopPanelVisibility() end,
									disabled = function() return not E.db.general.topPanel end,
								},
								offset = {
									order = 5, type = "range", name = "Outside Offset",
									desc = "Moves the panel farther outside the top edge of the screen.",
									min = 0, max = 100, step = 1,
									get = function() return E.db.general.topPanelSettings.offset end,
									set = function(_, value) E.db.general.topPanelSettings.offset = value Layout:TopPanelVisibility() end,
									disabled = function() return not E.db.general.topPanel end,
								},
							},
						},
						bottomPanelGroup = {
							order = 2,
							type = "group",
							name = "Bottom Panel",
							guiInline = true,
							args = {
								enable = {
									order = 1, type = "toggle", name = L["Enable"],
									get = function() return E.db.general.bottomPanel end,
									set = function(_, value) E.db.general.bottomPanel = value Layout:BottomPanelVisibility() end,
								},
								texture = {
									order = 2, type = "select", dialogControl = "LSM30_Statusbar", name = "Texture",
									values = AceGUIWidgetLSMlists.statusbar,
									get = function() return E.db.general.bottomPanelSettings.texture end,
									set = function(_, value) E.db.general.bottomPanelSettings.texture = value Layout:BottomPanelVisibility() end,
									disabled = function() return not E.db.general.bottomPanel end,
								},
								alpha = {
									order = 3, type = "range", name = "Opacity", isPercent = true,
									min = 0, max = 1, step = 0.05,
									get = function() return E.db.general.bottomPanelSettings.alpha end,
									set = function(_, value) E.db.general.bottomPanelSettings.alpha = value Layout:BottomPanelVisibility() end,
									disabled = function() return not E.db.general.bottomPanel end,
								},
								height = {
									order = 4, type = "range", name = "Height",
									min = 2, max = 100, step = 1,
									get = function() return E.db.general.bottomPanelSettings.height end,
									set = function(_, value) E.db.general.bottomPanelSettings.height = value Layout:BottomPanelVisibility() end,
									disabled = function() return not E.db.general.bottomPanel end,
								},
								offset = {
									order = 5, type = "range", name = "Outside Offset",
									desc = "Moves the panel farther outside the bottom edge of the screen.",
									min = 0, max = 100, step = 1,
									get = function() return E.db.general.bottomPanelSettings.offset end,
									set = function(_, value) E.db.general.bottomPanelSettings.offset = value Layout:BottomPanelVisibility() end,
									disabled = function() return not E.db.general.bottomPanel end,
								},
							},
						},
					},
				},
				afk = {
					order = 11,
					type = "toggle",
					name = L["AFK Mode"],
					desc = L["When you go AFK display the AFK screen."],
					set = function(info, value) E.db.general.afk = value AFK:Toggle() end
				},
				decimalLength = {
					order = 12,
					type = "range",
					name = L["Decimal Length"],
					desc = L["Controls the amount of decimals used in values displayed on elements like NamePlates and UnitFrames."],
					min = 0, max = 4, step = 1,
					set = function(info, value)
						E.db.general.decimalLength = value
						E:BuildPrefixValues()
						E:StaticPopup_Show("CONFIG_RL")
					end
				},
				numberPrefixStyle = {
					order = 13,
					type = "select",
					name = L["Unit Prefix Style"],
					desc = L["The unit prefixes you want to use when values are shortened in ElvUI. This is mostly used on UnitFrames."],
					set = function(info, value)
						E.db.general.numberPrefixStyle = value
						E:BuildPrefixValues()
						E:StaticPopup_Show("CONFIG_RL")
					end,
					values = {
						["CHINESE"] = "Chinese (W, Y)",
						["ENGLISH"] = "English (K, M, B)",
						["GERMAN"] = "German (Tsd, Mio, Mrd)",
						["KOREAN"] = "Korean (천, 만, 억)",
						["METRIC"] = "Metric (k, M, G)"
					}
				},
				smoothingAmount = {
					order = 14,
					type = "range",
					isPercent = true,
					name = L["Smoothing Amount"],
					desc = L["Controls the speed at which smoothed bars will be updated."],
					min = 0.1, max = 0.8, softMax = 0.75, softMin = 0.25, step = 0.01,
					set = function(info, value)
						E.db.general.smoothingAmount = value
						E:SetSmoothingAmount(value)
					end
				},
				locale = {
					order = 15,
					type = "select",
					name = L["LANGUAGE"],
					get = function(info) return E.global.general.locale end,
					set = function(info, value)
						E.global.general.locale = value
						E:StaticPopup_Show("CONFIG_RL")
					end,
					values = {
						["deDE"] = "Deutsch",
						["enUS"] = "English",
						["esMX"] = "Español",
						["frFR"] = "Français",
						["ptBR"] = "Português",
						["ruRU"] = "Русский",
						["zhCN"] = "简体中文",
						["zhTW"] = "正體中文",
						["koKR"] = "한국어"
					}
				}
			}
		},
		media = {
			order = 3,
			type = "group",
			name = L["Media"],
			get = function(info) return E.db.general[info[#info]] end,
			set = function(info, value) E.db.general[info[#info]] = value end,
			args = {
				header = {
					order = 1,
					type = "header",
					name = L["Media"]
				},
				fontGroup = {
					order = 2,
					type = "group",
					name = L["Font"],
					guiInline = true,
					args = {
						font = {
							order = 1,
							type = "select", dialogControl = "LSM30_Font",
							name = L["Default Font"],
							desc = L["The font that the core of the UI will use."],
							values = AceGUIWidgetLSMlists.font,
							set = function(info, value) E.db.general[info[#info]] = value E:UpdateMedia() E:UpdateFontTemplates() end
						},
						fontSize = {
							order = 2,
							type = "range",
							name = L["FONT_SIZE"],
							desc = L["Set the font size for everything in UI. Note: This doesn't effect somethings that have their own seperate options (UnitFrame Font, Datatext Font, ect..)"],
							min = 4, max = 32, step = 1,
							set = function(info, value) E.db.general[info[#info]] = value E:UpdateMedia() E:UpdateFontTemplates() end
						},
						fontStyle = {
							order = 3,
							type = "select",
							name = L["Font Outline"],
							values = C.Values.FontFlags,
							set = function(info, value) E.db.general[info[#info]] = value E:UpdateMedia() E:UpdateFontTemplates() end
						},
						applyFontToAll = {
							order = 4,
							type = "execute",
							name = L["Apply Font To All"],
							desc = L["Applies the font and font size settings throughout the entire user interface. Note: Some font size settings will be skipped due to them having a smaller font size by default."],
							func = function() E:StaticPopup_Show("APPLY_FONT_WARNING") end
						},
						dmgfont = {
							order = 5,
							type = "select", dialogControl = "LSM30_Font",
							name = L["CombatText Font"],
							desc = L["The font that combat text will use. |cffFF0000WARNING: This requires a game restart or re-log for this change to take effect.|r"],
							values = AceGUIWidgetLSMlists.font,
							get = function(info) return E.private.general[info[#info]] end,
							set = function(info, value) E.private.general[info[#info]] = value E:UpdateMedia() E:UpdateFontTemplates() E:StaticPopup_Show("PRIVATE_RL") end
						},
						namefont = {
							order = 6,
							type = "select", dialogControl = "LSM30_Font",
							name = L["Name Font"],
							desc = L["The font that appears on the text above players heads. |cffFF0000WARNING: This requires a game restart or re-log for this change to take effect.|r"],
							values = AceGUIWidgetLSMlists.font,
							get = function(info) return E.private.general[info[#info]] end,
							set = function(info, value) E.private.general[info[#info]] = value E:UpdateMedia() E:UpdateFontTemplates() E:StaticPopup_Show("PRIVATE_RL") end
						},
						replaceBlizzFonts = {
							order = 7,
							type = "toggle",
							name = L["Replace Blizzard Fonts"],
							desc = L["Replaces the default Blizzard fonts on various panels and frames with the fonts chosen in the Media section of the ElvUI Options. NOTE: Any font that inherits from the fonts ElvUI usually replaces will be affected as well if you disable this. Enabled by default."],
							get = function(info) return E.private.general[info[#info]] end,
							set = function(info, value) E.private.general[info[#info]] = value E:StaticPopup_Show("PRIVATE_RL") end
						}
					}
				},
				textureGroup = {
					order = 3,
					type = "group",
					name = L["Textures"],
					guiInline = true,
					get = function(info) return E.private.general[info[#info]] end,
					args = {
						normTex = {
							order = 1,
							type = "select", dialogControl = "LSM30_Statusbar",
							name = L["Primary Texture"],
							desc = L["The texture that will be used mainly for statusbars."],
							values = AceGUIWidgetLSMlists.statusbar,
							set = function(info, value)
								local previousValue = E.private.general[info[#info]]
								E.private.general[info[#info]] = value

								if E.db.unitframe.statusbar == previousValue then
									E.db.unitframe.statusbar = value
									E:UpdateAll(true)
								else
									E:UpdateMedia()
									E:UpdateStatusBars()
								end
							end
						},
						glossTex = {
							order = 2,
							type = "select", dialogControl = "LSM30_Statusbar",
							name = L["Secondary Texture"],
							desc = L["This texture will get used on objects like chat windows and dropdown menus."],
							values = AceGUIWidgetLSMlists.statusbar,
							set = function(info, value)
								E.private.general[info[#info]] = value
								E:UpdateMedia()
								E:UpdateFrameTemplates()
							end
						},
						applyTextureToAll = {
							order = 3,
							type = "execute",
							name = L["Apply Texture To All"],
							desc = L["Applies the primary texture to all statusbars."],
							func = function()
								local texture = E.private.general.normTex
								E.db.unitframe.statusbar = texture
								E.db.nameplates.statusbar = texture
								E:UpdateAll(true)
							end
						}
					}
				},
				colorsGroup = {
					order = 4,
					type = "group",
					name = L["COLORS"],
					guiInline = true,
					get = function(info)
						local t = E.db.general[info[#info]]
						local d = P.general[info[#info]]
						return t.r, t.g, t.b, t.a, d.r, d.g, d.b, d.a
					end,
					set = function(info, r, g, b, a)
						local setting = info[#info]
						local t = E.db.general[setting]
						t.r, t.g, t.b, t.a = r, g, b, a
						E:UpdateMedia()
						if setting == "bordercolor" then
							E:UpdateBorderColors()
						elseif setting == "backdropcolor" or setting == "backdropfadecolor" then
							E:UpdateBackdropColors()
						end
					end,
					args = {
						bordercolor = {
							order = 1,
							type = "color",
							name = L["Border Color"],
							desc = L["Main border color of the UI."],
							hasAlpha = false,
						},
						backdropcolor = {
							order = 2,
							type = "color",
							name = L["Backdrop Color"],
							desc = L["Main backdrop color of the UI."],
							hasAlpha = false,
						},
						backdropfadecolor = {
							order = 3,
							type = "color",
							name = L["Backdrop Faded Color"],
							desc = L["Backdrop color of transparent frames"],
							hasAlpha = true,
						},
						valuecolor = {
							order = 4,
							type = "color",
							name = L["Value Color"],
							desc = L["Color some texts use."],
							hasAlpha = false,
						},
						herocolor = {
							order = 5,
							type = "color",
							name = "My Class Color",
							desc = "Color of class colored elements.",
							hasAlpha = false,
						},
						cropIcon = {
							order = 6,
							type = "toggle",
							tristate = true,
							name = L["Crop Icons"],
							desc = L["This is for Customized Icons in your Interface/Icons folder."],
							get = function(info)
								local value = E.db.general[info[#info]]
								if value == 2 then return true
								elseif value == 1 then return nil
								else return false end
							end,
							set = function(info, value)
								E.db.general[info[#info]] = (value and 2) or (value == nil and 1) or 0
								E:StaticPopup_Show("PRIVATE_RL")
							end
						}
					}
				}
			}
		},
		totems = {
			order = 4,
			type = "group",
			name = L["Class Totems"],
			get = function(info) return E.db.general.totems[info[#info]] end,
			set = function(info, value) E.db.general.totems[info[#info]] = value Totems:PositionAndSize() end,
			hidden = function() return false end,
			args = {
				header = {
					order = 1,
					type = "header",
					name = TUTORIAL_TITLE47
				},
				enable = {
					order = 2,
					type = "toggle",
					name = L["Enable"],
					set = function(info, value) E.db.general.totems[info[#info]] = value Totems:ToggleEnable() end
				},
				size = {
					order = 3,
					type = "range",
					name = L["Button Size"],
					min = 24, max = 60, step = 1,
					disabled = function() return not E.db.general.totems.enable end
				},
				spacing = {
					order = 4,
					type = "range",
					name = L["Button Spacing"],
					min = 1, max = 10, step = 1,
					disabled = function() return not E.db.general.totems.enable end
				},
				sortDirection = {
					order = 5,
					type = "select",
					name = L["Sort Direction"],
					values = {
						["ASCENDING"] = L["Ascending"],
						["DESCENDING"] = L["Descending"]
					},
					disabled = function() return not E.db.general.totems.enable end
				},
				growthDirection = {
					order = 6,
					type = "select",
					name = L["Bar Direction"],
					values = {
						["VERTICAL"] = L["Vertical"],
						["HORIZONTAL"] = L["Horizontal"]
					},
					disabled = function() return not E.db.general.totems.enable end
				}
			}
		},
		chatBubblesGroup = {
			order = 5,
			type = "group",
			name = L["Chat Bubbles"],
			get = function(info) return E.private.general[info[#info]] end,
			set = function(info, value) E.private.general[info[#info]] = value E:StaticPopup_Show("PRIVATE_RL") end,
			args = {
				header = {
					order = 1,
					type = "header",
					name = L["Chat Bubbles"]
				},
				chatBubbles = {
					order = 2,
					type = "select",
					name = L["Chat Bubbles Style"],
					desc = L["Skin the blizzard chat bubbles."],
					values = {
						["backdrop"] = L["Skin Backdrop"],
						["nobackdrop"] = L["Remove Backdrop"],
						["backdrop_noborder"] = L["Skin Backdrop (No Borders)"],
						["disabled"] = L["DISABLE"]
					}
				},
				chatBubbleFont = {
					order = 3,
					type = "select",
					name = L["Font"],
					dialogControl = "LSM30_Font",
					values = AceGUIWidgetLSMlists.font,
					disabled = function() return E.private.general.chatBubbles == "disabled" end
				},
				chatBubbleFontSize = {
					order = 4,
					type = "range",
					name = L["FONT_SIZE"],
					min = 4, max = 32, step = 1,
					disabled = function() return E.private.general.chatBubbles == "disabled" end
				},
				chatBubbleFontOutline = {
					order = 5,
					type = "select",
					name = L["Font Outline"],
					disabled = function() return E.private.general.chatBubbles == "disabled" end,
					values = C.Values.FontFlags
				},
				chatBubbleName = {
					order = 6,
					type = "toggle",
					name = L["Chat Bubble Names"],
					desc = L["Display the name of the unit on the chat bubble."],
					disabled = function() return E.private.general.chatBubbles == "disabled" or E.private.general.chatBubbles == "nobackdrop" end
				}
			}
		},
		objectiveFrameGroup = {
			order = 6,
			type = "group",
			name = L["Objective Frame"],
			get = function(info) return E.db.general[info[#info]] end,
			args = {
				objectiveFrameHeader = {
					order = 1,
					type = "header",
					name = L["Objective Frame"],
				},
				watchFrameAutoHide = {
					order = 2,
					type = "toggle",
					name = L["Auto Hide"],
					desc = L["Automatically hide the objetive frame during boss or arena fights."],
					set = function(info, value) E.db.general.watchFrameAutoHide = value; Blizzard:SetObjectiveFrameAutoHide() end,
				},
				watchFrameHeight = {
					order = 3,
					type = "range",
					name = L["Objective Frame Height"],
					desc = L["Height of the objective tracker. Increase size to be able to see more objectives."],
					min = 400, max = E.screenheight, step = 1,
					set = function(info, value) E.db.general.watchFrameHeight = value; Blizzard:SetWatchFrameHeight() end,
				},
				watchFrameWidth = {
					order = 4,
					type = "range",
					name = L["Objective Frame Width"],
					desc = L["Width of the objective tracker. A wider tracker reduces text wrapping."],
					min = 160, max = 600, step = 1,
					set = function(info, value) E.db.general.watchFrameWidth = value; Blizzard:RefreshWatchFrameLayout() end,
				},
				watchFrameFont = {
					order = 5,
					type = "select", dialogControl = "LSM30_Font",
					name = L["Objective Tracker Font"],
					desc = L["Font used by the objective tracker."],
					values = AceGUIWidgetLSMlists.font,
					set = function(info, value) E.db.general.watchFrameFont = value; Blizzard:RefreshWatchFrameLayout() end,
				},
				watchFrameFontSize = {
					order = 6,
					type = "range",
					name = L["Objective Tracker Font Size"],
					min = 6, max = 32, step = 1,
					set = function(info, value) E.db.general.watchFrameFontSize = value; Blizzard:RefreshWatchFrameLayout() end,
				},
				watchFrameFontOutline = {
					order = 7,
					type = "select",
					name = L["Objective Tracker Font Outline"],
					values = C.Values.FontFlags,
					set = function(info, value) E.db.general.watchFrameFontOutline = value; Blizzard:RefreshWatchFrameLayout() end,
				},
				watchFrameAutoLineSpacing = {
					order = 8,
					type = "toggle",
					name = L["Automatic Tracker Line Spacing"],
					desc = L["Automatically increases the vertical spacing when a larger objective tracker font is used."],
					set = function(info, value) E.db.general.watchFrameAutoLineSpacing = value; Blizzard:RefreshWatchFrameLayout() end,
				},
				watchFrameLineSpacing = {
					order = 9,
					type = "range",
					name = L["Extra Tracker Line Spacing"],
					desc = L["Adds extra vertical space between wrapped objective tracker lines."],
					min = 0, max = 20, step = 1,
					disabled = function() return E.db.general.watchFrameAutoLineSpacing end,
					set = function(info, value) E.db.general.watchFrameLineSpacing = value; Blizzard:RefreshWatchFrameLayout() end,
				},
			},
		},
		threatGroup = {
			order = 7,
			type = "group",
			name = L["Threat"],
			get = function(info) return E.db.general.threat[info[#info]] end,
			args = {
				threatHeader = {
					order = 1,
					type = "header",
					name = L["Threat"]
				},
				enable = {
					order = 2,
					type = "toggle",
					name = L["Enable"],
					set = function(info, value)
						E.db.general.threat.enable = value
						Threat:ToggleEnable()
					end
				},
				preview = {
					order = 3,
					type = "toggle",
					name = "Preview",
					desc = "Show the threat bar with a sample value while configuring it.",
					get = function() return Threat.preview or false end,
					set = function(_, value) Threat:SetPreview(value) end,
					disabled = function() return not E.db.general.threat.enable end
				},
				detach = {
					order = 4,
					type = "toggle",
					name = "Detach",
					desc = "Detach the threat bar from the chat datatext panel and use its own mover.",
					set = function(info, value)
						E.db.general.threat.detach = value
						Threat:UpdatePosition()
					end,
					disabled = function() return not E.db.general.threat.enable end
				},
				position = {
					order = 5,
					type = "select",
					name = L["Position"],
					desc = L["Adjust the position of the threat bar to either the left or right datatext panels."],
					values = {
						["LEFTCHAT"] = L["Left Chat"],
						["RIGHTCHAT"] = L["Right Chat"]
					},
					set = function(info, value)
						E.db.general.threat.position = value
						Threat:UpdatePosition()
					end,
					disabled = function()
						return not E.db.general.threat.enable or E.db.general.threat.detach
					end
				},
				width = {
					order = 6,
					type = "range",
					name = "Width",
					min = 100, max = 1000, step = 1,
					set = function(info, value)
						E.db.general.threat.width = value
						Threat:UpdatePosition()
					end,
					disabled = function()
						return not E.db.general.threat.enable or not E.db.general.threat.detach
					end
				},
				height = {
					order = 7,
					type = "range",
					name = "Height",
					min = 8, max = 100, step = 1,
					set = function(info, value)
						E.db.general.threat.height = value
						Threat:UpdatePosition()
					end,
					disabled = function()
						return not E.db.general.threat.enable or not E.db.general.threat.detach
					end
				},
				appearanceHeader = {
					order = 10,
					type = "header",
					name = "Appearance"
				},
				texture = {
					order = 11,
					type = "select",
					dialogControl = "LSM30_Statusbar",
					name = "Statusbar Texture",
					values = AceGUIWidgetLSMlists.statusbar,
					set = function(info, value)
						E.db.general.threat.texture = value
						Threat:UpdateAppearance()
					end,
					disabled = function() return not E.db.general.threat.enable end
				},
				font = {
					order = 12,
					type = "select",
					dialogControl = "LSM30_Font",
					name = L["Font"],
					values = AceGUIWidgetLSMlists.font,
					set = function(info, value)
						E.db.general.threat.font = value
						Threat:UpdateAppearance()
					end,
					disabled = function() return not E.db.general.threat.enable end
				},
				textColor = {
					order = 13,
					type = "color",
					name = "Font Color",
					get = function()
						local c = E.db.general.threat.textColor
						return c.r, c.g, c.b
					end,
					set = function(_, r, g, b)
						local c = E.db.general.threat.textColor
						c.r, c.g, c.b = r, g, b
						Threat:UpdateAppearance()
					end,
					disabled = function() return not E.db.general.threat.enable end
				},
				textSize = {
					order = 14,
					type = "range",
					name = L["FONT_SIZE"],
					min = 6, max = 22, step = 1,
					set = function(info, value)
						E.db.general.threat.textSize = value
						Threat:UpdateAppearance()
					end,
					disabled = function() return not E.db.general.threat.enable end
				},
				textOutline = {
					order = 15,
					type = "select",
					name = L["Font Outline"],
					values = C.Values.FontFlags,
					set = function(info, value)
						E.db.general.threat.textOutline = value
						Threat:UpdateAppearance()
					end,
					disabled = function() return not E.db.general.threat.enable end
				},
				textX = {
					order = 16,
					type = "range",
					name = "Text X Offset",
					min = -200, max = 200, step = 1,
					set = function(info, value)
						E.db.general.threat.textX = value
						Threat:UpdateAppearance()
					end,
					disabled = function() return not E.db.general.threat.enable end
				},
				textY = {
					order = 17,
					type = "range",
					name = "Text Y Offset",
					min = -100, max = 100, step = 1,
					set = function(info, value)
						E.db.general.threat.textY = value
						Threat:UpdateAppearance()
					end,
					disabled = function() return not E.db.general.threat.enable end
				},
				colorsHeader = {
					order = 30,
					type = "header",
					name = "Threat Colors"
				},
				customColors = {
					order = 31,
					type = "toggle",
					name = "Custom Colors",
					desc = "Use the colors below instead of Blizzard's automatic threat colors.",
					set = function(info, value)
						E.db.general.threat.customColors = value
						if Threat.preview then Threat:ShowPreview() else Threat:Update() end
					end,
					disabled = function() return not E.db.general.threat.enable end
				},
				gradient = {
					order = 32,
					type = "toggle",
					name = "Gradient",
					desc = "Blend each Base Color into its Gradient Color.",
					set = function(info, value)
						E.db.general.threat.gradient = value
						if Threat.preview then Threat:ShowPreview() else Threat:Update() end
					end,
					disabled = function()
						return not E.db.general.threat.enable or not E.db.general.threat.customColors
					end
				}
			}
		},
		blizzUIImprovements = {
			order = 8,
			type = "group",
			name = L["BlizzUI Improvements"],
			get = function(info) return E.db.general[info[#info]] end,
			set = function(info, value) E.db.general[info[#info]] = value end,
			args = {
				header = {
					order = 1,
					type = "header",
					name = L["BlizzUI Improvements"]
				},
				interruptAnnounce = {
					order = 2,
					type = "select",
					name = L["Announce Interrupts"],
					desc = L["Announce when you interrupt a spell to the specified chat channel."],
					values = {
						["NONE"] = L["NONE"],
						["SAY"] = L["SAY"],
						["PARTY"] = L["Party Only"],
						["RAID"] = L["Party / Raid"],
						["RAID_ONLY"] = L["Raid Only"],
						["EMOTE"] = L["EMOTE"]
					},
					set = function(info, value)
						E.db.general[info[#info]] = value
						Misc:ToggleInterruptAnnounce()
					end
				},
				autoAcceptInvite = {
					order = 3,
					type = "toggle",
					name = L["Accept Invites"],
					desc = L["Automatically accept invites from guild/friends."]
				},
				hideErrorFrame = {
					order = 4,
					type = "toggle",
					name = L["Hide Error Text"],
					desc = L["Hides the red error text at the top of the screen while in combat."],
					set = function(info, value)
						E.db.general[info[#info]] = value
						Misc:ToggleErrorHandling()
					end
				},
				enhancedPvpMessages = {
					order = 5,
					type = "toggle",
					name = L["Enhanced PVP Messages"],
					desc = L["Display battleground messages in the middle of the screen."],
				},
				raidUtility = {
					order = 7,
					type = "toggle",
					name = L["RAID_CONTROL"],
					desc = L["Enables the ElvUI Raid Control panel."],
					get = function(info) return E.private.general[info[#info]] end,
					set = function(info, value)
						E.private.general[info[#info]] = value
						E:StaticPopup_Show("PRIVATE_RL")
					end
				},
				vehicleSeatIndicatorSize = {
					order = 8,
					type = "range",
					name = L["Vehicle Seat Indicator Size"],
					min = 64, max = 128, step = 4,
					set = function(info, value)
						E.db.general[info[#info]] = value
						Blizzard:UpdateVehicleFrame()
					end
				},
				windowMoverHeader = {
					order = 20,
					type = "header",
					name = "Movable Blizzard Windows",
				},
				windowMoverDescription = {
					order = 21,
					type = "description",
					name = "Move Blizzard windows by dragging the top area of the window. Positions are stored in the current ElvUI profile.",
				},
				blizzardWindowMoverEnabled = {
					order = 22,
					type = "toggle",
					name = "Enable Movable Blizzard Windows",
					get = function() return E.db.general.blizzardWindowMover and E.db.general.blizzardWindowMover.enabled end,
					set = function(_, value)
						E.db.general.blizzardWindowMover.enabled = value
						Blizzard:UpdateMovableBlizzardWindows()
					end,
				},
				resetBlizzardWindowPositions = {
					order = 23,
					type = "execute",
					name = "Reset All Window Positions",
					desc = "Reset every saved Blizzard window position for the current ElvUI profile.",
					func = function() Blizzard:ResetAllBlizzardWindowPositions() end,
					disabled = function() return not E.db.general.blizzardWindowMover or not E.db.general.blizzardWindowMover.enabled end,
				},
			}
		},
		timerBars = {
			order = 8.6,
			type = "group",
			name = "Timer Bars",
			args = (function()
				local args = {
					preview = {
						order = 1,
						type = "toggle",
						name = "Preview",
						desc = "Temporarily shows a Fatigue, a Breath and a Feign Death bar with sample values so you can set up size, text, colors and position. Not saved.",
						get = function() return Blizzard.mirrorTimerPreview or false end,
						set = function(_, value) Blizzard:ToggleMirrorTimerPreview(value) end
					},
				}
				local KEYS = {"color", "gradient", "color2", "width", "height", "textX", "textY", "font", "fontSize", "fontOutline"}

				local function Update() Blizzard:UpdateMirrorTimers() end

				local function AddBar(key, title, base)
					local function db() return E.db.general.mirrorTimers[key] end
					args[key.."Header"] = {order = base, type = "header", name = title}
					args[key.."Width"] = {
						order = base + 1, type = "range", name = L["Width"], min = 50, max = 600, step = 1,
						get = function() return db().width end,
						set = function(_, v) db().width = v; Update() end
					}
					args[key.."Height"] = {
						order = base + 2, type = "range", name = L["Height"], min = 4, max = 60, step = 1,
						get = function() return db().height end,
						set = function(_, v) db().height = v; Update() end
					}
					args[key.."Color"] = {
						order = base + 3, type = "color", name = "Color",
						desc = "Bar color. With Gradient enabled this is the start (left) color.",
						get = function() local c = db().color return c.r, c.g, c.b end,
						set = function(_, r, g, b) local c = db().color c.r, c.g, c.b = r, g, b Update() end
					}
					args[key.."Gradient"] = {
						order = base + 4, type = "toggle", name = "Gradient",
						desc = "Blend the bar from the Color into the Gradient Color.",
						get = function() return db().gradient end,
						set = function(_, v) db().gradient = v; Update() end
					}
					args[key.."Color2"] = {
						order = base + 5, type = "color", name = "Gradient Color",
						desc = "End (right) color of the gradient.",
						get = function() local c = db().color2 return c.r, c.g, c.b end,
						set = function(_, r, g, b) local c = db().color2 c.r, c.g, c.b = r, g, b Update() end,
						disabled = function() return not db().gradient end
					}
					args[key.."TextX"] = {
						order = base + 6, type = "range", name = "Text X", min = -200, max = 200, step = 1,
						get = function() return db().textX end,
						set = function(_, v) db().textX = v; Update() end
					}
					args[key.."TextY"] = {
						order = base + 7, type = "range", name = "Text Y", min = -50, max = 50, step = 1,
						get = function() return db().textY end,
						set = function(_, v) db().textY = v; Update() end
					}
					args[key.."Font"] = {
						order = base + 8, type = "select", dialogControl = "LSM30_Font", name = L["Font"],
						values = AceGUIWidgetLSMlists.font,
						get = function() return db().font end,
						set = function(_, v) db().font = v; Update() end
					}
					args[key.."FontSize"] = {
						order = base + 9, type = "range", name = L["FONT_SIZE"], min = 6, max = 32, step = 1,
						get = function() return db().fontSize end,
						set = function(_, v) db().fontSize = v; Update() end
					}
					args[key.."FontOutline"] = {
						order = base + 10, type = "select", name = L["Font Outline"], values = C.Values.FontFlags,
						get = function() return db().fontOutline end,
						set = function(_, v) db().fontOutline = v; Update() end
					}
				end

				AddBar("fatigue", "Fatigue", 10)
				AddBar("breath", "Breath", 30)
				AddBar("feigndeath", "Feign Death", 50)

				args.resetSettings = {
					order = 100, type = "execute", name = "Reset Settings",
					desc = "Resets size, text, font, colors and gradient of all bars.",
					func = function()
						local db = E.db.general.mirrorTimers
						local d = P.general.mirrorTimers
						for _, key in ipairs({"fatigue", "breath", "feigndeath"}) do
							for _, k in ipairs(KEYS) do
								if type(d[key][k]) == "table" then
									db[key][k].r, db[key][k].g, db[key][k].b = d[key][k].r, d[key][k].g, d[key][k].b
								else
									db[key][k] = d[key][k]
								end
							end
						end
						Update()
					end
				}
				return args
			end)()
		},
		durability = {
			order = 8.5,
			type = "group",
			name = "Durability",
			get = function(info) return E.db.general.durability[info[#info]] end,
			set = function(info, value)
				E.db.general.durability[info[#info]] = value
				Blizzard:UpdateDurabilityFrame()
			end,
			args = {
				header = {
					order = 1,
					type = "header",
					name = "Durability"
				},
				enable = {
					order = 3,
					type = "toggle",
					name = L["Enable"],
					desc = "Completely enables or disables the durability figure. When disabled it is never shown."
				},
				detach = {
					order = 4,
					type = "toggle",
					name = "Pop Out",
					desc = "Detach the figure from the minimap. A mover is created so you can place it anywhere (use /ec or the Toggle Anchors button).",
					disabled = function() return not E.db.general.durability.enable end
				},
				scale = {
					order = 5,
					type = "range",
					name = "Scale",
					desc = "Size of the durability figure.",
					min = 0.3, max = 2, step = 0.05, isPercent = true,
					disabled = function() return not E.db.general.durability.enable end
				},
				alpha = {
					order = 5.5,
					type = "range",
					name = "Alpha",
					desc = "Transparency of the durability figure.",
					min = 0.1, max = 1, step = 0.05, isPercent = true,
					disabled = function() return not E.db.general.durability.enable end
				},
				preview = {
					order = 6,
					type = "toggle",
					name = "Preview",
					desc = "Temporarily shows the figure with damaged parts so you can position and resize it. Not saved.",
					get = function() return Blizzard.durabilityPreview end,
					set = function(_, value) Blizzard:ToggleDurabilityPreview(value) end,
					disabled = function() return not E.db.general.durability.enable end
				},
				resetPosition = {
					order = 7,
					type = "execute",
					name = L["Reset Position"],
					desc = "Resets the position of the popped-out figure.",
					func = function() E:ResetMovers("Durability Frame") end,
					disabled = function() return not E.db.general.durability.enable or not E.db.general.durability.detach end
				}
			}
		},
		misc = {
			order = 9,
			type = "group",
			name = L["LOOT"],
			args = {
				header = {
					order = 1,
					type = "header",
					name = L["LOOT"]
				},
				loot = {
					order = 2,
					type = "toggle",
					name = L["LOOT"],
					desc = L["Enable/Disable the loot frame."],
					get = function() return E.private.general.loot end,
					set = function(_, value)
						E.private.general.loot = value
						E:StaticPopup_Show("PRIVATE_RL")
					end
				},
				lootRoll = {
					order = 3,
					type = "toggle",
					name = L["Loot Roll"],
					desc = L["Enable/Disable the loot roll frame."],
					get = function() return E.private.general.lootRoll end,
					set = function(_, value)
						E.private.general.lootRoll = value
						E:StaticPopup_Show("PRIVATE_RL")
					end
				},
				autoRoll = {
					order = 4,
					type = "toggle",
					name = L["Auto Greed/DE"],
					desc = L["Automatically select greed or disenchant (when available) on green quality items. This will only work if you are the max level."],
					get = function() return E.db.general.autoRoll end,
					set = function(_, value) E.db.general.autoRoll = value end,
					disabled = function() return not E.private.general.lootRoll end
				},
				preview = {
					order = 5,
					type = "toggle",
					name = "Preview",
					desc = "Show sample Loot Roll frames while configuring their appearance.",
					get = function() return Misc.lootRollPreviewEnabled or false end,
					set = function(_, value) Misc:SetLootRollPreview(value) end
				},
				appearanceHeader = {
					order = 10,
					type = "header",
					name = "Appearance"
				},
				font = {
					order = 11,
					type = "select",
					dialogControl = "LSM30_Font",
					name = L["Font"],
					values = AceGUIWidgetLSMlists.font,
					get = function() return E.db.general.lootStyle.font end,
					set = function(_, value)
						E.db.general.lootStyle.font = value
						Misc:UpdateLootAppearance()
					end
				},
				fontSize = {
					order = 12,
					type = "range",
					name = L["FONT_SIZE"],
					min = 6, max = 32, step = 1,
					get = function() return E.db.general.lootStyle.fontSize end,
					set = function(_, value)
						E.db.general.lootStyle.fontSize = value
						Misc:UpdateLootAppearance()
					end
				},
				fontOutline = {
					order = 13,
					type = "select",
					name = L["Font Outline"],
					values = C.Values.FontFlags,
					get = function() return E.db.general.lootStyle.fontOutline end,
					set = function(_, value)
						E.db.general.lootStyle.fontOutline = value
						Misc:UpdateLootAppearance()
					end
				},
				frameWidth = {
					order = 14,
					type = "range",
					name = "Frame Width",
					min = 220, max = 450, step = 1,
					get = function() return E.db.general.lootStyle.width or 328 end,
					set = function(_, value)
						E.db.general.lootStyle.width = value
						Misc:UpdateLootAppearance()
					end
				},
				foregroundTexture = {
					order = 15,
					type = "select",
					dialogControl = "LSM30_Statusbar",
					name = "Foreground Texture",
					values = AceGUIWidgetLSMlists.statusbar,
					get = function() return E.db.general.lootStyle.foregroundTexture end,
					set = function(_, value)
						E.db.general.lootStyle.foregroundTexture = value
						Misc:UpdateLootAppearance()
					end
				},
				backgroundTexture = {
					order = 16,
					type = "select",
					dialogControl = "LSM30_Statusbar",
					name = "Background Texture",
					values = AceGUIWidgetLSMlists.statusbar,
					get = function() return E.db.general.lootStyle.backgroundTexture end,
					set = function(_, value)
						E.db.general.lootStyle.backgroundTexture = value
						Misc:UpdateLootAppearance()
					end
				},
				backgroundAlpha = {
					order = 17,
					type = "range",
					name = "Background Alpha",
					min = 0, max = 1, step = 0.01,
					get = function() return E.db.general.lootStyle.backgroundAlpha end,
					set = function(_, value)
						E.db.general.lootStyle.backgroundAlpha = value
						Misc:UpdateLootAppearance()
					end
				},
				colorsHeader = {
					order = 20,
					type = "header",
					name = "Loot Quality Colors"
				},
				customColors = {
					order = 21,
					type = "toggle",
					name = "Custom Colors",
					get = function() return E.db.general.lootStyle.customColors end,
					set = function(_, value)
						E.db.general.lootStyle.customColors = value
						Misc:UpdateLootAppearance()
					end
				},
				gradient = {
					order = 22,
					type = "toggle",
					name = "Gradient",
					get = function() return E.db.general.lootStyle.gradient end,
					set = function(_, value)
						E.db.general.lootStyle.gradient = value
						Misc:UpdateLootAppearance()
					end,
					disabled = function() return not E.db.general.lootStyle.customColors end
				}
			}
		}
	}
}

-- Threat color rows: Name | Base Color -> Gradient Color | Default
do
	local args = E.Options.args.general.args.threatGroup.args

	local function RefreshThreatColors()
		if Threat.preview then
			Threat:ShowPreview()
		else
			Threat:Update()
		end
	end

	local function DefaultGradient(r, g, b)
		return r + ((1-r) * 0.18), g + ((1-g) * 0.18), b + ((1-b) * 0.18)
	end

	local function EnsureThreatColor(rootName, key)
		local db = E.db.general.threat
		db[rootName] = db[rootName] or {}

		local color = db[rootName][key]
		if not color then
			local defaults = P.general.threat[rootName] and P.general.threat[rootName][key]
			if defaults then
				color = {r = defaults.r, g = defaults.g, b = defaults.b}
			elseif rootName == "gradientColors" then
				local base = db.colors[key] or P.general.threat.colors[key]
				local r, g, b = DefaultGradient(base.r, base.g, base.b)
				color = {r = r, g = g, b = b}
			else
				color = {r = 1, g = 1, b = 1}
			end
			db[rootName][key] = color
		end

		return color
	end

	local function AddThreatColorRow(id, label, order)
		args[id.."Label"] = {
			order = order,
			type = "description",
			name = label,
			width = 0.72,
			fontSize = "medium"
		}

		args[id.."Base"] = {
			order = order + 0.1,
			type = "color",
			name = "Base Color",
			width = 0.78,
			disabled = function()
				return not E.db.general.threat.enable or not E.db.general.threat.customColors
			end,
			get = function()
				local c = EnsureThreatColor("colors", id)
				return c.r, c.g, c.b
			end,
			set = function(_, r, g, b)
				local c = EnsureThreatColor("colors", id)
				c.r, c.g, c.b = r, g, b
				RefreshThreatColors()
			end
		}

		args[id.."Gradient"] = {
			order = order + 0.3,
			type = "color",
			name = "Gradient Color",
			width = 0.82,
			disabled = function()
				local db = E.db.general.threat
				return not db.enable or not db.customColors or not db.gradient
			end,
			get = function()
				local c = EnsureThreatColor("gradientColors", id)
				return c.r, c.g, c.b
			end,
			set = function(_, r, g, b)
				local c = EnsureThreatColor("gradientColors", id)
				c.r, c.g, c.b = r, g, b
				RefreshThreatColors()
			end
		}

		args[id.."Default"] = {
			order = order + 0.4,
			type = "execute",
			name = "Default",
			width = 0.58,
			disabled = function()
				return not E.db.general.threat.enable or not E.db.general.threat.customColors
			end,
			func = function()
				local base = P.general.threat.colors[id]
				local grad = P.general.threat.gradientColors[id]

				E.db.general.threat.colors[id] = {r = base.r, g = base.g, b = base.b}
				E.db.general.threat.gradientColors[id] = {r = grad.r, g = grad.g, b = grad.b}
				RefreshThreatColors()
			end
		}

		args[id.."Break"] = {
			order = order + 0.9,
			type = "description",
			name = "",
			width = "full"
		}
	end

	args.colorRowsBreak = {
		order = 39,
		type = "description",
		name = "",
		width = "full"
	}

	AddThreatColorRow("low", "Low Threat", 40)
	AddThreatColorRow("medium", "Medium Threat", 50)
	AddThreatColorRow("high", "High Threat", 60)
	AddThreatColorRow("tanking", "Tanking", 70)
	AddThreatColorRow("preview", "Preview", 80)
end

-- Loot quality color rows: Name | Base Color | Gradient Color | Default
do
	local lootArgs = E.Options.args.general.args.misc.args

	local qualityRows = {
		{0, "Poor"},
		{1, "Common"},
		{2, "Uncommon"},
		{3, "Rare"},
		{4, "Epic"},
		{5, "Legendary"},
		{6, "Artifact"},
		{7, "Heirloom"},
	}

	local function EnsureLootColor(rootName, quality)
		local db = E.db.general.lootStyle
		db[rootName] = db[rootName] or {}
		local c = db[rootName][quality]
		if not c then
			local defaults = P.general.lootStyle[rootName][quality]
			c = {r = defaults.r, g = defaults.g, b = defaults.b}
			db[rootName][quality] = c
		end
		return c
	end

	local function RefreshLoot()
		Misc:UpdateLootAppearance()
	end

	lootArgs.colorRowsBreak = {
		order = 29,
		type = "description",
		name = "",
		width = "full"
	}

	for index, row in ipairs(qualityRows) do
		local quality, label = row[1], row[2]
		local prefix = "quality"..quality
		local order = 30 + ((index - 1) * 10)

		lootArgs[prefix.."Label"] = {
			order = order,
			type = "description",
			name = label,
			width = 0.72,
			fontSize = "medium"
		}

		lootArgs[prefix.."Base"] = {
			order = order + 0.1,
			type = "color",
			name = "Base Color",
			width = 0.78,
			disabled = function() return not E.db.general.lootStyle.customColors end,
			get = function()
				local c = EnsureLootColor("colors", quality)
				return c.r, c.g, c.b
			end,
			set = function(_, r, g, b)
				local c = EnsureLootColor("colors", quality)
				c.r, c.g, c.b = r, g, b
				RefreshLoot()
			end
		}

		lootArgs[prefix.."Gradient"] = {
			order = order + 0.2,
			type = "color",
			name = "Gradient Color",
			width = 0.82,
			disabled = function()
				local db = E.db.general.lootStyle
				return not db.customColors or not db.gradient
			end,
			get = function()
				local c = EnsureLootColor("gradientColors", quality)
				return c.r, c.g, c.b
			end,
			set = function(_, r, g, b)
				local c = EnsureLootColor("gradientColors", quality)
				c.r, c.g, c.b = r, g, b
				RefreshLoot()
			end
		}

		lootArgs[prefix.."Default"] = {
			order = order + 0.3,
			type = "execute",
			name = "Default",
			width = 0.58,
			func = function()
				local base = P.general.lootStyle.colors[quality]
				local grad = P.general.lootStyle.gradientColors[quality]
				E.db.general.lootStyle.colors[quality] = {r = base.r, g = base.g, b = base.b}
				E.db.general.lootStyle.gradientColors[quality] = {r = grad.r, g = grad.g, b = grad.b}
				RefreshLoot()
			end
		}

		lootArgs[prefix.."Break"] = {
			order = order + 0.9,
			type = "description",
			name = "",
			width = "full"
		}
	end
end

--------------------------------------------------------------------------
-- SingleButton Creator
--------------------------------------------------------------------------
do
	local SB = E.SingleButton
	local QUESTION = [[Interface\Icons\INV_Misc_QuestionMark]]

	local function IconValues()
		local values = {[SB.DEFAULT_ICON] = E:TextureString(QUESTION, ":32:32").."  ?"}
		if E.MacroIcons and E.MacroIcons.icons then
			for i, icon in ipairs(E.MacroIcons.icons) do
				values[icon.key] = E:TextureString(icon.path, ":32:32").."  "..i
			end
		end
		return values
	end

	E.Options.args.general.args.singleButton = {
		order = 20,
		type = "group",
		name = "SingleButton Creator",
		args = {
			header = {
				order = 1,
				type = "header",
				name = "SingleButton Creator"
			},
			icon = {
				order = 2,
				type = "multiselect",
				name = "Macro Icon",
				desc = "Pick the icon for the macro. The first entry is the default ? icon.",
				values = IconValues,
				get = function(_, key) return (E.db.general.singleButtonIcon or SB.DEFAULT_ICON) == key end,
				set = function(_, key) E.db.general.singleButtonIcon = key end
			},
			create = {
				order = 3,
				type = "execute",
				name = "Create Macro",
				desc = "Creates the general macro \"SingleButton\" with: "..SB.MACRO_BODY.."\nIf it already exists, its icon is updated.",
				func = function() SB:CreateMacro(E.db.general.singleButtonIcon) end
			},
			filter = {
				order = 4,
				type = "toggle",
				name = "Filter SingleButton Text",
				desc = "Removes chat spam from the text when spamming the button.",
				width = "full",
				get = function() return E.db.general.singleButtonFilter end,
				set = function(_, value) E.db.general.singleButtonFilter = value end
			},
			filterInfo = {
				order = 5,
				type = "description",
				fontSize = "medium",
				name = "When enabled, the message \""..SB.FILTER_TEXT.."\" is hidden. "..
					"The server sends it every time you press the SingleButton macro without a living enemy to attack "..
					"or a friendly target to heal, which floods the chat while you spam the button. "..
					"With this option on, the text no longer shows up in the chat window or as a red on-screen error. "..
					"All other chat messages are not affected."
			}
		}
	}
end

