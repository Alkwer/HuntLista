-- ============================================================
-- Hunt Lista - Core
-- ============================================================

local addonName, ns = ...
HuntLista = HuntLista or {}
local HL = HuntLista

HL.version = "1.0.4"
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
}

local function InitDB()
    if not HuntListaDB then
        HuntListaDB = {}
    end
    for k, v in pairs(defaults) do
        if HuntListaDB[k] == nil then
            HuntListaDB[k] = v
        end
    end
end

local function RebuildLookup()
    wipe(HuntLista_Lookup)
    if not HuntLista_Data or not HuntLista_Data.players then return end

    for name, info in pairs(HuntLista_Data.players) do
        local key = strlower(strtrim(name))
        HuntLista_Lookup[key] = {
            name = name,
            reason = info.reason or "",
            addedBy = info.addedBy or "",
            addedAt = info.addedAt or "",
            note = info.note or "",
        }
    end
end

function HL:NormalizeName(name)
    if not name or name == "" then return nil end
    name = strtrim(name)
    local base = name:match("^(.-)%-.+$")
    if base and base ~= "" then
        name = base
    end
    return name
end

function HL:GetInfo(name)
    name = HL:NormalizeName(name)
    if not name then return nil end

    local key = strlower(name)

    -- 1) dokladne dopasowanie
    if HuntLista_Lookup[key] then
        return HuntLista_Lookup[key]
    end

    -- 2) Forever: UnitName bywa zwraca tylko PIERWSZE slowo wieloczlonowej nazwy.
    --    Match TYLKO gdy na liscie jest "Slowo Reszta" a unit to dokladnie "Slowo".
    --    Min. 3 znaki, zeby krotkie fragmenty nie lapaly losowych ludzi.
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
    for _ in pairs(HuntLista_Lookup) do
        count = count + 1
    end
    return count
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
            if HuntListaDB.testMode then
                print("|cffff0000TEST MODE ON|r - /hl test off aby wylaczyc")
            end
        end
    elseif event == "PLAYER_LOGIN" then
        RebuildLookup()
    elseif event == "PLAYER_TARGET_CHANGED" then
        if HuntListaDB.alertOnTarget then
            HL:CheckUnit("target")
        end
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        if HuntListaDB.alertOnMouseover then
            HL:CheckUnit("mouseover")
        end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        if HuntListaDB.alertOnNameplate then
            local unit = ...
            HL:CheckUnit(unit)
        end
    end
end)

SLASH_HUNTLISTA1 = "/hl"
SLASH_HUNTLISTA2 = "/huntlista"
SlashCmdList["HUNTLISTA"] = function(msg)
    msg = strtrim(strlower(msg or ""))
    if msg == "" or msg == "show" or msg == "lista" then
        HL:ToggleList()
    elseif msg == "status" then
        print("|cff00ff00Hunt Lista|r")
        print("  Wersja addona: " .. HL.version)
        print("  Wersja danych: " .. HL.dataVersion)
        print("  Graczy na liscie: " .. HL:GetPlayerCount())
        print("  Test mode: " .. (HuntListaDB.testMode and "|cffff0000ON|r" or "OFF"))
        print("  Debug: " .. (HuntListaDB.debug and "ON" or "OFF"))
    elseif msg == "reload" or msg == "odswiez" then
        RebuildLookup()
        print("|cff00ff00Hunt Lista|r - dane odswiezone. Graczy: " .. HL:GetPlayerCount())
    elseif msg == "test" or msg == "test on" then
        HuntListaDB.testMode = true
        print("|cff00ff00Hunt Lista|r TEST MODE: ON")
    elseif msg == "test off" then
        HuntListaDB.testMode = false
        print("|cff00ff00Hunt Lista|r TEST MODE: OFF")
    elseif msg == "check" then
        print("|cff00ff00Hunt Lista|r DEBUG check:")
        print("  testMode = " .. tostring(HuntListaDB.testMode))
        print("  graczy w lookup = " .. HL:GetPlayerCount())
        local units = {"target", "mouseover"}
        for _, unit in ipairs(units) do
            if UnitExists(unit) then
                local n = UnitName(unit)
                local full = (UnitFullName and UnitFullName(unit)) or n
                local isPlayer = UnitIsPlayer(unit) and "yes" or "no"
                local isEnemy = UnitIsEnemy("player", unit) and "yes" or "no"
                local info = HL:GetInfo(n)
                print("  [" .. unit .. "] name=" .. tostring(n) .. " full=" .. tostring(full))
                print("    player=" .. isPlayer .. " enemy=" .. isEnemy .. " onList=" .. (info and ("YES -> " .. info.name) or "NO"))
                if info then
                    HL:CheckUnit(unit)
                end
            else
                print("  [" .. unit .. "] brak")
            end
        end
        print("  Lista w pamieci:")
        for k, info in pairs(HuntLista_Lookup) do
            print("    - [" .. k .. "] => " .. info.name)
        end
    elseif msg == "debug" then
        HuntListaDB.debug = not HuntListaDB.debug
        print("|cff00ff00Hunt Lista|r debug: " .. (HuntListaDB.debug and "ON" or "OFF"))
    else
        print("|cff00ff00Hunt Lista|r komendy:")
        print("  /hl          - lista")
        print("  /hl status")
        print("  /hl test / test off")
        print("  /hl check    - DEBUG target/mouseover")
        print("  /hl debug    - logi przy najechaniu")
    end
end

ns.HL = HL
ns.RebuildLookup = RebuildLookup
