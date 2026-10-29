local E, _, V, P, G = unpack(ElvUI); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local _, L = unpack(select(2, ...))

E.Options.args.skins = {
	type = "group",
	name = L["Skins"],
	childGroups = "tree",
	args = {
		intro = {
			order = 1,
			type = "description",
			name = L["SKINS_DESC"]
		},
		blizzardEnable = {
			order = 2,
			type = "toggle",
			name = L["Blizzard"],
			get = function(info) return E.private.skins.blizzard.enable end,
			set = function(info, value) E.private.skins.blizzard.enable = value E:StaticPopup_Show("PRIVATE_RL") end
		},
		ace3 = {
			order = 3,
			type = "toggle",
			name = "Ace3",
			get = function(info) return E.private.skins.ace3.enable end,
			set = function(info, value) E.private.skins.ace3.enable = value E:StaticPopup_Show("PRIVATE_RL") end
		},
		checkBoxSkin = {
			order = 4,
			type = "toggle",
			name = L["CheckBox Skin"],
			get = function(info) return E.private.skins.checkBoxSkin end,
			set = function(info, value) E.private.skins.checkBoxSkin = value E:StaticPopup_Show("PRIVATE_RL") end,
			disabled = function() return not E.private.skins.ace3.enable and not E.private.skins.blizzard.enable end
		},
		dropdownCheckBoxSkin = {
			order = 5,
			type = "toggle",
			name = L["Dropdown CheckBox Skin"],
			get = function(info) return E.private.skins.dropdownCheckBoxSkin end,
			set = function(info, value) E.private.skins.dropdownCheckBoxSkin = value E:StaticPopup_Show("PRIVATE_RL") end,
			disabled = function() return not E.private.skins.ace3.enable and not E.private.skins.blizzard.enable end
		},

		taxiScale = {
			order = 6,
			type = "range",
			name = L["Flight Map Scale"],
			desc = L["Scales the whole flight map including all flight points, so they stay clickable."],
			min = 0.8, max = 2, step = 0.05,
			isPercent = true,
			get = function() return E.private.skins.taxiScale or 1 end,
			set = function(_, value)
				E.private.skins.taxiScale = value
				local S = E:GetModule("Skins")
				if S.UpdateTaxiScale then S:UpdateTaxiScale() end
			end
		},

		shadows = {
			order = 50,
			type = "group",
			name = "Shadows",
			guiInline = false,
			args = {
				intro = {
					order = 1,
					type = "description",
					name = "Adds a configurable outer shadow to ElvUI's main visible frames. Group units and aura icons can be shadowed individually.",
				},
				enable = {
					order = 2,
					type = "toggle",
					name = "Enable Shadows",
					get = function() return E.db.frameShadows.enable end,
					set = function(_, value) E.db.frameShadows.enable = value E:GetModule("Skins"):UpdateFrameShadows() end,
				},
				color = {
					order = 3,
					type = "color",
					name = "Shadow Color",
					hasAlpha = true,
					get = function()
						local c = E.db.frameShadows.color
						return c.r, c.g, c.b, c.a
					end,
					set = function(_, r, g, b, a)
						local c = E.db.frameShadows.color
						c.r, c.g, c.b, c.a = r, g, b, a
						E:GetModule("Skins"):UpdateFrameShadows()
					end,
				},
				size = {
					order = 4,
					type = "range",
					name = "Shadow Size",
					min = 1, max = 20, step = 1,
					get = function() return E.db.frameShadows.size end,
					set = function(_, value) E.db.frameShadows.size = value E:GetModule("Skins"):UpdateFrameShadows() end,
				},
				actionbars = {
					order = 10,
					type = "group",
					name = "Action Bars",
					guiInline = true,
					args = {},
				},
				unitframes = {
					order = 20,
					type = "group",
					name = "Unit Frames",
					guiInline = true,
					args = {},
				},
				groups = {
					order = 30,
					type = "group",
					name = "Group Frames",
					guiInline = true,
					args = {},
				},
				castbars = {
					order = 35,
					type = "group",
					name = "Cast Bars",
					guiInline = true,
					args = {},
				},
				unitframeauras = {
					order = 36,
					type = "group",
					name = "Unit Frame Auras",
					guiInline = true,
					args = {},
				},
				wildcard = {
					order = 37,
					type = "group",
					name = "Wildcard",
					guiInline = true,
					hidden = function()
						return not (C_Player and C_Player.IsHero and C_Player:IsHero())
					end,
					args = {},
				},
				nameplates = {
					order = 38,
					type = "group",
					name = "Nameplates",
					guiInline = true,
					args = {},
				},
				other = {
					order = 40,
					type = "group",
					name = "Other Frames",
					guiInline = true,
					args = {},
				},
			},
		},
		addons = {
			order = 60,
			type = "group",
			name = "Addons",
			args = {
				intro = {
					order = 1,
					type = "description",
					name = "Shadow support for compatible ElvUI addons. Shadow color and size are controlled in Skins > Shadows.",
				},
				coaResources = {
					order = 10,
					type = "group",
					name = "CoA Resources",
					guiInline = true,
					hidden = function() return not (IsAddOnLoaded and IsAddOnLoaded("ElvUI_CoAResources")) end,
					args = {},
				},
				dtBars2 = {
					order = 20,
					type = "group",
					name = "DTBars2",
					guiInline = true,
					hidden = function() return not (IsAddOnLoaded and IsAddOnLoaded("ElvUI_DTBars2")) end,
					args = {},
				},
				enhanced = {
					order = 30,
					type = "group",
					name = "ElvUI Enhanced",
					guiInline = true,
					hidden = function() return not (IsAddOnLoaded and IsAddOnLoaded("ElvUI_Enhanced")) end,
					args = {},
				},
				squidBotsLite = {
					order = 40,
					type = "group",
					name = "SquidBots Lite",
					guiInline = true,
					hidden = function() return not (IsAddOnLoaded and IsAddOnLoaded("SquidBotsLite")) end,
					args = {},
				},
			},
		},
		blizzard = {
			order = 100,
			type = "group",
			name = "Blizzard",
			get = function(info) return E.private.skins.blizzard[info[#info]] end,
			set = function(info, value) E.private.skins.blizzard[info[#info]] = value E:StaticPopup_Show("CONFIG_RL") end,
			disabled = function() return not E.private.skins.blizzard.enable end,
			guiInline = true,
			args = {
				achievement = {
					type = "toggle",
					name = L["ACHIEVEMENTS"],
					desc = L["TOGGLESKIN_DESC"]
				},
				alertframes = {
					type = "toggle",
					name = L["Alert Frames"],
					desc = L["TOGGLESKIN_DESC"]
				},
				arena = {
					type = "toggle",
					name = L["Arena Frame"],
					desc = L["TOGGLESKIN_DESC"]
				},
				arenaregistrar = {
					type = "toggle",
					name = L["Arena Registrar"],
					desc = L["TOGGLESKIN_DESC"]
				},
				auctionhouse = {
					type = "toggle",
					name = L["AUCTIONS"],
					desc = L["TOGGLESKIN_DESC"]
				},
				bags = {
					type = "toggle",
					name = L["Bags"],
					desc = L["TOGGLESKIN_DESC"],
					disabled = function() return E.private.bags.enable end
				},
				barber = {
					type = "toggle",
					name = L["BARBERSHOP"],
					desc = L["TOGGLESKIN_DESC"]
				},
				bgmap = {
					type = "toggle",
					name = L["BG Map"],
					desc = L["TOGGLESKIN_DESC"]
				},
				bgscore = {
					type = "toggle",
					name = L["BG Score"],
					desc = L["TOGGLESKIN_DESC"]
				},
				binding = {
					type = "toggle",
					name = L["KEY_BINDINGS"],
					desc = L["TOGGLESKIN_DESC"]
				},
				BlizzardOptions = {
					type = "toggle",
					name = L["INTERFACE_OPTIONS"],
					desc = L["TOGGLESKIN_DESC"]
				},
				calendar = {
					type = "toggle",
					name = L["Calendar Frame"],
					desc = L["TOGGLESKIN_DESC"]
				},
				callboard = {
					type = "toggle",
					name = L["CallBoard Frame"],
					desc = L["TOGGLESKIN_DESC"]
				},
				character = {
					type = "toggle",
					name = L["Character Frame"],
					desc = L["TOGGLESKIN_DESC"]
				},
				debug = {
					type = "toggle",
					name = L["Debug Tools"],
					desc = L["TOGGLESKIN_DESC"]
				},
				dressingroom = {
					type = "toggle",
					name = L["DRESSUP_FRAME"],
					desc = L["TOGGLESKIN_DESC"]
				},
				friends = {
					type = "toggle",
					name = L["FRIENDS"],
					desc = L["TOGGLESKIN_DESC"]
				},
				gbank = {
					type = "toggle",
					name = L["GUILD_BANK"],
					desc = L["TOGGLESKIN_DESC"]
				},
				gossip = {
					type = "toggle",
					name = L["Gossip Frame"],
					desc = L["TOGGLESKIN_DESC"]
				},
				gmchat = {
					type = "toggle",
					name = L["GM Chat"],
					desc = L["TOGGLESKIN_DESC"]
				},
				guildregistrar = {
					type = "toggle",
					name = L["Guild Registrar"],
					desc = L["TOGGLESKIN_DESC"]
				},
				help = {
					type = "toggle",
					name = L["Help Frame"],
					desc = L["TOGGLESKIN_DESC"]
				},
				inspect = {
					type = "toggle",
					name = L["INSPECT"],
					desc = L["TOGGLESKIN_DESC"]
				},
				lfd = {
					type = "toggle",
					name = L["LFD Frame"],
					desc = L["TOGGLESKIN_DESC"]
				},
				lfr = {
					type = "toggle",
					name = L["LFR Frame"],
					desc = L["TOGGLESKIN_DESC"]
				},
				loot = {
					type = "toggle",
					name = L["Loot Frames"],
					desc = L["TOGGLESKIN_DESC"],
					disabled = function() return E.private.general.loot end
				},
				lootRoll = {
					type = "toggle",
					name = L["Loot Roll"],
					desc = L["TOGGLESKIN_DESC"],
					disabled = function() return E.private.general.lootRoll end
				},
				macro = {
					type = "toggle",
					name = L["MACROS"],
					desc = L["TOGGLESKIN_DESC"]
				},
				mail = {
					type = "toggle",
					name = L["MAIL_LABEL"],
					desc = L["TOGGLESKIN_DESC"]
				},
				merchant = {
					type = "toggle",
					name = L["MERCHANT"],
					desc = L["TOGGLESKIN_DESC"]
				},
				misc = {
					type = "toggle",
					name = L["Misc Frames"],
					desc = L["TOGGLESKIN_DESC"]
				},
				mirrorTimers = {
					type = "toggle",
					name = L["Mirror Timers"],
					desc = L["TOGGLESKIN_DESC"]
				},
				pathtoascension = {
					type = "toggle",
					name = L["Path To Ascension"],
					desc = L["TOGGLESKIN_DESC"]
				},
				petition = {
					type = "toggle",
					name = L["Petition Frame"],
					desc = L["TOGGLESKIN_DESC"]
				},
				pvp = {
					type = "toggle",
					name = L["PvP Frames"],
					desc = L["TOGGLESKIN_DESC"]
				},
				quest = {
					type = "toggle",
					name = L["Quest Frames"],
					desc = L["TOGGLESKIN_DESC"]
				},
				raid = {
					type = "toggle",
					name = L["Raid Frame"],
					desc = L["TOGGLESKIN_DESC"]
				},
				socket = {
					type = "toggle",
					name = L["Socket Frame"],
					desc = L["TOGGLESKIN_DESC"]
				},
				spellbook = {
					type = "toggle",
					name = L["SPELLBOOK"],
					desc = L["TOGGLESKIN_DESC"]
				},
				stable = {
					type = "toggle",
					name = L["Stable"],
					desc = L["TOGGLESKIN_DESC"]
				},
				tabard = {
					type = "toggle",
					name = L["Tabard Frame"],
					desc = L["TOGGLESKIN_DESC"]
				},
				talent = {
					type = "toggle",
					name = L["TALENTS"],
					desc = L["TOGGLESKIN_DESC"]
				},
				taxi = {
					type = "toggle",
					name = L["FLIGHT_MAP"],
					desc = L["TOGGLESKIN_DESC"]
				},
				timemanager = {
					type = "toggle",
					name = L["TIMEMANAGER_TITLE"],
					desc = L["TOGGLESKIN_DESC"]
				},
				tooltip = {
					type = "toggle",
					name = L["Tooltip"],
					desc = L["TOGGLESKIN_DESC"]
				},
				trade = {
					type = "toggle",
					name = L["TRADE"],
					desc = L["TOGGLESKIN_DESC"]
				},
				tradeskill = {
					type = "toggle",
					name = L["TRADESKILLS"],
					desc = L["TOGGLESKIN_DESC"]
				},
				trainer = {
					type = "toggle",
					name = L["Trainer Frame"],
					desc = L["TOGGLESKIN_DESC"]
				},
				tutorial = {
					type = "toggle",
					name = L["Tutorial Frame"],
					desc = L["TOGGLESKIN_DESC"]
				},
				watchframe = {
					type = "toggle",
					name = L["Watch Frame"],
					desc = L["TOGGLESKIN_DESC"]
				},
				worldmap = {
					type = "toggle",
					name = L["WORLD_MAP"],
					desc = L["TOGGLESKIN_DESC"]
				},
				WorldStateFrame = {
					type = "toggle",
					name = L["World State Frame"],
					desc = L["TOGGLESKIN_DESC"]
				}
			}
		}
	}
}

-- Populate Skins -> Shadows frame toggles.
do
	local shadowArgs = E.Options.args.skins.args.shadows.args
	local function AddToggle(group, key, name, order)
		shadowArgs[group].args[key] = {
			order = order,
			type = "toggle",
			name = name,
			get = function() return E.db.frameShadows.frames[key] end,
			set = function(_, value)
				E.db.frameShadows.frames[key] = value
				E:GetModule("Skins"):UpdateFrameShadow(key)
			end,
			disabled = function() return not E.db.frameShadows.enable end,
		}
	end

	for i = 1, 10 do AddToggle("actionbars", "actionbar"..i, "Action Bar "..i, i) end
	AddToggle("actionbars", "petbar", "Pet Bar", 20)
	AddToggle("actionbars", "stancebar", "Stance Bar", 21)
	AddToggle("actionbars", "totembar", "Totem Bar", 22)
	AddToggle("actionbars", "microbar", "Micro Bar", 23)

	AddToggle("unitframes", "player", "Player", 1)
	AddToggle("unitframes", "target", "Target", 2)
	AddToggle("unitframes", "targettarget", "Target of Target", 3)
	AddToggle("unitframes", "focus", "Focus", 4)
	AddToggle("unitframes", "pet", "Pet", 5)
	AddToggle("unitframes", "guardians", "Guardians", 10)
	AddToggle("unitframes", "playerclassbar", "Player Class Bar", 6)
	AddToggle("unitframes", "combobar", "Combo Bar (Detached)", 9)
	AddToggle("unitframes", "playerpowerbar", "Player Power Bar (Detached)", 7)
	AddToggle("unitframes", "targetpowerbar", "Target Power Bar (Detached)", 8)

	AddToggle("groups", "party", "Party Frames", 1)
	AddToggle("groups", "raid", "Raid Frames", 2)
	AddToggle("groups", "raid40", "Raid-40 Frames", 3)
	AddToggle("groups", "boss", "Boss Frames", 4)
	AddToggle("groups", "arena", "Arena Frames", 5)

	AddToggle("castbars", "playercastbar", "Player Cast Bar", 1)
	AddToggle("castbars", "targetcastbar", "Target Cast Bar", 2)
	AddToggle("castbars", "petcastbar", "Pet Cast Bar", 3)
	AddToggle("castbars", "partycastbar", "Party Cast Bars", 4)
	AddToggle("castbars", "bosscastbar", "Boss Cast Bars", 5)

	AddToggle("unitframeauras", "ufplayerbuffs", "Player Buff Icons", 1)
	AddToggle("unitframeauras", "ufplayerdebuffs", "Player Debuff Icons", 2)
	AddToggle("unitframeauras", "uftargetbuffs", "Target Buff Icons", 3)
	AddToggle("unitframeauras", "uftargetdebuffs", "Target Debuff Icons", 4)
	AddToggle("unitframeauras", "ufpartybuffs", "Party Buff Icons", 5)
	AddToggle("unitframeauras", "ufpartydebuffs", "Party Debuff Icons", 6)
	AddToggle("unitframeauras", "ufbossbuffs", "Boss Buff Icons", 7)
	AddToggle("unitframeauras", "ufbossdebuffs", "Boss Debuff Icons", 8)

	AddToggle("nameplates", "nameplatehealth", "Health Bar", 1)
	AddToggle("nameplates", "nameplatecastbar", "Cast Bar", 2)
	AddToggle("nameplates", "nameplatecasticon", "Cast Icon", 3)
	AddToggle("nameplates", "nameplatebuffs", "Buffs", 4)
	AddToggle("nameplates", "nameplatedebuffs", "Debuffs", 5)

	AddToggle("wildcard", "wildcardenergy", "Energy Bar", 1)
	AddToggle("wildcard", "wildcardrage", "Rage Bar", 2)

	AddToggle("other", "experience", "Experience Bar", 1)
	AddToggle("other", "reputation", "Reputation Bar", 2)
	AddToggle("other", "petexperience", "Pet Experience Bar", 3)
	AddToggle("other", "minimap", "Minimap", 4)
	AddToggle("other", "toppanel", "Top Panel", 5)
	AddToggle("other", "bottompanel", "Bottom Panel", 6)
	AddToggle("other", "leftchat", "Left Chat Panel", 7)
	AddToggle("other", "rightchat", "Right Chat Panel", 8)
	AddToggle("other", "bags", "Bags", 9)
	AddToggle("other", "bank", "Bank", 10)
	AddToggle("other", "buffs", "Player Buffs", 11)
	AddToggle("other", "debuffs", "Player Debuffs", 12)
	AddToggle("other", "tooltips", "Tooltips", 13)
	AddToggle("other", "threat", "Threat Bar", 14)
	AddToggle("other", "lootframe", "Loot Frame", 15)
	AddToggle("other", "lootroll", "Loot Roll", 16)
	AddToggle("other", "minimapbuttonbar", "Minimap Button Frame", 17)
	AddToggle("other", "blizzcharacter", "Character Window (+ Tabs)", 18)
	AddToggle("other", "blizzspellbook", "Spellbook & Professions (+ Tabs)", 19)
	AddToggle("other", "blizzfriends", "Friends List (+ Tabs)", 20)
	AddToggle("other", "blizzescape", "Escape Menu", 21)
	AddToggle("other", "blizzquestlog", "Quest Log", 22)
	AddToggle("other", "blizzdungeon", "Dungeon Browser (+ Tabs)", 23)
	AddToggle("other", "blizzhelp", "Help Window (+ Tabs)", 24)
	AddToggle("other", "blizzworldmap", "World Map", 25)
	AddToggle("other", "mirrortimers", "Mirror Timers", 26)
end

-- Populate Skins -> Addons with addon-specific shadow support.
do
	local addonArgs = E.Options.args.skins.args.addons.args
	local function AddAddonToggle(group, key, name, order)
		addonArgs[group].args[key] = {
			order = order,
			type = "toggle",
			name = name,
			get = function() return E.db.frameShadows.frames[key] end,
			set = function(_, value)
				E.db.frameShadows.frames[key] = value
				E:GetModule("Skins"):UpdateFrameShadow(key)
			end,
			disabled = function() return not E.db.frameShadows.enable end,
		}
	end

	AddAddonToggle("coaResources", "coaresources", "CoA Resource Bar", 1)
	AddAddonToggle("dtBars2", "dtbars2", "DataText Bars", 1)
	AddAddonToggle("enhanced", "enhancedminimapbar", "Minimap Addon Bar", 1)
	AddAddonToggle("squidBotsLite", "squidbotslite", "Command Buttons", 1)
end
