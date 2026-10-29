local E, _, V, P, G = unpack(ElvUI); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local C, L = unpack(select(2, ...))
local WM = E:GetModule("WorldMap")
local MM = E:GetModule("Minimap")
local AB = E:GetModule("ActionBars")
local MMk = E:GetModule("MapMarkers")
local MB = E:GetModule("MinimapButtons")
local FC = E:GetModule("FogClear")

E.Options.args.maps = {
	type = "group",
	name = L["Maps"],
	childGroups = "tab",
	args = {
		worldMap = {
			order = 1,
			type = "group",
			name = L["WORLD_MAP"],
			args = {
				header = {
					order = 1,
					type = "header",
					name = L["WORLD_MAP"]
				},
				enable = {
					order = 2,
					type = "toggle",
					name = L["Enable"],
					get = function(info) return E.private.worldmap[info[#info]] end,
					set = function(info, value) E.private.worldmap[info[#info]] = value; E:StaticPopup_Show("PRIVATE_RL") end
				},
				generalGroup = {
					order = 3,
					type = "group",
					name = L["General"],
					guiInline = true,
					args = {
						smallerWorldMap = {
							order = 1,
							type = "toggle",
							name = L["Smaller World Map"],
							desc = L["Make the world map smaller."],
							get = function(info) return E.global.general.smallerWorldMap end,
							set = function(info, value) E.global.general.smallerWorldMap = value E:StaticPopup_Show("GLOBAL_RL") end,
							disabled = function() return not WM.Initialized end
						},
						fadeMapWhenMoving = {
							order = 2,
							type = "toggle",
							name = L["MAP_FADE_TEXT"],
							get = function(info) return E.global.general.fadeMapWhenMoving end,
							set = function(info, value) E.global.general.fadeMapWhenMoving = value WM:UpdateMapAlpha() end
						},
						mapAlphaWhenMoving = {
							order = 3,
							type = "range",
							name = L["Map Opacity When Moving"],
							isPercent = true,
							min = 0, max = 1, step = 0.01,
							get = function(info) return E.global.general.mapAlphaWhenMoving end,
							set = function(info, value) E.global.general.mapAlphaWhenMoving = value WM:UpdateMapAlpha() end,
							disabled = function() return not E.global.general.fadeMapWhenMoving end
						}
					}
				},
				fogOfWarGroup = {
					order = 4,
					type = "group",
					name = "Fog of War",
					guiInline = true,
					args = {
						mode = {
							order = 1,
							type = "select",
							name = "World Map Fog",
							desc = "Choose how unexplored areas are displayed on the world map.",
							values = {
								DEFAULT = "Blizzard Default",
								REVEAL = "Reveal Fog of War"
							},
							get = function() return E.db.general.worldMapFog.mode end,
							set = function(_, value)
								E.db.general.worldMapFog.mode = value
								FC:UpdateFog()
							end
						},
						overlayColor = {
							order = 2,
							type = "color",
							name = "Overlay Color",
							hasAlpha = true,
							get = function()
								local color = E.db.general.worldMapFog.color
								return color.r, color.g, color.b, color.a
							end,
							set = function(_, r, g, b, a)
								local color = E.db.general.worldMapFog.color
								color.r, color.g, color.b, color.a = r, g, b, a or 1
								FC:ApplyFogColor()
							end,
							disabled = function() return E.db.general.worldMapFog.mode ~= "REVEAL" end
						},
						resetOverlayColor = {
							order = 3,
							type = "execute",
							name = "Reset Color",
							desc = "Reset the Fog of War overlay color to the default gray.",
							func = function()
								local color = E.db.general.worldMapFog.color
								color.r, color.g, color.b, color.a = 0.5, 0.5, 0.5, 1
								FC:ApplyFogColor()
							end,
							disabled = function() return E.db.general.worldMapFog.mode ~= "REVEAL" end
						}
					}
				},
				spacer = {
					order = 5,
					type = "description",
					name = "\n"
				},
				coordinatesGroup = {
					order = 6,
					type = "group",
					name = L["World Map Coordinates"],
					guiInline = true,
					disabled = function() return not WM.Initialized end,
					args = {
						enable = {
							order = 1,
							type = "toggle",
							name = L["Enable"],
							desc = L["Puts coordinates on the world map."],
							get = function(info) return E.global.general.WorldMapCoordinates.enable end,
							set = function(info, value) E.global.general.WorldMapCoordinates.enable = value E:StaticPopup_Show("GLOBAL_RL") end
						},
						spacer = {
							order = 2,
							type = "description",
							name = " "
						},
						position = {
							order = 3,
							type = "select",
							name = L["Position"],
							get = function(info) return E.global.general.WorldMapCoordinates.position end,
							set = function(info, value) E.global.general.WorldMapCoordinates.position = value WM:PositionCoords() end,
							disabled = function() return not E.global.general.WorldMapCoordinates.enable end,
							values = {
								["TOP"] = "TOP",
								["TOPLEFT"] = "TOPLEFT",
								["TOPRIGHT"] = "TOPRIGHT",
								["BOTTOM"] = "BOTTOM",
								["BOTTOMLEFT"] = "BOTTOMLEFT",
								["BOTTOMRIGHT"] = "BOTTOMRIGHT"
							}
						},
						xOffset = {
							order = 4,
							type = "range",
							name = L["X-Offset"],
							get = function(info) return E.global.general.WorldMapCoordinates.xOffset end,
							set = function(info, value) E.global.general.WorldMapCoordinates.xOffset = value WM:PositionCoords() end,
							disabled = function() return not E.global.general.WorldMapCoordinates.enable end,
							min = -200, max = 200, step = 1
						},
						yOffset = {
							order = 5,
							type = "range",
							name = L["Y-Offset"],
							get = function(info) return E.global.general.WorldMapCoordinates.yOffset end,
							set = function(info, value) E.global.general.WorldMapCoordinates.yOffset = value WM:PositionCoords() end,
							disabled = function() return not E.global.general.WorldMapCoordinates.enable end,
							min = -200, max = 200, step = 1
						}
					}
				},
				spacer2 = {
					order = 7,
					type = "description",
					name = "\n"
				},
				mapMarkersGroup = {
					order = 8,
					type = "group",
					name = L["Map Markers"],
					guiInline = true,
					disabled = function() return not WM.Initialized end,
					args = {
						enable = {
							order = 1,
							type = "toggle",
							name = L["Enable"],
							desc = L["Allows Map Markers to be created by middle clicking (Mouse3) on the world map.\nMarkers are automatically shared with raid members."],
							get = function(info) return E.db.general.mapMarkers[info[#info]] end,
							set = function(info, value) E.db.general.mapMarkers[info[#info]] = value E:StaticPopup_Show("PRIVATE_RL") end
						},
						showRaidMarkers = {
							order = 2,
							type = "toggle",
							name = L["Receive from Raid Members"],
							desc = L["Allows Raid Members to send you Map Markers"],
							get = function(info) return E.db.general.mapMarkers[info[#info]] end,
							set = function(info, value) E.db.general.mapMarkers[info[#info]] = value E:StaticPopup_Show("PRIVATE_RL") end,
							disabled = function() return not E.db.general.mapMarkers.enable end,
						},
						iconSize = {
							order = 3,
							type = "range",
							name = L["Icon Size"],
							desc = L["Set the size of the map markers"],
							min = 15, max = 50, step = 1,
							get = function(info) return E.db.general.mapMarkers[info[#info]] end,
							set = function(info, value) E.db.general.mapMarkers[info[#info]] = value MMk:ResizeAll() end,
							disabled = function() return not E.db.general.mapMarkers.enable end,
						},
					}
				}
			}
		},
		minimap = {
			order = 2,
			type = "group",
			name = L["MINIMAP_LABEL"],
			get = function(info) return E.db.general.minimap[info[#info]] end,
			childGroups = "tab",
			args = {
				minimapHeader = {
					order = 1,
					type = "header",
					name = L["MINIMAP_LABEL"]
				},
				generalGroup = {
					order = 2,
					type = "group",
					name = L["General"],
					guiInline = true,
					args = {
						enable = {
							order = 1,
							type = "toggle",
							name = L["Enable"],
							desc = L["Enable/Disable the minimap. |cffFF0000Warning: This will prevent you from seeing the consolidated buffs bar, and prevent you from seeing the minimap datatexts.|r"],
							get = function(info) return E.private.general.minimap[info[#info]] end,
							set = function(info, value) E.private.general.minimap[info[#info]] = value E:StaticPopup_Show("PRIVATE_RL") end
						},
						size = {
							order = 2,
							type = "range",
							name = L["Size"],
							desc = L["Adjust the size of the minimap."],
							min = 120, max = 250, step = 1,
							get = function(info) return E.db.general.minimap[info[#info]] end,
							set = function(info, value) E.db.general.minimap[info[#info]] = value MM:UpdateSettings() end,
							disabled = function() return not E.private.general.minimap.enable end
						}
					}
				},
				locationTextGroup = {
					order = 3,
					type = "group",
					name = L["Location Text"],
					args = {
						locationHeader = {
							order = 1,
							type = "header",
							name = L["Location Text"]
						},
						locationText = {
							order = 2,
							type = "select",
							name = L["Location Text"],
							desc = L["Change settings for the display of the location text that is on the minimap."],
							get = function(info) return E.db.general.minimap.locationText end,
							set = function(info, value) E.db.general.minimap.locationText = value MM:UpdateSettings() MM:Update_ZoneText() end,
							values = {
								["MOUSEOVER"] = L["Minimap Mouseover"],
								["SHOW"] = L["Always Display"],
								["HIDE"] = L["HIDE"]
							},
							disabled = function() return not E.private.general.minimap.enable end
						},
						spacer = {
							order = 3,
							type = "description",
							name = "\n"
						},
						locationFont = {
							order = 4,
							type = "select",
							dialogControl = "LSM30_Font",
							name = L["Font"],
							values = AceGUIWidgetLSMlists.font,
							set = function(info, value) E.db.general.minimap.locationFont = value MM:Update_ZoneText() end,
							disabled = function() return not E.private.general.minimap.enable end
						},
						locationFontSize = {
							order = 5,
							type = "range",
							name = L["FONT_SIZE"],
							min = 6, max = 36, step = 1,
							set = function(info, value) E.db.general.minimap.locationFontSize = value MM:Update_ZoneText() end,
							disabled = function() return not E.private.general.minimap.enable end
						},
						locationFontOutline = {
							order = 6,
							type = "select",
							name = L["Font Outline"],
							set = function(info, value) E.db.general.minimap.locationFontOutline = value MM:Update_ZoneText() end,
							disabled = function() return not E.private.general.minimap.enable end,
							values = C.Values.FontFlags
						}
					}
				},
				zoomResetGroup = {
					order = 4,
					type = "group",
					name = L["Reset Zoom"],
					args = {
						zoomResetHeader = {
							order = 1,
							type = "header",
							name = L["Reset Zoom"]
						},
						enableZoomReset = {
							order = 2,
							type = "toggle",
							name = L["Reset Zoom"],
							get = function(info) return E.db.general.minimap.resetZoom.enable end,
							set = function(info, value) E.db.general.minimap.resetZoom.enable = value MM:UpdateSettings() end,
							disabled = function() return not E.private.general.minimap.enable end
						},
						zoomResetTime = {
							order = 3,
							type = "range",
							name = L["Seconds"],
							min = 1, max = 15, step = 1,
							get = function(info) return E.db.general.minimap.resetZoom.time end,
							set = function(info, value) E.db.general.minimap.resetZoom.time = value MM:UpdateSettings() end,
							disabled = function() return (not E.db.general.minimap.resetZoom.enable or not E.private.general.minimap.enable) end
						}
					}
				},
				icons = {
					order = 5,
					type = "group",
					name = L["Buttons"],
					args = {
						header = {
							order = 0,
							type = "header",
							name = L["Buttons"]
						},
						calendar = {
							order = 1,
							type = "group",
							name = L["Calendar"],
							get = function(info) return E.db.general.minimap.icons.calendar[info[#info]] end,
							set = function(info, value) E.db.general.minimap.icons.calendar[info[#info]] = value MM:UpdateSettings() end,
							disabled = function() return not E.private.general.minimap.enable end,
							args = {
								calendarHeader = {
									order = 1,
									type = "header",
									name = L["Calendar"]
								},
								hideCalendar = {
									order = 2,
									type = "toggle",
									name = L["HIDE"],
									get = function(info) return E.private.general.minimap.hideCalendar end,
									set = function(info, value) E.private.general.minimap.hideCalendar = value MM:UpdateSettings() end,
									width = "full"
								},
								spacer = {
									order = 3,
									type = "description",
									name = "",
									width = "full"
								},
								position = {
									order = 4,
									type = "select",
									name = L["Position"],
									disabled = function() return E.private.general.minimap.hideCalendar end,
									values = {
										["LEFT"] = L["Left"],
										["RIGHT"] = L["Right"],
										["TOP"] = L["Top"],
										["BOTTOM"] = L["Bottom"],
										["TOPLEFT"] = L["Top Left"],
										["TOPRIGHT"] = L["Top Right"],
										["BOTTOMLEFT"] = L["Bottom Left"],
										["BOTTOMRIGHT"] = L["Bottom Right"]
									}
								},
								scale = {
									order = 5,
									type = "range",
									name = L["Scale"],
									min = 0.5, max = 2, step = 0.05,
									disabled = function() return E.private.general.minimap.hideCalendar end
								},
								xOffset = {
									order = 6,
									type = "range",
									name = L["X-Offset"],
									min = -50, max = 50, step = 1,
									disabled = function() return E.private.general.minimap.hideCalendar end
								},
								yOffset = {
									order = 7,
									type = "range",
									name = L["Y-Offset"],
									min = -50, max = 50, step = 1,
									disabled = function() return E.private.general.minimap.hideCalendar end
								}
							}
						},
						mail = {
							order = 3,
							type = "group",
							name = L["MAIL_LABEL"],
							get = function(info) return E.db.general.minimap.icons.mail[info[#info]] end,
							set = function(info, value) E.db.general.minimap.icons.mail[info[#info]] = value MM:UpdateSettings() end,
							disabled = function() return not E.private.general.minimap.enable end,
							args = {
								mailHeader = {
									order = 1,
									type = "header",
									name = L["MAIL_LABEL"]
								},
								position = {
									order = 2,
									type = "select",
									name = L["Position"],
									values = {
										["LEFT"] = L["Left"],
										["RIGHT"] = L["Right"],
										["TOP"] = L["Top"],
										["BOTTOM"] = L["Bottom"],
										["TOPLEFT"] = L["Top Left"],
										["TOPRIGHT"] = L["Top Right"],
										["BOTTOMLEFT"] = L["Bottom Left"],
										["BOTTOMRIGHT"] = L["Bottom Right"]
									}
								},
								scale = {
									order = 3,
									type = "range",
									name = L["Scale"],
									min = 0.5, max = 2, step = 0.05
								},
								xOffset = {
									order = 4,
									type = "range",
									name = L["X-Offset"],
									min = -50, max = 50, step = 1
								},
								yOffset = {
									order = 5,
									type = "range",
									name = L["Y-Offset"],
									min = -50, max = 50, step = 1
								}
							}
						},
						lfgEye = {
							order = 4,
							type = "group",
							name = L["LFG Queue"],
							get = function(info) return E.db.general.minimap.icons.lfgEye[info[#info]] end,
							set = function(info, value) E.db.general.minimap.icons.lfgEye[info[#info]] = value MM:UpdateSettings() end,
							disabled = function() return not E.private.general.minimap.enable end,
							args = {
								lfgEyeHeader = {
									order = 1,
									type = "header",
									name = L["LFG Queue"]
								},
								position = {
									order = 2,
									type = "select",
									name = L["Position"],
									values = {
										["LEFT"] = L["Left"],
										["RIGHT"] = L["Right"],
										["TOP"] = L["Top"],
										["BOTTOM"] = L["Bottom"],
										["TOPLEFT"] = L["Top Left"],
										["TOPRIGHT"] = L["Top Right"],
										["BOTTOMLEFT"] = L["Bottom Left"],
										["BOTTOMRIGHT"] = L["Bottom Right"]
									}
								},
								scale = {
									order = 3,
									type = "range",
									name = L["Scale"],
									min = 0.5, max = 2, step = 0.05
								},
								xOffset = {
									order = 4,
									type = "range",
									name = L["X-Offset"],
									min = -50, max = 50, step = 1
								},
								yOffset = {
									order = 5,
									type = "range",
									name = L["Y-Offset"],
									min = -50, max = 50, step = 1
								}
							}
						},
						battlefield = {
							order = 5,
							type = "group",
							name = L["PvP Queue"],
							get = function(info) return E.db.general.minimap.icons.battlefield[info[#info]] end,
							set = function(info, value) E.db.general.minimap.icons.battlefield[info[#info]] = value MM:UpdateSettings() end,
							disabled = function() return not E.private.general.minimap.enable end,
							args = {
								battlefieldHeader = {
									order = 1,
									type = "header",
									name = L["PvP Queue"]
								},
								position = {
									order = 2,
									type = "select",
									name = L["Position"],
									values = {
										["LEFT"] = L["Left"],
										["RIGHT"] = L["Right"],
										["TOP"] = L["Top"],
										["BOTTOM"] = L["Bottom"],
										["TOPLEFT"] = L["Top Left"],
										["TOPRIGHT"] = L["Top Right"],
										["BOTTOMLEFT"] = L["Bottom Left"],
										["BOTTOMRIGHT"] = L["Bottom Right"]
									}
								},
								scale = {
									order = 3,
									type = "range",
									name = L["Scale"],
									min = 0.5, max = 2, step = 0.05
								},
								xOffset = {
									order = 4,
									type = "range",
									name = L["X-Offset"],
									min = -50, max = 50, step = 1
								},
								yOffset = {
									order = 5,
									type = "range",
									name = L["Y-Offset"],
									min = -50, max = 50, step = 1
								}
							}
						},
						difficulty = {
							order = 6,
							type = "group",
							name = L["Instance Difficulty"],
							get = function(info) return E.db.general.minimap.icons.difficulty[info[#info]] end,
							set = function(info, value) E.db.general.minimap.icons.difficulty[info[#info]] = value MM:UpdateSettings() end,
							disabled = function() return not E.private.general.minimap.enable end,
							args = {
								difficultyHeader = {
									order = 1,
									type = "header",
									name = L["Instance Difficulty"]
								},
								position = {
									order = 2,
									type = "select",
									name = L["Position"],
									values = {
										["LEFT"] = L["Left"],
										["RIGHT"] = L["Right"],
										["TOP"] = L["Top"],
										["BOTTOM"] = L["Bottom"],
										["TOPLEFT"] = L["Top Left"],
										["TOPRIGHT"] = L["Top Right"],
										["BOTTOMLEFT"] = L["Bottom Left"],
										["BOTTOMRIGHT"] = L["Bottom Right"]
									}
								},
								scale = {
									order = 3,
									type = "range",
									name = L["Scale"],
									min = 0.5, max = 2, step = 0.05
								},
								xOffset = {
									order = 4,
									type = "range",
									name = L["X-Offset"],
									min = -50, max = 50, step = 1
								},
								yOffset = {
									order = 5,
									type = "range",
									name = L["Y-Offset"],
									min = -50, max = 50, step = 1
								}
							}
						},
						vehicleLeave = {
							order = 7,
							type = "group",
							name = L["LEAVE_VEHICLE"],
							get = function(info) return E.db.general.minimap.icons.vehicleLeave[info[#info]] end,
							set = function(info, value) E.db.general.minimap.icons.vehicleLeave[info[#info]] = value AB:UpdateVehicleLeave() end,
							disabled = function() return not E.private.general.minimap.enable end,
							args = {
								vehicleLeaveHeader = {
									order = 1,
									type = "header",
									name = L["LEAVE_VEHICLE"]
								},
								hide = {
									order = 2,
									type = "toggle",
									name = L["HIDE"]
								},
								spacer = {
									order = 3,
									type = "description",
									name = "",
									width = "full"
								},
								position = {
									order = 4,
									type = "select",
									name = L["Position"],
									values = {
										["LEFT"] = L["Left"],
										["RIGHT"] = L["Right"],
										["TOP"] = L["Top"],
										["BOTTOM"] = L["Bottom"],
										["TOPLEFT"] = L["Top Left"],
										["TOPRIGHT"] = L["Top Right"],
										["BOTTOMLEFT"] = L["Bottom Left"],
										["BOTTOMRIGHT"] = L["Bottom Right"]
									}
								},
								scale = {
									order = 5,
									type = "range",
									name = L["Scale"],
									min = 0.5, max = 2, step = 0.05,
								},
								xOffset = {
									order = 6,
									type = "range",
									name = L["X-Offset"],
									min = -50, max = 50, step = 1
								},
								yOffset = {
									order = 7,
									type = "range",
									name = L["Y-Offset"],
									min = -50, max = 50, step = 1
								}
							}
						}
					}
				}
			}
		},
		minimapButtons = {
			order = 3,
			type = "group",
			name = "Minimap Buttons",
			get = function(info) return E.db.general.minimap.buttonFrame[info[#info]] end,
			set = function(info, value)
				E.db.general.minimap.buttonFrame[info[#info]] = value
				if MB and MB.initialized then MB:UpdateSettings() end
			end,
			args = {
				header = {
					order = 1,
					type = "header",
					name = "Minimap Button Frame"
				},
				description = {
					order = 2,
					type = "description",
					name = "Collects addon minimap buttons into one ElvUI frame. Blizzard minimap controls are ignored."
				},
				enable = {
					order = 3,
					type = "toggle",
					name = L["Enable"],
					desc = "Enable the Minimap Button Frame. A reload is required when changing this setting.",
					set = function(_, value)
						E.db.general.minimap.buttonFrame.enable = value
						E:StaticPopup_Show("CONFIG_RL")
					end
				},
				rescan = {
					order = 4,
					type = "execute",
					name = "Rescan Buttons",
					desc = "Immediately scan the minimap for new addon buttons.",
					func = function() if MB and MB.initialized then MB:ScanButtons() end end,
					disabled = function() return not E.db.general.minimap.buttonFrame.enable or not MB.initialized end
				},
				layout = {
					order = 10,
					type = "group",
					name = "Layout",
					guiInline = true,
					disabled = function() return not E.db.general.minimap.buttonFrame.enable end,
					args = {
						buttonSize = {
							order = 1,
							type = "range",
							name = "Icon Size",
							min = 14, max = 64, step = 1
						},
						buttonSpacing = {
							order = 2,
							type = "range",
							name = "Icon Spacing",
							min = -2, max = 20, step = 1
						},
						buttonsPerRow = {
							order = 3,
							type = "range",
							name = "Icons Per Row",
							desc = "Maximum number of addon icons shown next to each other before a new row starts.",
							min = 1, max = 30, step = 1
						},
						growFrom = {
							order = 4,
							type = "select",
							name = "Grow From",
							values = {
								TOPLEFT = "Top Left (Right / Down)",
								TOPRIGHT = "Top Right (Left / Down)",
								BOTTOMLEFT = "Bottom Left (Right / Up)",
								BOTTOMRIGHT = "Bottom Right (Left / Up)"
							}
						},
						sortOrder = {
							order = 5,
							type = "select",
							name = "Sort",
							values = {
								NAME = "Name",
								DISCOVERY = "Discovery Order"
							}
						},
						frameStrata = {
							order = 6,
							type = "select",
							name = "Frame Strata",
							values = {LOW = "Low", MEDIUM = "Medium", HIGH = "High"}
						}
					}
				},
				appearance = {
					order = 20,
					type = "group",
					name = "Appearance",
					guiInline = true,
					disabled = function() return not E.db.general.minimap.buttonFrame.enable end,
					args = {
						backdrop = {
							order = 1,
							type = "toggle",
							name = "Backdrop"
						},
						backdropSpacing = {
							order = 2,
							type = "range",
							name = "Backdrop Spacing",
							min = 0, max = 20, step = 1,
							disabled = function() return not E.db.general.minimap.buttonFrame.enable or not E.db.general.minimap.buttonFrame.backdrop end
						},
						hideBackdropWhenEmpty = {
							order = 3,
							type = "toggle",
							name = "Hide Backdrop When Empty",
							disabled = function() return not E.db.general.minimap.buttonFrame.enable or not E.db.general.minimap.buttonFrame.backdrop end
						},
						mouseover = {
							order = 4,
							type = "toggle",
							name = L["Mouse Over"],
							desc = "Hide the complete button frame until the mouse is over it."
						},
						alpha = {
							order = 5,
							type = "range",
							name = L["Alpha"],
							min = 0.1, max = 1, step = 0.05
						},
						shadow = {
							order = 6,
							type = "toggle",
							name = "Shadow",
							desc = "Uses the shadow color and size from Skins > Shadows.",
							get = function() return E.db.frameShadows.frames.minimapbuttonbar end,
							set = function(_, value)
								E.db.frameShadows.frames.minimapbuttonbar = value
								local S = E:GetModule("Skins", true)
								if S and S.UpdateFrameShadow then S:UpdateFrameShadow("minimapbuttonbar") end
							end
						}
					}
				},
				position = {
					order = 30,
					type = "group",
					name = "Position",
					guiInline = true,
					disabled = function() return not E.db.general.minimap.buttonFrame.enable end,
					args = {
						anchorToMinimap = {
							order = 1,
							type = "toggle",
							name = "Anchor To Minimap",
							desc = "Anchor the frame directly to the minimap. Disable this to use the ElvUI mover."
						},
						anchorPoint = {
							order = 2,
							type = "select",
							name = L["Position"],
							values = {
								TOPLEFT = "Top Left", TOP = "Top", TOPRIGHT = "Top Right",
								LEFT = "Left", CENTER = "Center", RIGHT = "Right",
								BOTTOMLEFT = "Bottom Left", BOTTOM = "Bottom", BOTTOMRIGHT = "Bottom Right"
							},
							disabled = function() return not E.db.general.minimap.buttonFrame.enable or not E.db.general.minimap.buttonFrame.anchorToMinimap end
						},
						xOffset = {
							order = 3,
							type = "range",
							name = L["X-Offset"],
							min = -250, max = 250, step = 1,
							disabled = function() return not E.db.general.minimap.buttonFrame.enable or not E.db.general.minimap.buttonFrame.anchorToMinimap end
						},
						yOffset = {
							order = 4,
							type = "range",
							name = L["Y-Offset"],
							min = -250, max = 250, step = 1,
							disabled = function() return not E.db.general.minimap.buttonFrame.enable or not E.db.general.minimap.buttonFrame.anchorToMinimap end
						}
					}
				}
			}
		}
	}
}
