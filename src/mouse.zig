const std = @import("std");
const ziglua = @import("ziglua");

const Lua = ziglua.Lua;

fn luaOpenFunction(lua: *Lua) i32 {
    const funcs = [_]ziglua.FnReg{};

    lua.newLib(&funcs);
    return 1;
}

pub fn registerModule(lua: *Lua) void {
    lua.requireF("input.mouse", ziglua.wrap(luaOpenFunction), true);
}

