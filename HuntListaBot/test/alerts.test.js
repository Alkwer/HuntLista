const { test } = require('node:test');
const fs = require('node:fs');
const path = require('node:path');
const { runLua } = require('./lua');
const { luaString } = require('../data');
const files = ['Core.lua', 'Alerts.lua', 'Kills.lua'];
const sources = files.map(file => luaString(fs.readFileSync(path.join(__dirname, '../../HuntLista', file), 'utf8')));

const setup = `
frames, logs, timers, units, plates = {}, {}, {}, {}, {}
now, sounds, fallbackReads = 100, 0, 0
SlashCmdList = {}
issecretvalue = function(value) return value == 'HIDDEN' end
strlower = function(s) assert(not issecretvalue(s)); return string.lower(s) end
strtrim = function(s) assert(not issecretvalue(s)); return (s:gsub('^%s+', ''):gsub('%s+$', '')) end
wipe = function(t) for k in pairs(t) do t[k] = nil end end
function widget(parent)
    local w = { parent = parent, scripts = {}, events = {}, shown = false, children = {} }
    function w:RegisterEvent(e) self.events[e] = true end
    function w:SetScript(e, fn) self.scripts[e] = fn end
    function w:SetParent(p) self.parent = p end
    function w:Show() self.shown = true end
    function w:Hide() self.shown = false end
    function w:IsShown() return self.shown end
    function w:CreateTexture() local t = widget(self); self.children[#self.children+1] = t; return t end
    return setmetatable(w, { __index = function(_, key)
        if key:match('^Set') or key == 'ClearAllPoints' then return function() end end
    end })
end
CreateFrame = function(_, name, parent)
    local f = widget(parent); frames[#frames+1] = f; if name then _G[name] = f end; return f
end
TargetFrame, UIParent = widget(), widget()
C_Timer = { After = function(seconds, fn) timers[#timers+1] = fn end }
Constants = { CharacterNameSeparatorConsts = { CHARACTERNAME_SURNAME_SEPARATOR = ' ' } }
UnitExists = function(unit) assert(not issecretvalue(unit)); return units[unit] ~= nil end
UnitIsPlayer = function(unit) return units[unit].player ~= false end
UnitIsEnemy = function(_, unit) return units[unit].enemy ~= false end
UnitNameUnmodified = function(unit)
    local u = units[unit]; if u then return u.first, u.surname end
end
UnitName = function(unit) fallbackReads = fallbackReads + 1; return 'Mega', 'Enemy' end
C_NamePlate = { GetNamePlateForUnit = function(unit) assert(not issecretvalue(unit)); return plates[unit] end }
GetTime = function() return now end
time = GetTime
print = function(msg) logs[#logs+1] = msg end
HuntListaDB = {}
HuntLista_Lookup = {}
HuntLista_Data = { version = 'test', players = {
    ['Mega Enemy'] = {}, ['Mega Rival'] = {}, ['Zed Alpha-Beta'] = {},
    ['Case Conflict'] = {}, ['case conflict'] = {}, ['Solo'] = {},
} }
local ns = {}
${sources.map((source, i) => `assert(load(${source}, '${files[i]}'))('HuntLista', ns)`).join('\n')}
HuntLista.PlayHuntSound = function() sounds = sounds + 1 end
function event(e, ...)
    for _,f in ipairs(frames) do if f.events[e] then f.scripts.OnEvent(f, e, ...) end end
end
event('ADDON_LOADED', 'HuntLista')
event('PLAYER_LOGIN')
logs = {}
function setUnit(token, first, surname)
    units[token] = { first = first, surname = surname }
    if token:match('^nameplate') then plates[token] = { UnitFrame = widget() } end
end
function targetIcons()
    local count = 0
    for _,f in ipairs(frames) do if f.parent == TargetFrame and f.shown then count = count + 1 end end
    return count
end
function command(text) SlashCmdList.HUNTLISTA(text) end
`;

function scenario(code) { runLua(setup + '\n' + code); }

test('unit alerts require the full exact name, retain surnames and reject ambiguity', () => {
    scenario(`
        setUnit('target', 'Mega', 'Innocent')
        event('PLAYER_TARGET_CHANGED')
        assert(#logs == 0 and sounds == 0 and targetIcons() == 0)
        setUnit('target', 'Mega', 'Enemy')
        event('PLAYER_TARGET_CHANGED')
        assert(#logs == 1 and logs[1]:find('Mega Enemy', 1, true) and targetIcons() == 1)
        setUnit('target', 'Mega', 'Rival')
        event('PLAYER_TARGET_CHANGED')
        assert(#logs == 2 and sounds == 2)
        setUnit('target', 'Zed', 'Alpha-Beta')
        event('PLAYER_TARGET_CHANGED')
        assert(logs[3]:find('Zed Alpha-Beta', 1, true))
        setUnit('target', 'Case', 'Conflict')
        event('PLAYER_TARGET_CHANGED')
        assert(#logs == 3 and targetIcons() == 0)
        setUnit('target', 'Solo', nil)
        event('PLAYER_TARGET_CHANGED')
        assert(#logs == 4 and targetIcons() == 1)
    `);
});

test('one target icon persists with the same target and clears for an unlisted or missing target', () => {
    scenario(`
        setUnit('target', 'Mega', 'Enemy')
        event('PLAYER_TARGET_CHANGED')
        local count = #frames
        for i = 1, 5 do event('PLAYER_TARGET_CHANGED') end
        now = now + 10
        for _,callback in ipairs(timers) do callback() end
        assert(targetIcons() == 1 and #frames == count and sounds == 1)
        setUnit('target', 'Other', 'Person')
        event('PLAYER_TARGET_CHANGED')
        assert(targetIcons() == 0)
        setUnit('target', 'Mega', 'Enemy')
        event('PLAYER_TARGET_CHANGED')
        assert(targetIcons() == 1)
        units.target = nil
        event('PLAYER_TARGET_CHANGED')
        assert(targetIcons() == 0)
    `);
});

test('alert toggles are independent of icons, and disabled addon and icon settings are respected', () => {
    scenario(`
        HuntListaDB.alertOnTarget = false
        HuntListaDB.alertOnMouseover = false
        HuntListaDB.alertOnNameplate = false
        setUnit('target', 'Mega', 'Enemy'); event('PLAYER_TARGET_CHANGED')
        setUnit('mouseover', 'Mega', 'Enemy'); event('UPDATE_MOUSEOVER_UNIT')
        setUnit('nameplate1', 'Mega', 'Enemy'); event('NAME_PLATE_UNIT_ADDED', 'nameplate1')
        local icon = plates.nameplate1.UnitFrame.HuntListaIcon
        assert(#logs == 0 and sounds == 0 and targetIcons() == 1 and icon.shown)
        HuntListaDB.alertOnNameplate = true
        event('NAME_PLATE_UNIT_ADDED', 'nameplate1')
        assert(#logs == 1 and sounds == 1)
        HuntListaDB.enabled = false
        event('PLAYER_TARGET_CHANGED'); event('NAME_PLATE_UNIT_ADDED', 'nameplate1')
        assert(targetIcons() == 0 and not icon.shown and #logs == 1)
        HuntListaDB.enabled = true; HuntListaDB.showIcon = false
        event('PLAYER_TARGET_CHANGED'); event('NAME_PLATE_UNIT_ADDED', 'nameplate1')
        assert(targetIcons() == 0 and not icon.shown)
    `);
});

test('nameplate removal and frame reuse clear stale icons even after the plate API loses the unit', () => {
    scenario(`
        setUnit('nameplate1', 'Mega', 'Enemy'); event('NAME_PLATE_UNIT_ADDED', 'nameplate1')
        local plate = plates.nameplate1
        assert(plate.UnitFrame.HuntListaIcon.shown)
        plates.nameplate1 = nil
        event('NAME_PLATE_UNIT_REMOVED', 'nameplate1')
        assert(not plate.UnitFrame.HuntListaIcon.shown)
        setUnit('nameplate2', 'Other', 'Person'); plates.nameplate2 = plate
        event('NAME_PLATE_UNIT_ADDED', 'nameplate2')
        assert(not plate.UnitFrame.HuntListaIcon.shown)
    `);
});

test('hidden name parts and tokens are skipped without falling back to another identity API', () => {
    scenario(`
        setUnit('target', 'Mega', 'Enemy'); event('PLAYER_TARGET_CHANGED')
        units.target.surname = 'HIDDEN'; event('PLAYER_TARGET_CHANGED')
        assert(targetIcons() == 0)
        setUnit('nameplate1', 'HIDDEN', 'Enemy'); event('NAME_PLATE_UNIT_ADDED', 'nameplate1')
        assert(not rawget(plates.nameplate1.UnitFrame, 'HuntListaIcon'))
        HuntLista:CheckUnit('HIDDEN')
        assert(HuntLista:GetInfo('HIDDEN') == nil and fallbackReads == 0 and #logs == 1)
        UnitNameUnmodified = function() error('Unavailable') end
        event('PLAYER_TARGET_CHANGED'); assert(fallbackReads == 0)
    `);
});

test('friendly players and NPCs are excluded except for the explicit friendly test mode', () => {
    scenario(`
        setUnit('target', 'Mega', 'Enemy'); units.target.enemy = false
        event('PLAYER_TARGET_CHANGED'); assert(targetIcons() == 0 and #logs == 0)
        HuntListaDB.testMode = true
        event('PLAYER_TARGET_CHANGED'); assert(targetIcons() == 1 and #logs == 1)
        units.target.player = false
        event('PLAYER_TARGET_CHANGED'); assert(targetIcons() == 0 and #logs == 1)
    `);
});

test('manual kills require full names and reset typos cannot clear local history', () => {
    scenario(`
        command('kill Mega'); command('kill Case Conflict')
        assert(HuntLista:GetTotalKills() == 0)
        command('kill Mega Enemy'); command('kill Zed Alpha-Beta')
        assert(HuntLista:GetTotalKills() == 2)
        for _,text in ipairs({'killresetfoo', 'resetkillsfoo', 'killreset', 'resetkills', 'killreset all', 'killreset Mega'}) do
            command(text); assert(HuntLista:GetTotalKills() == 2, text)
        end
        command('killreset Zed Alpha-Beta'); assert(HuntLista:GetTotalKills() == 1)
        command('killreset all confirm'); assert(HuntLista:GetTotalKills() == 0)
    `);
});

test('/hl reload clearly instructs a game UI reload instead of claiming disk data was reloaded', () => {
    scenario(`
        command('reload')
        assert(#logs == 1 and logs[1]:find('/reload', 1, true) and logs[1]:find('dysku', 1, true))
    `);
});
