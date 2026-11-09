-- ============================================================
-- Hunt Lista - Okienko po smierci z nickiem do skopiowania
-- ============================================================

local addonName, ns = ...
local HL = ns.HL or HuntLista

local playerGUID
local lastAttackerName = nil
local lastAttackerTime = 0
local deathFrame

HL.NameCache = HL.NameCache or {}

-- Czyści nick: kolory, realm, gildia <...>, tylko pierwsza linia
local function CleanPlayerName(name)
    if not name or name == "" then return nil end
    name = strtrim(name)

    -- kody kolorow / tekstury
    name = name:gsub("|c%x%x%x%x%x%x%x%x", "")
    name = name:gsub("|r", "")
    name = name:gsub("|T.-|t", "")
    name = name:gsub("|A.-|a", "")

    -- tylko pierwsza linia (druga bywa gildia)
    name = name:match("([^
]+)") or name
    name = strtrim(name)

    -- wyrzuc calkowicie tagi gildii: <Something>
    if name:match("^<.*>$") then
        return nil
    end
    name = name:gsub("%s*<.->%s*", " ")
    name = name:gsub("%s*%b<>%s*", " ")

    -- realm Name-Realm
    local base = name:match("^(.-)%-[^%-]+$")
    if base and base ~= "" and not base:find(" ") then
        -- ostroznie: nicki ze spacja + myslnik rzadkie; klasyczny realm bez spacji w base
        -- lepiej: odetnij tylko gdy po myslniku wyglada jak realm (bez spacji)
        local before, after = name:match("^(.-)%-([^%-]+)$")
        if before and after and not after:find(" ") then
            name = before
        end
    end

    name = strtrim(name)
    name = name:gsub("%s+", " ")

    if name == "" then return nil end
    return name
end

local function FirstWord(name)
    if not name then return nil end
    return strlower((strtrim(name):match("^(%S+)") or name))
end

function HL:CacheFullName(full)
    full = CleanPlayerName(full)
    if not full then return end
    -- nie cache'uj samego tagu / smieci
    if full:find("<") or full:find(">") then return end

    local fw = FirstWord(full)
    if not fw or #fw < 2 then return end

    local prev = HL.NameCache[fw]
    -- preferuj nazwe ze spacja (pelny nick Forever), ale nie dluzszy smiec
    if not prev then
        HL.NameCache[fw] = full
    elseif #full > #prev and full:find(" ") then
        HL.NameCache[fw] = full
    elseif #full > #prev and not prev:find(" ") then
        HL.NameCache[fw] = full
    end
end

function HL:ResolveFullName(name)
    name = CleanPlayerName(name)
    if not name then return nil end

    local fw = FirstWord(name)
    local cached = fw and HL.NameCache[fw]
    if cached then
        cached = CleanPlayerName(cached)
        if cached and #cached >= #name then
            return cached
        end
    end

    if HL.GetInfo then
        local info = HL:GetInfo(name)
        if info and info.name then
            local n = CleanPlayerName(info.name)
            if n and #n >= #name then return n end
        end
    end

    return name
end

function HL:CacheUnit(unit)
    if not unit or not UnitExists(unit) then return end
    if not UnitIsPlayer(unit) then return end

    local n = UnitName(unit)
    if n then HL:CacheFullName(n) end

    if C_NamePlate and C_NamePlate.GetNamePlateForUnit then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate and plate.UnitFrame then
            local uf = plate.UnitFrame
            -- tylko pole name / Name - NIE wszystkie regiony (tam jest gildia)
            if uf.name and uf.name.GetText then
                local t = uf.name:GetText()
                if t and not t:match("^<") then
                    HL:CacheFullName(t)
                end
            end
            if uf.Name and uf.Name.GetText then
                local t = uf.Name:GetText()
                if t and not t:match("^<") then
                    HL:CacheFullName(t)
                end
            end
        end
    end
end

local function CreateDeathFrame()
    if deathFrame then return deathFrame end

    local f = CreateFrame("Frame", "HuntListaDeathFrame", UIParent, "BackdropTemplate")
    f:SetSize(340, 150)
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

    local sub = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    sub:SetPoint("TOP", title, "BOTTOM", 0, -4)
    sub:SetTextColor(0.7, 0.7, 0.7)
    sub:SetText("Kliknij w nick, Ctrl+C aby skopiowac")

    local eb = CreateFrame("EditBox", nil, f)
    eb:SetSize(260, 32)
    eb:SetPoint("TOP", sub, "BOTTOM", 0, -12)
    eb:SetAutoFocus(false)
    eb:SetFontObject("GameFontHighlightLarge")
    eb:SetJustifyH("CENTER")
    eb:SetTextInsets(8, 8, 0, 0)
    eb:SetMaxLetters(64)

    local bg = eb:CreateTexture(nil, "BACKGROUND")
    bg:SetAllPoints()
    bg:SetColorTexture(0.12, 0.12, 0.12, 0.95)

    eb:SetScript("OnEscapePressed", function(self)
        self:ClearFocus()
        f:Hide()
    end)
    eb:SetScript("OnMouseDown", function(self)
        self:SetFocus()
        self:HighlightText()
    end)
    eb:SetScript("OnEditFocusGained", function(self)
        self:HighlightText()
    end)
    f.editBox = eb

    local onList = f:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
    onList:SetPoint("TOP", eb, "BOTTOM", 0, -8)
    f.onListText = onList

    local function MakeBtn(w, label)
        local b = CreateFrame("Button", nil, f)
        b:SetSize(w, 26)
        local t = b:CreateTexture(nil, "BACKGROUND")
        t:SetAllPoints()
        t:SetColorTexture(0.2, 0.05, 0.05, 0.95)
        local fs = b:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        fs:SetPoint("CENTER")
        fs:SetText(label)
        b:SetScript("OnEnter", function()
            t:SetColorTexture(0.35, 0.1, 0.1, 1)
        end)
        b:SetScript("OnLeave", function()
            t:SetColorTexture(0.2, 0.05, 0.05, 0.95)
        end)
        return b
    end

    local selectBtn = MakeBtn(110, "Zaznacz")
    selectBtn:SetPoint("BOTTOMLEFT", 28, 14)
    selectBtn:SetScript("OnClick", function()
        eb:SetFocus()
        eb:HighlightText()
    end)

    local close = MakeBtn(110, "Zamknij")
    close:SetPoint("BOTTOMRIGHT", -28, 14)
    close:SetScript("OnClick", function()
        eb:ClearFocus()
        f:Hide()
    end)

    deathFrame = f
    return f
end

function HL:ShowKillerPopup(name)
    if HuntListaDB and HuntListaDB.deathPopup == false then return end
    if not name or name == "" then return end

    name = HL:ResolveFullName(name)
    name = CleanPlayerName(name)
    if not name then return end

    local f = CreateDeathFrame()
    f.editBox:SetText(name)

    local info = HL.GetInfo and HL:GetInfo(name) or nil
    if info then
        f.onListText:SetText("|cffff6666Juz na Hunt Liscie|r")
    else
        f.onListText:SetText("|cffaaaaaaNie ma na liscie - wklej na Discord|r")
    end

    print("|cffff4444[Hunt Lista]|r Zabojca: |cffffff00" .. name .. "|r")
    f:Show()
end

function HL:HideKillerPopup()
    if deathFrame then
        if deathFrame.editBox then deathFrame.editBox:ClearFocus() end
        deathFrame:Hide()
    end
end

local cacheFrame = CreateFrame("Frame")
cacheFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
cacheFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
cacheFrame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
cacheFrame:RegisterEvent("PLAYER_LOGIN")
cacheFrame:SetScript("OnEvent", function(_, event, unit)
    if event == "PLAYER_LOGIN" then
        playerGUID = UnitGUID("player")
        wipe(HL.NameCache)
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        HL:CacheUnit(unit)
    elseif event == "PLAYER_TARGET_CHANGED" then
        HL:CacheUnit("target")
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        HL:CacheUnit("mouseover")
    end
end)

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
            HL:CacheFullName(sourceName)

        elseif subevent == "UNIT_DIED" then
            if lastAttackerName and (GetTime() - lastAttackerTime) < 20 then
                HL:ShowKillerPopup(lastAttackerName)
            end
        end
    end
end)
