-- Forever exposes PARTY_KILL directly; the combat-log API is restricted.
-- See docs/forever-kill-detection.md for the client API sources and live test.
local HL = HuntLista
local frame
local registered = false
local names, slots, nextSlot = {}, {}, 0
local CACHE_LIMIT, CACHE_AGE = 256, 120
local stats = { events = 0, counted = 0, hidden = 0, missing = 0, other = 0 }
HL.killDetectionStatus = "oczekiwanie na logowanie"

local function Secret(value)
    return issecretvalue and issecretvalue(value)
end

local function Text(value)
    return not Secret(value) and type(value) == "string" and value ~= ""
end

local function ReadGUID(unit)
    local ok, guid = pcall(UnitGUID, unit)
    if ok and Text(guid) then return guid end
    return nil, ok and Secret(guid)
end

local function PlayerGUID(guid)
    return Text(guid) and guid:sub(1, 7) == "Player-"
end

local function ReadName(unit, expectedGUID)
    local guid, hidden = ReadGUID(unit)
    if hidden then return nil, true end
    if not PlayerGUID(guid) or (expectedGUID and guid ~= expectedGUID) then return end
    local ok, first, surname = pcall(UnitNameUnmodified, unit)
    if not ok then return end
    if Secret(first) or Secret(surname) then return nil, true end
    if not Text(first) or (surname ~= nil and type(surname) ~= "string") then return end
    local full = first
    if surname and surname ~= "" then
        local constants = Constants and Constants.CharacterNameSeparatorConsts
        full = first .. (constants and constants.CHARACTERNAME_SURNAME_SEPARATOR or " ") .. surname
    end
    if #full > 128 or full:find("[%c|]") or strtrim(full) ~= full then return end
    return full
end

function HL:CacheKillUnit(unit)
    if not Text(unit) then return end
    local guid = ReadGUID(unit)
    if not PlayerGUID(guid) then return end
    local name = ReadName(unit, guid)
    if not name then return end
    if not names[guid] then
        nextSlot = nextSlot % CACHE_LIMIT + 1
        if slots[nextSlot] then names[slots[nextSlot]] = nil end
        slots[nextSlot] = guid
    end
    names[guid] = { name = name, at = GetTime() }
end

local function NameForGUID(guid)
    if UnitTokenFromGUID then
        local ok, unit = pcall(UnitTokenFromGUID, guid)
        if ok and Secret(unit) then return nil, true end
        if ok and Text(unit) then
            local name, hidden = ReadName(unit, guid)
            if hidden then return nil, true end
            if name then return name end
        end
    end
    -- A unit token may disappear before PARTY_KILL. Only use an observation of
    -- this exact GUID; Death.lua's first-name cache is deliberately not used.
    local cached = names[guid]
    if cached and GetTime() - cached.at <= CACHE_AGE then return cached.name end
end

local function OnKill(_, _, attackerGUID, targetGUID)
    stats.events = stats.events + 1
    if HuntListaDB and HuntListaDB.enabled == false then return end
    if Secret(attackerGUID) or Secret(targetGUID) then
        stats.hidden = stats.hidden + 1
        return
    end
    if not Text(attackerGUID) or not PlayerGUID(targetGUID) then return end
    local playerGUID, hidden = ReadGUID("player")
    if hidden then stats.hidden = stats.hidden + 1; return end
    if not playerGUID then return end
    if attackerGUID ~= playerGUID then
        local petGUID, petHidden = ReadGUID("pet")
        if petHidden then stats.hidden = stats.hidden + 1; return end
        if attackerGUID ~= petGUID then stats.other = stats.other + 1; return end
    end
    local name, nameHidden = NameForGUID(targetGUID)
    if nameHidden then stats.hidden = stats.hidden + 1; return end
    if not name then stats.missing = stats.missing + 1; return end
    if HL:RecordKill(name, "party_kill") then stats.counted = stats.counted + 1 end
end

function HL:InitKillDetection()
    if registered then return end
    if not UnitGUID or not UnitNameUnmodified then
        HL.killDetectionStatus = "brak API nazw/GUID; pozostaja komunikaty czatu"
        return
    end
    if C_EventUtils and C_EventUtils.IsEventValid then
        local ok, valid = pcall(C_EventUtils.IsEventValid, "PARTY_KILL")
        if not ok or not valid then
            HL.killDetectionStatus = "brak PARTY_KILL; pozostaja komunikaty czatu"
            return
        end
    end
    frame = frame or CreateFrame("Frame")
    frame:SetScript("OnEvent", OnKill)
    local ok, result = pcall(frame.RegisterEvent, frame, "PARTY_KILL")
    if not ok or result == false then
        HL.killDetectionStatus = "rejestracja PARTY_KILL zablokowana; pozostaja komunikaty czatu"
        return
    end
    registered = true
    HL.killDetectionStatus = "PARTY_KILL zarejestrowany"
    HL:CacheKillUnit("target")
    HL:CacheKillUnit("mouseover")
end

function HL:PrintKillDetectionStatus()
    print("  Wykrywanie zabojstw: " .. HL.killDetectionStatus)
    print("  Od /reload: zdarzenia=" .. stats.events .. ", naliczone z listy=" .. stats.counted
        .. ", ukryte dane=" .. stats.hidden .. ", brak pelnego nicku=" .. stats.missing
        .. ", cudzy zabojca=" .. stats.other)
end
