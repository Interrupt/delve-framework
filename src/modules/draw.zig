const std = @import("std");
const ziglua = @import("ziglua");

const Lua = ziglua.Lua;

pub fn makeLib(lua: *Lua) i32 {
    const funcs = [_]ziglua.FnReg{
        .{ .name = "clear", .func = ziglua.wrap(clear) },
        .{ .name = "line", .func = ziglua.wrap(line) },
    };

    lua.newLib(&funcs);
    return 1;
}

fn clear(lua: *Lua) i32 {
    var color_idx = lua.toNumber(1) catch 0;
    std.debug.print("Draw Module: clear {d}\n", .{color_idx});
    return 1;
}

fn line(lua: *Lua) i32 {
    var start_x = lua.toNumber(1) catch 0;
    var start_y = lua.toNumber(2) catch 0;
    var end_x = lua.toNumber(3) catch 0;
    var end_y = lua.toNumber(4) catch 0;
    var color_idx = lua.toNumber(5) catch 0;
    std.debug.print("Draw Module: line({d},{d},{d},{d},{d})\n", .{start_x, start_y, end_x, end_y, color_idx});
    return 1;
}
