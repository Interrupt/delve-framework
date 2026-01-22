const std = @import("std");
const delve = @import("delve");
const app = delve.app;

var gpa = std.heap.GeneralPurposeAllocator(.{}){};

const lua_module = delve.module.lua_simple;
const fps_module = delve.module.fps_counter;

// This example shows how to integrate with lua scripting

pub fn main() !void {
    // Pick the allocator to use depending on platform
    const builtin = @import("builtin");
    if (builtin.os.tag == .wasi or builtin.os.tag == .emscripten) {
        // Web builds hack: use the C allocator to avoid OOM errors
        // See https://github.com/ziglang/zig/issues/19072
        try delve.init(std.heap.c_allocator);
    } else {
        // Using the default allocator will let us detect memory leaks
        try delve.init(delve.mem.createDefaultAllocator());
    }

    // The simple lua module emulates a Pico-8 style app.
    // It will call the lua file's _init on startup, _update on tick, _draw when drawing,
    // and _shutdown at the end.
    try lua_module.registerModule("assets/main.lua");

    try fps_module.registerModule();

    try app.start(app.AppConfig{ .title = "Delve Framework - Lua Example" });
}
