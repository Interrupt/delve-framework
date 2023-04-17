const std = @import("std");
const ziglua = @import("ziglua");

const Lua = ziglua.Lua;

fn makeLib(lua: *Lua) i32 {
    const funcs = [_]ziglua.FnReg{
        .{ .name = "position", .func = ziglua.wrap(position) },
    };

    lua.newLib(&funcs);
    return 1;
}

pub fn openModule(lua: *Lua) void {
    lua.requireF("input.mouse", ziglua.wrap(makeLib), true);
}

// Get Mouse Position
fn position(lua: *Lua) i32 {
    // Return the x & y positions!
    lua.pushNumber(0);
    lua.pushNumber(0);
    return 1;
}
