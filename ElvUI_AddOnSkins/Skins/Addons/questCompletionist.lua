local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

if not AS:IsAddonLODorEnabled("QuestCompletionist") then return end

local _G = _G
local select, unpack, type, find = select, unpack, type, string.find
local CreateFrame = CreateFrame

-- Quest Completionist 1.2
-- Appearance only: sizes, anchors, scripts and list logic stay untouched.
-- The addon builds its window at load time and keeps most widgets unnamed,
-- so they are found by type/properties among the frame's children.

local ROW_H = 18

local function SkinRow(row)
	-- flat ElvUI highlight instead of the Blizzard quest-title glow
	row:SetHighlightTexture(E.media.blankTex, "ADD")
	local hl = row:GetHighlightTexture()
	if hl then
		hl:SetTexture(E.media.blankTex)
		hl:SetVertexColor(1, 1, 1, 0.12)
		hl:SetAllPoints()
	end

	-- selected-zone marker (left list): same flat look, keep the addon's own colour/alpha
	if row.sel then
		row.sel:SetTexture(E.media.blankTex)
		row.sel:SetVertexColor(unpack(E.media.rgbvaluecolor))
		row.sel:SetAlpha(0.18)
		row.sel.SetTexture = E.noop
	end
end

S:AddCallbackForAddon("QuestCompletionist", "QuestCompletionist", function()
	if not E.db or not E.db.addOnSkins or not E.db.addOnSkins.skins.QuestCompletionist then return end

	local frame = _G.QuestCompletionistFrame
	if not frame or frame.__AS_QuestCompletionist then return end
	frame.__AS_QuestCompletionist = true

	-- Main window: drop the Blizzard dialog border/background
	frame:SetBackdrop(nil)
	frame:SetTemplate("Transparent")
	if frame.CreateShadow then frame:CreateShadow(5) end

	if frame.title then
		frame.title:ClearAllPoints()
		frame.title:Point("TOP", frame, "TOP", 0, -10)
		frame.title:FontTemplate(nil, 14, "OUTLINE")
		frame.title:SetTextColor(unpack(E.media.rgbvaluecolor))
	end

	-- Search box and filter check boxes (named globals)
	if _G.QuestCompletionistSearch then
		S:HandleEditBox(_G.QuestCompletionistSearch)
	end
	S:HandleCheckBox(_G.QuestCompletionistHideDone)
	S:HandleCheckBox(_G.QuestCompletionistOnlyMine)
	S:HandleCheckBox(_G.QuestCompletionistShowUnob)

	-- Scroll bars of the zone list and the quest list
	if _G.QuestCompletionistLeftScrollScrollBar then
		S:HandleScrollBar(_G.QuestCompletionistLeftScrollScrollBar)
	end
	if _G.QuestCompletionistRightScrollScrollBar then
		S:HandleScrollBar(_G.QuestCompletionistRightScrollScrollBar)
	end

	-- Children: close button, progress bar, refresh button, list panels, list rows
	for i = 1, select("#", frame:GetChildren()) do
		local child = select(i, frame:GetChildren())
		local name = child:GetName()
		local objType = child:GetObjectType()

		if objType == "StatusBar" then
			-- progress bar
			child:SetStatusBarTexture(E.media.normTex)
			child:SetStatusBarColor(0.1, 0.7, 0.1)
			if child.bg then child.bg:SetTexture(nil) end
			child:CreateBackdrop("Default")
			if E.RegisterStatusBar then E:RegisterStatusBar(child) end
			if child.text then child.text:FontTemplate(nil, 11, "OUTLINE") end

		elseif objType == "Button" and not name then
			local normal = child:GetNormalTexture()
			local tex = normal and normal:GetTexture()
			if type(tex) == "string" and find(tex, "MinimizeButton") then
				-- UIPanelCloseButton
				S:HandleCloseButton(child, frame)
			elseif child:GetText() == "Refresh" then
				S:HandleButton(child)
			elseif child:GetHeight() == ROW_H then
				SkinRow(child)
			end

		elseif objType == "Frame" and not name and child.GetBackdrop then
			-- list panels (tooltip-style backdrop)
			local bd = child:GetBackdrop()
			if bd and type(bd.bgFile) == "string" and find(bd.bgFile, "UI%-Tooltip%-Background") then
				child:SetBackdrop(nil)
				child:SetTemplate("Transparent")
			end
		end
	end
end)
