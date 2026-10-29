local E, _, V, P, G = unpack(ElvUI); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local C, L = unpack(select(2, ...))
local mod = E:GetModule("DataBars")

E.Options.args.databars = {
	type = "group",
	name = L["DataBars"],
	childGroups = "tab",
	get = function(info) return E.db.databars[info[#info]] end,
	set = function(info, value) E.db.databars[info[#info]] = value end,
	args = {
		intro = {
			order = 1,
			type = "description",
			name = L["DATABAR_DESC"]
		},
		spacer = {
			order = 2,
			type = "description",
			name = ""
		},
		experience = {
			order = 3,
			type = "group",
			name = L["XPBAR_LABEL"],
			get = function(info) return mod.db.experience[info[#info]] end,
			set = function(info, value) mod.db.experience[info[#info]] = value mod:ExperienceBar_UpdateDimensions() end,
			args = {
				header = {
					order = 1,
					type = "header",
					name = L["XPBAR_LABEL"]
				},
				enable = {
					order = 2,
					type = "toggle",
					name = L["Enable"],
					set = function(info, value) mod.db.experience[info[#info]] = value mod:ExperienceBar_Toggle() end
				},
				customRates = {
					order = 2.5,
					type = "toggle",
					name = "Custom XP Rates",
					desc = "Right-click the XP bar to open a menu for setting the XP rate (.xp 1-5, .xp default, .xp).",
					set = function(info, value) mod.db.experience[info[#info]] = value end
				},
				mouseover = {
					order = 3,
					type = "toggle",
					name = L["Mouseover"]
				},
				hideAtMaxLevel = {
					order = 4,
					type = "toggle",
					name = L["Hide At Max Level"],
					set = function(info, value) mod.db.experience[info[#info]] = value mod:ExperienceBar_Update() end
				},
				hideInVehicle = {
					order = 5,
					type = "toggle",
					name = L["Hide In Vehicle"],
					set = function(info, value) mod.db.experience[info[#info]] = value mod:ExperienceBar_Update() end
				},
				hideInCombat = {
					order = 6,
					type = "toggle",
					name = L["Hide In Combat"],
					set = function(info, value) mod.db.experience[info[#info]] = value mod:ExperienceBar_Update() end
				},
				showBubbles = {
					order = 6,
					type = "toggle",
					name = L["Show Bubbles"]
				},
				spacer = {
					order = 7,
					type = "description",
					name = " "
				},
				orientation = {
					order = 8,
					type = "select",
					name = L["Statusbar Fill Orientation"],
					desc = L["Direction the bar moves on gains/losses"],
					values = {
						["HORIZONTAL"] = L["Horizontal"],
						["VERTICAL"] = L["Vertical"]
					}
				},
				width = {
					order = 9,
					type = "range",
					name = L["Width"],
					min = 5, max = ceil(GetScreenWidth() or 800), step = 1
				},
				height = {
					order = 10,
					type = "range",
					name = L["Height"],
					min = 5, max = ceil(GetScreenHeight() or 800), step = 1
				},
				font = {
					order = 11,
					type = "select", dialogControl = "LSM30_Font",
					name = L["Font"],
					values = AceGUIWidgetLSMlists.font
				},
				textSize = {
					order = 12,
					type = "range",
					name = L["FONT_SIZE"],
					min = 6, max = 22, step = 1
				},
				fontOutline = {
					order = 13,
					type = "select",
					name = L["Font Outline"],
					values = C.Values.FontFlags
				},
				textFormat = {
					order = 14,
					type = "select",
					name = L["Text Format"],
					width = "double",
					values = {
						NONE = L["NONE"],
						CUR = L["Current"],
						REM = L["Remaining"],
						PERCENT = L["Percent"],
						CURMAX = L["Current - Max"],
						CURPERC = L["Current - Percent"],
						CURREM = L["Current - Remaining"],
						CURPERCREM = L["Current - Percent (Remaining)"],
					},
					set = function(info, value) mod.db.experience[info[#info]] = value mod:ExperienceBar_Update() end
				},
				appearance = {
					order = 15,
					type = "group",
					name = "Bar Appearance",
					guiInline = true,
					get = function(info) return mod.db.experience[info[#info]] end,
					set = function(info, value)
						mod.db.experience[info[#info]] = value
						mod:ExperienceBar_UpdateDimensions()
						mod:ExperienceBar_Update()
					end,
					args = {
						customTexture = {
							order = 1, type = "toggle", name = "Custom Texture",
							desc = "Use a separate texture for this data bar instead of the global ElvUI statusbar texture."
						},
						texture = {
							order = 2, type = "select", dialogControl = "LSM30_Statusbar", name = "Texture",
							values = AceGUIWidgetLSMlists.statusbar,
							disabled = function() return not mod.db.experience.customTexture end
						},
						customColor = {
							order = 3, type = "toggle", name = "Custom Base Color",
							desc = "Override the normal XP bar color with your own base color."
						},
						baseColor = {
							order = 4, type = "color", name = "Base Color", hasAlpha = true,
							disabled = function() return not mod.db.experience.customColor end,
							get = function()
								local c = mod.db.experience.baseColor
								return c.r, c.g, c.b, c.a
							end,
							set = function(_, r, g, b, a)
								local c = mod.db.experience.baseColor
								c.r, c.g, c.b, c.a = r, g, b, a
								mod:ExperienceBar_UpdateDimensions()
							end
						},
						gradient = {
							order = 5, type = "toggle", name = "Gradient",
							desc = "Blend from the base color to the gradient color."
						},
						gradientColor = {
							order = 6, type = "color", name = "Gradient Color", hasAlpha = true,
							disabled = function() return not mod.db.experience.gradient end,
							get = function()
								local c = mod.db.experience.gradientColor
								return c.r, c.g, c.b, c.a
							end,
							set = function(_, r, g, b, a)
								local c = mod.db.experience.gradientColor
								c.r, c.g, c.b, c.a = r, g, b, a
								mod:ExperienceBar_UpdateDimensions()
							end
						}
					}
				},
				questXP = {
					order = 16,
					type = "group",
					name = L["Quest XP"],
					guiInline = true,
					get = function(info) return mod.db.experience.questXP[info[#info]] end,
					disabled = function() return not mod.db.experience.enable or not mod.db.experience.questXP.enable end,
					args = {
						enable = {
							order = 1,
							type = "toggle",
							name = L["Enable"],
							set = function(info, value)
								mod.db.experience.questXP.enable = value
								mod:ExperienceBar_QuestXPToggle()
							end,
							disabled = function() return not mod.db.experience.enable end
						},
						color = {
							order = 2,
							type = "color",
							name = L["Quest XP Color"],
							hasAlpha = true,
							get = function(info)
								local t = mod.db.experience.questXP.color
								return t.r, t.g, t.b, t.a, 0, 1, 0, 0.4
							end,
							set = function(info, r, g, b, a)
								local t = mod.db.experience.questXP.color
								t.r, t.g, t.b, t.a = r, g, b, a
								mod:ExperienceBar_UpdateDimensions()
							end
						},
						questCurrentZoneOnly = {
							order = 3,
							type = "toggle",
							name = L["Quests in Current Zone Only"],
							set = function(info, value)
								mod.db.experience.questXP.questCurrentZoneOnly = value
								mod:ExperienceBar_QuestXPUpdate()
							end
						},
						questCompletedOnly = {
							order = 4,
							type = "toggle",
							name = L["Completed Quests Only"],
							set = function(info, value)
								mod.db.experience.questXP.questCompletedOnly = value
								mod:ExperienceBar_QuestXPUpdate()
							end
						},
						tooltip = {
							order = 5,
							type = "toggle",
							name = L["Add Quest XP to Tooltip"],
							set = function(info, value) mod.db.experience.questXP.tooltip = value end
						}
					}
				}
			}
		},
		reputation = {
			order = 4,
			type = "group",
			name = L["REPUTATION"],
			get = function(info) return mod.db.reputation[info[#info]] end,
			set = function(info, value) mod.db.reputation[info[#info]] = value mod:ReputationBar_UpdateDimensions() end,
			args = {
				header = {
					order = 1,
					type = "header",
					name = L["REPUTATION"]
				},
				enable = {
					order = 2,
					type = "toggle",
					name = L["Enable"],
					set = function(info, value) mod.db.reputation[info[#info]] = value mod:ReputationBar_Toggle() end
				},
				mouseover = {
					order = 3,
					type = "toggle",
					name = L["Mouseover"]
				},
				hideInVehicle = {
					order = 4,
					type = "toggle",
					name = L["Hide In Vehicle"],
					set = function(info, value) mod.db.reputation[info[#info]] = value mod:ReputationBar_Update() end
				},
				hideInCombat = {
					order = 5,
					type = "toggle",
					name = L["Hide In Combat"],
					set = function(info, value) mod.db.reputation[info[#info]] = value mod:ReputationBar_Update() end
				},
				showBubbles = {
					order = 6,
					type = "toggle",
					name = L["Show Bubbles"]
				},
				spacer = {
					order = 7,
					type = "description",
					name = " "
				},
				orientation = {
					order = 8,
					type = "select",
					name = L["Statusbar Fill Orientation"],
					desc = L["Direction the bar moves on gains/losses"],
					values = {
						["HORIZONTAL"] = L["Horizontal"],
						["VERTICAL"] = L["Vertical"]
					}
				},
				width = {
					order = 9,
					type = "range",
					name = L["Width"],
					min = 5, max = ceil(GetScreenWidth() or 800), step = 1
				},
				height = {
					order = 10,
					type = "range",
					name = L["Height"],
					min = 5, max = ceil(GetScreenHeight() or 800), step = 1
				},
				font = {
					order = 11,
					type = "select", dialogControl = "LSM30_Font",
					name = L["Font"],
					values = AceGUIWidgetLSMlists.font
				},
				textSize = {
					order = 12,
					type = "range",
					name = L["FONT_SIZE"],
					min = 6, max = 22, step = 1
				},
				fontOutline = {
					order = 13,
					type = "select",
					name = L["Font Outline"],
					values = C.Values.FontFlags
				},
				textFormat = {
					order = 14,
					type = "select",
					name = L["Text Format"],
					width = "double",
					values = {
						NONE = L["NONE"],
						CUR = L["Current"],
						REM = L["Remaining"],
						PERCENT = L["Percent"],
						CURMAX = L["Current - Max"],
						CURPERC = L["Current - Percent"],
						CURREM = L["Current - Remaining"],
						CURPERCREM = L["Current - Percent (Remaining)"],
					},
					set = function(info, value) mod.db.reputation[info[#info]] = value mod:ReputationBar_Update() end
				},
				appearance = {
					order = 15,
					type = "group",
					name = "Bar Appearance",
					guiInline = true,
					get = function(info) return mod.db.reputation[info[#info]] end,
					set = function(info, value)
						mod.db.reputation[info[#info]] = value
						mod:ReputationBar_UpdateDimensions()
						mod:ReputationBar_Update()
					end,
					args = {
						customTexture = {
							order = 1, type = "toggle", name = "Custom Texture",
							desc = "Use a separate texture for this data bar instead of the global ElvUI statusbar texture."
						},
						texture = {
							order = 2, type = "select", dialogControl = "LSM30_Statusbar", name = "Texture",
							values = AceGUIWidgetLSMlists.statusbar,
							disabled = function() return not mod.db.reputation.customTexture end
						},
						customColor = {
							order = 3, type = "toggle", name = "Custom Base Color",
							desc = "Override the normal reputation standing color. If disabled, the current standing color is used as the gradient base."
						},
						baseColor = {
							order = 4, type = "color", name = "Base Color", hasAlpha = true,
							disabled = function() return not mod.db.reputation.customColor end,
							get = function()
								local c = mod.db.reputation.baseColor
								return c.r, c.g, c.b, c.a
							end,
							set = function(_, r, g, b, a)
								local c = mod.db.reputation.baseColor
								c.r, c.g, c.b, c.a = r, g, b, a
								mod:ReputationBar_Update()
							end
						},
						gradient = {
							order = 5, type = "toggle", name = "Gradient",
							desc = "Blend from the base color (or current standing color) to the gradient color."
						},
						gradientColor = {
							order = 6, type = "color", name = "Gradient Color", hasAlpha = true,
							disabled = function() return not mod.db.reputation.gradient end,
							get = function()
								local c = mod.db.reputation.gradientColor
								return c.r, c.g, c.b, c.a
							end,
							set = function(_, r, g, b, a)
								local c = mod.db.reputation.gradientColor
								c.r, c.g, c.b, c.a = r, g, b, a
								mod:ReputationBar_Update()
							end
						}
					}
				}
			}
		}
	}
}
