const std = @import("std");
const debug = @import("../debug.zig");
const ziglua = @import("ziglua");
const input = @import("../platform/input.zig");

// const Lua = ziglua.Lua;

// pub fn makeLib(lua: *Lua) i32 {
//     const funcs = [_]ziglua.FnReg{
//         .{ .name = "key", .func = ziglua.wrap(isKeyPressed) },
//     };
//
//     lua.newLib(&funcs);
//     return 1;
// }

pub fn key(key_idx: usize) bool {
   return input.isKeyPressed(key_idx);
}
