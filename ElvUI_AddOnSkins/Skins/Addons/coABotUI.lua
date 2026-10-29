local E, L, V, P, G = unpack(ElvUI)
local S = E:GetModule("Skins")
local AS = E:GetModule("AddOnSkins")

if not AS:IsAddonLODorEnabled("CoABotUI") then return end

-- CoABotUI owns its own frames and behaviour. This file modifies appearance only.
S:AddCallbackForAddon("CoABotUI", "CoABotUI", function()
    if not E.db or not E.db.addOnSkins or not E.db.addOnSkins.skins.CoABotUI then return end

    local function SkinButton(button)
        if button.__AS_CoABotUI then return end
        button.__AS_CoABotUI = true
        if button.icon and button.icon.SetTexCoord then
            button.icon:SetTexCoord(unpack(E.TexCoords))
        end
        -- Some custom icon buttons have no text and no Blizzard template.
        if button.GetNormalTexture and button:GetNormalTexture() then
            S:HandleButton(button)
        elseif button.GetText and button:GetText() then
            S:HandleButton(button)
        elseif button.SetTemplate and button.GetBackdrop then
            button:SetTemplate("Default")
        end
    end

    local function SkinFrame(frame)
        if frame.__AS_CoABotUI then return end
        frame.__AS_CoABotUI = true
        if frame.SetTemplate and frame.GetBackdrop then
            frame:SetTemplate("Transparent")
        end
    end

    -- The two UIDropDownMenuTemplate controls are Frames rather than Buttons.
    -- Their Blizzard borders and arrows require the dropdown skin explicitly.
    local function SkinDropdown(drop)
        if not drop or drop.__AS_CoABotUI_Dropdown then return end
        if S.HandleDropDownBox then
            S:HandleDropDownBox(drop)
            drop.__AS_CoABotUI_Dropdown = true
        end
    end

    local function SkinEditBox(box)
        if box.__AS_CoABotUI then return end
        box.__AS_CoABotUI = true
        -- CoABotUI's custom boxes define their own tooltip-style backdrop.
        -- Replace it with the standard ElvUI input appearance, leaving size,
        -- numeric settings, handlers and text untouched.
        if S.HandleEditBox then S:HandleEditBox(box) end
        if box.SetTemplate then box:SetTemplate("Default") end
    end

    local function SkinElement(child)
        if child.__AS_CoABotUI then return end
        if child == _G.CoABotUIBrowseRole or child == _G.CoABotUIInviteMenu then
            SkinDropdown(child)
        elseif child.IsObjectType and child:IsObjectType("EditBox") then
            SkinEditBox(child)
        elseif child.IsObjectType and child:IsObjectType("CheckButton") then
            child.__AS_CoABotUI = true
            if S.HandleCheckBox then S:HandleCheckBox(child) end
        elseif child.IsObjectType and child:IsObjectType("Button") then
            SkinButton(child)
        elseif child.IsObjectType and child:IsObjectType("ScrollFrame") then
            child.__AS_CoABotUI = true
            local bar = child.ScrollBar or (child.GetName and child:GetName() and _G[child:GetName().."ScrollBar"])
            if bar and not bar.__AS_CoABotUI then
                bar.__AS_CoABotUI = true
                S:HandleScrollBar(bar)
            end
        elseif child.IsObjectType and child:IsObjectType("Frame") then
            -- Style only true dialog shells, not every invisible layout container.
            local name = child.GetName and child:GetName()
            if name == "CoABotUIRoleMenu" or name == "CoABotUISpecMenu" or
               name == "CoABotUIFormationMenu" or name == "CoABotUIRecipeProfessionMenu" then
                SkinFrame(child)
            end
        end
    end

    local function Visit(frame, depth)
        if not frame or depth > 8 then return end
        for _, child in ipairs({frame:GetChildren()}) do
            SkinElement(child)
            if child.GetChildren then Visit(child, depth + 1) end
        end
    end

    local function SkinAll()
        local main = _G.CoABotUIMainFrame
        if not main then return false end
        SkinFrame(main)
        Visit(main, 0)
        SkinDropdown(_G.CoABotUIBrowseRole)
        SkinDropdown(_G.CoABotUIInviteMenu)
        for _, name in ipairs({
            "CoABotUITaskBoard", "CoABotUIBotBrowser", "CoABotUIOrderPicker",
            "CoABotUIGearPanel", "CoABotUIRoleMenu", "CoABotUISpecMenu",
            "CoABotUIFormationMenu", "CoABotUIRecipeProfessionMenu"
        }) do
            local frame = _G[name]
            if frame then
                if name == "CoABotUIRoleMenu" or name == "CoABotUISpecMenu" or
                   name == "CoABotUIFormationMenu" or name == "CoABotUIRecipeProfessionMenu" then
                    SkinFrame(frame)
                end
                Visit(frame, 0)
            end
        end
        return true
    end

    local watcher = CreateFrame("Frame")
    watcher:RegisterEvent("PLAYER_ENTERING_WORLD")
    watcher:RegisterEvent("ADDON_LOADED")
    watcher:SetScript("OnEvent", function(self, event, addon)
        if event ~= "ADDON_LOADED" or addon == "CoABotUI" then SkinAll() end
    end)

    -- Dynamically created list rows and menus need a later skin pass.
    -- Unlike a permanent OnUpdate, this checks only while the UI is visible.
    local elapsed = 0
    watcher:SetScript("OnUpdate", function(self, dt)
        elapsed = elapsed + dt
        if elapsed < 0.35 then return end
        elapsed = 0
        local main = _G.CoABotUIMainFrame
        if main and main:IsShown() then SkinAll() end
    end)
    SkinAll()
end)
