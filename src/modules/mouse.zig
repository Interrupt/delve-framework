const std = @import("std");
const ziglua = @import("ziglua");
const input = @import("../systems/input.zig");


const Lua = ziglua.Lua;

pub fn makeLib(lua: *Lua) i32 {
    const funcs = [_]ziglua.FnReg{
        .{ .name = "position", .func = ziglua.wrap(position) },
        .{ .name = "button", .func = ziglua.wrap(button) },
    };

    lua.newLib(&funcs);
    return 1;
}

// Get Mouse Position
fn position(lua: *Lua) i32 {
    const mouse_pos = input.getMousePosition();

    // Return the x & y positions!
    lua.pushNumber(mouse_pos.x);
    lua.pushNumber(mouse_pos.y);
    return 2;
}

// Get Mouse Button Pressed State
fn button(lua: *Lua) i32 {
    var button_idx = @as(u5, @truncate(@as(u32, @intFromFloat(lua.toNumber(1) catch 0))));

    const is_pressed = input.isMouseButtonPressed(button_idx);
    lua.pushBoolean(is_pressed);
    return 1;
}
