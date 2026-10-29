local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local mod = E:GetModule("DataBars")
local LSM = E.Libs.LSM

function mod.OnLeave(self)
	if (self == ElvUI_ExperienceBar and mod.db.experience.mouseover)
	or (self == ElvUI_ReputationBar and mod.db.reputation.mouseover)
	then
		E:UIFrameFadeOut(self, 1, self:GetAlpha(), 0)
	end
	GameTooltip:Hide()
end

function mod:CreateBar(name, onEnter, onClick, ...)
	local bar = CreateFrame("Button", name, E.UIParent)
	bar:Point(...)
	bar:SetScript("OnEnter", onEnter)
	bar:SetScript("OnLeave", mod.OnLeave)
	bar:SetScript("OnClick", onClick)
	bar:SetFrameStrata("LOW")
	bar:SetTemplate("Transparent")
	bar:Hide()

	bar.statusBar = CreateFrame("StatusBar", nil, bar)
	bar.statusBar:SetInside()
	bar.statusBar:SetStatusBarTexture(E.media.normTex)
	E:RegisterStatusBar(bar.statusBar)
	bar.text = bar.statusBar:CreateFontString(nil, "OVERLAY")
	bar.text:FontTemplate()
	bar.text:Point("CENTER")

	return bar
end
function mod:CreateBarBubbles(bar)
	local bubbles = CreateFrame("Frame", "$parent_Bubbles", bar)
	bubbles:SetAllPoints()
	bubbles.textures = {}

	for i = 1, 19 do
		bubbles.textures[i] = bubbles:CreateTexture(nil, "OVERLAY")
		bubbles.textures[i]:SetTexture(0, 0, 0, 1)
	end

	bar.bubbles = bubbles

	return bubbles
end

function mod:UpdateBarBubbles(bar, db)
	if db.showBubbles then
		local vertical = db.orientation ~= "HORIZONTAL"
		local width = vertical and db.width or 1
		local height = not vertical and db.height or 1
		local offset = (vertical and db.height or db.width) / 20

		for i, texture in ipairs(bar.bubbles.textures) do
			texture:Size(width, height)
			texture:Point("TOPLEFT", bar, "TOPLEFT", vertical and 0 or offset * i, vertical and -offset * i or 0)
			texture:Show()
		end
	else
		for _, texture in ipairs(bar.bubbles.textures) do
			texture:Hide()
		end
	end
end

function mod:GetDataBarTexture(db)
	if db and db.customTexture and db.texture then
		return LSM:Fetch("statusbar", db.texture) or E.media.normTex
	end
	return E.media.normTex
end

function mod:ApplyDataBarAppearance(statusBar, db, fallbackColor)
	if not statusBar or not db then return end

	local texturePath = self:GetDataBarTexture(db)
	statusBar:SetStatusBarTexture(texturePath)

	local fallback = fallbackColor or {r = 1, g = 1, b = 1, a = 1}
	local base = db.customColor and db.baseColor or fallback
	local r, g, b, a = base.r or 1, base.g or 1, base.b or 1, base.a or 1
	local texture = statusBar:GetStatusBarTexture()

	if db.gradient and texture and texture.SetGradientAlpha then
		local finish = db.gradientColor or base
		local er, eg, eb, ea = finish.r or r, finish.g or g, finish.b or b, finish.a or a
		local direction = db.orientation == "VERTICAL" and "VERTICAL" or "HORIZONTAL"

		statusBar:SetStatusBarColor(1, 1, 1, 1)
		texture:SetGradientAlpha(direction, r, g, b, a, er, eg, eb, ea)
		statusBar.__ElvUIDataBarGradientApplied = true
	else
		if texture and texture.SetGradientAlpha then
			texture:SetGradientAlpha("HORIZONTAL", 1, 1, 1, 1, 1, 1, 1, 1)
		end
		statusBar:SetStatusBarColor(r, g, b, a)
		statusBar.__ElvUIDataBarGradientApplied = nil
	end
end

function mod:UpdateDataBarDimensions()
	self:ExperienceBar_UpdateDimensions()
	self:ReputationBar_UpdateDimensions()
end


function mod:Initialize()
	self.db = E.db.databars
	self.maxExpansionLevel = MAX_PLAYER_LEVEL_TABLE[GetAccountExpansionLevel()]
	self:ExperienceBar_Load()
	self:ReputationBar_Load()
end

local function InitializeCallback()
	mod:Initialize()
end

E:RegisterModule(mod:GetName(), InitializeCallback)