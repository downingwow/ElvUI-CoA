local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

if not AS:IsAddonLODorEnabled("LootCollector") then return end

local _G = _G
local ipairs, unpack = ipairs, unpack
local CreateFrame = CreateFrame

-- LootCollector 1.0.6 - discovery toasts and the scrolling ticker
-- Appearance only: sizes, anchors, scripts, queue and ticker logic stay untouched.
-- The toast frames are created lazily by Toast:acquireToast() and the ticker in the module's
-- OnInitialize, so everything is skinned at creation time.

local skinnedToasts = {}

local function SkinToast(f)
	if not f or f.__AS_LootCollector then return end
	f.__AS_LootCollector = true

	-- replaces the Blizzard tooltip backdrop set by the addon
	f:SetTemplate("Transparent")
	if f.CreateShadow then f:CreateShadow(5) end

	-- icon with its own border
	if f.icon then
		local holder = CreateFrame("Frame", nil, f)
		holder:SetFrameLevel(f:GetFrameLevel() + 1)
		holder:Size(38, 38)
		holder:Point("LEFT", f, "LEFT", 8, 0)
		holder:SetTemplate("Default")

		f.icon:SetParent(holder)
		f.icon:SetDrawLayer("ARTWORK")
		f.icon:ClearAllPoints()
		f.icon:Point("TOPLEFT", holder, "TOPLEFT", 2, -2)
		f.icon:Point("BOTTOMRIGHT", holder, "BOTTOMRIGHT", -2, 2)
		f.icon:SetTexCoord(unpack(E.TexCoords))
		f.iconHolder = holder
	end

	if f.close then
		S:HandleCloseButton(f.close, f)
	end

	skinnedToasts[#skinnedToasts + 1] = f
end

local function SkinTicker()
	local frame = _G.LootCollectorTickerToast
	if not frame or frame.__AS_LootCollector then return end
	frame.__AS_LootCollector = true

	frame:SetTemplate("Transparent")
	if frame.CreateShadow then frame:CreateShadow(5) end

	for i = 1, frame:GetNumChildren() do
		local child = select(i, frame:GetChildren())
		if child and child.GetObjectType and child:GetObjectType() == "Button" and child.GetNormalTexture then
			S:HandleCloseButton(child, frame)
			break
		end
	end
end

-- "LootCollector" button on the world map (LootCollectorFilterButton, UIPanelButtonTemplate).
-- It is created lazily by the map module, so a light watcher skins it as soon as it exists.
local function SkinMapButton()
	local btn = _G.LootCollectorFilterButton
	if not btn then return false end
	if not btn.__AS_LootCollector then
		btn.__AS_LootCollector = true
		S:HandleButton(btn)
	end
	return true
end

local function WatchMapButton()
	if SkinMapButton() then return end
	local watcher = CreateFrame("Frame")
	local elapsed = 0
	watcher:SetScript("OnUpdate", function(self, dt)
		elapsed = elapsed + dt
		if elapsed < 0.5 then return end
		elapsed = 0
		if SkinMapButton() then
			self:SetScript("OnUpdate", nil)
		end
	end)
end

S:AddCallbackForAddon("LootCollector", "LootCollector", function()
	if not E.db or not E.db.addOnSkins or not E.db.addOnSkins.skins.LootCollector then return end

	WatchMapButton()

	local LC = _G.LootCollector
	local Toast = LC and LC.GetModule and LC:GetModule("Toast", true)
	if not Toast or Toast.__AS_LootCollector then return end
	Toast.__AS_LootCollector = true

	-- skin every new toast frame as it is created
	local acquireToast = Toast.acquireToast
	if acquireToast then
		Toast.acquireToast = function(self, ...)
			local f = acquireToast(self, ...)
			SkinToast(f)
			return f
		end
	end

	-- the addon colours the border white (or 15% white) - keep ElvUI's border instead
	Toast.ApplyFrameStyle = function()
		for _, f in ipairs(skinnedToasts) do
			f:SetBackdropBorderColor(unpack(E.media.bordercolor))
		end
		local ticker = _G.LootCollectorTickerToast
		if ticker and ticker.__AS_LootCollector then
			ticker:SetBackdropBorderColor(unpack(E.media.bordercolor))
		end
	end

	-- the ticker is created in the addon's OnInitialize; try now and again at login
	SkinTicker()
	local waiter = CreateFrame("Frame")
	waiter:RegisterEvent("PLAYER_LOGIN")
	waiter:SetScript("OnEvent", function(self)
		self:UnregisterAllEvents()
		SkinTicker()
		Toast:ApplyFrameStyle()
	end)
end)
