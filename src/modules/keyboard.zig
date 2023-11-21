const std = @import("std");
const debug = @import("../debug.zig");
const ziglua = @import("ziglua");
const input = @import("../backend/input.zig");

const Lua = ziglua.Lua;

pub fn makeLib(lua: *Lua) i32 {
    const funcs = [_]ziglua.FnReg{
        .{ .name = "key", .func = ziglua.wrap(isKeyPressed) },
    };

    lua.newLib(&funcs);
    return 1;
}

fn isKeyPressed(lua: *Lua) i32 {
    var key_idx = @as(usize, @intFromFloat(lua.toNumber(1) catch 0));

    const pressed = input.isKeyPressed(key_idx);
    lua.pushBoolean(pressed);
    return 1;
}
