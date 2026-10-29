local E, L, V, P, G = unpack(select(2, ...)); --Import: Engine, Locales, PrivateDB, ProfileDB, GlobalDB
local UF = E:GetModule("UnitFrames")

--[[
	Reverse Fill fuer Health-Bars (und die daran haengenden Prediction-Bars).

	Bei "reverse" fuellt sich der Bar von rechts nach links
	(bzw. bei VERTICAL von oben nach unten).

	Umsetzung (bewusst OHNE SetReverseFill, damit es auf jedem Client gleich laeuft):
	- Die echte StatusBar-Textur bleibt unangetastet und wird nur unsichtbar gemacht
	  (die Engine layoutet sie ständig neu, daran darf man nicht herumschrauben -> Flackern).
	- Stattdessen zeichnet eine eigene "Proxy"-Textur den Balken, rechts verankert.
	- bar:GetStatusBarTexture() liefert bei Reverse die Proxy-Textur zurueck, dadurch
	  haengen Heal-Prediction, Cutaway, Portrait, Glow, Gradient usw. automatisch richtig dran.
	- Farbe/Textur der echten Textur werden per Hook auf die Proxy-Textur gespiegelt.
	- Aktualisiert wird ueber Smoothie (bar.PostSmoothUpdate) nach jedem SetValue/SetMinMaxValues.
]]

--Lua functions
--WoW API / Variables
local hooksecurefunc = hooksecurefunc

-- immer die Proxy-Variante benutzen (siehe oben)
local HAS_NATIVE = false
UF.HAS_NATIVE_REVERSEFILL = HAS_NATIVE

-- Liest die Einstellung direkt aus der DB (unabhaengig von der Configure-Reihenfolge)
function UF:IsReverseFill(frame)
	local db = frame and frame.db
	return (db and db.health and db.health.reverseFill) and true or false
end

-- Echte Textur sicher unsichtbar halten (die Engine setzt Alpha/Farbe z.B. bei Farbwechseln im Kampf zurueck)
local function HideReal(bar)
	local real = bar.__rfReal
	if real then
		real:SetAlpha(0)
		local c = bar.__rfColor
		if c then real:SetVertexColor(c[1], c[2], c[3], 0) end
	end
end

local function ApplyEmulated(bar)
	if not bar.__reverseFill then return end

	local tex = bar.__rfProxy
	if not tex then return end

	HideReal(bar)

	local lo, hi = bar:GetMinMaxValues()
	local value = bar:GetValue() or lo
	local pct = 0
	if hi and lo and hi > lo then
		pct = (value - lo) / (hi - lo)
	end
	if pct < 0 then pct = 0 elseif pct > 1 then pct = 1 end

	tex:ClearAllPoints()
	if bar:GetOrientation() == "VERTICAL" then
		local height = bar:GetHeight()
		if not height or height <= 0 then height = bar.HEIGHT or 0 end

		tex:SetPoint("TOPLEFT", bar, "TOPLEFT")
		tex:SetPoint("TOPRIGHT", bar, "TOPRIGHT")
		tex:SetHeight(height * pct)
		tex:SetTexCoord(0, 1, 0, pct)
	else
		local width = bar:GetWidth()
		if not width or width <= 0 then width = bar.WIDTH or 0 end

		tex:SetPoint("TOPRIGHT", bar, "TOPRIGHT")
		tex:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT")
		tex:SetWidth(width * pct)
		tex:SetTexCoord(1 - pct, 1, 0, 1)
	end

	if pct <= 0 then
		tex:Hide()
	else
		tex:Show()
	end
end

local function SyncTexture(bar)
	local proxy, real = bar.__rfProxy, bar.__rfReal
	if proxy and real then
		proxy:SetTexture(real:GetTexture())
	end
end

local function SyncColor(bar, r, g, b, a)
	local proxy = bar.__rfProxy
	if proxy and r then
		a = a or 1
		bar.__rfColor = {r, g, b, a}
		proxy:SetVertexColor(r, g, b, a)
		HideReal(bar)
	end
end

local function OnSizeChanged(bar)
	if bar.__reverseFill then
		ApplyEmulated(bar)
	end
end

-- Proxy-Textur + Hooks einmalig pro Bar anlegen
local function EnsureProxy(bar)
	if bar.__rfProxy then return end

	local real = bar:GetStatusBarTexture()
	local proxy = bar:CreateTexture(nil, "ARTWORK")
	proxy:SetTexture(real:GetTexture())
	proxy:Hide()

	bar.__rfReal = real
	bar.__rfProxy = proxy

	-- Alle Anker-Abfragen (HealComm, Cutaway, Portrait, Glow, Gradient ...) bekommen bei Reverse die Proxy-Textur
	bar.GetStatusBarTexture = function(self)
		if self.__reverseFill then
			return self.__rfProxy
		end
		return self.__rfReal
	end

	hooksecurefunc(bar, "SetStatusBarColor", function(self, r, g, b, a)
		if self.__reverseFill then SyncColor(self, r, g, b, a) end
	end)
	hooksecurefunc(bar, "SetStatusBarTexture", function(self)
		if self.__reverseFill then SyncTexture(self) end
	end)

	bar:HookScript("OnSizeChanged", OnSizeChanged)
end

-- Nach einem SetStatusBarTexture & Co. erneut anwenden (Sicherheitsnetz)
function UF:ReapplyReverseFill(bar)
	if bar and bar.__reverseFill and bar.__rfProxy then
		SyncTexture(bar)
		ApplyEmulated(bar)
	end
end

--[[
	bar     - StatusBar
	reverse - true/false
	smooth  - ob Smoothing (E:SetSmoothing) fuer diesen Bar aktiv sein soll
]]
function UF:SetupReverseFill(bar, reverse, smooth)
	reverse = reverse and true or false
	smooth = smooth and true or false

	local wasReverse = bar.__reverseFill

	if reverse then
		EnsureProxy(bar)

		bar.__reverseFill = true
		bar.PostSmoothUpdate = ApplyEmulated
		bar.__instantSmooth = not smooth -- ohne Smoothing: sofort schreiben, aber Hook trotzdem ausfuehren
		E:SetSmoothing(bar, true)

		-- echte Textur verstecken, Proxy uebernimmt Farbe/Textur
		SyncTexture(bar)
		if not wasReverse or not bar.__rfColor then
			-- nur beim ersten Aktivieren von der echten Textur lesen (danach ist ihr Alpha 0)
			local r, g, b, a = bar.__rfReal:GetVertexColor()
			SyncColor(bar, r, g, b, a)
		else
			local c = bar.__rfColor
			SyncColor(bar, c[1], c[2], c[3], c[4])
		end

		ApplyEmulated(bar)
	else
		bar.__reverseFill = false
		bar.PostSmoothUpdate = nil
		bar.__instantSmooth = nil
		E:SetSmoothing(bar, smooth)

		if wasReverse and bar.__rfProxy then
			bar.__rfProxy:Hide()
			bar.__rfReal:SetAlpha(1)
			local c = bar.__rfColor
			if c then bar.__rfReal:SetVertexColor(c[1], c[2], c[3], c[4]) end

			-- Engine zwingen, die echte Textur neu zu berechnen
			local setMinMax = bar.SetMinMaxValues_ or bar.SetMinMaxValues
			local setValue = bar.SetValue_ or bar.SetValue
			local lo, hi = bar:GetMinMaxValues()
			setMinMax(bar, lo, hi)
			setValue(bar, bar:GetValue())
		end
	end
end
