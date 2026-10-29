local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local DT = E:GetModule("DataTexts")
local LSM = E.Libs.LSM

--Lua functions
local pairs, type, gsub, format = pairs, type, gsub, format
--WoW API / Variables
local CreateFrame, InCombatLockdown = CreateFrame, InCombatLockdown

DT.CustomPanels = {}
DT.MAX_CUSTOM_SLOTS = 12

DT.CustomPanelDefaults = {
	numPoints = 3,
	width = 300,
	height = 22,
	backdrop = true,
	border = true,
	transparent = false,
	alpha = 0.8,
	texture = "ElvUI Blank",
	font = "PT Sans Narrow",
	fontSize = 12,
	fontOutline = "NONE",
	shadow = false,
	shadowSize = 4,
}

function DT:GetCustomPanelFrameName(id)
	return "ElvUI_DTPanel_"..gsub(id, "[^%w]", "_")
end

function DT:GetCustomPanelMoverName(id)
	return DT:GetCustomPanelFrameName(id).."Mover"
end

local function ApplyDefaults(cfg)
	for key, value in pairs(DT.CustomPanelDefaults) do
		if cfg[key] == nil then cfg[key] = value end
	end
	return cfg
end

function DT:ApplyCustomPanelStyle(panel, cfg)
	local color = E.db.general.backdropfadecolor or {r = 0.06, g = 0.06, b = 0.06}
	local bg = cfg.transparent and (E.media.backdropfadecolor or color) or (E.media.backdropcolor or color)
	local br, bgc, bb = bg.r or bg[1] or 0.06, bg.g or bg[2] or 0.06, bg.b or bg[3] or 0.06
	local er, eg, eb = unpack(E.media.bordercolor)

	if cfg.backdrop then
		panel:SetBackdrop({
			bgFile = LSM:Fetch("statusbar", cfg.texture, true) or E.media.blankTex,
			edgeFile = cfg.border and E.media.blankTex or nil,
			tile = false, tileSize = 0, edgeSize = E.mult,
			insets = {left = 0, right = 0, top = 0, bottom = 0}
		})
		panel:SetBackdropColor(br, bgc, bb, cfg.alpha or 0.8)
		if cfg.border then panel:SetBackdropBorderColor(er, eg, eb) end
	else
		panel:SetBackdrop(nil)
	end

	if cfg.shadow then
		if not panel.shadow then panel:CreateShadow(cfg.shadowSize) end
		panel.shadow:SetOutside(panel, cfg.shadowSize, cfg.shadowSize)
		panel.shadow:SetBackdrop({edgeFile = LSM:Fetch("border", "ElvUI GlowBorder"), edgeSize = E:Scale(cfg.shadowSize)})
		panel.shadow:SetBackdropBorderColor(0, 0, 0, 0.9)
		panel.shadow:Show()
	elseif panel.shadow then
		panel.shadow:Hide()
	end
end

function DT:CreateCustomPanel(id)
	local cfg = E.global.datatexts.customPanels[id]
	if not cfg then return end
	ApplyDefaults(cfg)

	local frameName = self:GetCustomPanelFrameName(id)
	local moverName = self:GetCustomPanelMoverName(id)
	local panel = self.CustomPanels[id]

	if not panel then
		panel = CreateFrame("Frame", frameName, E.UIParent)
		panel:SetFrameStrata("BACKGROUND")
		panel:SetFrameLevel(2)
		panel.isCustom = true
		panel.customID = id
		panel:Point("CENTER", E.UIParent, "CENTER", 0, 0)
		self.CustomPanels[id] = panel
	end

	panel.customConfig = cfg
	panel:Size(cfg.width, cfg.height)
	panel:Show()

	self.RegisteredPanels[frameName] = panel
	self:RegisterPanel(panel, cfg.numPoints, "ANCHOR_TOP", 0, 4)

	-- ueberzaehlige Slots verstecken, benutzte zeigen
	for i = 1, self.MAX_CUSTOM_SLOTS do
		local button = panel.dataPanels[self:GetPointKey(panel, i)]
		if button then
			if i <= cfg.numPoints then button:Show() else
				button:Hide()
				button:UnregisterAllEvents()
				button:SetScript("OnUpdate", nil)
				button.text:SetText(nil)
			end
		end
	end

	if not self.db.panels[frameName] then self.db.panels[frameName] = {} end

	self:ApplyCustomPanelStyle(panel, cfg)

	if E.DisabledMovers[moverName] then
		E:EnableMover(moverName)
	elseif not E.CreatedMovers[moverName] then
		E:CreateMover(panel, moverName, id, nil, nil, nil, "ALL,GENERAL", nil, "datatexts,customPanels")
	end

	-- RegisterPanel und CreateMover setzen beide OnSizeChanged per SetScript und ueberschreiben sich gegenseitig;
	-- deshalb hier einen gemeinsamen Handler setzen, der Mover und Slots gleichzeitig anpasst
	panel:SetScript("OnSizeChanged", function(self)
		if self.mover and not InCombatLockdown() then
			self.mover:Size(self:GetSize())
		end
		DT.UpdateAllDimensions(self)
	end)
	if panel.mover then panel.mover:Size(cfg.width, cfg.height) end
end

function DT:DeleteCustomPanel(id)
	local panel = self.CustomPanels[id]
	local frameName = self:GetCustomPanelFrameName(id)
	local moverName = self:GetCustomPanelMoverName(id)

	if E.global.datatexts.customPanels then
		E.global.datatexts.customPanels[id] = nil
	end

	if panel then
		for _, button in pairs(panel.dataPanels) do
			button:UnregisterAllEvents()
			button:SetScript("OnUpdate", nil)
			button:SetScript("OnEnter", nil)
			button:SetScript("OnClick", nil)
			button.text:SetText(nil)
		end
		panel:Hide()
	end

	self.RegisteredPanels[frameName] = nil
	if self.db.panels then self.db.panels[frameName] = nil end
	if E.db.movers then E.db.movers[moverName] = nil end

	if E.CreatedMovers[moverName] then
		E:DisableMover(moverName)
	end
end

-- Legt alle Panels aus der globalen Config an bzw. aktualisiert sie; entfernt Panels die nicht mehr existieren
function DT:UpdateCustomPanels(skipLoad)
	if not self.db or not E.global.datatexts then return end
	local panels = E.global.datatexts.customPanels
	if not panels then
		E.global.datatexts.customPanels = {}
		panels = E.global.datatexts.customPanels
	end

	for id in pairs(panels) do
		self:CreateCustomPanel(id)
	end

	for id, panel in pairs(self.CustomPanels) do
		if not panels[id] and panel:IsShown() then
			self:DeleteCustomPanel(id)
		end
	end

	if not skipLoad then self:LoadDataTexts() end
end
