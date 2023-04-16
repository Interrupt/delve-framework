const std = @import("std");
const ziglua = @import("ziglua");

const Lua = ziglua.Lua;

fn luaOpenFunction(lua: *Lua) i32 {
    const funcs = [_]ziglua.FnReg{
        .{ .name = "clear", .func = ziglua.wrap(clear) },
    };

    lua.newLib(&funcs);
    return 1;
}

pub fn registerModule(lua: *Lua) void {
    lua.requireF("draw", ziglua.wrap(luaOpenFunction), true);
}

pub fn clear(lua: *Lua) i32 {
    _ = lua;
    std.debug.print("Draw Module: clear\n", .{});
    return 1;
}
