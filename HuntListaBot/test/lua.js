const assert = require('node:assert/strict');
const { lua, lauxlib, lualib, to_luastring, to_jsstring } = require('fengari');

function runLua(source, inspect = () => {}) {
    const state = lauxlib.luaL_newstate();
    lualib.luaL_openlibs(state);
    try {
        let status = lauxlib.luaL_loadstring(state, to_luastring(source));
        if (status === lua.LUA_OK) status = lua.lua_pcall(state, 0, 0, 0);
        assert.equal(status, lua.LUA_OK, status === lua.LUA_OK ? '' : to_jsstring(lua.lua_tostring(state, -1)));
        inspect(state);
    } finally {
        lua.lua_close(state);
    }
}

module.exports = { runLua, lua, to_luastring, to_jsstring };
