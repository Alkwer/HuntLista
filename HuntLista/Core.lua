-- ============================================================
-- Hunt Lista - Core
-- ============================================================

local addonName, ns = ...
HuntLista = HuntLista or {}
local HL = HuntLista

HL.version = "1.0.0"
HL.dataVersion = (HuntLista_Data and HuntLista_Data.version) or "brak"

-- Domyślne ustawienia
local defaults = {
    enabled = true,
    sound = true,
    alertOnNameplate = true,
    alertOnTarget = true,
    alertOnMouseover = true,
    showIcon = true,
    minimapButton = true,
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

-- Buduje szybki lookup (case-insensitive)
local function RebuildLookup()
    wipe(HuntLista_Lookup)
    if not HuntLista_Data or not HuntLista_Data.players then return end

    for name, info in pairs(HuntLista_Data.players) do
        local key = strlower(name)
        HuntLista_Lookup[key] = {
            name = name,          -- oryginalna wielkość liter
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

-- Eventy
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
            print("|cff00ff00Hunt Lista|r załadowane. Wersja danych: |cffffff00" .. HL.dataVersion .. "|r  (" .. HL:GetPlayerCount() .. " graczy)")
            print("Komenda: |cffffff00/hl|r  lub  |cffffff00/huntlista|r")
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

-- Slash commands
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
        print("  Graczy na liście: " .. HL:GetPlayerCount())
        print("  Ostatnia aktualizacja: " .. (HuntLista_Data and HuntLista_Data.lastUpdate or "?"))
    elseif msg == "reload" or msg == "odswiez" then
        RebuildLookup()
        print("|cff00ff00Hunt Lista|r – dane odświeżone. Graczy: " .. HL:GetPlayerCount())
    else
        print("|cff00ff00Hunt Lista|r komendy:")
        print("  /hl          – otwórz listę")
        print("  /hl status   – status danych")
        print("  /hl reload   – przeładuj lookup")
    end
end

-- Eksport dla innych plików
ns.HL = HL
ns.RebuildLookup = RebuildLookup
