-- ============================================================
-- Hunt Lista - Core
-- ============================================================

local addonName, ns = ...
HuntLista = HuntLista or {}
local HL = HuntLista

HL.version = "1.1.3"
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
}

local function InitDB()
    if not HuntListaDB then HuntListaDB = {} end
    for k, v in pairs(defaults) do
        if HuntListaDB[k] == nil then HuntListaDB[k] = v end
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
        if HL.CacheFullName then HL:CacheFullName(name) end
    end
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
    elseif event == "PLAYER_TARGET_CHANGED" then
        if HL.CacheUnit then HL:CacheUnit("target") end
        if HuntListaDB.alertOnTarget then HL:CheckUnit("target") end
    elseif event == "UPDATE_MOUSEOVER_UNIT" then
        if HL.CacheUnit then HL:CacheUnit("mouseover") end
        if HuntListaDB.alertOnMouseover then HL:CheckUnit("mouseover") end
    elseif event == "NAME_PLATE_UNIT_ADDED" then
        local unit = ...
        if HL.CacheUnit then HL:CacheUnit(unit) end
        if HuntListaDB.alertOnNameplate then HL:CheckUnit(unit) end
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
        print("  Death module: " .. (HL.ShowKillerPopup and "OK" or "BRAK"))
        print("  Death popup: " .. ((HuntListaDB.deathPopup ~= false) and "ON" or "OFF"))
    elseif msg == "reload" or msg == "odswiez" then
        RebuildLookup()
        print("|cff00ff00Hunt Lista|r odswiezone. Graczy: " .. HL:GetPlayerCount())
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
            print("Sprawdz czy w HuntLista.toc jest linia: Death.lua")
            print("i czy plik Death.lua lezy w folderze addona.")
            return
        end
        local name = msg:match("^killer%s+(.+)$")
        if name and name ~= "" then
            HuntLista:ShowKillerPopup(name)
        elseif UnitExists("target") and UnitName("target") then
            if HL.CacheUnit then HL:CacheUnit("target") end
            HuntLista:ShowKillerPopup(UnitName("target"))
        else
            HuntLista:ShowKillerPopup("Test Nick")
            print("|cff00ff00Hunt Lista|r brak targetu - testowy nick")
        end
    elseif msg == "check" then
        for _, unit in ipairs({"target", "mouseover"}) do
            if UnitExists(unit) then
                if HL.CacheUnit then HL:CacheUnit(unit) end
                local n = UnitName(unit)
                local full = HL.ResolveFullName and HL:ResolveFullName(n) or n
                print("  [" .. unit .. "] " .. tostring(n) .. " -> " .. tostring(full))
            end
        end
    elseif msg == "debug" then
        HuntListaDB.debug = not HuntListaDB.debug
        print("debug: " .. (HuntListaDB.debug and "ON" or "OFF"))
    else
        print("|cff00ff00Hunt Lista|r: /hl  /hl status  /hl killer  /hl death  /hl test")
    end
end

ns.HL = HL
