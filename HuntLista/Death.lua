-- ============================================================
-- Hunt Lista - Okienko po smierci (bez taintu) + cache pelnych nickow
-- ============================================================

local addonName, ns = ...
local HL = ns.HL or HuntLista

local playerGUID
local lastAttackerName = nil
local lastAttackerTime = 0
local deathFrame

-- Forever: UnitName/CLEU zwraca "Mowie", nameplate pokazuje "Mowie Cowie"
-- Cache: pierwsze_slowo(lower) -> najdluzsza widziana pelna nazwa
HL.NameCache = HL.NameCache or {}

local function StripRealm(name)
    if not name or name == "" then return nil end
    name = strtrim(name)
    -- usun kody kolorow
    name = name:gsub("|c%x%x%x%x%x%x%x%x", ""):gsub("|r", "")
    name = name:gsub("|T.-|t", "")
    local base = name:match("^(.-)%-[^%-]+$")
    if base and base ~= "" then name = base end
    name = strtrim(name)
    if name == "" then return nil end
    return name
end

local function FirstWord(name)
    if not name then return nil end
    return strlower(strtrim(name):match("^(%S+)") or name)
end

function HL:CacheFullName(full)
    full = StripRealm(full)
    if not full then return end
    local fw = FirstWord(full)
    if not fw then return end
    local prev = HL.NameCache[fw]
    if not prev or #full > #prev then
        HL.NameCache[fw] = full
    end
end

function HL:ResolveFullName(name)
    name = StripRealm(name)
    if not name then return nil end
    local fw = FirstWord(name)
    local cached = fw and HL.NameCache[fw]
    if cached and #cached >= #name then
        return cached
    end
    -- jesli na liscie jest dluzszy wariant
    if HL.GetInfo then
        local info = HL:GetInfo(name)
        if info and info.name and #info.name >= #name then
            return info.name
        end
    end
    return name
end

function HL:CacheUnit(unit)
    if not unit or not UnitExists(unit) then return end
    if not UnitIsPlayer(unit) then return end

    local n = UnitName(unit)
    if n then HL:CacheFullName(n) end

    -- nameplate fontstring czesto ma PELNA nazwe w Forever
    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate and plate.UnitFrame then
            local uf = plate.UnitFrame
            local candidates = {}
            if uf.name and uf.name.GetText then
                table.insert(candidates, uf.name:GetText())
            end
            if uf.Name and uf.Name.GetText then
                table.insert(candidates, uf.Name:GetText())
            end
            -- czasem name jest dzieckiem
            if uf.GetRegions then
                local regions = { uf:GetRegions() }
                for _, r in ipairs(regions) do
                    if r and r.GetObjectType and r:GetObjectType() == "FontString" and r.GetText then
                        local t = r:GetText()
                        if t and #t > 1 and not t:find("%%") then
                            table.insert(candidates, t)
                        end
                    end
                end
            end
            for _, t in ipairs(candidates) do
                if t and n and #StripRealm(t) or 0 >= #(n or "") then
                    HL:CacheFullName(t)
                elseif t then
                    HL:CacheFullName(t)
                end
            end
        end
    end
end

local function MakeButton(parent, width, text)
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(width, 26)
    b.bg = b:CreateTexture(nil, "BACKGROUND")
    b.bg:SetAllPoints()
    b.bg:SetColorTexture(0.15, 0.15, 0.15, 0.95)
    b.border = b:CreateTexture(nil, "BORDER")
    b.border:SetPoint("TOPLEFT", -1, 1)
    b.border:SetPoint("BOTTOMRIGHT", 1, -1)
    b.border:SetColorTexture(0.45, 0.1, 0.1, 0.9)
    b.label = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    b.label:SetPoint("CENTER")
    b.label:SetText(text)
    b:SetScript("OnEnter", function(self)
        self.bg:SetColorTexture(0.3, 0.1, 0.1, 1)
    end)
    b:SetScript("OnLeave", function(self)
        self.bg:SetColorTexture(0.15, 0.15, 0.15, 0.95)
    end)
    return b
end

local function CreateDeathFrame()
    if deathFrame then return deathFrame end

    local f = CreateFrame("Frame", "HuntListaDeathFrame", UIParent, "BackdropTemplate")
    f:SetSize(360, 130)
    f:SetPoint("CENTER", 0, 120)
    f:SetBackdrop({
        bgFile = "Interface\\DialogFrame\\UI-DialogBox-Background-Dark",
        edgeFile = "Interface\\DialogFrame\\UI-DialogBox-Border",
        tile = true, tileSize = 32, edgeSize = 32,
        insets = { left = 8, right = 8, top = 8, bottom = 8 }
    })
    f:SetBackdropColor(0, 0, 0, 0.92)
    f:SetFrameStrata("DIALOG")
    f:EnableMouse(true)
    f:SetMovable(true)
    f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving)
    f:SetScript("OnDragStop", f.StopMovingOrSizing)
    f:Hide()

    local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    title:SetPoint("TOP", 0, -16)
    title:SetText("|cffff4444Zabil cie|r")

    local hint = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    hint:SetPoint("TOP", title, "BOTTOM", 0, -2)
    hint:SetTextColor(0.65, 0.65, 0.65)
    hint:SetText("Nick tez jest w chacie - latwo skopiowac")

    local nameFS = f:CreateFontString(nil, "OVERLAY", "GameFontHighlightLarge")
    nameFS:SetPoint("TOP", hint, "BOTTOM", 0, -12)
    nameFS:SetTextColor(1, 0.85, 0.2)
    f.nameFS = nameFS

    local onList = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    onList:SetPoint("TOP", nameFS, "BOTTOM", 0, -8)
    f.onListText = onList

    local close = MakeButton(f, 100, "Zamknij")
    close:SetPoint("BOTTOM", 0, 14)
    close:SetScript("OnClick", function() f:Hide() end)

    deathFrame = f
    return f
end

function HL:ShowKillerPopup(name)
    if HuntListaDB and HuntListaDB.deathPopup == false then return end
    if not name or name == "" then return end

    -- sprobuj uzupelnic pelna nazwe z cache / listy
    name = HL:ResolveFullName(name)
    if not name then return end

    local f = CreateDeathFrame()
    f.nameFS:SetText(name)

    local info = HL.GetInfo and HL:GetInfo(name) or nil
    if info then
        f.onListText:SetText("|cffff6666Juz na Hunt Liscie|r")
    else
        f.onListText:SetText("|cffaaaaaaNie ma na liscie - wklej na Discord|r")
    end

    -- chat = pewne kopiowanie bez taintu
    print("|cffff4444[Hunt Lista]|r Zabojca: |cffffff00" .. name .. "|r")

    f:Show()
end

function HL:HideKillerPopup()
    if deathFrame then deathFrame:Hide() end
end

-- Cache nazw z nameplate / target / mouseover
local cacheFrame = CreateFrame("Frame")
cacheFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
cacheFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
cacheFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
cacheFrame:RegisterEvent("PLAYER_LOGIN")
cacheFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        playerGUID = UnitGUID("player")
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        HL:CacheUnit(unit)
    elseif event == "PLAYER_TARGET_CHANGED" then
        HL:CacheUnit("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        HL:CacheUnit("mouseover")
    end
end)

-- Combat log + smierc
local cleu = CreateFrame("Frame")
cleu:RegisterEvent("PLAYER_DEAD")
cleu:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
cleu:SetScript("OnEvent", function(_, event)
    if event == "PLAYER_DEAD" then
        local name = lastAttackerName
        if name and (GetTime() - lastAttackerTime) < 20 then
            HL:ShowKillerPopup(name)
        elseif UnitExists("target") and UnitIsPlayer("target") then
            HL:CacheUnit("target")
            local n = UnitName("target")
            if n then HL:ShowKillerPopup(n) end
        end
        return
    end

    if event == "COMBAT_LOG_EVENT_UNFILTERED" then
        if not playerGUID then playerGUID = UnitGUID("player") end
        if not playerGUID then return end

        local _, subevent, _, sourceGUID, sourceName, _, _, destGUID = CombatLogGetCurrentEventInfo()

        if destGUID ~= playerGUID then return end
        if not sourceGUID or sourceGUID == playerGUID then return end
        if not sourceName or sourceName == "" then return end

        if subevent == "SWING_DAMAGE"
            or subevent == "RANGE_DAMAGE"
            or subevent == "SPELL_DAMAGE"
            or subevent == "SPELL_PERIODIC_DAMAGE"
            or subevent == "SPELL_BUILDING_DAMAGE" then

            lastAttackerName = sourceName
            lastAttackerTime = GetTime()
            -- od razu sprobuj cache
            HL:CacheFullName(sourceName)

        elseif subevent == "UNIT_DIED" then
            if lastAttackerName and (GetTime() - lastAttackerTime) < 20 then
                HL:ShowKillerPopup(lastAttackerName)
            end
        end
    end
end)
