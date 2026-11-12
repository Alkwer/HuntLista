-- ============================================================
-- Hunt Lista - Alerty + ikonka
-- ============================================================

local addonName, ns = ...
local HL = ns.HL or HuntLista

local lastAlert = {}
local ALERT_COOLDOWN = 8

local function CanAlert(name)
    local now = GetTime()
    if lastAlert[name] and (now - lastAlert[name]) < ALERT_COOLDOWN then
        return false
    end
    lastAlert[name] = now
    return true
end

function HL:CheckUnit(unit)
    if not HuntListaDB or HuntListaDB.enabled == false then return end
    if not unit or not UnitExists(unit) then return end
    if not UnitIsPlayer(unit) then return end

    if not HuntListaDB.testMode then
        if not UnitIsEnemy("player", unit) then return end
    end

    local okN, name = pcall(UnitName, unit)
    if not okN or type(name) ~= "string" or name == "" then return end
    if issecretvalue and issecretvalue(name) then return end

    local info = HL:GetInfo(name)
    if not info and HL.ResolveFullName then
        local full = HL:ResolveFullName(name)
        if full then info = HL:GetInfo(full) end
    end
    if not info and UnitFullName then
        local okF, full = pcall(UnitFullName, unit)
        if okF and full then info = HL:GetInfo(full) end
    end

    if HuntListaDB.debug then
        print("|cff888888[HL debug]|r unit=" .. tostring(unit) .. " name=" .. tostring(name)
            .. " onList=" .. (info and ("YES:" .. info.name) or "NO"))
    end

    if not info then return end

    if CanAlert(strlower(name)) then
        local reason = (info.reason and info.reason ~= "") and (" - " .. info.reason) or ""
        local msg = "|cffff0000[HUNT]|r |cffffff00" .. info.name .. "|r" .. reason
        if RaidNotice_AddMessage and RaidWarningFrame then
            pcall(function()
                RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
            end)
        end
        print(msg)
        if HL.PlayHuntSound then HL:PlayHuntSound() end
    end

    if HuntListaDB.showIcon then
        HL:ShowHuntIcon(unit, info)
    end
end

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
    icon.tex:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
    icon.tex:SetVertexColor(1, 0.2, 0.2)
    icon:Hide()
    table.insert(iconPool, icon)
    return icon
end

function HL:ShowHuntIcon(unit, info)
    if unit == "target" or unit == "mouseover" then
        local icon = GetIcon()
        icon:ClearAllPoints()

        if unit == "target" and TargetFrame then
            icon:SetParent(TargetFrame)
            icon:SetPoint("CENTER", TargetFrame, "TOP", 0, 12)
            icon:Show()
            C_Timer.After(6, function()
                if icon:IsShown() then icon:Hide() end
            end)
        end
    end
end

local function EnsurePlateIcon(uf)
    if not uf.HuntListaIcon then
        uf.HuntListaIcon = uf:CreateTexture(nil, "OVERLAY")
        uf.HuntListaIcon:SetSize(18, 18)
        uf.HuntListaIcon:SetPoint("RIGHT", uf.healthBar or uf, "LEFT", -2, 0)
        uf.HuntListaIcon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcon_8")
        uf.HuntListaIcon:SetVertexColor(1, 0.15, 0.15)
    end
    return uf.HuntListaIcon
end

local function OnNamePlateAdded(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if not plate or not plate.UnitFrame then return end
    local uf = plate.UnitFrame

    if uf.HuntListaIcon then
        uf.HuntListaIcon:Hide()
    end

    if not HuntListaDB or not HuntListaDB.showIcon then return end
    if not UnitIsPlayer(unit) then return end
    if not HuntListaDB.testMode then
        if not UnitIsEnemy("player", unit) then return end
    end

    local name = UnitName(unit)
    if not HL:IsOnList(name) then return end

    local icon = EnsurePlateIcon(uf)
    icon:Show()
end

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
