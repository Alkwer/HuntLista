const { test } = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');
const { parseDataLua, generateLua, validateNick, createDataStore } = require('../data');
const { runLua, lua, to_luastring, to_jsstring } = require('./lua');
const original = fs.readFileSync(path.join(__dirname, '../../HuntLista/Data.lua'), 'utf8');
const plain = value => JSON.parse(JSON.stringify(value));
const player = { reason: 'Powód', addedBy: 'tester', addedAt: '2026-11-12', note: '' };
const withKillDefaults = entry => ({ kills: '0', lastKillBy: '', lastKillAt: '', ...entry });

function github(content = original) {
    const fake = { content, sha: '1', writes: [], reads: 0, readError: null, writeError: null };
    fake.client = { rest: { repos: {
        async getContent() {
            fake.reads++;
            if (fake.readError) throw fake.readError;
            return { data: { type: 'file', encoding: 'base64', sha: fake.sha,
                content: Buffer.from(fake.content).toString('base64') } };
        },
        async createOrUpdateFileContents(request) {
            if (fake.writeError) throw fake.writeError;
            assert.equal(request.sha, fake.sha, 'write must use the SHA of its source data');
            fake.writes.push(request);
            fake.content = Buffer.from(request.content, 'base64').toString('utf8');
            fake.sha = String(Number(fake.sha) + 1);
        },
    } } };
    fake.store = createDataStore(fake.client, { owner: 'test', repo: 'test', path: 'Data.lua' });
    return fake;
}

test('existing Data.lua round-trips all players and Unicode without executing it', () => {
    const data = parseDataLua(original);
    assert.deepEqual(plain(parseDataLua('\uFEFF' + original.replace(/\n/g, '\r\n'))), plain(data));
    const expected = plain(data);
    for (const [name, entry] of Object.entries(expected.players)) expected.players[name] = withKillDefaults(entry);
    assert.deepEqual(plain(parseDataLua(generateLua(data))), expected);
});

test('every Lua string field preserves payloads, control characters, Unicode and trailing backslashes', () => {
    const payloads = [
        '" .. (function() HUNTLISTA_AUDIT_MARKER = true; return "Audit" end)() .. "',
        '\\", exploit = (function() HUNTLISTA_AUDIT_MARKER = true end)(), --',
        'Zażółć gęślą jaźń — Tollwütige Fledermaus 🏹',
        Array.from({ length: 32 }, (_, i) => String.fromCharCode(i) + '123').join('') + '\x7f9',
        'trailing\\', '\\123', '"quoted"\r\nnew line', '__proto__', 'constructor',
    ];
    for (const text of payloads) {
        const data = { version: text, lastUpdate: text, updatedBy: text, players: Object.create(null) };
        data.players[text] = { reason: text, addedBy: text, addedAt: text, note: text,
            kills: '7', lastKillBy: text, lastKillAt: text };
        const generated = generateLua(data);
        assert.deepEqual(plain(parseDataLua(generated)), plain(data));
        // The updater's existing counter must still recognize exactly one player.
        assert.equal((generated.match(/\["[^"]+"\]\s*=/g) || []).length, 1);
        runLua(generated + '\nassert(HUNTLISTA_AUDIT_MARKER == nil)', state => {
            lua.lua_getglobal(state, to_luastring('HuntLista_Data'));
            for (const key of ['version', 'lastUpdate', 'updatedBy']) {
                lua.lua_getfield(state, -1, to_luastring(key));
                assert.equal(to_jsstring(lua.lua_tostring(state, -1)), text);
                lua.lua_pop(state, 1);
            }
            lua.lua_getfield(state, -1, to_luastring('players'));
            lua.lua_getfield(state, -1, to_luastring(text));
            for (const key of ['reason', 'addedBy', 'addedAt', 'note', 'lastKillBy', 'lastKillAt']) {
                lua.lua_getfield(state, -1, to_luastring(key));
                assert.equal(to_jsstring(lua.lua_tostring(state, -1)), text);
                lua.lua_pop(state, 1);
            }
        });
    }
});

test('parser rejects executable code, duplicate keys and unsupported schemas', () => {
    for (const content of [
        original + '\nHUNTLISTA_AUDIT_MARKER = true',
        original.replace('players = {', 'players = (function() return {} end)(), ignored = {'),
        original.replace('players = {', 'players = {}, players = {'),
        original.replace('reason = "",', 'reason = "", reason = "duplicate",'),
        original.replace('reason = "",', 'unexpected = "",'),
        original.replace('reason = "",', 'reason = 42,'),
        original.replace('players = {', 'players = { "anonymous",'),
        original.replace('HuntLista_Lookup = {}', 'HuntLista_Lookup = ""'),
        original.replace('HuntLista_Lookup = {}', ''),
        original.replace('reason = "",', 'reason = "\\255",'),
        original.slice(0, -20),
    ]) assert.throws(() => parseDataLua(content));
});

test('new nick validation preserves spaces and Unicode, rejects empty/control/oversized input', () => {
    assert.equal(validateNick('  Mega Chad  '), 'Mega Chad');
    assert.equal(validateNick('Tollwütige Fledermaus'), 'Tollwütige Fledermaus');
    for (const nick of ['', '  ', 'nick\nname', 'a'.repeat(65), null]) assert.throws(() => validateNick(nick));
});

test('long Lua strings normalize line endings like Lua, while escaped CRLF stays literal', () => {
    const chunk = reason => `HuntLista_Data = { version = "v", lastUpdate = "now", updatedBy = "test", players = {
        ["Audit"] = { reason = ${reason} }
    }}\nHuntLista_Lookup = {}`;
    for (const ending of ['\r\n', '\n\r', '\r', '\n']) {
        const content = chunk(`[=[first${ending}second]=]`);
        runLua(content + '\nassert(HuntLista_Data.players.Audit.reason == "first" .. string.char(10) .. "second")');
        assert.equal(parseDataLua(content).players.Audit.reason, 'first\nsecond');
    }
    assert.equal(parseDataLua(chunk('"first\\013\\010second"')).players.Audit.reason, 'first\r\nsecond');
    const duplicateKeys = chunk('"ok"').replace('["Audit"] = { reason = "ok" }',
        '[ [[first\r\nsecond]] ] = {}, [ [=[first\nsecond]=] ] = {}');
    assert.throws(() => parseDataLua(duplicateKeys), /Powtórzony klucz/);
});

test('fresh store preserves the remote list when adding and removing without local state', async () => {
    const fake = github();
    const before = plain(await fake.store.read());
    const result = await fake.store.update(data => { data.players['New Player'] = player; });
    assert.equal(Object.keys(result.data.players).length, Object.keys(before.players).length + 1);
    for (const [name, entry] of Object.entries(before.players)) {
        before.players[name] = withKillDefaults(entry);
        assert.deepEqual(plain(result.data.players[name]), before.players[name]);
    }
    const restarted = createDataStore(fake.client, { owner: 'test', repo: 'test', path: 'Data.lua' });
    await restarted.update(data => { delete data.players['New Player']; });
    assert.deepEqual(plain((await restarted.read()).players), before.players);
});

test('every change reads current remote data and concurrent local commands are serialized', async () => {
    const fake = github();
    await fake.store.read();
    const external = parseDataLua(fake.content);
    external.players['External Edit'] = player;
    fake.content = generateLua(external);
    fake.sha = '2';
    await Promise.all(['First Player', 'Second Player'].map(name =>
        fake.store.update(data => { data.players[name] = player; })));
    assert.equal(Object.keys((await fake.store.read()).players).length, Object.keys(parseDataLua(original).players).length + 3);
    assert.deepEqual(fake.writes.map(write => write.sha), ['2', '3']);
});

test('failed reads and invalid remote data cannot publish an empty list', async () => {
    for (const status of [403, 404, 500]) {
        const fake = github();
        fake.readError = Object.assign(new Error('Read failed'), { status });
        await assert.rejects(fake.store.update(data => { data.players.New = player; }));
        assert.equal(fake.writes.length, 0);
    }
    const fake = github('invalid Lua');
    await assert.rejects(fake.store.update(data => { data.players.New = player; }));
    assert.equal(fake.writes.length, 0);
});
test('conflict/write failure does not retain a pending mutation; next command reads again', async () => {
    const fake = github();
    fake.writeError = Object.assign(new Error('Conflict'), { status: 409 });
    await assert.rejects(fake.store.update(data => { data.players.Failed = player; }));
    fake.writeError = null;
    await fake.store.update(data => { data.players.Success = player; });
    assert.equal(fake.reads, 2);
    assert.equal(Object.hasOwn(parseDataLua(fake.content).players, 'Failed'), false);
    assert.ok(parseDataLua(fake.content).players.Success);
});

test('no-op removal does not publish or bump the version', async () => {
    const fake = github();
    const result = await fake.store.update(() => false);
    assert.equal(result.changed, false);
    assert.equal(result.data.version, parseDataLua(original).version);
    assert.equal(fake.writes.length, 0);
});
