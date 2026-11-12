-- ============================================================
-- Hunt Lista - Powiadomienia o zabojstwach dla gildii z addonem
-- ============================================================

local HL = HuntLista
local PREFIX = "HuntListaKill"
local COOLDOWN = 3
local registered = false
local recentSent = {}
local recentReceived = {}

local function PlainText(value)
    return (not issecretvalue or not issecretvalue(value)) and type(value) == "string"
end

local function ValidName(name, limit)
    return PlainText(name) and #name > 0 and #name <= limit
        and not name:find("[%c|]") and strtrim(name) == name
end

local function Enabled()
    return HuntListaDB and HuntListaDB.enabled ~= false and HuntListaDB.guildKillAlerts ~= false
end

local function Prune(entries, now)
    for key, at in pairs(entries) do
        if now - at >= COOLDOWN then entries[key] = nil end
    end
end

local function ShowKill(killer, victim)
    local msg = "|cff00ff00[HUNT - GILDIA]|r Zabojstwo: " .. killer .. " -> |cffff6666" .. victim .. "|r"
    RaidNotice_AddMessage(RaidWarningFrame, msg, ChatTypeInfo["RAID_WARNING"])
    print(msg)
    if HL.PlayHuntSound then
        HL:PlayHuntSound()
    elseif HuntListaDB and HuntListaDB.sound then
        pcall(function() PlaySound(SOUNDKIT.RAID_WARNING, "Master") end)
    end
end

local function Failure(reason)
    HL.guildKillStatus = reason
    print("|cffffaa00Hunt Lista|r Powiadomienie gildii: " .. reason)
end

function HL:InitGuildKills()
    if registered then return true end
    if not C_ChatInfo or not C_ChatInfo.RegisterAddonMessagePrefix or not C_ChatInfo.SendAddonMessage then
        Failure("brak API komunikacji addonow")
        return false
    end
    local ok, result = pcall(C_ChatInfo.RegisterAddonMessagePrefix, PREFIX)
    if not ok or (result ~= 0 and result ~= 1 and result ~= true) then
        Failure("nie udalo sie zarejestrowac kanalu")
        return false
    end
    registered = true
    HL.guildKillStatus = "gotowe"
    return true
end

function HL:BroadcastGuildKill(name)
    if not Enabled() or not IsInGuild() or not ValidName(name, 128) then return false end
    local normalized = HL.NormalizeName and HL:NormalizeName(name) or name
    local info = HuntLista_Lookup and HuntLista_Lookup[strlower(normalized)]
    if not info or not ValidName(info.name, 128) then return false end
    local victim = info.name
    local key = strlower(victim)
    local now = GetTime()
    Prune(recentSent, now)
    if recentSent[key] then return false end
    if not registered and not HL:InitGuildKills() then return false end

    recentSent[key] = now
    local ok, result = pcall(C_ChatInfo.SendAddonMessage, PREFIX, "1\t" .. victim, "GUILD")
    if not ok or (result ~= 0 and result ~= true) then
        recentSent[key] = nil
        Failure("nie wyslano wiadomosci (" .. tostring(result) .. ")")
        return false
    end
    HL.guildKillStatus = "gotowe"
    return true
end

local frame = CreateFrame("Frame")
frame:RegisterEvent("PLAYER_LOGIN")
frame:RegisterEvent("CHAT_MSG_ADDON")
frame:SetScript("OnEvent", function(_, event, prefix, message, channel, sender)
    if event == "PLAYER_LOGIN" then
        HL:InitGuildKills()
        return
    end
    if not Enabled() or not IsInGuild() then return end
    if not PlainText(prefix) or not PlainText(channel) or prefix ~= PREFIX or channel ~= "GUILD" then return end
    if not PlainText(message) or #message > 130 or not ValidName(sender, 192) then return end
    local victim = message:match("^1\t([^\t]+)$")
    if not ValidName(victim, 128) then return end

    local now = GetTime()
    Prune(recentSent, now)
    Prune(recentReceived, now)
    local victimKey = strlower(victim)
    if recentSent[victimKey] then return end
    local key = strlower(sender) .. "\t" .. victimKey
    if recentReceived[key] then return end
    recentReceived[key] = now
    ShowKill(sender, victim)
end)
