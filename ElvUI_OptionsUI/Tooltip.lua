local E, _, V, P, G = unpack(ElvUI); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local C, L = unpack(select(2, ...))
local TT = E:GetModule("Tooltip")

local GameTooltipStatusBar = GameTooltipStatusBar

local function DefaultFactionGradient(r, g, b)
	return r + ((1-r) * 0.18), g + ((1-g) * 0.18), b + ((1-b) * 0.18)
end

local function RefreshUnitTooltip()
	if not GameTooltip or not GameTooltip:IsShown() then return end
	local _, unit = GameTooltip:GetUnit()
	if unit then GameTooltip:SetUnit(unit) end
end

local function EnsureFactionGradientColor(index)
	E.db.tooltip.factionGradientColors = E.db.tooltip.factionGradientColors or {}
	local color = E.db.tooltip.factionGradientColors[index]
	if not color then
		local base = E.db.tooltip.factionColors[index] or P.tooltip.factionColors[index]
		local r, g, b = DefaultFactionGradient(base.r, base.g, base.b)
		color = {r = r, g = g, b = b}
		E.db.tooltip.factionGradientColors[index] = color
	end
	return color
end

E.Options.args.tooltip = {
	type = "group",
	name = L["Tooltip"],
	childGroups = "tab",
	get = function(info) return E.db.tooltip[info[#info]] end,
	set = function(info, value) E.db.tooltip[info[#info]] = value end,
	args = {
		intro = {
			order = 1,
			type = "description",
			name = L["TOOLTIP_DESC"]
		},
		enable = {
			order = 2,
			type = "toggle",
			name = L["Enable"],
			get = function(info) return E.private.tooltip[info[#info]] end,
			set = function(info, value) E.private.tooltip[info[#info]] = value E:StaticPopup_Show("PRIVATE_RL") end
		},
		general = {
			order = 3,
			type = "group",
			name = L["General"],
			disabled = function() return not E.Tooltip.Initialized end,
			args = {
				header = {
					order = 1,
					type = "header",
					name = L["General"]
				},
				cursorAnchor = {
					order = 2,
					type = "toggle",
					name = L["Cursor Anchor"],
					desc = L["Should tooltip be anchored to mouse cursor"]
				},
				cursorAnchorType = {
					order = 3,
					type = "select",
					name = L["Cursor Anchor Type"],
					values = {
						["ANCHOR_CURSOR"] = L["ANCHOR_CURSOR"],
						["ANCHOR_CURSOR_LEFT"] = L["ANCHOR_CURSOR_LEFT"],
						["ANCHOR_CURSOR_RIGHT"] = L["ANCHOR_CURSOR_RIGHT"],
					},
					disabled = function() return (not E.db.tooltip.cursorAnchor) end
				},
				cursorAnchorX = {
					order = 4,
					type = "range",
					name = L["Cursor Anchor Offset X"],
					min = -128, max = 128, step = 1,
					disabled = function() return (not E.db.tooltip.cursorAnchor) or (E.db.tooltip.cursorAnchorType == "ANCHOR_CURSOR") end
				},
				cursorAnchorY = {
					order = 5,
					type = "range",
					name = L["Cursor Anchor Offset Y"],
					min = -128, max = 128, step = 1,
					disabled = function() return (not E.db.tooltip.cursorAnchor) or (E.db.tooltip.cursorAnchorType == "ANCHOR_CURSOR") end
				},
				targetInfo = {
					order = 6,
					type = "toggle",
					name = L["Target Info"],
					desc = L["When in a raid group display if anyone in your raid is targeting the current tooltip unit."]
				},
				alwaysShowRealm = {
					order = 7,
					type = "toggle",
					name = L["Always Show Realm"],
				},
				playerTitles = {
					order = 8,
					type = "toggle",
					name = L["Player Titles"],
					desc = L["Display player titles."]
				},
				guildRanks = {
					order = 9,
					type = "toggle",
					name = L["Guild Ranks"],
					desc = L["Display guild ranks if a unit is guilded."]
				},
				itemCount = {
					order = 12,
					type = "select",
					name = L["Item Count"],
					desc = L["Display how many of a certain item you have in your possession."],
					values = {
						["BAGS_ONLY"] = L["Bags Only"],
						["BANK_ONLY"] = L["Bank Only"],
						["BOTH"] = L["Both"],
						["NONE"] = L["NONE"]
					}
				},
				colorAlpha = {
					order = 13,
					type = "range",
					name = L["OPACITY"],
					isPercent = true,
					min = 0, max = 1, step = 0.01,
				},
				fontGroup = {
					order = 14,
					type = "group",
					guiInline = true,
					name = L["Tooltip Font Settings"],
					args = {
						font = {
							order = 1,
							type = "select", dialogControl = "LSM30_Font",
							name = L["Font"],
							values = AceGUIWidgetLSMlists.font,
							get = function(info) return E.db.tooltip.font end,
							set = function(info, value) E.db.tooltip.font = value TT:SetTooltipFonts() end
						},
						fontOutline = {
							order = 2,
							type = "select",
							name = L["Font Outline"],
							values = C.Values.FontFlags,
							get = function(info) return E.db.tooltip.fontOutline end,
							set = function(info, value) E.db.tooltip.fontOutline = value TT:SetTooltipFonts() end
						},
						spacer = {
							order = 3,
							type = "description",
							name = ""
						},
						headerFontSize = {
							order = 4,
							type = "range",
							name = L["Header Font Size"],
							min = 4, max = 50, step = 1,
							get = function(info) return E.db.tooltip.headerFontSize end,
							set = function(info, value) E.db.tooltip.headerFontSize = value TT:SetTooltipFonts() end
						},
						textFontSize = {
							order = 5,
							type = "range",
							name = L["Text Font Size"],
							min = 4, max = 33, step = 1,
							get = function(info) return E.db.tooltip.textFontSize end,
							set = function(info, value) E.db.tooltip.textFontSize = value TT:SetTooltipFonts() end
						},
						smallTextFontSize = {
							order = 6,
							type = "range",
							name = L["Comparison Font Size"],
							desc = L["This setting controls the size of text in item comparison tooltips."],
							min = 4, max = 33, step = 1,
							get = function(info) return E.db.tooltip.smallTextFontSize end,
							set = function(info, value) E.db.tooltip.smallTextFontSize = value TT:SetTooltipFonts() end
						}
					}
				},
				factionColors = {
					order = 15,
					type = "group",
					name = L["Custom Faction Colors"],
					guiInline = true,
					args = {
						useCustomFactionColors = {
							order = 1,
							type = "toggle",
							name = L["Custom Faction Colors"],
							width = 1.35,
							get = function() return E.db.tooltip.useCustomFactionColors end,
							set = function(_, value) E.db.tooltip.useCustomFactionColors = value RefreshUnitTooltip() end
						},
						useCustomFactionGradient = {
							order = 1.1,
							type = "toggle",
							name = "Gradient",
							width = 0.8,
							disabled = function() return not E.db.tooltip.useCustomFactionColors end,
							get = function() return E.db.tooltip.useCustomFactionGradient end,
							set = function(_, value) E.db.tooltip.useCustomFactionGradient = value RefreshUnitTooltip() end
						},
						rowHeader = {
							order = 1.2,
							type = "header",
							name = ""
						}
					}
				}
			}
		},
		visibility = {
			order = 4,
			type = "group",
			name = L["Visibility"],
			get = function(info) return E.db.tooltip.visibility[info[#info]] end,
			set = function(info, value) E.db.tooltip.visibility[info[#info]] = value end,
			disabled = function() return not E.Tooltip.Initialized end,
			args = {
				header = {
					order = 1,
					type = "header",
					name = L["Visibility"]
				},
				actionbars = {
					order = 2,
					type = "select",
					name = L["ActionBars"],
					desc = L["Choose when you want the tooltip to show. If a modifer is chosen, then you need to hold that down to show the tooltip."],
					values = {
						["ALL"] = L["Always Hide"],
						["NONE"] = L["Never Hide"],
						["SHIFT"] = L["SHIFT_KEY"],
						["ALT"] = L["ALT_KEY_TEXT"],
						["CTRL"] = L["CTRL_KEY"]
					}
				},
				bags = {
					order = 3,
					type = "select",
					name = L["Bags/Bank"],
					desc = L["Choose when you want the tooltip to show. If a modifer is chosen, then you need to hold that down to show the tooltip."],
					values = {
						["ALL"] = L["Always Hide"],
						["NONE"] = L["Never Hide"],
						["SHIFT"] = L["SHIFT_KEY"],
						["ALT"] = L["ALT_KEY_TEXT"],
						["CTRL"] = L["CTRL_KEY"]
					}
				},
				unitFrames = {
					order = 4,
					type = "select",
					name = L["UnitFrames"],
					desc = L["Choose when you want the tooltip to show. If a modifer is chosen, then you need to hold that down to show the tooltip."],
					values = {
						["ALL"] = L["Always Hide"],
						["NONE"] = L["Never Hide"],
						["SHIFT"] = L["SHIFT_KEY"],
						["ALT"] = L["ALT_KEY_TEXT"],
						["CTRL"] = L["CTRL_KEY"]
					}
				},
				combat = {
					order = 5,
					type = "toggle",
					name = L["Hide In Combat"],
					desc = L["Hide tooltip while in combat."]
				},
				combatOverride = {
					order = 6,
					type = "select",
					name = L["Combat Override Key"],
					desc = L["Choose when you want the tooltip to show in combat. If a modifer is chosen, then you need to hold that down to show the tooltip."],
					disabled = function() return not E.db.tooltip.visibility.combat end,
					values = {
						["ALL"] = L["Always Hide"],
						["SHIFT"] = L["SHIFT_KEY"],
						["ALT"] = L["ALT_KEY_TEXT"],
						["CTRL"] = L["CTRL_KEY"]
					}
				}
			}
		},
		healthBar = {
			order = 6,
			type = "group",
			name = L["Health Bar"],
			get = function(info) return E.db.tooltip.healthBar[info[#info]] end,
			set = function(info, value) E.db.tooltip.healthBar[info[#info]] = value end,
			disabled = function() return not E.Tooltip.Initialized end,
			args = {
				header = {
					order = 1,
					type = "header",
					name = L["Health Bar"]
				},
				height = {
					order = 2,
					type = "range",
					name = L["Height"],
					min = 1, max = 15, step = 1,
					set = function(info, value) E.db.tooltip.healthBar.height = value GameTooltipStatusBar:Height(value) end
				},
				texture = {
					order = 3,
					type = "select", dialogControl = "LSM30_Statusbar",
					name = L["StatusBar Texture"],
					values = AceGUIWidgetLSMlists.statusbar,
					set = function(info, value)
						E.db.tooltip.healthBar.texture = value
						local texture = E.Libs.LSM:Fetch("statusbar", value) or E.media.normTex
						GameTooltipStatusBar:SetStatusBarTexture(texture)
					end
				},
				statusPosition = {
					order = 4,
					type = "select",
					name = L["Position"],
					values = {
						["BOTTOM"] = L["Bottom"],
						["TOP"] = L["Top"]
					}
				},
				text = {
					order = 5,
					type = "toggle",
					name = L["Text"],
					set = function(info, value)
						E.db.tooltip.healthBar.text = value
						if value then
							GameTooltipStatusBar.text:Show()
						else
							GameTooltipStatusBar.text:Hide()
						end
					end
				},
				font = {
					order = 6,
					type = "select", dialogControl = "LSM30_Font",
					name = L["Font"],
					values = AceGUIWidgetLSMlists.font,
					set = function(info, value)
						E.db.tooltip.healthBar.font = value
						GameTooltipStatusBar.text:FontTemplate(E.Libs.LSM:Fetch("font", E.db.tooltip.healthBar.font), E.db.tooltip.healthBar.fontSize, E.db.tooltip.healthBar.fontOutline)
					end,
					disabled = function() return not E.db.tooltip.healthBar.text end
				},
				fontSize = {
					order = 7,
					type = "range",
					name = L["FONT_SIZE"],
					min = 4, max = 33, step = 1,
					set = function(info, value)
						E.db.tooltip.healthBar.fontSize = value
						GameTooltipStatusBar.text:FontTemplate(E.Libs.LSM:Fetch("font", E.db.tooltip.healthBar.font), E.db.tooltip.healthBar.fontSize, E.db.tooltip.healthBar.fontOutline)
					end,
					disabled = function() return not E.db.tooltip.healthBar.text end
				},
				fontOutline = {
					order = 8,
					type = "select",
					name = L["Font Outline"],
					values = C.Values.FontFlags,
					set = function(info, value)
						E.db.tooltip.healthBar.fontOutline = value
						GameTooltipStatusBar.text:FontTemplate(E.Libs.LSM:Fetch("font", E.db.tooltip.healthBar.font), E.db.tooltip.healthBar.fontSize, E.db.tooltip.healthBar.fontOutline)
					end,
					disabled = function() return not E.db.tooltip.healthBar.text end
				}
			}
		}
	}
}

for i = 1, 8 do
	local index = i
	local order = 10 + ((i - 1) * 5)
	local args = E.Options.args.tooltip.args.general.args.factionColors.args

	args["faction"..i.."Name"] = {
		order = order,
		type = "description",
		name = L["FACTION_STANDING_LABEL"..i],
		width = 0.72,
		fontSize = "medium"
	}
	args["faction"..i.."Base"] = {
		order = order + 0.1,
		type = "color",
		hasAlpha = false,
		name = "Base Color",
		width = 0.72,
		disabled = function() return not E.Tooltip.Initialized or not E.db.tooltip.useCustomFactionColors end,
		get = function()
			local color = E.db.tooltip.factionColors[index] or P.tooltip.factionColors[index]
			return color.r, color.g, color.b
		end,
		set = function(_, r, g, b)
			E.db.tooltip.factionColors[index] = E.db.tooltip.factionColors[index] or {}
			local color = E.db.tooltip.factionColors[index]
			color.r, color.g, color.b = r, g, b
			RefreshUnitTooltip()
		end
	}
	args["faction"..i.."Gradient"] = {
		order = order + 0.2,
		type = "color",
		hasAlpha = false,
		name = "Gradient Color",
		width = 0.82,
		disabled = function() return not E.Tooltip.Initialized or not E.db.tooltip.useCustomFactionColors or not E.db.tooltip.useCustomFactionGradient end,
		get = function()
			local color = EnsureFactionGradientColor(index)
			return color.r, color.g, color.b
		end,
		set = function(_, r, g, b)
			local color = EnsureFactionGradientColor(index)
			color.r, color.g, color.b = r, g, b
			RefreshUnitTooltip()
		end
	}
	args["faction"..i.."Reset"] = {
		order = order + 0.3,
		type = "execute",
		name = "Reset",
		width = 0.6,
		disabled = function() return not E.Tooltip.Initialized or not E.db.tooltip.useCustomFactionColors end,
		func = function()
			local baseDefault = P.tooltip.factionColors[index]
			E.db.tooltip.factionColors[index] = {r = baseDefault.r, g = baseDefault.g, b = baseDefault.b}

			local gradientDefault = P.tooltip.factionGradientColors and P.tooltip.factionGradientColors[index]
			E.db.tooltip.factionGradientColors = E.db.tooltip.factionGradientColors or {}
			if gradientDefault then
				E.db.tooltip.factionGradientColors[index] = {r = gradientDefault.r, g = gradientDefault.g, b = gradientDefault.b}
			else
				local r, g, b = DefaultFactionGradient(baseDefault.r, baseDefault.g, baseDefault.b)
				E.db.tooltip.factionGradientColors[index] = {r = r, g = g, b = b}
			end

			RefreshUnitTooltip()
		end
	}
	args["faction"..i.."Divider"] = {
		order = order + 0.4,
		type = "header",
		name = "",
		width = "full"
	}
end
