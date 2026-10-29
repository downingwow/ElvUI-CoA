local E, L, V, P, G = unpack(ElvUI)
local EP = E.Libs.EP
local AS = E:NewModule("AddOnSkins")

local AddOnName = ...

local lower = string.lower

local GetAddOnInfo = GetAddOnInfo
local IsAddOnLoadOnDemand = IsAddOnLoadOnDemand

local addonList = {
	"Omen",
	"Recount",
	"SexyCooldown",
	"DBM",
	"Skada",
	"Auctionator",
	"BugSack",
	"CallToArms",
	"Postal",
	"QuestPointer",
	"Clique",
	"FloAspectBar",
	"FloTotemBar",
	"Spy",
	"AtlasLoot",
	"Atlas",
	"FlightMap",
	"WeakAuras",
	"Overachiever",
	"OpenGF",
	"KHunterTimers",
	"TellMeWhen",
	"GearScore",
	"AllStats",
	"BlackList",
	"GnomishVendorShrinker",
	"ACP",
	"EveryQuest",
	"_NPCScan",
	"MoveAnything",
	"VanasKoS",
	"BindPad",
	"ZygorGuidesViewer",
	"ZygorTalentAdvisor",
	"WowLua",
	"ChatBar",
	"Skillet",
	"TotemTimers",
	"PlateBuffs",
	"MageNuggets",
	"InspectEquip",
	"AdvancedTradeSkillWindow",
	"AtlasQuest",
	"AckisRecipeList",
	"LightHeaded",
	"Carbonite",
	"Enchantrix",
	"FishingBuddy",
	"Talented",
	"TinyPad",
	"ZOMGBuffs",
	"BuyEmAll",
	"Doom_CooldownPulse",
	"AdiBags",
	"PallyPower",
	"KarniCrap",
	"TradeskillInfo",
	"PAB",
	"EPGP",
	"EPGP_LootMaster",
	"RaidRoll",
	"RaidCooldowns",
	"EventAlert",
	"WIM",
	"BigWigs",
	"Outfitter",
	"Poisoner",
	"TrinketMenu",
	"Stalker",
	"ChocolateBar",
	"EquipCompare",
	"SuperDuperMacro",
	"CLCRet",
	"FeralbyNight",
	"Factionizer",
	"PowerAuras",
	"Quartz",
	"TipTac",
	"Swatter",
	"BeanCounter",
	"Informant",
	"SlideBar",
	"AuctioneerSuite",
	"Altoholic",
	"LoseControl",
	"SilverDragon",
	"_NPCScanOverlay",
	"Examiner",
	"Mapster",
	"ArkInventory",
	"QuestGuru",
	"QuestGuru_Tracker",
	"SatrinaBuffFrame",
	"LootCouncil_Lite",
	"ElvinCDs",
	"oRA3",
	"RCLootCouncil",
	"QDKP2_GUI",
	"LootWonAlert",
	"SquidBotsLite",
	"CoABotUI",
	"AzerothAdmin",
	"Decursive",
	"CoAItemSearch",
	"LootCollector",
	"QuestCompletionist",
	"Ascension_AddonPanel",
	"GhostFrame",
}
local addonAlias = {
	["DBM"] = "DBM-Core",
	["Swatter"] = "!Swatter",
	["AuctioneerSuite"] = "Auc-Advanced",
	["_NPCScanOverlay"] = "_NPCScan.Overlay",
	["ElvinCDs"] = "!ElvinCDs",
}

AS.addons = {}

-- CoA profile storage fix:
-- AddOn skin toggles used to live in E.private.addOnSkins while the remaining
-- AddOnSkins settings were stored in E.db.addOnSkins. Keep every user-facing
-- setting in the active ElvUI profile instead.
local function MigrateCoAProfileStorage()
	if not E.db or not E.db.addOnSkins then return end
	E.db.addOnSkins.skins = E.db.addOnSkins.skins or {}

	if not E.db.addOnSkins._coaStorageMigrated then
		local old = E.private and E.private.addOnSkins
		if old then
			for _, addonName in ipairs(addonList) do
				if old[addonName] ~= nil then
					E.db.addOnSkins.skins[addonName] = old[addonName]
				end
			end
		end
		E.db.addOnSkins._coaStorageMigrated = true
	end

	for _, addonName in ipairs(addonList) do
		if E.db.addOnSkins.skins[addonName] == nil then
			E.db.addOnSkins.skins[addonName] = true
		end
	end
end

MigrateCoAProfileStorage()


do
	local temp = {}
	for alias, addonName in pairs(addonAlias) do
		temp[lower(addonName)] = alias
	end

	for i = 1, GetNumAddOns() do
		local name, _, _, enabled = GetAddOnInfo(i)
		local state = (enabled and 1) or (IsAddOnLoadOnDemand(i) and 2)

		if state then
			AS.addons[lower(name)] = state

			if temp[name] then
				AS.addons[lower(temp[name])] = state
			end
		end
	end

	-- Zygor Guides Viewer Remastered liegt im Ordner "ZygorGuidesViewerRM",
	-- der Skin-Schalter heisst weiterhin "ZygorGuidesViewer"
	if AS.addons["zygorguidesviewerrm"] then
		AS.addons["zygorguidesviewer"] = AS.addons["zygorguidesviewer"] or AS.addons["zygorguidesviewerrm"]
		AS.addons["zygortalentadvisor"] = AS.addons["zygortalentadvisor"] or AS.addons["zygorguidesviewerrm"]
	end

	V.addOnSkins = {}

	for _, addonName in ipairs(addonList) do
		V.addOnSkins[addonName] = true
	end
end

function AS:IsAddonEnabled(addon)
	return self.addons[lower(addonAlias[addon] or addon)] == 1
end

function AS:IsAddonLOD(addon)
	return self.addons[lower(addonAlias[addon] or addon)] == 2
end

function AS:IsAddonLODorEnabled(addon)
	return self.addons[lower(addonAlias[addon] or addon)] ~= nil
end

function AS:RegisterAddonOption(addonName, options)
	-- GhostFrame is part of the game UI (FrameXML), not an addon -> always available
	if addonName ~= "GhostFrame" and not self:IsAddonLODorEnabled(addonName) then return end

	local displayName = addonName
	if addonName == "SquidBotsLite" then
		displayName = "SquidBots Lite"
	elseif addonName == "GhostFrame" then
		displayName = "Ghost Buttons (Graveyard / Closest Town)"
	end

	options[addonName] = {
		type = "toggle",
		name = displayName,
		desc = L["TOGGLESKIN_DESC"],
	}
end

local function getOptions()
	local positionValues = {
		TOPLEFT = "TOPLEFT",
		LEFT = "LEFT",
		BOTTOMLEFT = "BOTTOMLEFT",
		RIGHT = "RIGHT",
		TOPRIGHT = "TOPRIGHT",
		BOTTOMRIGHT = "BOTTOMRIGHT",
		CENTER = "CENTER",
		TOP = "TOP",
		BOTTOM = "BOTTOM"
	}

	local backdropValues = {
		["Default"] = L["Default"],
		["Transparent"] = L["Transparent"],
		["NoBackdrop"] = NONE
	}

	local options = {
		order = 50,
		type = "group",
		childGroups = "tab",
		name = string.format("|cff1784d1%s|r", L["AddOn Skins"]),
		args = {
			skins = {
				order = 1,
				type = "group",
				childGroups = "tab",
				name = L["Skins"],
				get = function(info) return E.db.addOnSkins.skins[info[#info]] end,
				set = function(info, value)
					E.db.addOnSkins.skins[info[#info]] = value
					E:StaticPopup_Show("PRIVATE_RL")
				end,
				args = {
					header = {
						order = 1,
						type = "header",
						name = L["Skins"]
					}
				}
			},
			misc = {
				order = 2,
				type = "group",
				childGroups = "tab",
				name = L["Misc Options"],
				args = {
					header = {
						order = 1,
						type = "header",
						name = L["Misc Options"],
					},
					skadaGroup = {
						order = 2,
						type = "group",
						name = "Skada",
						get = function(info) return E.db.addOnSkins[info[#info]] end,
						set = function(info, value)
							E.db.addOnSkins[info[#info]] = value
							Skada:ApplySettings()
						end,
						disabled = function() return not AS:IsAddonLODorEnabled("Skada") end,
						args = {
							skadaTemplate = {
								order = 1,
								type = "select",
								name = L["Template"],
								values = backdropValues
							},
							skadaTemplateGloss = {
								order = 2,
								type = "toggle",
								name = L["Template Gloss"],
								disabled = function() return E.db.addOnSkins.skadaTemplate ~= "Default" or not AS:IsAddonLODorEnabled("Skada") end
							},
							spacer = {
								order = 3,
								type = "description",
								name = ""
							},
							skadaTitleTemplate = {
								order = 4,
								type = "select",
								name = L["Title Template"],
								values = backdropValues
							},
							skadaTitleTemplateGloss = {
								order = 5,
								type = "toggle",
								name = L["Title Template Gloss"],
								disabled = function() return E.db.addOnSkins.skadaTitleTemplate ~= "Default" or not AS:IsAddonLODorEnabled("Skada") end
							}
						}
					},
					recountGroup = {
						order = 3,
						type = "group",
						name = "Recount",
						get = function(info) return E.db.addOnSkins[info[#info]] end,
						set = function(info, value)
							local db = E.db.addOnSkins
							db[info[#info]] = value
							Recount.MainWindow.header:SetTemplate(db.recountTitleTemplate, db.recountTitleTemplate == "Default" and db.recountTitleTemplateGloss or false)
							Recount.MainWindow.backdrop:SetTemplate(db.recountTemplate, db.recountTemplate == "Default" and db.recountTemplateGloss or false)
						end,
						disabled = function() return not AS:IsAddonLODorEnabled("Recount") end,
						args = {
							recountTemplate = {
								order = 1,
								type = "select",
								name = L["Template"],
								values = backdropValues
							},
							recountTemplateGloss = {
								order = 2,
								type = "toggle",
								name = L["Template Gloss"],
								disabled = function() return E.db.addOnSkins.recountTemplate ~= "Default" or not AS:IsAddonLODorEnabled("Recount") end
							},
							spacer = {
								order = 3,
								type = "description",
								name = ""
							},
							recountTitleTemplate = {
								order = 4,
								type = "select",
								name = L["Title Template"],
								values = backdropValues
							},
							recountTitleTemplateGloss = {
								order = 5,
								type = "toggle",
								name = L["Title Template Gloss"],
								disabled = function() return E.db.addOnSkins.recountTitleTemplate ~= "Default" or not AS:IsAddonLODorEnabled("Recount") end
							}
						}
					},
					omenGroup = {
						order = 4,
						type = "group",
						name = "Omen",
						get = function(info) return E.db.addOnSkins[info[#info]] end,
						set = function(info, value)
							local db = E.db.addOnSkins
							db[info[#info]] = value
							Omen.Title:SetTemplate(db.omenTitleTemplate, db.omenTitleTemplate == "Default" and db.omenTitleTemplateGloss or false)
							Omen.BarList:SetTemplate(db.omenTemplate, db.omenTemplate == "Default" and db.omenTemplateGloss or false)
						end,
						disabled = function() return not AS:IsAddonLODorEnabled("Omen") end,
						args = {
							omenTemplate = {
								order = 1,
								type = "select",
								name = L["Template"],
								values = backdropValues
							},
							omenTemplateGloss = {
								order = 2,
								type = "toggle",
								name = L["Template Gloss"],
								disabled = function() return E.db.addOnSkins.omenTemplate ~= "Default" or not AS:IsAddonLODorEnabled("Omen") end
							},
							spacer = {
								order = 3,
								type = "description",
								name = ""
							},
							omenTitleTemplate = {
								order = 4,
								type = "select",
								name = L["Title Template"],
								values = backdropValues
							},
							omenTitleTemplateGloss = {
								order = 5,
								type = "toggle",
								name = L["Title Template Gloss"],
								disabled = function() return E.db.addOnSkins.omenTitleTemplate ~= "Default" or not AS:IsAddonLODorEnabled("Omen") end
							}
						}
					},
					detailsGroup = {
						order = 5,
						type = "group",
						name = "Details",
						disabled = function() return not AS:IsAddonLODorEnabled("Details") end,
						args = {
							detailsClassGradient = {
								order = 1,
								type = "toggle",
								name = "Use ElvUI Class Gradients",
								desc = "Use the Base and Gradient class colors from UnitFrames > General > Colors > Gradient for Details bars. Details itself is not modified.",
								get = function() return E.db.addOnSkins.detailsClassGradient end,
								set = function(_, value)
									E.db.addOnSkins.detailsClassGradient = value
									if AS.RefreshDetailsClassGradients then
										AS:RefreshDetailsClassGradients()
									end
								end
							},
							detailsBarShadows = {
								order = 2,
								type = "toggle",
								name = "Use ElvUI Fill Shadows",
								desc = "Draw a shadow around the visible Details fill texture only, using ElvUI's Skins > Shadows master enable, color and size.",
								get = function() return E.db.addOnSkins.detailsBarShadows end,
								set = function(_, value)
									E.db.addOnSkins.detailsBarShadows = value
									if AS.RefreshDetailsBarShadows then
										AS:RefreshDetailsBarShadows()
									end
								end
							}
						}
					},
					cellGroup = {
						order = 6,
						type = "group",
						name = "Cell",
						disabled = function() return not AS:IsAddonLODorEnabled("Cell") end,
						args = {
							cellGradient = {
								order = 1,
								type = "toggle",
								name = "Cell Gradient",
								desc = "Use ElvUI's UnitFrame class Base and Gradient colors on Cell player health bars. Cell itself is not modified.",
								get = function() return E.db.addOnSkins.cellGradient end,
								set = function(_, value)
									E.db.addOnSkins.cellGradient = value
									if AS.RefreshCellGradients then
										AS:RefreshCellGradients()
									end
								end
							}
						}
					},
					dbmGroup = {
						order = 7,
						type = "group",
						name = "DBM",
						get = function(info) return E.db.addOnSkins[info[#info]] end,
						set = function(info, value)
							E.db.addOnSkins[info[#info]] = value
							if DBM.ReleaseRevision >= 20220412000000 then -- 9.2.14
								DBT:ApplyStyle()
							else
								DBM.Bars:ApplyStyle()
							end
							DBM.BossHealth:UpdateSettings()
						end,
						disabled = function() return not AS:IsAddonLODorEnabled("DBM-Core") end,
						args = {
							dbmBarHeight = {
								order = 1,
								type = "range",
								min = 6, max = 60, step = 1,
								name = "Bar Height",
								hidden = function() return DBM.ReleaseRevision > 7000 end
							},
							dbmFont = {
								order = 2,
								type = "select",
								dialogControl = "LSM30_Font",
								name = L["Font"],
								values = AceGUIWidgetLSMlists.font,
								hidden = function() return DBM.ReleaseRevision > 7000 end
							},
							dbmFontSize = {
								order = 3,
								type = "range",
								min = 6, max = 22, step = 1,
								name = L["Font Size"],
								hidden = function() return DBM.ReleaseRevision > 7000 end
							},
							dbmFontOutline = {
								order = 4,
								type = "select",
								name = L["Font Outline"],
								values = {
									["NONE"] = L["None"],
									["OUTLINE"] = "OUTLINE",
									["MONOCHROMEOUTLINE"] = "MONOCROMEOUTLINE",
									["THICKOUTLINE"] = "THICKOUTLINE"
								},
								hidden = function() return DBM.ReleaseRevision > 7000 end
							},
							dbmIconSize = {
								order = 5,
								type = "range",
								min = 0.1, max = 2, step = 0.1,
								name = L["Icon Size"],
							},
							dbmTemplate = {
								order = 6,
								type = "select",
								name = L["Template"],
								values = backdropValues
							},
							DBMSkinHalf = {
								order = 7,
								type = "toggle",
								name = L["DBM Half-bar Skin"]
							}
						}
					},
					waGroup = {
						order = 8,
						type = "group",
						name = "WeakAuras",
						get = function(info) return E.db.addOnSkins[info[#info]] end,
						set = function(info, value)
							E.db.addOnSkins[info[#info]] = value
							E:StaticPopup_Show("PRIVATE_RL")
						end,
						disabled = function() return not AS:IsAddonLODorEnabled("WeakAuras") end,
						hidden = WeakAuras and WeakAuras.IsCorrectVersion ~= nil or false,
						args = {
							weakAuraAuraBar = {
								order = 1,
								type = "toggle",
								name = L["AuraBar Backdrop"]
							},
							weakAuraIconCooldown = {
								order = 2,
								type = "toggle",
								name = L["Icon Cooldown"]
							}
						}
					},
					chatBarGroup = {
						order = 9,
						type = "group",
						name = "ChatBar",
						get = function(info) return E.db.addOnSkins[info[#info]] end,
						set = function(info, value)
							E.db.addOnSkins[info[#info]] = value
							ChatBar_UpdateButtonOrientation()
							ChatBar_UpdateButtons()
						end,
						disabled = function() return not AS:IsAddonLODorEnabled("ChatBar") end,
						args = {
							chatBarSize = {
								order = 1,
								type = "range",
								min = 0, max = 60, step = 1,
								name = "Button Size"
							},
							chatBarSpacing = {
								order = 2,
								type = "range",
								min = 0, max = 60, step = 1,
								name = "Button Spacing"
							},
							chatBarTextPoint = {
								order = 3,
								type = "select",
								name = L["Text Position"],
								values = positionValues
							},
							chatBarTextXOffset = {
								order = 4,
								type = "range",
								min = -300, max = 300, step = 1,
								name = L["Text xOffset"],
								desc = L["Offset position for text."]
							},
							chatBarTextYOffset = {
								order = 5,
								type = "range",
								min = -300, max = 300, step = 1,
								name = L["Text yOffset"],
								desc = L["Offset position for text."]
							}
						}
					},
					bwGroup = {
						order = 10,
						type = "group",
						name = "BigWigs",
						get = function(info) return E.db.addOnSkins[info[#info]] end,
						set = function(info, value) E.db.addOnSkins[info[#info]] = value end,
						disabled = function() return not AS:IsAddonLODorEnabled("BigWigs") end,
						args = {
							bigwigsBarHeight = {
								order = 1,
								type = "range",
								min = 10, max = 40, step = 1,
								name = "Bar Height"
							},
							bigwigsFontSize = {
								order = 2,
								type = "range",
								min = 6, max = 22, step = 1,
								name = L["Font Size"]
							},
							bigwigsFontOutline = {
								order = 3,
								type = "select",
								name = L["Font Outline"],
								values = {
									["NONE"] = L["None"],
									["OUTLINE"] = "OUTLINE",
									["MONOCHROMEOUTLINE"] = "MONOCROMEOUTLINE",
									["THICKOUTLINE"] = "THICKOUTLINE"
								}
							}
						}
					}
				}
			},
			embed = {
				order = 3,
				type = "group",
				name = "Embed Settings",
				get = function(info) return E.db.addOnSkins.embed[info[#info]] end,
				set = function(info, value)
					E.db.addOnSkins.embed[info[#info]] = value
					E:GetModule("EmbedSystem"):EmbedUpdate()
				end,
				args = {
					desc = {
						order = 1,
						type = "description",
						name = "Settings to control Embedded AddOns: Available Embeds: Omen | Skada | Recount ",
					},
					embedType = {
						order = 2,
						type = "select",
						name = L["Embed Type"],
						values = {
							["DISABLE"] = L["Disable"],
							["SINGLE"] = L["Single"],
							["DOUBLE"] = L["Double"]
						},
					},
					leftWindow = {
						order = 3,
						type = "select",
						name = L["Left Panel"],
						values = {
							["Recount"] = "Recount",
							["Omen"] = "Omen",
							["Skada"] = "Skada",
							["Details"] = "Details"
						},
						disabled = function() return E.db.addOnSkins.embed.embedType == "DISABLE" end
					},
					rightWindow = {
						order = 4,
						type = "select",
						name = L["Right Panel"],
						values = {
							["Recount"] = "Recount",
							["Omen"] = "Omen",
							["Skada"] = "Skada",
							["Details"] = "Details"
						},
						disabled = function() return E.db.addOnSkins.embed.embedType ~= "DOUBLE" end
					},
					leftWindowWidth = {
						order = 5,
						type = "range",
						min = 100, max = 300, step = 1,
						name = L["Left Window Width"]
					},
					hideChat = {
						order = 6,
						type = "select",
						name = "Hide Chat Frame",
						values = E:GetModule("EmbedSystem"):GetChatWindowInfo(),
						disabled = function() return E.db.addOnSkins.embed.embedType == "DISABLE" end
					},
					rightChatPanel = {
						order = 7,
						type = "toggle",
						name = "Embed into Right Chat Panel"
					},
					belowTopTab = {
						order = 8,
						type = "toggle",
						name = "Embed Below Top Tab"
					}
				}
			},
			squidBots = {
				order = 4,
				type = "group",
				name = "SquidBots Bar",
				disabled = function() return not _G.SquidBotsLite_GetLook end,
				get = function(info)
					local key = info[#info]
					if key == "outline" then return SquidBotsLite_GetLook("outline") == "" and "NONE" or SquidBotsLite_GetLook("outline") end
					if key == "font" then
						local path = SquidBotsLite_GetLook("font")
						if not path then return nil end
						for name, file in pairs(LibStub("LibSharedMedia-3.0"):HashTable("font")) do
							if file == path then return name end
						end
						return nil
					end
					return SquidBotsLite_GetLook(key)
				end,
				set = function(info, value)
					local key = info[#info]
					if key == "outline" then value = value == "NONE" and "" or value end
					if key == "font" then value = LibStub("LibSharedMedia-3.0"):Fetch("font", value) end
					SquidBotsLite_SetLook(key, value)
				end,
				args = {
					vertical = { order = 1, type = "toggle", name = "Vertical (top to bottom)", desc = "Arrange the buttons from top to bottom instead of left to right." },
					gap = { order = 2, type = "range", min = -10, max = 60, step = 1, name = "Button spacing", desc = "Extra pixels between the buttons (0 = default)." },
					captionHeader = { order = 3, type = "header", name = "Text under the buttons" },
					capX = { order = 4, type = "range", min = -50, max = 50, step = 1, name = "Text X offset" },
					capY = { order = 5, type = "range", min = -50, max = 50, step = 1, name = "Text Y offset" },
					font = { order = 6, type = "select", dialogControl = "LSM30_Font", name = L["Font"], values = AceGUIWidgetLSMlists.font },
					size = { order = 7, type = "range", min = 6, max = 22, step = 1, name = L["Font Size"] },
					outline = {
						order = 8, type = "select", name = L["Font Outline"],
						values = { NONE = L["None"], OUTLINE = "OUTLINE", THICKOUTLINE = "THICKOUTLINE", MONOCHROMEOUTLINE = "MONOCHROMEOUTLINE" },
					},
					reset = {
						order = 9, type = "execute", name = "Reset",
						func = function() SquidBotsLite_ResetLook() end,
					},
				},
			}
		}
	}

	local target = options.args.skins.args

	for _, addonName in ipairs(addonList) do
		AS:RegisterAddonOption(addonName, target)
	end

	if target.WeakAuras then
		target.WeakAuras.hidden = WeakAuras and WeakAuras.IsCorrectVersion ~= nil or false
	end

	E.Options.args.addOnSkins = options
end

function AS:Initialize()
	MigrateCoAProfileStorage()
	EP:RegisterPlugin(AddOnName, getOptions)
end

local function InitializeCallback()
	AS:Initialize()
end

E:RegisterModule(AS:GetName(), InitializeCallback)