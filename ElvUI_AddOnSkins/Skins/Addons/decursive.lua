local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

if not AS:IsAddonLODorEnabled("Decursive") then return end

local _G = _G
local ipairs, unpack, format = ipairs, unpack, format

-- Decursive 2.5.1 / CoA build
-- Keep all Decursive behavior intact; this file only changes presentation.
S:AddCallbackForAddon("Decursive", "Decursive", function()
	if not E.db.addOnSkins.skins.Decursive then return end

	local D = _G.Dcr
	if not D then return end

	local function SkinFont(fontString, size, outline)
		if not fontString or fontString.__AS_DecursiveFont then return end
		if fontString.FontTemplate then
			fontString:FontTemplate(nil, size, outline)
		end
		fontString.__AS_DecursiveFont = true
	end

	local function SkinButton(button, closeButton)
		if not button or button.__AS_Decursive then return end

		if closeButton then
			S:HandleCloseButton(button)
		else
			S:HandleButton(button)
		end

		button.__AS_Decursive = true
	end

	local function SkinFrame(frame)
		if not frame or frame.__AS_Decursive then return end
		frame:StripTextures()
		frame:SetTemplate("Transparent")
		frame.__AS_Decursive = true
	end

	local function SkinMainBar()
		local frame = _G.DecursiveMainBar
		if not frame then return end

		SkinFrame(frame)
		SkinFont(_G.DecursiveMainBarText, 11, "OUTLINE")

		SkinButton(_G.DecursiveMainBarPriority)
		SkinButton(_G.DecursiveMainBarSkip)
		SkinButton(_G.DecursiveMainBarHide, true)
	end

	local function SkinAnchor()
		local frame = _G.DecursiveAnchor
		if not frame then return end

		SkinFrame(frame)
		SkinFont(_G.DecursiveAnchorText, 11, "OUTLINE")
		SkinButton(_G.DecursiveAnchorDirection)
	end

	local function SkinListEntries(frame)
		if not frame then return end
		local frameName = frame:GetName()
		if not frameName then return end

		for i = 1, 10 do
			local entry = _G[frameName.."Index"..format("%02d", i)]
			if entry and not entry.__AS_DecursiveEntry then
				local text = _G[entry:GetName().."Text"]
				SkinFont(text, 11)
				entry.__AS_DecursiveEntry = true
			end
		end
	end

	local function SkinListFrame(frame)
		if not frame then return end
		local frameName = frame:GetName()
		if not frameName then return end

		SkinFrame(frame)
		SkinFont(_G[frameName.."Text"], 12, "OUTLINE")

		SkinButton(_G[frameName.."Clear"])
		SkinButton(_G[frameName.."Close"], true)
		SkinButton(_G[frameName.."Populate"])
		SkinButton(_G[frameName.."Add"])

		local scrollBar = _G[frameName.."ScrollFrameScrollBar"]
		if scrollBar and not scrollBar.__AS_Decursive then
			S:HandleScrollBar(scrollBar)
			scrollBar.__AS_Decursive = true
		end

		SkinListEntries(frame)
	end

	local function SkinPopulateButtons()
		local frame = _G.DecursivePopulateListFrame
		if not frame then return end

		SkinFrame(frame)
		SkinFont(_G.DecursivePopulateListFrameTitle, 12, "OUTLINE")
		SkinFont(_G.DecursivePopulateListFrameText, 11)

		-- Static and dynamically-added class/group buttons all live directly
		-- inside the populate frame, so discover them instead of hardcoding
		-- only the original 3.3.5 class list.
		for _, child in ipairs({frame:GetChildren()}) do
			if child and child.IsObjectType and child:IsObjectType("Button") and not child.__AS_Decursive then
				local name = child:GetName()
				if name == "DecursivePopulateListFrameClose" then
					SkinButton(child, true)
				else
					SkinButton(child)
				end
			end
		end
	end

	local function SkinMUFHandle()
		local button = _G.DcrMUFsContainerDragButton
		if not button or button.__AS_Decursive then return end

		-- The drag handle is intentionally only visible on hover in Decursive.
		-- Keep that behavior and only replace the old Blizzard highlight.
		local highlight = button:GetHighlightTexture()
		if highlight then
			highlight:SetTexture(E.Media.Textures.Highlight)
			highlight:SetVertexColor(1, 1, 1, 0.30)
			highlight:SetAllPoints()
		end

		button.__AS_Decursive = true
	end

	local function SkinLiveListItem(item)
		if not item or not item.Frame or item.Frame.__AS_Decursive then return end

		local frame = item.Frame
		frame:CreateBackdrop("Transparent")

		if item.BackGroundTexture then
			item.BackGroundTexture:SetTexture(nil)
		end

		if item.IconTexture then
			item.IconTexture:SetTexCoord(unpack(E.TexCoords))
		end

		SkinFont(item.DebuffAppsFontString, 10, "OUTLINE")
		SkinFont(item.UnitNameFontString, 10, "OUTLINE")
		SkinFont(item.UnitIDFontString, 8)
		SkinFont(item.DebuffTypeFontString, 10)
		SkinFont(item.DebuffNameFontString, 10)

		frame.__AS_Decursive = true
	end

	local function SkinExistingLiveList()
		if not D.LiveList or not D.LiveList.ExistingPerID then return end
		for _, item in ipairs(D.LiveList.ExistingPerID) do
			SkinLiveListItem(item)
		end
	end

	local function SkinTooltip()
		local tooltip = _G.DcrDisplay_Tooltip
		if not tooltip or tooltip.__AS_Decursive then return end
		tooltip:SetTemplate("Transparent")
		tooltip.__AS_Decursive = true
	end

	local function SkinAll()
		SkinMainBar()
		SkinAnchor()
		SkinListFrame(_G.DecursivePriorityListFrame)
		SkinListFrame(_G.DecursiveSkipListFrame)
		SkinPopulateButtons()
		SkinMUFHandle()
		SkinExistingLiveList()
		SkinTooltip()
	end

	-- Decursive creates live-list rows only when they are needed.
	if D.LiveList and D.LiveList.Create then
		hooksecurefunc(D.LiveList, "Create", function(self)
			local item = self.ExistingPerID and self.ExistingPerID[self.Number]
			SkinLiveListItem(item)
		end)
	end

	-- Extra class buttons in the quick-populate window can be created lazily.
	if _G.DecursivePopulateListFrame then
		_G.DecursivePopulateListFrame:HookScript("OnShow", SkinPopulateButtons)
	end

	SkinAll()
end)
