pub const c = @cImport({
    @cInclude("luaconf.h");
    @cInclude("lua.h");
    @cInclude("lualib.h");
    @cInclude("lauxlib.h");
});

pub fn init() void {
    const LuaState = c.luaL_newstate();
    c.luaL_openlibs(LuaState);
    c.luaL_dostring(LuaState, "print('Hello from Lua!')");
}
