-- Hunt Lista - alerts and icons. Core owns the unit event subscriptions.
local addonName, ns = ...
local HL = ns.HL or HuntLista
local lastAlert = {}
local ALERT_COOLDOWN = 8
local targetIcon
local plateIcons = {}

local function PlainUnit(unit)
    return (not issecretvalue or not issecretvalue(unit)) and type(unit) == "string" and unit ~= ""
end

local function TrueResult(fn, ...)
    if not fn then return false end
    local ok, value = pcall(fn, ...)
    return ok and (not issecretvalue or not issecretvalue(value)) and value == true
end

local function PlateFrame(unit)
    if not C_NamePlate or not C_NamePlate.GetNamePlateForUnit then return end
    local ok, plate = pcall(C_NamePlate.GetNamePlateForUnit, unit)
    if ok and plate then return plate.UnitFrame end
end

function HL:HideHuntIcon(unit)
    if not PlainUnit(unit) then return end
    if unit == "target" then
        if targetIcon then targetIcon:Hide() end
    elseif plateIcons[unit] then
        plateIcons[unit]:Hide()
        plateIcons[unit] = nil
    end
end

local function ShowTargetIcon()
    if not TargetFrame then return end
    if not targetIcon then
        targetIcon = CreateFrame("Frame", nil, TargetFrame)
        targetIcon:SetSize(24, 24)
        targetIcon:SetPoint("CENTER", TargetFrame, "TOP", 0, 12)
        local texture = targetIcon:CreateTexture(nil, "OVERLAY")
        texture:SetAllPoints()
        texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
        texture:SetVertexColor(1, 0.2, 0.2)
    end
    targetIcon:Show()
end

local function ShowPlateIcon(unit, uf)
    if not uf then return end
    if not uf.HuntListaIcon then
        uf.HuntListaIcon = uf:CreateTexture(nil, "OVERLAY")
        uf.HuntListaIcon:SetSize(18, 18)
        uf.HuntListaIcon:SetPoint("RIGHT", uf.healthBar or uf, "LEFT", -2, 0)
        uf.HuntListaIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
        uf.HuntListaIcon:SetVertexColor(1, 0.15, 0.15)
    end
    plateIcons[unit] = uf.HuntListaIcon
    uf.HuntListaIcon:Show()
end

function HL:CheckUnit(unit)
    if not PlainUnit(unit) then return end
    HL:HideHuntIcon(unit)
    local plate = unit ~= "target" and unit ~= "mouseover" and PlateFrame(unit)
    -- Blizzard can reuse a plate frame for a different unit token.
    if plate and plate.HuntListaIcon then plate.HuntListaIcon:Hide() end
    if not HuntListaDB or HuntListaDB.enabled == false then return end
    if not TrueResult(UnitExists, unit) or not TrueResult(UnitIsPlayer, unit) then return end
    if not HuntListaDB.testMode and not TrueResult(UnitIsEnemy, "player", unit) then return end

    local name = HL:GetUnitFullName(unit)
    local info = HL:GetInfo(name)
    if not info then return end

    if HuntListaDB.showIcon then
        if unit == "target" then ShowTargetIcon()
        elseif plate then ShowPlateIcon(unit, plate) end
    end

    local setting = "alertOnNameplate"
    if unit == "target" then setting = "alertOnTarget"
    elseif unit == "mouseover" then setting = "alertOnMouseover" end
    if not HuntListaDB[setting] then return end
    local key = strlower(info.name)
    local now = GetTime()
    if lastAlert[key] and now - lastAlert[key] < ALERT_COOLDOWN then return end
    lastAlert[key] = now

    local reason = (info.reason and info.reason ~= "") and (" - " .. info.reason) or ""
    local msg = "|cffff0000[HUNT]|r |cffffff00" .. info.name .. "|r" .. reason
    if RaidNotice_AddMessage and RaidWarningFrame then
        pcall(RaidNotice_AddMessage, RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
    end
    print(msg)
    if HL.PlayHuntSound then HL:PlayHuntSound() end
end
