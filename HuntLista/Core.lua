-- ============================================================
-- Hunt Lista - Core
-- ============================================================

local addonName, ns = ...
HuntLista = HuntLista or {}
local HL = HuntLista

HL.version = "1.0.1-test"
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
        local key = strlower(name)
        HuntLista_Lookup[key] = {
            name = name,
            reason = info.reason or "",
            addedBy = info.addedBy or "",
            addedAt = info.addedAt or "",
            note = info.note or "",
        }
    end
end

function HL:IsOnList(name)
    if not name or name == "" then return false end
    return HuntLista_Lookup[strlower(name)] ~= nil
end

function HL:GetInfo(name)
    if not name then return nil end
    return HuntLista_Lookup[strlower(name)]
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
            print("|cff00ff00Hunt Lista|r zaladowane. Wersja danych: |cffffff00" .. HL.dataVersion .. "|r  (" .. HL:GetPlayerCount() .. " graczy)")
            print("Komenda: |cffffff00/hl|r  lub  |cffffff00/huntlista|r")
            if HuntListaDB.testMode then
                print("|cffff0000TEST MODE ON|r - alertuje tez sojusznikow. /hl test off aby wylaczyc")
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
        print("  Ostatnia aktualizacja: " .. (HuntLista_Data and HuntLista_Data.lastUpdate or "?"))
        print("  Test mode: " .. (HuntListaDB.testMode and "|cffff0000ON|r" or "OFF"))
    elseif msg == "reload" or msg == "odswiez" then
        RebuildLookup()
        print("|cff00ff00Hunt Lista|r - dane odswiezone. Graczy: " .. HL:GetPlayerCount())
    elseif msg == "test" or msg == "test on" then
        HuntListaDB.testMode = true
        print("|cff00ff00Hunt Lista|r TEST MODE: ON - alertuje tez sojusznikow")
    elseif msg == "test off" then
        HuntListaDB.testMode = false
        print("|cff00ff00Hunt Lista|r TEST MODE: OFF - tylko wrogowie")
    else
        print("|cff00ff00Hunt Lista|r komendy:")
        print("  /hl          - otworz liste")
        print("  /hl status   - status danych")
        print("  /hl reload   - przeladuj lookup")
        print("  /hl test     - wlacz test (sojusznicy tez)")
        print("  /hl test off - wylacz test (tylko wrogowie)")
    end
end

ns.HL = HL
ns.RebuildLookup = RebuildLookup
