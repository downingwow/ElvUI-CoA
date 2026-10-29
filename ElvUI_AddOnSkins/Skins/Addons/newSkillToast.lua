local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

if not AS:IsAddonLODorEnabled("Ascension_NewSkillToast") then return end

local _G = _G
local select, unpack = select, unpack
local CreateFrame = CreateFrame
local hooksecurefunc = hooksecurefunc

-- Ascension New Skill Toast 1.0.0
-- Skin: ElvUI-Look fuer den "Neuer Skill erlernt"-Frame.
-- Mover: "New Skill Toast" in /moveui (verschiebt NewSkillToastHolder).
-- Preview: dauerhafte Vorschau solange die Mover sichtbar sind + Button in den AddOnSkins-Optionen.
-- Nur Optik/Position - die Logik des Addons bleibt unberuehrt.

S:AddCallbackForAddon("Ascension_NewSkillToast", "Ascension_NewSkillToast", function()
	local toast = _G.NewSkillToast
	local frame = toast and toast.frame
	local holder = toast and toast.holder
	if not frame or frame.__AS_NewSkillToast then return end
	frame.__AS_NewSkillToast = true

	------------------------------------------------------------------
	-- Mover (immer, auch wenn der Skin deaktiviert ist)
	------------------------------------------------------------------
	holder.moverActive = true
	E:CreateMover(holder, "NewSkillToastMover", "New Skill Toast", nil, nil, nil, "ALL,GENERAL")

	local mover = _G.NewSkillToastMover
	if mover then
		-- Vorschau, solange die Mover (ElvUI Config-Modus) angezeigt werden
		mover:HookScript("OnShow", function() toast.SetStickyPreview(true) end)
		mover:HookScript("OnHide", function() toast.SetStickyPreview(false) end)
		if mover:IsShown() then toast.SetStickyPreview(true) end
	end

	------------------------------------------------------------------
	-- Skin
	------------------------------------------------------------------
	if not E.db or not E.db.addOnSkins or not E.db.addOnSkins.skins.Ascension_NewSkillToast then return end

	-- Blizzard-Dialog-Rahmen entfernen
	frame:SetBackdrop(nil)
	frame:SetTemplate("Transparent")
	if frame.CreateShadow then frame:CreateShadow(5) end

	-- Glow-Rand um das Icon ausblenden, Icon-Rahmen im ElvUI-Stil
	if frame.glow then frame.glow:Hide(); frame.glow.Show = E.noop end
	if frame.iconBorder then frame.iconBorder:Hide() end

	if frame.icon then
		local iconHolder = CreateFrame("Frame", nil, frame)
		iconHolder:SetFrameLevel(frame:GetFrameLevel() + 1)
		iconHolder:Size(50, 50)
		iconHolder:Point("LEFT", frame, "LEFT", 12, 0)
		iconHolder:SetTemplate("Default")

		frame.icon:SetParent(iconHolder)
		frame.icon:SetDrawLayer("ARTWORK")
		frame.icon:ClearAllPoints()
		frame.icon:Point("TOPLEFT", iconHolder, "TOPLEFT", 2, -2)
		frame.icon:Point("BOTTOMRIGHT", iconHolder, "BOTTOMRIGHT", -2, 2)
		frame.icon:SetTexCoord(unpack(E.TexCoords))
		frame.iconHolder = iconHolder

		-- Texte neben das neue Icon setzen
		frame.title:ClearAllPoints()
		frame.title:Point("TOPLEFT", iconHolder, "TOPRIGHT", 10, -3)
		frame.title:Point("RIGHT", frame, "RIGHT", -12, 0)
		frame.name:ClearAllPoints()
		frame.name:Point("TOPLEFT", frame.title, "BOTTOMLEFT", 0, -5)
		frame.name:Point("RIGHT", frame, "RIGHT", -12, 0)
	end

	-- Schriften
	frame.title:FontTemplate(nil, 12, "OUTLINE")
	frame.title:SetTextColor(unpack(E.media.rgbvaluecolor))
	frame.name:FontTemplate(nil, 16, "OUTLINE")
	frame.name:SetTextColor(1, 1, 1)
end)
