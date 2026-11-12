-- ============================================================
-- Hunt Lista - Core
-- ============================================================

local addonName, ns = ...
HuntLista = HuntLista or {}
local HL = HuntLista

HL.version = "1.3.3"
HL.dataVersion = (HuntLista_Data and HuntLista_Data.version) or "brak"

local defaults = {
    enabled = true,
    sound = true,
    soundPreset = "raid",
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

-- Na Forever PlaySoundFile czesto nie rzuca bledu przy braku pliku,
-- wiec najpierw gramy po klasycznych ID (PlaySound).
HL.SoundPresets = {
    raid = {
        label = "Raid Warning",
        ids = { 8959 },
        files = { "Sound\\Interface\\RaidWarning.ogg" },
    },
    alarm = {
        label = "Alarm",
        ids = { 12889, 12867, 8475 },
        files = {
            "Sound\\Interface\\AlarmClockWarning3.ogg",
            "Sound\\Interface\\igQuestFailed.ogg",
        },
    },
    bell = {
        label = "Bell",
        ids = { 6594, 6595, 6660 },
        files = {
            "Sound\\Doodad\\BellTollHorde.ogg",
            "Sound\\Doodad\\BellTollAlliance.ogg",
        },
    },
    tell = {
        label = "Whisper",
        ids = { 3081, 3093, 876 },
        files = {
            "Sound\\Interface\\iTellMessage.ogg",
            "Sound\\Interface\\FriendJoin.ogg",
        },
    },
    map = {
        label = "Map Ping",
        ids = { 3175, 1115 },
        files = {
            "Sound\\Interface\\MapPing.ogg",
            "Sound\\Interface\\MagicClick.ogg",
        },
    },
    level = {
        label = "Level Up",
        ids = { 888, 5274 },
        files = {
            "Sound\\Spells\\LevelUp.ogg",
            "Sound\\Interface\\igQuestListComplete.ogg",
        },
    },
    aggro = {
        label = "Quest / Fanfare",
        ids = { 878, 880 },
        files = {
            "Sound\\Interface\\iQuestComplete.ogg",
            "Sound\\Interface\\igQuestListComplete.ogg",
        },
    },
    pvp = {
        label = "PVP Flag",
        ids = { 8174, 8192 },
        files = {
            "Sound\\Interface\\PVPFlagTakenHorde.ogg",
            "Sound\\Interface\\PVPFlagTakenAlliance.ogg",
        },
    },
}

function HL:PlayHuntSound()
    if not HuntListaDB or HuntListaDB.sound == false then return end
    local key = HuntListaDB.soundPreset or "raid"
    local preset = HL.SoundPresets[key] or HL.SoundPresets.raid

    -- 1) numeryczne ID (najpewniejsze na Classic / Forever)
    if preset.ids and PlaySound then
        for _, id in ipairs(preset.ids) do
            local ok = pcall(PlaySound, id, "Master")
            if ok then return end
        end
        for _, id in ipairs(preset.ids) do
            local ok = pcall(PlaySound, id)
            if ok then return end
        end
    end

    -- 2) pliki
    if preset.files and PlaySoundFile then
        for _, path in ipairs(preset.files) do
            pcall(PlaySoundFile, path, "Master")
        end
    end
end

function HL:ListSoundPresets()
    local cur = (HuntListaDB and HuntListaDB.soundPreset) or "raid"
    local on = not HuntListaDB or HuntListaDB.sound ~= false
    print("|cff00ff00Hunt Lista|r dzwieki: " .. (on and "|cff88ff88ON|r" or "|cffff6666OFF|r")
        .. "  preset: |cffffff00" .. cur .. "|r")
    for k, p in pairs(HL.SoundPresets) do
        local mark = (k == cur) and " |cff88ff88<--|r" or ""
        print("  |cffffff00" .. k .. "|r - " .. (p.label or k) .. mark)
    end
    print("  /hl sound <nazwa>  |  /hl sound test  |  /hl sound on/off")
end

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
        print("  Sound: " .. ((HuntListaDB.sound ~= false) and "ON" or "OFF")
            .. " (" .. (HuntListaDB.soundPreset or "raid") .. ")")
        print("  Powiadomienia gildii: " .. (HuntListaDB.guildKillAlerts and "ON" or "OFF") .. " (" .. (HL.guildKillStatus or "?") .. ")")
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
    elseif msg == "sound" or msg == "dzwiek" then
        HL:ListSoundPresets()
    elseif msg == "sound on" or msg == "dzwiek on" then
        HuntListaDB.sound = true
        print("sound: ON")
        HL:PlayHuntSound()
    elseif msg == "sound off" or msg == "dzwiek off" then
        HuntListaDB.sound = false
        print("sound: OFF")
    elseif msg == "sound test" or msg == "dzwiek test" then
        HuntListaDB.sound = true
        print("sound test: " .. (HuntListaDB.soundPreset or "raid"))
        HL:PlayHuntSound()
    elseif msg:match("^sound%s+") or msg:match("^dzwiek%s+") then
        local which = msg:match("^sound%s+(.+)$") or msg:match("^dzwiek%s+(.+)$")
        which = strtrim(which or "")
        if which == "test" then
            HuntListaDB.sound = true
            print("sound test: " .. (HuntListaDB.soundPreset or "raid"))
            HL:PlayHuntSound()
        elseif which == "on" then
            HuntListaDB.sound = true
            print("sound: ON")
            HL:PlayHuntSound()
        elseif which == "off" then
            HuntListaDB.sound = false
            print("sound: OFF")
        elseif HL.SoundPresets[which] then
            HuntListaDB.soundPreset = which
            HuntListaDB.sound = true
            print("sound: |cffffff00" .. which .. "|r (" .. (HL.SoundPresets[which].label or which) .. ")")
            HL:PlayHuntSound()
        else
            print("|cffff0000Nieznany dzwiek:|r " .. tostring(which))
            HL:ListSoundPresets()
        end
    elseif msg == "debug" then
        HuntListaDB.debug = not HuntListaDB.debug
        print("debug: " .. (HuntListaDB.debug and "ON" or "OFF"))
    else
        print("|cff00ff00Hunt Lista|r: /hl  /hl kills  /hl kill Nick")
        print("  Discord sync: /hunt kill Nick  (potem Auto Updater)")
        print("  /hl status  /hl killer  /hl death  /hl test")
        print("  /hl guildkills on  /hl guildkills off")
        print("  /hl sound  /hl sound test  /hl sound raid|alarm|bell|...")
    end
end

ns.HL = HL
ns.RebuildLookup = RebuildLookup
