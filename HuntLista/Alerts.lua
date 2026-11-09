-- ============================================================
-- Hunt Lista - Alerty + ikonka
-- ============================================================

local addonName, ns = ...
local HL = ns.HL or HuntLista

-- Cooldown na alerty (żeby nie spamowało)
local lastAlert = {}
local ALERT_COOLDOWN = 8 -- sekund

local function CanAlert(name)
    local now = GetTime()
    if lastAlert[name] and (now - lastAlert[name]) < ALERT_COOLDOWN then
        return false
    end
    lastAlert[name] = now
    return true
end

function HL:CheckUnit(unit)
    if not HuntListaDB.enabled then return end
    if not UnitExists(unit) then return end
    if not UnitIsPlayer(unit) then return end

    -- Tylko wrogowie (przeciwna frakcja)
    if not UnitIsEnemy("player", unit) then return end

    local name = UnitName(unit)
    if not name then return end

    local info = HL:GetInfo(name)
    if not info then return end

    -- Alert tekstowy + dźwięk
    if CanAlert(name) then
        local reason = info.reason ~= "" and (" – " .. info.reason) or ""
        local msg = "|cffff0000[HUNT]|r |cffffff00" .. info.name .. "|r" .. reason

        -- Raid warning style
        RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
        print(msg)

        if HuntListaDB.sound then
            PlaySound(SOUNDKIT.RAID_WARNING, "Master")
        end
    end

    -- Ikonka na nameplate / target
    if HuntListaDB.showIcon then
        HL:ShowHuntIcon(unit, info)
    end
end

-- Prosta ikonka (czerwona czaszka / target)
local iconPool = {}

local function GetIcon()
    for _, icon in ipairs(iconPool) do
        if not icon:IsShown() then
            return icon
        end
    end
    local icon = CreateFrame("Frame", nil, UIParent)
    icon:SetSize(24, 24)
    icon.tex = icon:CreateTexture(nil, "OVERLAY")
    icon.tex:SetAllPoints()
    icon.tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8") -- czaszka
    icon.tex:SetVertexColor(1, 0.2, 0.2)
    icon:Hide()
    table.insert(iconPool, icon)
    return icon
end

function HL:ShowHuntIcon(unit, info)
    -- Na razie prosty sposób: pokazuje ikonkę przy targetcie / mouseover
    -- Pełna integracja z nameplates wymaga więcej kodu (hooki na nameplate frames)

    if unit == "target" or unit == "mouseover" then
        local icon = GetIcon()
        icon:ClearAllPoints()

        if unit == "target" and TargetFrame then
            icon:SetParent(TargetFrame)
            icon:SetPoint("CENTER", TargetFrame, "TOP", 0, 12)
            icon:Show()
            -- Auto hide po chwili
            C_Timer.After(6, function()
                if icon:IsShown() then icon:Hide() end
            end)
        end
    end
end

-- Hook na nameplates (podstawowy)
local function OnNamePlateAdded(unit)
    if not HuntListaDB.showIcon then return end
    if not UnitIsPlayer(unit) then return end
    if not UnitIsEnemy("player", unit) then return end

    local name = UnitName(unit)
    if not HL:IsOnList(name) then return end

    -- Próbujemy znaleźć frame nameplate
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or not plate.UnitFrame then return end

    local uf = plate.UnitFrame
    if not uf.HuntListaIcon then
        uf.HuntListaIcon = uf:CreateTexture(nil, "OVERLAY")
        uf.HuntListaIcon:SetSize(18, 18)
        uf.HuntListaIcon:SetPoint("RIGHT", uf.healthBar or uf, "LEFT", -2, 0)
        uf.HuntListaIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
        uf.HuntListaIcon:SetVertexColor(1, 0.15, 0.15)
    end
    uf.HuntListaIcon:Show()
end

-- Podpinamy się do eventu nameplate
local npFrame = CreateFrame("Frame")
npFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
npFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
npFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "NAME_PLATE_UNIT_ADDED" then
        OnNamePlateAdded(unit)
        HL:CheckUnit(unit)
    elseif event == "NAME_PLATE_UNIT_REMOVED" then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate and plate.UnitFrame and plate.UnitFrame.HuntListaIcon then
            plate.UnitFrame.HuntListaIcon:Hide()
        end
    end
end)
