-- ============================================================
-- Hunt Lista - Core
-- ============================================================

local addonName, ns = ...
HuntLista = HuntLista or {}
local HL = HuntLista

HL.version = "1.3.0"
HL.dataVersion = (HuntLista_Data and HuntLista_Data.version) or "brak"

local defaults = {
    enabled = true,
    sound = true,
    alertOnNameplate = true,
    alertOnTarget = true,
    alertOnMouseover = true,
    showIcon = true,
    minimapButton = true,
    testMode = false,
    debug = false,
    deathPopup = true,
    guildKillAlerts = true,
}

local function InitDB()
    if not HuntListaDB then HuntListaDB = {} end
    for k, v in pairs(defaults) do
        if HuntListaDB[k] == nil then HuntListaDB[k] = v end
    end
    if not HuntListaDB.kills then HuntListaDB.kills = {} end
end

local function RebuildLookup()
    wipe(HuntLista_Lookup)
    if not HuntLista_Data or not HuntLista_Data.players then return end
    for name, info in pairs(HuntLista_Data.players) do
        local key = strlower(strtrim(name))
        local kills = tonumber(info.kills) or 0
        HuntLista_Lookup[key] = {
            name = name,
            reason = info.reason or "",
            addedBy = info.addedBy or "",
            addedAt = info.addedAt or "",
            note = info.note or "",
            kills = kills,
            lastKillBy = info.lastKillBy or "",
            lastKillAt = info.lastKillAt or "",
        }
        if HL.CacheFullName then
            pcall(function() HL:CacheFullName(name) end)
        end
    end
    HL.dataVersion = (HuntLista_Data and HuntLista_Data.version) or "brak"
end

function HL:NormalizeName(name)
    if not name or name == "" then return nil end
    name = strtrim(name)
    local base = name:match("^(.-)%-.+$")
    if base and base ~= "" then name = base end
    return name
end

function HL:GetInfo(name)
    name = HL:NormalizeName(name)
    if not name then return nil end
    local key = strlower(name)
    if HuntLista_Lookup[key] then return HuntLista_Lookup[key] end
    if #key >= 3 then
        for k, info in pairs(HuntLista_Lookup) do
            if #k > #key and k:sub(1, #key + 1) == key .. " " then
                return info
            end
        end
    end
    return nil
end

function HL:IsOnList(name)
    return HL:GetInfo(name) ~= nil
end

function HL:GetPlayerCount()
    local count = 0
    for _ in pairs(HuntLista_Lookup) do count = count + 1 end
    return count
end

-- Wspolny licznik z Data.lua (gildia)
function HL:GetSharedKillCount(name)
    local info = HL:GetInfo(name)
    if info and info.kills then return tonumber(info.kills) or 0 end
    return 0
end

function HL:GetSharedTotalKills()
    local n = 0
    for _, info in pairs(HuntLista_Lookup) do
        n = n + (tonumber(info.kills) or 0)
    end
    return n
end

local function SafeCacheUnit(unit)
    if HL.CacheUnit then
        pcall(function() HL:CacheUnit(unit) end)
    end
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("ADDON_LOADED")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("PLAYER_TARGET_CHANGED")
frame:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
frame:RegisterEvent("NAME_PLATE_UNIT_ADDED")

frame:SetScript("OnEvent", function(self, event, ...)
    if event == "ADDON_LOADED" then
        local loaded = ...
        if loaded == addonName then
            InitDB()
            RebuildLookup()
            print("|cff00ff00Hunt Lista|r zaladowane. Wersja: |cffffff00" .. HL.version .. "|r  dane: " .. HL.dataVersion .. " (" .. HL:GetPlayerCount() .. " graczy)")
            print("Komenda: |cffffff00/hl|r")
        end

    elseif event == "PLAYER_LOGIN" then
        RebuildLookup()
        if HL.InitDeathModule then pcall(function() HL:InitDeathModule() end) end

    elseif event == "PLAYER_TARGET_CHANGED" then
        SafeCacheUnit("target")
        if HL.OnTargetChangedDeath then pcall(function() HL:OnTargetChangedDeath() end) end
        if HuntListaDB and HuntListaDB.alertOnTarget then HL:CheckUnit("target") end

    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        SafeCacheUnit("mouseover")
        if HuntListaDB and HuntListaDB.alertOnMouseover then HL:CheckUnit("mouseover") end

    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        SafeCacheUnit(unit)
        if HuntListaDB and HuntListaDB.alertOnNameplate then HL:CheckUnit(unit) end
    end
end)

SLASH_HUNTLISTA1 = "/hl"
SLASH_HUNTLISTA2 = "/huntlista"
SlashCmdList["HUNTLISTA"] = function(msg)
    msg = strtrim(strlower(msg or ""))

    if msg == "close" then
        if HL.HideKillerPopup then HL:HideKillerPopup() end
        return
    end

    if msg == "" or msg == "show" or msg == "lista" then
        HL:ToggleList()
    elseif msg == "status" then
        print("|cff00ff00Hunt Lista|r")
        print("  Wersja addona: " .. HL.version)
        print("  Wersja danych: " .. HL.dataVersion)
        print("  Graczy: " .. HL:GetPlayerCount())
        print("  Zabojstwa gildii: " .. HL:GetSharedTotalKills())
        print("  Zabojstwa lokalne (Ty): " .. (HL.GetTotalKills and HL:GetTotalKills() or 0))
        print("  Death popup: " .. ((HuntListaDB.deathPopup ~= false) and "ON" or "OFF"))
        print("  Powiadomienia gildii: " .. (HuntListaDB.guildKillAlerts and "ON" or "OFF") .. " (" .. (HL.guildKillStatus or "inicjalizacja") .. ")")
    elseif msg == "guildkills" or msg == "guildkills on" then
        HuntListaDB.guildKillAlerts = true
        print("Powiadomienia gildii: ON")
    elseif msg == "guildkills off" then
        HuntListaDB.guildKillAlerts = false
        print("Powiadomienia gildii: OFF")
    elseif msg == "kills" or msg == "zabojstwa" then
        print("|cff00ff00Hunt Lista|r Ranking (z Data.lua / gildia):")
        local rows = {}
        for _, info in pairs(HuntLista_Lookup) do
            local k = tonumber(info.kills) or 0
            if k > 0 then table.insert(rows, { name = info.name, kills = k, by = info.lastKillBy }) end
        end
        table.sort(rows, function(a, b)
            if a.kills == b.kills then return a.name < b.name end
            return a.kills > b.kills
        end)
        if #rows == 0 then
            print("  (brak — na Discord: /hunt kill Nick)")
        else
            for i, r in ipairs(rows) do
                print("  " .. i .. ". |cffff6666" .. r.name .. "|r x" .. r.kills
                    .. (r.by and r.by ~= "" and (" (" .. r.by .. ")") or ""))
            end
        end
        if HL.PrintKills then
            print("|cffaaaaaa--- lokalnie (tylko Ta postac) ---|r")
            HL:PrintKills()
        end
    elseif msg:match("^killreset") or msg:match("^resetkills") then
        local who = msg:match("^killreset%s+(.+)$") or msg:match("^resetkills%s+(.+)$")
        if HL.ResetKills then HL:ResetKills(who) end
    elseif msg:match("^kill%s+") then
        local who = msg:match("^kill%s+(.+)$")
        if who and HL.RecordKill then
            HL:RecordKill(who, "manual")
            print("|cffaaaaaaZglos tez na Discord: /hunt kill " .. who .. "|r")
        end
    elseif msg == "reload" or msg == "odswiez" then
        RebuildLookup()
        print("|cff00ff00Hunt Lista|r odswiezone. Graczy: " .. HL:GetPlayerCount())
        print("|cffaaaaaa(To NIE wczytuje Data.lua z dysku - uzyj /reload UI)|r")
    elseif msg == "test" or msg == "test on" then
        HuntListaDB.testMode = true
        print("TEST MODE: ON")
    elseif msg == "test off" then
        HuntListaDB.testMode = false
        print("TEST MODE: OFF")
    elseif msg == "death" or msg == "death on" then
        HuntListaDB.deathPopup = true
        print("death popup: ON")
    elseif msg == "death off" then
        HuntListaDB.deathPopup = false
        print("death popup: OFF")
    elseif msg == "killer" or msg:match("^killer%s+") then
        if not HuntLista.ShowKillerPopup then
            print("|cffff0000Hunt Lista|r modul Death nie zaladowany.")
            return
        end
        local name = msg:match("^killer%s+(.+)$")
        if name and name ~= "" then
            HuntLista:ShowKillerPopup(name)
        elseif UnitExists("target") and UnitName("target") then
            SafeCacheUnit("target")
            HuntLista:ShowKillerPopup(UnitName("target"))
        else
            HuntLista:ShowKillerPopup("Test Nick")
        end
    elseif msg == "check" then
        for _, unit in ipairs({"target", "mouseover"}) do
            if UnitExists(unit) then
                SafeCacheUnit(unit)
                local n = UnitName(unit)
                local full = HL.ResolveFullName and HL:ResolveFullName(n) or n
                print("  [" .. unit .. "] " .. tostring(n) .. " -> " .. tostring(full))
            end
        end
    elseif msg == "debug" then
        HuntListaDB.debug = not HuntListaDB.debug
        print("debug: " .. (HuntListaDB.debug and "ON" or "OFF"))
    else
        print("|cff00ff00Hunt Lista|r: /hl  /hl kills  /hl kill Nick")
        print("  Discord sync: /hunt kill Nick  (potem Auto Updater)")
        print("  /hl status  /hl killer  /hl death  /hl test")
        print("  /hl guildkills on  /hl guildkills off")
    end
end

ns.HL = HL
ns.RebuildLookup = RebuildLookup
