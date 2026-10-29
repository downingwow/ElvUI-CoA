local MAJOR, MINOR = "LibElvUIPlugin-1.0", 31
local lib = LibStub:NewLibrary(MAJOR, MINOR)
if not lib then return end
-- GLOBALS: ElvUI

--[[----------------------------
Plugin Table Format: (for reference only).
	{
		name		- name of the plugin
		callback	- callback to call when ElvUI_OptionsUI is loaded
		isLib		- plugin is a library
		version		- version of the plugin (pulls version info from metadata, libraries can define their own)

	-- After new version recieved from another user:
		old			- plugin is old version
		newversion	- newer version number
	}

LibElvUIPlugin API:
	RegisterPlugin(name, callback, isLib, libVersion)
	-- Registers a module with the given name and option callback:
		name		- name of plugin
		verion		- version number
		isLib		- plugin is a library
		libVersion	- plugin library version (optional, defaults to 1)

	HookInitialize(table, function)
	-- Posthook ElvUI Initialize function:
		table		- addon table
		function	- function to call after Initialize (may be a string, that exists on the addons table: table['string'])
----------------------------]]--

local pairs, ipairs = pairs, ipairs
local tonumber, type = tonumber, type
local ceil = math.ceil
local format, gmatch, gsub, len, match, sub = string.format, string.gmatch, string.gsub, string.len, string.match, string.sub
local tinsert, wipe = table.insert, table.wipe

local GetAddOnMetadata = GetAddOnMetadata
local GetNumPartyMembers = GetNumRaidMembers
local GetNumRaidMembers = GetNumRaidMembers
local IsAddOnLoaded = IsAddOnLoaded
local IsInInstance = IsInInstance
local SendAddonMessage = SendAddonMessage

local UNKNOWN = UNKNOWN

lib.prefix = "ElvUIPluginVC"
lib.plugins = {}
lib.groupSize = 0
lib.index = 0

local MSG_OUTDATED = "Your version of %s %s is out of date (latest is version %s). You can download the latest version from the Ascension Launcher, or https://github.com/Ascension-Addons/ElvUI"
local HDR_CONFIG = "Plugins"
local HDR_INFORMATION = "LibElvUIPlugin-1.0.%d - Plugins Loaded (Green means you have current version, Red means out of date)"
local INFO_BY = "by"
local INFO_VERSION = "Version:"
local INFO_NEW = "Newest:"
local LIBRARY = "Library"

local locale = GetLocale()
if locale == "deDE" then
	MSG_OUTDATED = "Deine Version von %s %s ist veraltet (akutelle Version ist %s). Du kannst die aktuelle Version von https://github.com/Ascension-Addons/ElvUI/ herunterrladen."
	HDR_CONFIG = "Plugins"
	HDR_INFORMATION = "LibElvUIPlugin-1.0.%d - Plugins geladen (Grün bedeutet du hast die aktuelle Version, Rot bedeutet es ist veraltet)"
	INFO_BY = "von"
	INFO_VERSION = "Version:"
	INFO_NEW = "Neuste:"
	LIBRARY = "Bibliothek"
elseif locale == "ruRU" then
	MSG_OUTDATED = "Ваша версия %s %s устарела (последняя версия %s). Вы можете скачать последнюю версию на https://github.com/Ascension-Addons/ElvUI/"
	HDR_CONFIG = "Плагины"
	HDR_INFORMATION = "LibElvUIPlugin-1.0.%d - загруженные плагины (зеленый означает, что у вас последняя версия, красный - устаревшая)"
	INFO_BY = "от"
	INFO_VERSION = "Версия:"
	INFO_NEW = "Последняя:"
	LIBRARY = "Библиотека"
elseif locale == "zhCN" then
	MSG_OUTDATED = "你的 %s %s 版本已经过期 (最新版本是 %s)。你可以从 https://github.com/Ascension-Addons/ElvUI/ 下载最新版本"
	HDR_CONFIG = "插件"
	HDR_INFORMATION = "LibElvUIPlugin-1.0.%d - 载入的插件 (绿色表示拥有当前版本, 红色表示版本已经过期)"
	INFO_BY = "作者"
	INFO_VERSION = "版本:"
	INFO_NEW = "最新:"
	LIBRARY = "库"
elseif locale == "zhTW" then
	MSG_OUTDATED = "你的 %s %s 版本已經過期 (最新版本為 %s)。你可以透過 https://github.com/Ascension-Addons/ElvUI/ 下載最新的版本"
	HDR_CONFIG = "插件"
	HDR_INFORMATION = "LibElvUIPlugin-1.0.%d - 載入的插件 (綠色表示擁有當前版本, 紅色表示版本已經過期)"
	INFO_BY = "作者"
	INFO_VERSION = "版本:"
	INFO_NEW = "最新:"
	LIBRARY = "庫"
end

local E
local function checkElvUI()
	if not E then
		E = ElvUI[1]
		assert(E, "ElvUI not found.")
	end
end

-- Plugin option callbacks can add new root groups after AceConfigDialog already
-- built its TreeGroup. Notify the registry after plugin option changes so the
-- entire left navigation tree is rebuilt instead of only refreshing cached lines.
local function RefreshElvUIOptionsTree()
	if not E or not E.Libs or not E.Libs.AceConfigRegistry then return end

	local function notify()
		E.Libs.AceConfigRegistry:NotifyChange("ElvUI")
	end

	-- Delay by one frame when possible so a plugin callback can finish creating
	-- all of its option groups before AceConfig rebuilds the tree.
	if E.Delay then
		E:Delay(0, notify)
	else
		notify()
	end
end

-- Keep third-party ElvUI option pages from overflowing the root navigation.
-- Core option keys are captured by ElvUI_OptionsUI before plugin callbacks run.
-- Any new root group created later is treated as a plugin page and exposed under
-- the existing "Plugins" tree node. CoA Resources intentionally remains a root page.
lib.groupedOptionKeys = lib.groupedOptionKeys or {}

local PLUGIN_ROOT_EXCEPTIONS = {
	coaResources = true,
	search = true, -- ElvUI core Search stays at root and must never be grouped as a plugin.
}

local function BuildCoreOptionLookup()
	local core = { plugins = true }
	if E and E.OriginalOptions then
		for _, key in ipairs(E.OriginalOptions) do
			core[key] = true
		end
	end
	return core
end

local function MakeHiddenRootAlias(group)
	local alias = {}
	for key, value in pairs(group) do
		alias[key] = value
	end

	-- Keep the legacy root path valid for plugins which call
	-- AceConfigDialog:SelectGroup("ElvUI", "theirKey"), but do not render that
	-- duplicate entry in ElvUI's root tree. The args table is shared.
	alias.hidden = true
	return alias
end

local function FixKnownPluginOptionNames(key, group)
	-- ElvUI_DTBars2 can expose its Strata option with a nil localized name on
	-- a fresh character/profile load. AceConfig rejects nil option names and
	-- prevents the entire ElvUI options window from opening. Keep this fix
	-- deliberately scoped to that known option instead of rewriting plugin tables.
	if key == "dtbars" and type(group) == "table" and type(group.args) == "table" then
		local strata = group.args.strata
		if type(strata) == "table" and strata.name == nil then
			strata.name = "Strata"
		end
	end
end

local function OrganizePluginOptionGroups()
	if not E or not E.Options or not E.Options.args then return end
	local pluginRoot = E.Options.args.plugins
	if not pluginRoot or type(pluginRoot.args) ~= "table" then return end

	-- Search remains available internally, but there must be no visible Search
	-- entry either at root or inside the Plugins category.
	pluginRoot.args.search = nil
	E.Options.args.search = nil
	E.Options.args.searchEditBox = nil

	local core = BuildCoreOptionLookup()
	local candidates = {}
	for key, group in pairs(E.Options.args) do
		if not core[key] and not PLUGIN_ROOT_EXCEPTIONS[key] and key ~= "plugins"
		and type(group) == "table" and group.type == "group" then
			table.insert(candidates, key)
		end
	end

	for _, key in ipairs(candidates) do
		local current = E.Options.args[key]
		FixKnownPluginOptionNames(key, current)
		local state = lib.groupedOptionKeys[key]

		-- A plugin may rebuild its root option table later. Re-home the new table
		-- when that happens instead of keeping a stale copy under Plugins.
		if not state or current ~= state.alias then
			local source = current
			pluginRoot.args[key] = source
			local alias = MakeHiddenRootAlias(source)
			E.Options.args[key] = alias
			lib.groupedOptionKeys[key] = { source = source, alias = alias }
		elseif state and pluginRoot.args[key] ~= state.source then
			pluginRoot.args[key] = state.source
		end
	end
end


function lib:RegisterPlugin(name, callback, isLib, libVersion)
	checkElvUI()

	local plugin = {
		name = name,
		callback = callback
	}

	if isLib then
		plugin.isLib = true
		plugin.version = libVersion or 1
	else
		plugin.version = (name == MAJOR and MINOR) or GetAddOnMetadata(name, "Version") or UNKNOWN
	end

	lib.plugins[name] = plugin

	if not lib.registeredPrefix and E.global.general.versionCheck then
		lib.VCFrame:RegisterEvent("CHAT_MSG_ADDON")
		lib.VCFrame:RegisterEvent("RAID_ROSTER_UPDATE")
		lib.VCFrame:RegisterEvent("PARTY_MEMBERS_CHANGED")
		lib.VCFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
		lib.registeredPrefix = true
	end

	local loaded = IsAddOnLoaded("ElvUI_OptionsUI")
	if not loaded then
		lib.CFFrame:RegisterEvent("ADDON_LOADED")
	elseif loaded then
		if name ~= MAJOR then
			E.Options.args.plugins.args.plugins.name = lib:GeneratePluginList()
		end

		if callback then
			callback()
		end

		OrganizePluginOptionGroups()
		RefreshElvUIOptionsTree()
	end

	return plugin
end

local function SendVersionCheckMessage()
	lib:SendPluginVersionCheck(lib:GenerateVersionCheckMessage())
end

function lib:DelayedSendVersionCheck(delay)
	if not E.SendPluginVersionCheck then
		E.SendPluginVersionCheck = SendVersionCheckMessage
	end

	if not lib.SendMessageWaiting then
		lib.SendMessageWaiting = E:Delay(delay or 10, E.SendPluginVersionCheck)
	end
end

function lib:OptionsUILoaded(_, addon)
	if addon == "ElvUI_OptionsUI" then
		lib:GetPluginOptions()

		for _, plugin in pairs(lib.plugins) do
			if plugin.callback then
				plugin.callback()
			end
		end

		-- Collect third-party root option pages under the expandable Plugins
		-- category, then rebuild the tree once all callbacks have finished.
		OrganizePluginOptionGroups()
		RefreshElvUIOptionsTree()

		lib.CFFrame:UnregisterEvent("ADDON_LOADED")
	end
end

function lib:GenerateVersionCheckMessage()
	local list = ""
	for _, plugin in pairs(lib.plugins) do
		if plugin.name ~= MAJOR then
			list = list .. plugin.name .. "=" .. plugin.version .. ";"
		end
	end
	return list
end

function lib:GetPluginOptions()
	E.Options.args.plugins = {
		order = -10,
		type = "group",
		-- Keep the Plugins category visually distinct in ElvUI's left tree.
		-- Only the leading P is light blue; the remaining text stays white.
		name = (GetLocale() == "enUS" or GetLocale() == "enGB") and "|cff66ccffP|r|cfffffffflugins|r" or HDR_CONFIG,
		guiInline = false,
		args = {
			pluginheader = {
				order = 1,
				type = "header",
				name = format(HDR_INFORMATION, MINOR)
			},
			plugins = {
				order = 2,
				type = "description",
				name = lib:GeneratePluginList()
			}
		}
	}
end

do	-- this will handle `8.1.5.0015` into `8.150015` etc
	local verStrip = function(a, b) return a..gsub(b, "%.", "") end
	function lib:StripVersion(version)
		local ver = gsub(version, "(%d-%.)([%d%.]+)", verStrip)
		return tonumber(ver)
	end
end

function lib:VersionCheck(event, prefix, message, _, sender)
	if (event == "CHAT_MSG_ADDON" and prefix == lib.prefix) and (sender and message and not match(message, "^%s-$")) then
		if sender == E.myname then return end

		if not E.pluginRecievedOutOfDateMessage then
			for name, version in gmatch(message, "([^=]+)=([%d%p]+);") do
				local plugin = (version and name) and lib.plugins[name]
				if plugin and plugin.version then
					local Pver, ver = lib:StripVersion(plugin.version), lib:StripVersion(version)
					if (ver and Pver) and (ver > Pver) then
						plugin.old, plugin.newversion = true, version
						local title = GetAddOnMetadata(plugin.name, "Title") or plugin.name
						E:Print(format(MSG_OUTDATED, title, plugin.version, plugin.newversion))
						E.pluginRecievedOutOfDateMessage = true
					end
				end
			end
		end
	elseif event == "PLAYER_ENTERING_WORLD" then
		lib:DelayedSendVersionCheck()
	else
		local numRaid = GetNumRaidMembers()
		local num = numRaid > 0 and numRaid or (GetNumPartyMembers() + 1)

		if num ~= lib.groupSize then
			if num > 1 and num > lib.groupSize then
				lib:DelayedSendVersionCheck()
			end
			lib.groupSize = num
		end
	end
end

function lib:GeneratePluginList()
	local list = ""
	for _, plugin in pairs(lib.plugins) do
		if plugin.name ~= MAJOR then
			local author = GetAddOnMetadata(plugin.name, "Author")
			local title = GetAddOnMetadata(plugin.name, "Title") or plugin.name
			local color = (plugin.old and E:RGBToHex(1, 0, 0)) or E:RGBToHex(0, 1, 0)
			list = list .. title
			if author then list = list .. " " .. INFO_BY .. " " .. author end
			list = list .. color .. (plugin.isLib and " " .. LIBRARY or " - " .. INFO_VERSION .. " " .. plugin.version)
			if plugin.old then list = list .. " (" .. INFO_NEW .. plugin.newversion .. ")" end
			list = list .. "|r\n"
		end
	end
	return list
end

function lib:ClearSendMessageWait()
	lib.SendMessageWaiting = nil
end

function lib:SendPluginVersionCheck(message)
	if (not message) or match(message, "^%s-$") then
		lib.ClearSendMessageWait()
		return
	end

	local ChatType
	if GetNumRaidMembers() > 1 then
		local _, instanceType = IsInInstance()
		ChatType = instanceType == "pvp" and "BATTLEGROUND" or "RAID"
	elseif GetNumPartyMembers() > 0 then
		ChatType = "PARTY"
	end

	if not ChatType then
		lib.ClearSendMessageWait()
		return
	end

	local maxChar, msgLength = 254 - len(lib.prefix), len(message)
	if msgLength > maxChar then
		local delay, splitMessage = 0

		for _ = 1, ceil(msgLength / maxChar) do
			splitMessage = match(sub(message, 1, maxChar), ".+;")
			if splitMessage then -- incase the string is over `maxChar` but doesnt contain `;`
				message = gsub(message, "^"..gsub(splitMessage, "([%-%.%+%[%]%(%)%$%^%%%?%*])", "%%%1"), "")
				E:Delay(delay, SendAddonMessage, lib.prefix, splitMessage, ChatType)
				delay = delay + 1
			end
		end

		E:Delay(delay, lib.ClearSendMessageWait)
	else
		SendAddonMessage(lib.prefix, message, ChatType)
		lib.ClearSendMessageWait()
	end
end

function lib.Initialized()
	if not lib.inits then return end

	for _, initTbl in ipairs(lib.inits) do
		initTbl[2](initTbl[1])
	end

	wipe(lib.inits)
end

function lib:HookInitialize(tbl, func)
	if not (tbl and func) then return end

	if type(func) == "string" then
		func = tbl[func]
	end

	if not self.inits then
		self.inits = {}
		checkElvUI()
		hooksecurefunc(E, "Initialize", self.Initialized)
	end

	tinsert(lib.inits, {tbl, func})
end

lib.VCFrame = CreateFrame("Frame")
lib.VCFrame:SetScript("OnEvent", lib.VersionCheck)

lib.CFFrame = CreateFrame("Frame")
lib.CFFrame:SetScript("OnEvent", lib.OptionsUILoaded)