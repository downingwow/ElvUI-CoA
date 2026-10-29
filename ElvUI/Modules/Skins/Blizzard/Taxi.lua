local E, L, V, P, G = unpack(select(2, ...)) --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local S = E:GetModule("Skins")

--Lua functions
--WoW API / Variables

S:AddCallback("Skin_Taxi", function()
	if not E.private.skins.blizzard.enable or not E.private.skins.blizzard.taxi then return end

	TaxiFrame:StripTextures()

	TaxiFrame:CreateBackdrop("Transparent")
	TaxiFrame.backdrop:Point("TOPLEFT", 11, -12)
	TaxiFrame.backdrop:Point("BOTTOMRIGHT", -32, 76)

	S:SetUIPanelWindowInfo(TaxiFrame, "width")
	S:SetBackdropHitRect(TaxiFrame)

	TaxiPortrait:Kill()

	S:HandleCloseButton(TaxiCloseButton, TaxiFrame.backdrop)

	TaxiRouteMap:CreateBackdrop("Default")

	local TAXI_MAP_WIDTH = 331		-- orig 316
	local TAXI_MAP_HEIGHT = 369		-- orig 352

	_G.TAXI_MAP_WIDTH = TAXI_MAP_WIDTH
	_G.TAXI_MAP_HEIGHT = TAXI_MAP_HEIGHT

	TaxiMap:Size(TAXI_MAP_WIDTH, TAXI_MAP_HEIGHT)
	TaxiRouteMap:Size(TAXI_MAP_WIDTH, TAXI_MAP_HEIGHT)

	TaxiMap:Point("TOP", -11, -48)
	TaxiRouteMap:Point("TOP", -11, -48)
end)

-- Flugkarte skalieren (unabhaengig vom Skin). Skaliert Frame, Karte, Flugpunkte und
-- Klickbereiche gemeinsam, dadurch bleiben alle Flugpunkte exakt klickbar.
function S:UpdateTaxiScale()
	if not TaxiFrame then return end

	local scale = tonumber(E.private.skins and E.private.skins.taxiScale) or 1
	if scale < 0.5 then scale = 0.5 elseif scale > 2.5 then scale = 2.5 end

	if TaxiFrame:GetScale() ~= scale then
		TaxiFrame:SetScale(scale)
	end
end

S:AddCallback("Skin_TaxiScale", function()
	if not TaxiFrame then return end

	S:UpdateTaxiScale()

	-- Falls ein anderes Addon/Blizzard die Skalierung beim Oeffnen zuruecksetzt
	TaxiFrame:HookScript("OnShow", function()
		S:UpdateTaxiScale()
	end)
end)
