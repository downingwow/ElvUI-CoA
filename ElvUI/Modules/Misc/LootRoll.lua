local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local M = E:GetModule("Misc")
local LSM = E.Libs.LSM

--Lua functions
local pairs, ipairs, unpack = pairs, ipairs, unpack
local find, format = string.find, string.format
local tinsert, twipe = table.insert, table.wipe
--WoW API / Variables
local ChatEdit_InsertLink = ChatEdit_InsertLink
local CreateFrame = CreateFrame
local CursorOnUpdate = CursorOnUpdate
local CursorUpdate = CursorUpdate
local DressUpItemLink = DressUpItemLink
local GetLootRollItemInfo = GetLootRollItemInfo
local GetLootRollItemLink = GetLootRollItemLink
local GetLootRollTimeLeft = GetLootRollTimeLeft
local IsModifiedClick = IsModifiedClick
local ResetCursor = ResetCursor
local RollOnLoot = RollOnLoot
local SetDesaturation = SetDesaturation
local UnitClass = UnitClass

local ITEM_QUALITY_COLORS = ITEM_QUALITY_COLORS
local ROLL_DISENCHANT = ROLL_DISENCHANT

local POSITION = "TOP"
local FRAME_WIDTH, FRAME_HEIGHT = 328, 28

M.RollBars = {}

local locale = GetLocale()
local rollMessages = locale == "deDE" and {
	["(.*) passt automatisch bei (.+), weil [ersi]+ den Gegenstand nicht benutzen kann.$"] = 0,
	["(.*) würfelt nicht für: (.+|r)$"] = 0,
	["(.*) hat für (.+) 'Bedarf' ausgewählt"] = 1,
	["(.*) hat für (.+) 'Gier' ausgewählt"] = 2,
	["(.*) hat für '(.+)' Entzauberung gewählt."] = 3,
} or locale == "frFR" and {
	["(.*) a passé pour : (.+) parce qu'((il)|(elle)) ne peut pas ramasser cette objet.$"] = 0,
	["(.*) a passé pour : (.+)"] = 0,
	["(.*) a choisi Besoin pour : (.+)"] = 1,
	["(.*) a choisi Cupidité pour : (.+)"] = 2,
	["(.*) a choisi Désenchantement pour : (.+)"] = 3,
} or locale == "zhCN" and {
	["(.*)自动放弃了：(.+)，因为他无法拾取该物品$"] = 0,
	["(.*)自动放弃了：(.+)，因为她无法拾取该物品$"] = 0,
	["(.*)放弃了：(.+)"] = 0,
	["(.*)选择了需求取向：(.+)"] = 1,
	["(.*)选择了贪婪取向：(.+)"] = 2,
	["(.*)选择了分解取向：(.+)"] = 3,
} or locale == "zhTW" and {
	["(.*)自動放棄:(.+)，因為他無法拾取該物品$"] = 0,
	["(.*)自動放棄:(.+)，因為她無法拾取該物品$"] = 0,
	["(.*)放棄了:(.+)"] = 0,
	["(.*)選擇了需求:(.+)"] = 1,
	["(.*)選擇了貪婪:(.+)"] = 2,
	["(.*)選擇了分解:(.+)"] = 3,
} or locale == "ruRU" and {
	["(.*) автоматически передает предмет (.+), поскольку не может его забрать"] = 0,
	["(.*) пропускает розыгрыш предмета \"(.+)\", поскольку не может его забрать"] = 0,
	["(.*) отказывается от предмета (.+)%."] = 0,
	["Разыгрывается: (.+)%. (.*): \"Мне это нужно\""] = 1,
	["Разыгрывается: (.+)%. (.*): \"Не откажусь\""] = 2,
	["Разыгрывается: (.+)%. (.*): \"Распылить\""] = 3,
} or locale == "koKR" and {
	["(.*)님이 획득할 수 없는 아이템이어서 자동으로 주사위 굴리기를 포기했습니다: (.+)"] = 0,
	["(.*)님이 주사위 굴리기를 포기했습니다: (.+)"] = 0,
	["(.*)님이 입찰을 선택했습니다: (.+)"] = 1,
	["(.*)님이 차비를 선택했습니다: (.+)"] = 2,
	["(.*)님이 마력 추출을 선택했습니다: (.+)"] = 3,
} or locale == "esES" and {
	["^(.*) pasó automáticamente de: (.+) porque no puede despojar este objeto.$"] = 0,
	["^(.*) pasó de: (.+|r)$"] = 0,
	["(.*) eligió Necesidad para: (.+)"] = 1,
	["(.*) eligió Codicia para: (.+)"] = 2,
	["(.*) eligió Desencantar para: (.+)"] = 3,
} or locale == "esMX" and {
	["^(.*) pasó automáticamente de: (.+) porque no puede despojar este objeto.$"] = 0,
	["^(.*) pasó de: (.+|r)$"] = 0,
	["(.*) eligió Necesidad para: (.+)"] = 1,
	["(.*) eligió Codicia para: (.+)"] = 2,
	["(.*) eligió Desencantar para: (.+)"] = 3,
} or {
	["^(.*) automatically passed on: (.+) because s?he cannot loot that item.$"] = 0,
	["^(.*) passed on: (.+|r)$"] = 0,
	["(.*) has selected Need for: (.+)"] = 1,
	["(.*) has selected Greed for: (.+)"] = 2,
	["(.*) has selected Disenchant for: (.+)"] = 3
}

local rollTypes = {
	[0] = {
		tooltipText = PASS,
		normalTexture = "Interface\\Buttons\\UI-GroupLoot-Pass-Up",
		pushedTexture = "Interface\\Buttons\\UI-GroupLoot-Pass-Down",
		highlightTexture = nil,
	},
	[1] = {
		tooltipText = NEED,
		newbieText = NEED_NEWBIE,
		normalTexture = "Interface\\Buttons\\UI-GroupLoot-Dice-Up",
		pushedTexture = "Interface\\Buttons\\UI-GroupLoot-Dice-Down",
		highlightTexture = "Interface\\Buttons\\UI-GroupLoot-Dice-Highlight",
	},
	[2] = {
		tooltipText = GREED,
		newbieText = GREED_NEWBIE,
		normalTexture = "Interface\\Buttons\\UI-GroupLoot-Coin-Up",
		pushedTexture = "Interface\\Buttons\\UI-GroupLoot-Coin-Down",
		highlightTexture = "Interface\\Buttons\\UI-GroupLoot-Coin-Highlight",
	},
	[3] = {
		tooltipText = ROLL_DISENCHANT,
		newbieText = ROLL_DISENCHANT_NEWBIE,
		normalTexture = "Interface\\Buttons\\UI-GroupLoot-DE-Up",
		pushedTexture = "Interface\\Buttons\\UI-GroupLoot-DE-Down",
		highlightTexture = "Interface\\Buttons\\UI-GroupLoot-DE-Highlight",
	},
}

local reasons = {
	LOOT_ROLL_INELIGIBLE_REASON1,
	LOOT_ROLL_INELIGIBLE_REASON2,
	LOOT_ROLL_INELIGIBLE_REASON3,
	LOOT_ROLL_INELIGIBLE_REASON4,
	LOOT_ROLL_INELIGIBLE_REASON5,
}

local function buttonOnEnter(self)
	GameTooltip:SetOwner(self, "ANCHOR_RIGHT")

	GameTooltip:SetText(self.tooltipText)

	if self.newbieText and SHOW_NEWBIE_TIPS == "1" then
		GameTooltip:AddLine(self.newbieText, 1, 0.82, 0, true)
	end

	if self:IsEnabled() == 0 then
		GameTooltip:AddLine(self.reason, 1, 0.1, 0.1, true)
	end

	for playerName, rollData in pairs(self.parent.rollResults) do
		if self.rollType == rollData[1] and rollData[2] then
			local classColor = RAID_CLASS_COLORS[rollData[2]]
			GameTooltip:AddLine(playerName, classColor.r, classColor.g, classColor.b)
		end
	end

	GameTooltip:Show()
end

local function buttonOnLeave()
	GameTooltip:Hide()
end

local function buttonOnClick(self)
	RollOnLoot(self.parent.rollID, self.rollType)
end

local function toggleLootButton(self, state, reason, reasonValue)
	if state then
		self:Enable()
		self:SetAlpha(1)
		self.reason = nil
		SetDesaturation(self:GetNormalTexture(), false)
	else
		self:Disable()
		self:SetAlpha(0.2)
		self.reason = reasonValue and format(reasons[reason], reasonValue) or reasons[reason]
		SetDesaturation(self:GetNormalTexture(), true)
	end
end

local function increaseRollCount(self, count)
	local text = self.text:GetText()
	if not text or text == "" then
		self.text:SetText(count or 1)
	else
		self.text:SetText(self.text:GetText() + (count or 1))
	end
end

local function GetLootFrameWidth()
	local db = M:GetLootStyle()
	local width = tonumber(db.width) or FRAME_WIDTH
	return math.max(220, math.min(450, width))
end

local function SetLootItemText(frame, text)
	if not frame or not frame.itemName then return end

	local fontString = frame.itemName
	local fullText = text or ""
	frame.lootItemFullName = fullText

	fontString:SetText(fullText)
	if fullText == "" or not fontString.GetStringWidth then return end

	local available = fontString:GetWidth() or 0
	if available <= 4 or fontString:GetStringWidth() <= available then return end

	local suffix = "..."
	local low, high = 0, #fullText
	local best = suffix

	while low <= high do
		local mid = math.floor((low + high) / 2)
		local candidate = string.sub(fullText, 1, mid)..suffix
		fontString:SetText(candidate)

		if fontString:GetStringWidth() <= available then
			best = candidate
			low = mid + 1
		else
			high = mid - 1
		end
	end

	fontString:SetText(best)
end

local function FetchLootTexture(name, fallback)
	if LSM and name then
		return LSM:Fetch("statusbar", name) or fallback
	end
	return fallback
end

local function ApplyGradientToTexture(texture, r1, g1, b1, a1, r2, g2, b2, a2)
	if not texture then return end
	texture:SetVertexColor(1, 1, 1, 1)
	if texture.SetGradientAlpha then
		texture:SetGradientAlpha("HORIZONTAL", r1, g1, b1, a1, r2, g2, b2, a2)
	end
end

function M:UpdateLootRollFrameStyle(frame)
	if not frame then return end

	local db = self:GetLootStyle()
	local width = GetLootFrameWidth()
	frame:SetWidth(width)

	if frame.itemName and frame.bindText then
		frame.itemName:ClearAllPoints()
		frame.itemName:Point("LEFT", frame.bindText, "RIGHT", 1, 0)
		frame.itemName:Point("RIGHT", frame, "RIGHT", -5, 0)
		frame.itemName:SetHeight(10)
	end

	local font = self:GetLootFont()
	local size = db.fontSize or 12
	local outline = db.fontOutline or "OUTLINE"
	local fgTex = FetchLootTexture(db.foregroundTexture, E.media.normTex)
	local bgTex = FetchLootTexture(db.backgroundTexture, E.media.blankTex or E.media.normTex)
	local quality = frame.quality or 4
	local r, g, b = self:GetLootQualityColor(quality)
	local r2, g2, b2 = self:GetLootGradientColor(quality)
	local alpha = db.backgroundAlpha or 0.18

	if frame.status then
		frame.status:SetStatusBarTexture(fgTex)

		local texture = frame.status:GetStatusBarTexture()
		if db.customColors and db.gradient then
			frame.status:SetStatusBarColor(1, 1, 1, 1)
			ApplyGradientToTexture(texture, r, g, b, 0.82, r2, g2, b2, 0.82)
		else
			-- SetStatusBarColor already applies the correct quality/custom color
			-- to the statusbar texture. Do not reset the texture to white here,
			-- otherwise default loot-quality colors are lost when Custom Colors is off.
			frame.status:SetStatusBarColor(r, g, b, 0.82)
		end

		if frame.status.bg then
			frame.status.bg:SetTexture(bgTex)
			if db.customColors and db.gradient and frame.status.bg.SetGradientAlpha then
				ApplyGradientToTexture(frame.status.bg, r, g, b, alpha, r2, g2, b2, alpha)
			else
				frame.status.bg:SetVertexColor(r, g, b, alpha)
			end
		end
	end

	if frame.bindText then
		frame.bindText:FontTemplate(font, size, outline)
	end
	if frame.itemName then
		frame.itemName:FontTemplate(font, size, outline)
	end

	local buttons = {"passButton", "needButton", "greedButton", "disenchantButton"}
	for _, key in ipairs(buttons) do
		local button = frame[key]
		if button and button.text then
			button.text:FontTemplate(font, size, outline)
		end
	end

	if frame.itemName and frame.lootItemFullName then
		SetLootItemText(frame, frame.lootItemFullName)
	end
end

function M:UpdateLootRollStyle()
	if self.lootRollPreviewContainer then
		self.lootRollPreviewContainer:SetWidth(GetLootFrameWidth())
	end

	for _, frame in ipairs(self.RollBars or {}) do
		self:UpdateLootRollFrameStyle(frame)
	end

	if self.lootRollPreviews then
		for _, frame in ipairs(self.lootRollPreviews) do
			self:UpdateLootRollFrameStyle(frame)
		end
	end
end

function M:CreateLootRollPreviewFrame(index, value, quality, labelText)
	local name = "ElvUI_LootRollPreview"..index
	local container = self.lootRollPreviewContainer or E.UIParent
	local frame = CreateFrame("Frame", name, container)
	frame:Size(GetLootFrameWidth(), FRAME_HEIGHT)
	frame:SetTemplate()
	frame:SetFrameStrata("DIALOG")
	frame.quality = quality or 4

	local y = -((index - 1) * (FRAME_HEIGHT + 8))
	frame:Point("TOP", container, "TOP", 0, y)

	-- Drag the whole preview stack directly by any preview frame.
	frame:EnableMouse(true)
	frame:RegisterForDrag("LeftButton")
	frame:SetScript("OnDragStart", function()
		if M.lootRollPreviewContainer then
			M.lootRollPreviewContainer:StartMoving()
		end
	end)
	frame:SetScript("OnDragStop", function()
		if M.lootRollPreviewContainer then
			M.lootRollPreviewContainer:StopMovingOrSizing()
		end
	end)

	local db = self:GetLootStyle()
	local font = self:GetLootFont()
	local fontSize = db.fontSize or 12
	local fontOutline = db.fontOutline or "OUTLINE"

	local itemButton = CreateFrame("Button", "$parentIconFrame", frame)
	itemButton:Size(FRAME_HEIGHT - (E.Border * 2))
	itemButton:Point("RIGHT", frame, "LEFT", -(E.Spacing * 3), 0)
	itemButton:CreateBackdrop()
	itemButton.hasItem = 1
	frame.itemButton = itemButton

	itemButton.icon = itemButton:CreateTexture(nil, "OVERLAY")
	itemButton.icon:SetAllPoints()
	itemButton.icon:SetTexCoord(unpack(E.TexCoords))
	itemButton.icon:SetTexture("Interface\\Icons\\INV_Misc_Gem_Amethyst_02")

	local fade = frame:CreateTexture(nil, "BORDER")
	fade:Point("TOPLEFT", frame, "TOPLEFT", 4, 0)
	fade:Point("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 0)
	fade:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
	fade:SetBlendMode("ADD")
	fade:SetGradientAlpha("VERTICAL", 0.1, 0.1, 0.1, 0, 0.1, 0.1, 0.1, 0)
	frame.fade = fade

	local status = CreateFrame("StatusBar", "$parentStatusBar", frame)
	status:SetInside()
	status:SetFrameLevel(status:GetFrameLevel() - 1)
	status:SetMinMaxValues(0, 100)
	status:SetValue(value or 0)
	status.parent = frame
	frame.status = status

	status.bg = status:CreateTexture(nil, "BACKGROUND")
	status.bg:SetAllPoints()

	local spark = frame:CreateTexture(nil, "OVERLAY")
	spark:Size(14, FRAME_HEIGHT)
	spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	spark:SetBlendMode("ADD")
	spark:Point("CENTER", status, "LEFT", (status:GetValue() / 100) * status:GetWidth(), 0)
	frame.spark = spark
	status.spark = spark

	frame.needButton = self:CreateRollButton(frame, 1)
	frame.greedButton = self:CreateRollButton(frame, 2)
	frame.disenchantButton = self:CreateRollButton(frame, 3)
	frame.passButton = self:CreateRollButton(frame, 0)

	frame.needButton:SetHitRectInsets(0, 0, -2, 0)
	frame.greedButton:SetHitRectInsets(0, 0, -3, 1)
	frame.disenchantButton:SetHitRectInsets(0, 0, -2, 0)
	frame.passButton:SetHitRectInsets(0, 0, 0, -2)

	frame.needButton:Point("LEFT", frame.itemButton, "RIGHT", 4, -1)
	frame.greedButton:Point("LEFT", frame.needButton, "RIGHT", 1, -1)
	frame.disenchantButton:Point("LEFT", frame.greedButton, "RIGHT", 0, 1)
	frame.passButton:Point("LEFT", frame.disenchantButton, "RIGHT", 0, 2)

	frame.needButton.text:Point("CENTER", -1, 4)
	frame.greedButton.text:Point("CENTER", 1, 5)
	frame.disenchantButton.text:Point("CENTER", 1, 4)
	frame.passButton.text:Point("CENTER", 1, 2)

	-- Prevent preview interaction from trying to perform real loot actions.
	for _, button in ipairs({frame.needButton, frame.greedButton, frame.disenchantButton, frame.passButton}) do
		button.rollID = nil
		button:SetScript("OnClick", nil)
	end

	-- Optional sample counts so the text styling is also visible.
	frame.needButton.text:SetText("")
	frame.greedButton.text:SetText("")
	frame.disenchantButton.text:SetText("")
	frame.passButton.text:SetText("")

	frame.bindText = frame:CreateFontString(nil, "ARTWORK")
	frame.bindText:FontTemplate(font, fontSize, fontOutline)
	frame.bindText:Point("LEFT", frame.passButton, "RIGHT", 2, 0)
	frame.bindText:SetText("BoP")

	local itemName = frame:CreateFontString(nil, "ARTWORK")
	itemName:FontTemplate(font, fontSize, fontOutline)
	itemName:Point("LEFT", frame.bindText, "RIGHT", 1, 0)
	itemName:Point("RIGHT", frame, "RIGHT", -5, 0)
	itemName:SetHeight(10)
	itemName:SetJustifyH("LEFT")
	frame.itemName = itemName
	SetLootItemText(frame, labelText or "Loot Preview")

	frame.rollResults = {}
	frame.rollButtons = {
		[0] = frame.passButton,
		[1] = frame.needButton,
		[2] = frame.greedButton,
		[3] = frame.disenchantButton,
	}

	self:UpdateLootRollFrameStyle(frame)
	frame:Hide()

	return frame
end

function M:CreateLootRollPreview()
	if self.lootRollPreviews then
		return self.lootRollPreviews
	end

	local container = CreateFrame("Frame", "ElvUI_LootRollPreviewContainer", E.UIParent)
	container:Size(GetLootFrameWidth(), (FRAME_HEIGHT * 6) + (8 * 5))
	container:Point("CENTER", E.UIParent, "CENTER", 0, 140)
	container:SetMovable(true)
	container:SetClampedToScreen(true)
	container:SetFrameStrata("DIALOG")
	self.lootRollPreviewContainer = container

	self.lootRollPreviews = {
		self:CreateLootRollPreviewFrame(1, 95, 2, "Uncommon Loot Preview"),
		self:CreateLootRollPreviewFrame(2, 80, 3, "Rare Loot Preview"),
		self:CreateLootRollPreviewFrame(3, 65, 4, "Epic Loot Preview"),
		self:CreateLootRollPreviewFrame(4, 50, 5, "Legendary Loot Preview"),
		self:CreateLootRollPreviewFrame(5, 35, 6, "Artifact Loot Preview"),
		self:CreateLootRollPreviewFrame(6, 20, 7, "Heirloom Loot Preview"),
	}

	local Skins = E:GetModule("Skins", true)
	if Skins and Skins.Initialized and Skins.UpdateFrameShadow then
		Skins:UpdateFrameShadow("lootroll")
	end

	return self.lootRollPreviews
end

function M:SetLootRollPreview(state)
	self.lootRollPreviewEnabled = state and true or false

	local previews = self:CreateLootRollPreview()

	for _, frame in ipairs(previews) do
		if self.lootRollPreviewEnabled then
			self:UpdateLootRollFrameStyle(frame)
			frame:Show()
		else
			frame:Hide()
		end
	end

	if self.lootRollPreviewContainer then
		if self.lootRollPreviewEnabled then
			self.lootRollPreviewContainer:Show()
		else
			self.lootRollPreviewContainer:Hide()
		end
	end

	local Skins = E:GetModule("Skins", true)
	if Skins and Skins.Initialized and Skins.UpdateFrameShadow then
		Skins:UpdateFrameShadow("lootroll")
	end
end

function M:CreateRollButton(parent, rollType)
	local data = rollTypes[rollType]

	local button = CreateFrame("Button", nil, parent)
	button:Size(FRAME_HEIGHT - 4)
	button:SetNormalTexture(data.normalTexture)
	button:SetPushedTexture(data.highlightTexture)
	button:SetHighlightTexture(data.pushedTexture)

	button:SetMotionScriptsWhileDisabled(true)
	button:SetScript("OnEnter", buttonOnEnter)
	button:SetScript("OnLeave", buttonOnLeave)
	button:SetScript("OnClick", buttonOnClick)

	button.ToggleLootButton = toggleLootButton
	button.IncreaseRollCount = increaseRollCount
	button.parent = parent
	button.rollType = rollType
	button.tooltipText = data.tooltipText
	button.newbieText = data.newbieText

	button.text = button:CreateFontString(nil, nil)
	local style = self:GetLootStyle()
	button.text:FontTemplate(self:GetLootFont(), style.fontSize or 12, style.fontOutline or "OUTLINE")

	return button
end

local function itemOnEnter(self)
	GameTooltip:SetOwner(self, POSITION == "TOP" and "ANCHOR_BOTTOMLEFT" or "ANCHOR_TOPLEFT")
	GameTooltip:SetLootRollItem(self.rollID)

	CursorUpdate(self)
end

local function itemOnLeave()
	GameTooltip:Hide()
	ResetCursor()
end

local function itemOnUpdate(self)
	if GameTooltip:IsOwned(self) then
		GameTooltip:SetOwner(self, POSITION == "TOP" and "ANCHOR_BOTTOMLEFT" or "ANCHOR_TOPLEFT")
		GameTooltip:SetLootRollItem(self.rollID)
	end

	CursorOnUpdate(self)
end

local function itemOnClick(self)
	if IsModifiedClick("CHATLINK") then
		ChatEdit_InsertLink(self.link)
	elseif IsModifiedClick("DRESSUP") then
		DressUpItemLink(self.link)
	end
end

local function statusbarOnUpdate(self)
	local timeLeft = GetLootRollTimeLeft(self.parent.rollID)
	if timeLeft < 0 or timeLeft > self.parent.rollTime then
		timeLeft = 0
	else
		self.spark:Point("CENTER", self, "LEFT", (timeLeft / self.parent.rollTime) * self:GetWidth(), 0)
	end

	self:SetValue(timeLeft)
end

function M:CreateRollFrame()
	self.numFrames = self.numFrames + 1

	local frame = CreateFrame("Frame", format("ElvUI_GroupLootFrame%d", self.numFrames), E.UIParent)
	frame:Size(GetLootFrameWidth(), FRAME_HEIGHT)
	frame:SetTemplate()
	frame:SetFrameStrata("DIALOG")
	frame:Hide()

	if POSITION == "TOP" then
		frame:Point("TOP", self.numFrames > 1 and self.RollBars[self.numFrames - 1] or AlertFrameHolder, "BOTTOM", 0, -4)
	else
		frame:Point("BOTTOM", self.numFrames > 1 and self.RollBars[self.numFrames - 1] or AlertFrameHolder, "TOP", 0, 4)
	end

	local itemButton = CreateFrame("Button", "$parentIconFrame", frame)
	itemButton:Size(FRAME_HEIGHT - (E.Border * 2))
	itemButton:Point("RIGHT", frame, "LEFT", -(E.Spacing * 3), 0)
	itemButton:CreateBackdrop()
	itemButton:SetScript("OnEnter", itemOnEnter)
	itemButton:SetScript("OnLeave", itemOnLeave)
	itemButton:SetScript("OnUpdate", itemOnUpdate)
	itemButton:SetScript("OnClick", itemOnClick)
	itemButton.hasItem = 1
	frame.itemButton = itemButton

	itemButton.icon = itemButton:CreateTexture(nil, "OVERLAY")
	itemButton.icon:SetAllPoints()
	itemButton.icon:SetTexCoord(unpack(E.TexCoords))

	local fade = frame:CreateTexture(nil, "BORDER")
	fade:Point("TOPLEFT", frame, "TOPLEFT", 4, 0)
	fade:Point("BOTTOMRIGHT", frame, "BOTTOMRIGHT", -4, 0)
	fade:SetTexture("Interface\\ChatFrame\\ChatFrameBackground")
	fade:SetBlendMode("ADD")
	fade:SetGradientAlpha("VERTICAL", 0.1, 0.1, 0.1, 0, 0.1, 0.1, 0.1, 0)
	frame.fade = fade

	local status = CreateFrame("StatusBar", "$parentStatusBar", frame)
	status:SetInside()
	status:SetFrameLevel(status:GetFrameLevel() - 1)
	status:SetStatusBarTexture(E.media.normTex)
	status:SetStatusBarColor(0.8, 0.8, 0.8, 0.9)
	status.parent = frame
	E:RegisterStatusBar(status)
	status:SetScript("OnUpdate", statusbarOnUpdate)
	frame.status = status

	status.bg = status:CreateTexture(nil, "BACKGROUND")
	status.bg:SetAlpha(0.1)
	status.bg:SetAllPoints()

	local spark = frame:CreateTexture(nil, "OVERLAY")
	spark:Size(14, FRAME_HEIGHT)
	spark:SetTexture("Interface\\CastingBar\\UI-CastingBar-Spark")
	spark:SetBlendMode("ADD")
	status.spark = spark

	frame.passButton = self:CreateRollButton(frame, 0)
	frame.needButton = self:CreateRollButton(frame, 1)
	frame.greedButton = self:CreateRollButton(frame, 2)
	frame.disenchantButton = self:CreateRollButton(frame, 3)

	frame.needButton:SetHitRectInsets(0, 0, -2, 0)
	frame.greedButton:SetHitRectInsets(0, 0, -3, 1)
	frame.disenchantButton:SetHitRectInsets(0, 0, -2, 0)
	frame.passButton:SetHitRectInsets(0, 0, 0, -2)

	frame.needButton:Point("LEFT", frame.itemButton, "RIGHT", 4, -1)
	frame.greedButton:Point("LEFT", frame.needButton, "RIGHT", 1, -1)
	frame.disenchantButton:Point("LEFT", frame.greedButton, "RIGHT", 0, 1)
	frame.passButton:Point("LEFT", frame.disenchantButton, "RIGHT", 0, 2)

	frame.needButton.text:Point("CENTER", -1, 4)
	frame.greedButton.text:Point("CENTER", 1, 5)
	frame.disenchantButton.text:Point("CENTER", 1, 4)
	frame.passButton.text:Point("CENTER", 1, 2)

	frame.bindText = frame:CreateFontString()
	frame.bindText:Point("LEFT", frame.passButton, "RIGHT", 2, 0)
	frame.bindText:FontTemplate(nil, nil, "OUTLINE")

	local itemName = frame:CreateFontString(nil, "ARTWORK")
	itemName:FontTemplate(nil, nil, "OUTLINE")
	itemName:Point("LEFT", frame.bindText, "RIGHT", 1, 0)
	itemName:Point("RIGHT", frame, "RIGHT", -5, 0)
	itemName:SetHeight(10)
	itemName:SetJustifyH("LEFT")
	frame.itemName = itemName

	frame.rollResults = {}
	frame.rollButtons = {
		[0] = frame.passButton,
		[1] = frame.needButton,
		[2] = frame.greedButton,
		[3] = frame.disenchantButton,
	}

	tinsert(self.RollBars, frame)
	self:UpdateLootRollFrameStyle(frame)

	local Skins = E:GetModule("Skins", true)
	if Skins and Skins.Initialized and Skins.UpdateFrameShadow then
		Skins:UpdateFrameShadow("lootroll")
	end

	return frame
end

function M:ReleaseFrame(frame)
	frame:Hide()
	frame.rollID = nil
	frame.rollTime = nil

	for i = 0, 3 do
		frame.rollButtons[i].text:SetText("")
	end

	twipe(frame.rollResults)
end

function M:GetFrame()
	for _, frame in ipairs(M.RollBars) do
		if not frame.rollID then
			return frame
		end
	end

	return self:CreateRollFrame()
end

function M:START_LOOT_ROLL(_, rollID, rollTime)
	local f = self:GetFrame()
	f.rollID = rollID
	f.rollTime = rollTime

	local texture, name, count, quality, bindOnPickUp, canNeed, canGreed, canDisenchant, reasonNeed, reasonGreed, reasonDisenchant, deSkillRequired = GetLootRollItemInfo(rollID)

	f.itemButton.icon:SetTexture(texture)
	f.itemButton.rollID = rollID
	f.itemButton.link = GetLootRollItemLink(rollID)

	local displayName = count > 1 and format("%dx %s", count, name) or name

	f.status:SetMinMaxValues(0, rollTime)
	f.status:SetValue(rollTime)

	f.quality = quality
	self:UpdateLootRollFrameStyle(f)

	f.bindText:SetText(bindOnPickUp and "BoP" or "BoE")
	f.bindText:SetVertexColor(bindOnPickUp and 1 or 0.3, bindOnPickUp and 0.3 or 1, bindOnPickUp and 0.1 or 0.3)
	SetLootItemText(f, displayName)

	f.needButton:ToggleLootButton(canNeed, reasonNeed)
	f.greedButton:ToggleLootButton(canGreed, reasonGreed)
	f.disenchantButton:ToggleLootButton(canDisenchant, reasonDisenchant, deSkillRequired)

	f:Show()

	AlertFrame_FixAnchors()

	if E.db.general.autoRoll and E.mylevel == MAX_PLAYER_LEVEL and quality == 2 and not bindOnPickUp then
		if canDisenchant then
			RollOnLoot(rollID, 3)
		else
			RollOnLoot(rollID, 2)
		end
	end
end

function M:CANCEL_LOOT_ROLL(_, rollID)
	for _, frame in ipairs(self.RollBars) do
		if frame.rollID == rollID then
			self:ReleaseFrame(frame)
			E:StaticPopup_Hide("CONFIRM_LOOT_ROLL", self.rollID)
			break
		end
	end
end

function M:ParseRollChoice(msg)
	for regex, rollType in pairs(rollMessages) do
		local _, _, playerName, itemName = find(msg, regex)

		if playerName and itemName and playerName ~= "Everyone" then
			if locale == "ruRU" and rollType ~= 0 then
				playerName, itemName = itemName, playerName
			end

			return playerName, itemName, rollType
		end
	end
end

function M:CHAT_MSG_LOOT(_, msg)
	local playerName, itemName, rollType = self:ParseRollChoice(msg)

	if playerName and itemName then
		local _, class = UnitClass(playerName)

		for _, frame in ipairs(self.RollBars) do
			if frame.rollID and frame.itemButton.link == itemName and not frame.rollResults[playerName] then
				frame.rollResults[playerName] = {rollType, class}
				frame.rollButtons[rollType]:IncreaseRollCount()
				break
			end
		end
	end
end

function M:LoadLootRoll()
	if not E.private.general.lootRoll then return end

	self.numFrames = 0

	self:RegisterEvent("CHAT_MSG_LOOT")
	self:RegisterEvent("START_LOOT_ROLL")
	self:RegisterEvent("CANCEL_LOOT_ROLL")

	UIParent:UnregisterEvent("START_LOOT_ROLL")
	UIParent:UnregisterEvent("CANCEL_LOOT_ROLL")

	for i = 1, NUM_GROUP_LOOT_FRAMES do
		_G["GroupLootFrame"..i]:UnregisterEvent("CANCEL_LOOT_ROLL")
	end

	self:UpdateLootRollStyle()
end